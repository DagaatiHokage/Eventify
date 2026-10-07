-- Local development only: sample events so the feed is not empty.
-- `supabase db reset` runs this after the migrations. Never run in production.

insert into public.events (
  slug, title, description, category_id, city_id, starts_at, ends_at,
  venue_name, address, location, is_free, price_text, ticket_url, status
)
select
  v.slug, v.title, v.description,
  (select id from public.categories where slug = v.category),
  (select id from public.cities where slug = 'accra'),
  date_trunc('hour', now()) + v.starts_in,
  date_trunc('hour', now()) + v.starts_in + v.duration,
  v.venue, v.address,
  extensions.st_setsrid(extensions.st_makepoint(v.lng, v.lat), 4326)::extensions.geography,
  v.is_free, v.price_text, v.ticket_url, 'approved'
from (values
  ('sample-design-meetup', 'Sample: Accra Design Meetup',
   'Placeholder event for local development.', 'technology',
   interval '2 days', interval '3 hours', 'Sample venue, Osu', 'Oxford Street, Osu, Accra',
   -0.1817, 5.5560, true, null, null),
  ('sample-live-highlife', 'Sample: Live Highlife Night',
   'Placeholder event for local development.', 'music',
   interval '5 days', interval '4 hours', 'Sample venue, Labone', 'Labone, Accra',
   -0.1720, 5.5650, false, 'GHS 100', 'https://example.com/tickets'),
  ('sample-food-market', 'Sample: Weekend Food Market',
   'Placeholder event for local development.', 'food',
   interval '9 days', interval '6 hours', 'Sample venue, East Legon', 'East Legon, Accra',
   -0.1580, 5.6350, true, null, null)
) as v(slug, title, description, category, starts_in, duration, venue, address,
       lng, lat, is_free, price_text, ticket_url)
on conflict (slug) do nothing;
