-- Eventify MVP schema: cities, profiles, categories, interests, organizers,
-- events, saved events, reports, push tokens and a moderation audit log.
-- Row-level security is enabled on every table; see the policies below.

create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

create type public.user_role as enum ('user', 'admin');

create type public.event_status as enum (
  'draft', 'pending', 'approved', 'rejected', 'cancelled', 'archived'
);

create type public.report_reason as enum (
  'incorrect_info', 'fake_event', 'spam', 'inappropriate', 'event_cancelled', 'other'
);

create type public.report_status as enum ('open', 'actioned', 'dismissed');

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.cities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  country_code char(2) not null,
  timezone text not null,
  center extensions.geography(Point, 4326) not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_path text,
  city_id uuid references public.cities (id) on delete set null,
  role public.user_role not null default 'user',
  is_suspended boolean not null default false,
  notify_reminders boolean not null default true,
  notify_updates boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  icon text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.user_interests (
  user_id uuid not null references public.profiles (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, category_id)
);

create table public.organizers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  website text check (website ~* '^https?://'),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

-- Contact details stay private to the organizer's creator and admins.
create table public.organizer_contacts (
  organizer_id uuid primary key references public.organizers (id) on delete cascade,
  email text,
  phone text,
  check (email is not null or phone is not null)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null check (char_length(title) between 3 and 140),
  description text not null default '',
  image_path text,
  category_id uuid not null references public.categories (id),
  city_id uuid not null references public.cities (id),
  organizer_id uuid references public.organizers (id) on delete set null,
  submitted_by uuid references public.profiles (id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  venue_name text not null,
  address text not null,
  location extensions.geography(Point, 4326),
  is_free boolean not null default true,
  price_text text,
  ticket_url text check (ticket_url ~* '^https?://'),
  status public.event_status not null default 'pending',
  rejection_reason text,
  save_count integer not null default 0,
  view_count integer not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(title, '')), 'A')
    || setweight(to_tsvector('simple', coalesce(venue_name, '')), 'B')
    || setweight(to_tsvector('simple', coalesce(address, '')), 'B')
    || setweight(to_tsvector('simple', coalesce(description, '')), 'C')
  ) stored,
  check (ends_at >= starts_at)
);

create index events_feed_idx on public.events (city_id, status, starts_at);
create index events_category_idx on public.events (category_id);
create index events_submitted_by_idx on public.events (submitted_by);
create index events_organizer_idx on public.events (organizer_id);
create index events_location_idx on public.events using gist (location);
create index events_search_idx on public.events using gin (search);
create index events_title_trgm_idx on public.events using gin (title extensions.gin_trgm_ops);

create table public.saved_events (
  user_id uuid not null references public.profiles (id) on delete cascade,
  event_id uuid not null references public.events (id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, event_id)
);

create index saved_events_event_idx on public.saved_events (event_id);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  reason public.report_reason not null,
  details text check (char_length(details) <= 1000),
  status public.report_status not null default 'open',
  resolved_by uuid references public.profiles (id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index reports_open_idx on public.reports (status, created_at);

create table public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

create index push_tokens_user_idx on public.push_tokens (user_id);

create table public.event_audit (
  id bigint generated always as identity primary key,
  event_id uuid not null references public.events (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  from_status public.event_status,
  to_status public.event_status not null,
  note text,
  created_at timestamptz not null default now()
);

create index event_audit_event_idx on public.event_audit (event_id, created_at);

-- ---------------------------------------------------------------------------
-- Helper functions
-- ---------------------------------------------------------------------------

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and not is_suspended
  );
$$;

create function public.is_suspended()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select is_suspended from public.profiles where id = auth.uid()),
    false
  );
$$;

-- True when the statement comes from an app user (anon or signed in) rather
-- than the service role, a migration, or a security-definer function.
create function public.is_client_request()
returns boolean
language sql
stable
set search_path = ''
as $$
  select current_user in ('anon', 'authenticated');
$$;

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Create a profile for every new auth user.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_path)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Only admins may change roles or suspensions.
create function public.guard_profile_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.is_client_request() and not public.is_admin()
     and (new.role is distinct from old.role
          or new.is_suspended is distinct from old.is_suspended) then
    raise exception 'Only admins can change role or suspension'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_guard
  before update on public.profiles
  for each row execute function public.guard_profile_changes();

create trigger events_set_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

-- Submissions always enter moderation as pending, and only admins move them
-- through the review states (FR-013).
create function public.guard_event_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.is_client_request() and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.status := 'pending';
      new.submitted_by := auth.uid();
      new.rejection_reason := null;
      new.save_count := 0;
      new.view_count := 0;
      new.published_at := null;
    elsif new.status is distinct from old.status
       or new.submitted_by is distinct from old.submitted_by
       or new.rejection_reason is distinct from old.rejection_reason
       or new.save_count is distinct from old.save_count
       or new.view_count is distinct from old.view_count
       or new.published_at is distinct from old.published_at then
      raise exception 'Only admins can change moderation fields'
        using errcode = '42501';
    end if;
  end if;

  if new.status = 'approved' and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$$;

create trigger events_guard
  before insert or update on public.events
  for each row execute function public.guard_event_changes();

create function public.log_event_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.event_audit (event_id, actor_id, from_status, to_status, note)
    values (
      new.id,
      auth.uid(),
      case when tg_op = 'UPDATE' then old.status end,
      new.status,
      new.rejection_reason
    );
  end if;
  return null;
end;
$$;

create trigger events_audit
  after insert or update of status on public.events
  for each row execute function public.log_event_status();

