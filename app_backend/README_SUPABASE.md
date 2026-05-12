# Eco-Guide Supabase Backend

This folder is now the backend source of truth for Eco-Guide. The mobile app and backoffice connect directly to Supabase using the anon key, Supabase Auth, Row Level Security, Storage, Realtime, and Postgres RPC functions.

## Environment

Create `.env` from `.env.example`:

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_DB_URL=
```

Only use `SUPABASE_SERVICE_ROLE_KEY` from local/admin scripts. Never put it in `app_front` or `app_backoffice`.

## Local Setup

```bash
supabase start
supabase db reset
```

`supabase db reset` applies:

- `supabase/migrations/202605100001_native_schema.sql`
- `supabase/migrations/202605100002_business_rpc.sql`
- `supabase/seed.sql`

## Auth

Users are managed by Supabase Auth. A trigger creates `public.profiles` rows automatically when users sign up.

Email/password uses `Supabase.auth.signUp` and `signInWithPassword`. Google login uses Supabase OAuth, so Google must be enabled in Supabase Dashboard > Authentication > Providers.

Add these redirect URLs in Supabase Dashboard > Authentication > URL Configuration:

- `io.supabase.ecoguide://login-callback/` for `app_front`
- `io.supabase.ecoguide.admin://login-callback/` for `app_backoffice` mobile/desktop builds
- The deployed web URL for `app_backoffice` if it runs as Flutter Web

To create an admin:

1. Sign up from the app/backoffice.
2. In Supabase SQL editor, run:

```sql
update public.profiles
set role = 'admin'
where email = 'admin@ecoguide.ma';
```

## Runtime

The NestJS runtime is no longer required for the Supabase-native architecture. The old `src/` folder is kept only as legacy reference during migration.
