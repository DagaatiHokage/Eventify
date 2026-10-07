-- Access-rule smoke checks. Run against a local database after `supabase db reset`:
--   psql "$DB_URL" -A -t -f supabase/tests/rls_smoke.sql
-- Lines marked "expect 0" must print 0; the four ERROR lines (anon insert,
-- status change by a submitter, self-promotion to admin, duplicate report) are expected.

\set ON_ERROR_STOP 0
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000a','a@x.com','{"full_name":"Ama"}'),
 ('00000000-0000-0000-0000-00000000000b','b@x.com','{}'),
 ('00000000-0000-0000-0000-0000000000ad','admin@x.com','{}');
update profiles set role='admin' where id='00000000-0000-0000-0000-0000000000ad';
select 'profile created', display_name from profiles where id='00000000-0000-0000-0000-00000000000a';

\echo == anon
set role anon; select set_config('request.jwt.claim.sub','',false);
select 'anon sees approved', count(*) from events;
insert into events (slug,title,category_id,city_id,starts_at,ends_at,venue_name,address) select 'x','xxxx',(select id from categories limit 1),(select id from cities limit 1),now(),now(),'v','a';
select 'anon feed', title, round(score::numeric,3) from get_feed((select id from cities where slug='accra'));
reset role;

\echo == user A submits
set role authenticated; select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false);
insert into events (slug,title,category_id,city_id,starts_at,ends_at,venue_name,address,status,save_count)
 select 'a-party','A party',(select id from categories where slug='music'),(select id from cities where slug='accra'),now()+interval '1 day',now()+interval '1 day 2 hours','v','a','approved',999;
select 'A own submission', slug, status, save_count, submitted_by is not null from events where slug='a-party';
update events set status='approved' where slug='a-party';
update events set title='A party (edited)' where slug='a-party';
select 'A edited title', title from events where slug='a-party';
update profiles set role='admin' where id=auth.uid();
update profiles set display_name='Ama K' where id=auth.uid();
select 'A profiles visible', count(*) from profiles;
insert into user_interests select auth.uid(), id from categories where slug='food';
insert into saved_events (user_id, event_id) select auth.uid(), id from events where slug='sample-design-meetup';
select 'save_count after save', save_count from events where slug='sample-design-meetup';
select 'A feed', title, round(score::numeric,3) from get_feed((select id from cities where slug='accra'), 5.556, -0.1817);
insert into reports (event_id,user_id,reason) select id, auth.uid(), 'spam' from events where slug='sample-food-market';
insert into reports (event_id,user_id,reason) select id, auth.uid(), 'spam' from events where slug='sample-food-market';
insert into organizers (name, created_by) values ('Ama Events', auth.uid());
insert into organizer_contacts select id, 'ama@x.com', null from organizers where name='Ama Events';
reset role;

\echo == user B
set role authenticated; select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000b',false);
select 'B sees A pending event (expect 0)', count(*) from events where slug='a-party';
select 'B sees A saves (expect 0)', count(*) from saved_events;
select 'B sees A reports (expect 0)', count(*) from reports;
select 'B sees organizer name', count(*) from organizers;
select 'B sees organizer contacts (expect 0)', count(*) from organizer_contacts;
update events set title='hijack' where slug='sample-design-meetup';
select 'title after B hijack', title from events where slug='sample-design-meetup';
reset role;

\echo == admin approves
set role authenticated; select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000ad',false);
update events set status='approved' where slug='a-party';
select 'admin sees reports', count(*) from reports;
select 'admin sees contacts', count(*) from organizer_contacts;
reset role;
select 'after approve', status, published_at is not null from events where slug='a-party';
select 'audit', from_status, to_status, actor_id from event_audit e join events v on v.id=e.event_id where v.slug='a-party' order by e.id;
\echo == unsave
set role authenticated; select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000a',false);
delete from saved_events;
reset role;
select 'save_count after unsave', save_count from events where slug='sample-design-meetup';
