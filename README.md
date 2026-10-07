# Eventify

Eventify helps people discover what's happening around them. This repository holds the MVP described in the Eventify SRS v1.0: a Flutter mobile app on a Supabase backend, launching in Accra.

## Layout

| Path | What it is |
| --- | --- |
| `app/` | Flutter app for Android and iOS |
| `supabase/migrations/` | Database schema, access rules and reference data (Accra, categories) |
| `supabase/seed.sql` | Sample events for local development only |
| `supabase/tests/` | Access-rule smoke checks and the CI stubs |

The web admin dashboard and public share pages (Next.js) come in a later phase under `admin/`.

## Running the app

Requires Flutter 3.47 (stable).

```sh
cd app
flutter pub get
cp env.example.json env.json   # fill in your Supabase URL and publishable key
flutter run --dart-define-from-file=env.json
```

Without `env.json` the app still starts, with no backend connected.

## Database

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli) and Docker.

```sh
supabase start      # local Postgres, Auth and Storage
supabase db reset   # applies migrations, then seed.sql
```

To push the schema to the hosted project: `supabase link --project-ref <ref>` then `supabase db push`.

### Access rules in short

- Anyone, signed in or not, can read approved events, active categories and cities.
- Signed-in users submit events, which always enter moderation as `pending`; they can edit or delete their own until reviewed.
- Saved events, interests, push tokens and reports belong to their user.
- Admins (`profiles.role = 'admin'`) approve, reject and edit everything. Make the first admin from the SQL editor:
  `update profiles set role = 'admin' where id = '<user id>';`
