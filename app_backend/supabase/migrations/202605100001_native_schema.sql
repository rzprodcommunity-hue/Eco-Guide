create extension if not exists "uuid-ossp";
create extension if not exists postgis;

do $$ begin
  create type public.user_role as enum ('admin', 'user');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.trail_difficulty as enum ('easy', 'moderate', 'difficult');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.poi_type as enum (
    'viewpoint', 'flora', 'fauna', 'historical', 'water',
    'camping', 'danger', 'rest_area', 'information'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.quiz_category as enum (
    'flora', 'fauna', 'ecology', 'history', 'geography', 'safety'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.service_category as enum (
    'guide', 'artisan', 'accommodation', 'restaurant', 'transport', 'equipment'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.activity_type as enum (
    'trail_started', 'trail_completed', 'poi_visited', 'quiz_answered', 'download'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.cache_resource_type as enum ('trail', 'poi', 'quiz', 'full_region');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  role public.user_role not null default 'user',
  "firstName" text,
  "lastName" text,
  "avatarUrl" text,
  "isActive" boolean not null default true,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public.trails (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null,
  distance numeric(10,2) not null,
  difficulty public.trail_difficulty not null default 'moderate',
  geojson jsonb,
  geometry geometry(LineString, 4326),
  "estimatedDuration" integer,
  "elevationGain" integer,
  "imageUrls" text[],
  region text,
  "averageRating" numeric(2,1),
  "reviewCount" integer not null default 0,
  "startLatitude" numeric(10,7),
  "startLongitude" numeric(10,7),
  "isActive" boolean not null default true,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public.pois (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type public.poi_type not null default 'viewpoint',
  description text not null,
  badge text,
  "learnMoreUrl" text,
  latitude numeric(10,7) not null,
  longitude numeric(10,7) not null,
  location geometry(Point, 4326),
  "mediaUrl" text,
  "additionalMediaUrls" text[],
  "videoUrls" text[],
  "audioGuideUrl" text,
  "trailId" uuid references public.trails(id) on delete set null,
  "isActive" boolean not null default true,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  answers jsonb not null,
  "correctAnswerIndex" integer not null,
  explanation text,
  category public.quiz_category,
  "imageUrl" text,
  "trailId" uuid references public.trails(id) on delete set null,
  "poiId" uuid references public.pois(id) on delete set null,
  points integer not null default 10,
  "isActive" boolean not null default true,
  "createdAt" timestamptz not null default now()
);

create table if not exists public.quiz_scores (
  id uuid primary key default gen_random_uuid(),
  "userId" uuid not null references auth.users(id) on delete cascade,
  category public.quiz_category,
  "totalScore" integer not null default 0,
  "quizzesCompleted" integer not null default 0,
  "correctAnswers" integer not null default 0,
  "totalQuestions" integer not null default 0,
  "bestPercentage" double precision not null default 0,
  "createdAt" timestamptz not null default now(),
  "lastPlayedAt" timestamptz not null default now()
);

create unique index if not exists quiz_scores_user_category_unique
  on public.quiz_scores ("userId", category)
  where category is not null;

create unique index if not exists quiz_scores_user_general_unique
  on public.quiz_scores ("userId")
  where category is null;

create table if not exists public.quiz_badges (
  id uuid primary key default gen_random_uuid(),
  "userId" uuid not null references auth.users(id) on delete cascade,
  key text not null,
  label text not null,
  description text,
  icon text,
  color text,
  threshold integer not null,
  category public.quiz_category,
  "unlockedAt" timestamptz not null default now(),
  unique ("userId", key)
);

create table if not exists public.local_services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category public.service_category not null,
  description text not null,
  contact text,
  email text,
  website text,
  address text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  location geometry(Point, 4326),
  "imageUrl" text,
  "additionalImages" text[],
  languages text[],
  rating numeric(3,2),
  "reviewCount" integer not null default 0,
  "isActive" boolean not null default true,
  "isVerified" boolean not null default false,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  "userId" uuid not null references auth.users(id) on delete cascade,
  type public.activity_type not null,
  "trailId" uuid references public.trails(id) on delete set null,
  "poiId" uuid references public.pois(id) on delete set null,
  metadata jsonb,
  "createdAt" timestamptz not null default now()
);

create table if not exists public.sos_alerts (
  id uuid primary key default gen_random_uuid(),
  "userId" uuid not null references auth.users(id) on delete cascade,
  "userEmail" text not null,
  "userName" text not null,
  latitude double precision not null,
  longitude double precision not null,
  message text,
  "emergencyContact" text,
  status text not null default 'active',
  "resolvedAt" timestamptz,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public.offline_cache (
  id uuid primary key default gen_random_uuid(),
  "userId" uuid not null references auth.users(id) on delete cascade,
  "resourceType" public.cache_resource_type not null,
  "resourceId" text not null,
  version integer not null default 1,
  "downloadedAt" timestamptz not null default now(),
  "expiresAt" timestamptz,
  "sizeBytes" bigint not null default 0
);

create index if not exists trails_start_gist on public.trails
  using gist (st_setsrid(st_makepoint("startLongitude"::double precision, "startLatitude"::double precision), 4326))
  where "startLatitude" is not null and "startLongitude" is not null;

create index if not exists pois_location_gist on public.pois
  using gist (st_setsrid(st_makepoint(longitude::double precision, latitude::double precision), 4326));

create index if not exists local_services_location_gist on public.local_services
  using gist (st_setsrid(st_makepoint(longitude::double precision, latitude::double precision), 4326))
  where latitude is not null and longitude is not null;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new."updatedAt" = now();
  return new;
end;
$$;

drop trigger if exists touch_profiles_updated_at on public.profiles;
create trigger touch_profiles_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_trails_updated_at on public.trails;
create trigger touch_trails_updated_at
  before update on public.trails
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_pois_updated_at on public.pois;
create trigger touch_pois_updated_at
  before update on public.pois
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_local_services_updated_at on public.local_services;
create trigger touch_local_services_updated_at
  before update on public.local_services
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_sos_alerts_updated_at on public.sos_alerts;
create trigger touch_sos_alerts_updated_at
  before update on public.sos_alerts
  for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role, "firstName", "lastName")
  values (
    new.id,
    new.email,
    coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'user'),
    new.raw_user_meta_data ->> 'firstName',
    new.raw_user_meta_data ->> 'lastName'
  )
  on conflict (id) do update set
    email = excluded.email,
    "firstName" = excluded."firstName",
    "lastName" = excluded."lastName";
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and "isActive" = true
  );
$$;

alter table public.profiles enable row level security;
alter table public.trails enable row level security;
alter table public.pois enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_scores enable row level security;
alter table public.quiz_badges enable row level security;
alter table public.local_services enable row level security;
alter table public.activities enable row level security;
alter table public.sos_alerts enable row level security;
alter table public.offline_cache enable row level security;

drop policy if exists "profiles select own or admin" on public.profiles;
create policy "profiles select own or admin" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles update own or admin" on public.profiles;
create policy "profiles update own or admin" on public.profiles
  for update to authenticated using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists "public read active trails" on public.trails;
create policy "public read active trails" on public.trails
  for select to anon, authenticated using ("isActive" = true or public.is_admin());

drop policy if exists "admin write trails" on public.trails;
create policy "admin write trails" on public.trails
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public read active pois" on public.pois;
create policy "public read active pois" on public.pois
  for select to anon, authenticated using ("isActive" = true or public.is_admin());

drop policy if exists "admin write pois" on public.pois;
create policy "admin write pois" on public.pois
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public read active quizzes" on public.quizzes;
create policy "public read active quizzes" on public.quizzes
  for select to anon, authenticated using ("isActive" = true or public.is_admin());

drop policy if exists "admin write quizzes" on public.quizzes;
create policy "admin write quizzes" on public.quizzes
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public read active verified local services" on public.local_services;
create policy "public read active verified local services" on public.local_services
  for select to anon, authenticated using (("isActive" = true and "isVerified" = true) or public.is_admin());

drop policy if exists "admin write local services" on public.local_services;
create policy "admin write local services" on public.local_services
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "users read own quiz scores or admin" on public.quiz_scores;
create policy "users read own quiz scores or admin" on public.quiz_scores
  for select to authenticated using ("userId" = auth.uid() or public.is_admin());

drop policy if exists "users insert own quiz scores" on public.quiz_scores;
create policy "users insert own quiz scores" on public.quiz_scores
  for insert to authenticated with check ("userId" = auth.uid() or public.is_admin());

drop policy if exists "users update own quiz scores" on public.quiz_scores;
create policy "users update own quiz scores" on public.quiz_scores
  for update to authenticated using ("userId" = auth.uid() or public.is_admin())
  with check ("userId" = auth.uid() or public.is_admin());

drop policy if exists "users read own badges or admin" on public.quiz_badges;
create policy "users read own badges or admin" on public.quiz_badges
  for select to authenticated using ("userId" = auth.uid() or public.is_admin());

drop policy if exists "users read own activities or admin" on public.activities;
create policy "users read own activities or admin" on public.activities
  for select to authenticated using ("userId" = auth.uid() or public.is_admin());

drop policy if exists "users insert own activities" on public.activities;
create policy "users insert own activities" on public.activities
  for insert to authenticated with check ("userId" = auth.uid() or public.is_admin());

drop policy if exists "users read own sos or admin" on public.sos_alerts;
create policy "users read own sos or admin" on public.sos_alerts
  for select to authenticated using ("userId" = auth.uid() or public.is_admin());

drop policy if exists "users create own sos" on public.sos_alerts;
create policy "users create own sos" on public.sos_alerts
  for insert to authenticated with check ("userId" = auth.uid());

drop policy if exists "admin resolve sos" on public.sos_alerts;
create policy "admin resolve sos" on public.sos_alerts
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "users manage own offline cache" on public.offline_cache;
create policy "users manage own offline cache" on public.offline_cache
  for all to authenticated using ("userId" = auth.uid() or public.is_admin())
  with check ("userId" = auth.uid() or public.is_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('trail-media', 'trail-media', true, 52428800, array['image/jpeg', 'image/png', 'image/webp']),
  ('poi-media', 'poi-media', true, 52428800, array['image/jpeg', 'image/png', 'image/webp']),
  ('service-media', 'service-media', true, 52428800, array['image/jpeg', 'image/png', 'image/webp']),
  ('audio-guides', 'audio-guides', true, 52428800, array['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/x-wav']),
  ('videos', 'videos', true, 52428800, array['video/mp4', 'video/quicktime', 'video/webm'])
on conflict (id) do nothing;

drop policy if exists "public read published media" on storage.objects;
create policy "public read published media" on storage.objects
  for select to anon, authenticated
  using (bucket_id in ('trail-media', 'poi-media', 'service-media', 'audio-guides', 'videos'));

drop policy if exists "admins manage media" on storage.objects;
create policy "admins manage media" on storage.objects
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