create function public.update_save_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.events set save_count = save_count + 1 where id = new.event_id;
  else
    update public.events set save_count = greatest(save_count - 1, 0) where id = old.event_id;
  end if;
  return null;
end;
$$;

create trigger saved_events_count
  after insert or delete on public.saved_events
  for each row execute function public.update_save_count();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.cities enable row level security;
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.user_interests enable row level security;
alter table public.organizers enable row level security;
alter table public.organizer_contacts enable row level security;
alter table public.events enable row level security;
alter table public.saved_events enable row level security;
alter table public.reports enable row level security;
alter table public.push_tokens enable row level security;
alter table public.event_audit enable row level security;

-- Cities and categories: anyone reads active rows, admins manage.
create policy "Active cities are public" on public.cities
  for select to anon, authenticated using (is_active or public.is_admin());
create policy "Admins manage cities" on public.cities
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Active categories are public" on public.categories
  for select to anon, authenticated using (is_active or public.is_admin());
create policy "Admins manage categories" on public.categories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Profiles: users see and edit their own row; admins see and edit all.
create policy "Users read own profile" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "Users update own profile" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- Interests, saved events and push tokens belong to their user.
create policy "Users manage own interests" on public.user_interests
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "Users manage own saved events" on public.saved_events
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "Users manage own push tokens" on public.push_tokens
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Organizers: names are public; creators and admins edit.
create policy "Organizers are public" on public.organizers
  for select to anon, authenticated using (true);
create policy "Users create organizers" on public.organizers
  for insert to authenticated
  with check (created_by = auth.uid() and not public.is_suspended());
create policy "Creators and admins update organizers" on public.organizers
  for update to authenticated
  using (created_by = auth.uid() or public.is_admin())
  with check (created_by = auth.uid() or public.is_admin());
create policy "Admins delete organizers" on public.organizers
  for delete to authenticated using (public.is_admin());

create policy "Creators and admins manage organizer contacts" on public.organizer_contacts
  for all to authenticated
  using (
    public.is_admin()
    or exists (select 1 from public.organizers o
               where o.id = organizer_id and o.created_by = auth.uid())
  )
  with check (
    public.is_admin()
    or exists (select 1 from public.organizers o
               where o.id = organizer_id and o.created_by = auth.uid())
  );

-- Events: approved events are public; submitters see their own; admins see all.
create policy "Approved events are public" on public.events
  for select to anon, authenticated
  using (status = 'approved' or submitted_by = auth.uid() or public.is_admin());
create policy "Users submit events" on public.events
  for insert to authenticated
  with check (not public.is_suspended());
create policy "Submitters edit pending events, admins edit all" on public.events
  for update to authenticated
  using ((submitted_by = auth.uid() and status = 'pending') or public.is_admin())
  with check ((submitted_by = auth.uid() and status = 'pending') or public.is_admin());
create policy "Submitters delete pending events, admins delete all" on public.events
  for delete to authenticated
  using ((submitted_by = auth.uid() and status in ('draft', 'pending')) or public.is_admin());

-- Reports: users file and read their own; admins triage.
create policy "Users file reports" on public.reports
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'open' and not public.is_suspended());
create policy "Users read own reports, admins read all" on public.reports
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "Admins update reports" on public.reports
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Admins delete reports" on public.reports
  for delete to authenticated using (public.is_admin());

create policy "Admins read the audit log" on public.event_audit
  for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Home feed (SRS section 23): relevance = proximity + interest + soonness + popularity
-- ---------------------------------------------------------------------------

create function public.get_feed(
  p_city_id uuid,
  p_lat double precision default null,
  p_lng double precision default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  slug text,
  title text,
  image_path text,
  category_id uuid,
  starts_at timestamptz,
  ends_at timestamptz,
  venue_name text,
  address text,
  is_free boolean,
  price_text text,
  distance_m double precision,
  score double precision
)
language sql
stable
set search_path = public, extensions
as $$
  with origin as (
    select coalesce(
      case when p_lat is not null and p_lng is not null
        then st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography end,
      c.center
    ) as point
    from cities c
    where c.id = p_city_id
  ),
  interests as (
    select ui.category_id from user_interests ui where ui.user_id = auth.uid()
  ),
  candidates as (
    select e.*, st_distance(e.location, o.point) as dist
    from events e
    cross join origin o
    where e.city_id = p_city_id
      and e.status = 'approved'
      and e.ends_at > now()
  ),
  popularity as (
    select greatest(max(c.save_count), 1)::double precision as max_saves from candidates c
  )
  select
    c.id, c.slug, c.title, c.image_path, c.category_id, c.starts_at, c.ends_at,
    c.venue_name, c.address, c.is_free, c.price_text,
    c.dist as distance_m,
    -- Proximity: 1 at the user, 0 at 25 km or more; neutral when unknown.
    0.4 * coalesce(greatest(0, 1 - c.dist / 25000.0), 0.5)
    -- Interest: 1 for a chosen category; neutral when no interests are set.
    + 0.3 * case
        when not exists (select 1 from interests) then 0.5
        when c.category_id in (select i.category_id from interests i) then 1
        else 0
      end
    -- Soonness: 1 for events already on or starting now, 0 at 7 days out.
    + 0.2 * greatest(0, 1 - extract(epoch from greatest(c.starts_at - now(), interval '0')) / 604800.0)
    -- Popularity: saves relative to the most-saved upcoming event in the city.
    + 0.1 * (c.save_count / p.max_saves)
    as score
  from candidates c
  cross join popularity p
  order by score desc, c.starts_at, c.id
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0);
$$;
