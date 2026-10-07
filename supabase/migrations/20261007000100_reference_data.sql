-- Launch city and the initial categories from the SRS (FR-005).
-- Both stay editable from the admin dashboard.

insert into public.cities (slug, name, country_code, timezone, center)
values (
  'accra', 'Accra', 'GH', 'Africa/Accra',
  extensions.st_setsrid(extensions.st_makepoint(-0.1870, 5.6037), 4326)::extensions.geography
)
on conflict (slug) do nothing;

insert into public.categories (slug, name, icon, sort_order)
values
  ('music', 'Music', 'music_note', 10),
  ('technology', 'Technology', 'computer', 20),
  ('business', 'Business', 'business_center', 30),
  ('arts-culture', 'Arts & Culture', 'palette', 40),
  ('food', 'Food', 'restaurant', 50),
  ('sports', 'Sports', 'sports_soccer', 60),
  ('education', 'Education', 'school', 70),
  ('community', 'Community', 'groups', 80),
  ('lifestyle', 'Lifestyle', 'spa', 90),
  ('networking', 'Networking', 'handshake', 100)
on conflict (slug) do nothing;
