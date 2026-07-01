--
-- PostgreSQL database dump
--

\restrict sXrYjAvfhCMcfQjcjYI8Lbayim1t4I1zhecepJ4p2Muw6DDuf6ZJuDhAvamkai7

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: activity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.activity_type AS ENUM (
    'trail_started',
    'trail_completed',
    'poi_visited',
    'quiz_answered',
    'download'
);


--
-- Name: cache_resource_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.cache_resource_type AS ENUM (
    'trail',
    'poi',
    'quiz',
    'full_region'
);


--
-- Name: poi_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.poi_type AS ENUM (
    'viewpoint',
    'flora',
    'fauna',
    'historical',
    'water',
    'camping',
    'danger',
    'rest_area',
    'information'
);


--
-- Name: quiz_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quiz_category AS ENUM (
    'flora',
    'fauna',
    'ecology',
    'history',
    'geography',
    'safety'
);


--
-- Name: service_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.service_category AS ENUM (
    'guide',
    'artisan',
    'accommodation',
    'restaurant',
    'transport',
    'equipment'
);


--
-- Name: trail_difficulty; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.trail_difficulty AS ENUM (
    'easy',
    'moderate',
    'difficult'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'admin',
    'user'
);


--
-- Name: admin_dashboard_overview(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_dashboard_overview() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select case when public.is_admin() then jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'trails', (select count(*) from public.trails),
    'pois', (select count(*) from public.pois),
    'quizzes', (select count(*) from public.quizzes),
    'localServices', (select count(*) from public.local_services),
    'activities', (select count(*) from public.activities),
    'activeSosAlerts', (select count(*) from public.sos_alerts where status = 'active'),
    'recentActivities', coalesce((
      select jsonb_agg(to_jsonb(a.*) order by a."createdAt" desc)
      from (select * from public.activities order by "createdAt" desc limit 10) a
    ), '[]'::jsonb)
  ) else jsonb_build_object() end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: sos_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sos_alerts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "userId" uuid NOT NULL,
    "userEmail" text NOT NULL,
    "userName" text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    message text,
    "emergencyContact" text,
    status text DEFAULT 'active'::text NOT NULL,
    "resolvedAt" timestamp with time zone,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: create_sos_alert(double precision, double precision, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_sos_alert(latitude double precision, longitude double precision, message text DEFAULT NULL::text, emergency_contact text DEFAULT NULL::text) RETURNS public.sos_alerts
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  current_profile public.profiles;
  saved public.sos_alerts;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into current_profile
  from public.profiles
  where id = auth.uid();

  insert into public.sos_alerts (
    "userId", "userEmail", "userName", latitude, longitude,
    message, "emergencyContact"
  )
  values (
    auth.uid(),
    coalesce(current_profile.email, ''),
    trim(coalesce(current_profile."firstName", '') || ' ' || coalesce(current_profile."lastName", '')),
    latitude,
    longitude,
    message,
    emergency_contact
  )
  returning * into saved;

  return saved;
end;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and "isActive" = true
  );
$$;


--
-- Name: local_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.local_services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    category public.service_category NOT NULL,
    description text NOT NULL,
    contact text,
    email text,
    website text,
    address text,
    latitude numeric(10,7),
    longitude numeric(10,7),
    location public.geometry(Point,4326),
    "imageUrl" text,
    "additionalImages" text[],
    languages text[],
    rating numeric(3,2),
    "reviewCount" integer DEFAULT 0 NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    "isVerified" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: nearby_local_services(double precision, double precision, double precision, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nearby_local_services(lat double precision, lng double precision, radius double precision DEFAULT 50, service_category text DEFAULT NULL::text) RETURNS SETOF public.local_services
    LANGUAGE sql STABLE
    AS $$
  select *
  from public.local_services
  where "isActive" = true
    and "isVerified" = true
    and latitude is not null
    and longitude is not null
    and (service_category is null or category::text = service_category)
    and st_dwithin(
      st_setsrid(st_makepoint(longitude::double precision, latitude::double precision), 4326)::geography,
      st_setsrid(st_makepoint(lng, lat), 4326)::geography,
      radius * 1000
    )
  order by st_distance(
    st_setsrid(st_makepoint(longitude::double precision, latitude::double precision), 4326)::geography,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography
  );
$$;


--
-- Name: pois; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pois (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    type public.poi_type DEFAULT 'viewpoint'::public.poi_type NOT NULL,
    description text NOT NULL,
    badge text,
    "learnMoreUrl" text,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    location public.geometry(Point,4326),
    "mediaUrl" text,
    "additionalMediaUrls" text[],
    "videoUrls" text[],
    "audioGuideUrl" text,
    "trailId" uuid,
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: nearby_pois(double precision, double precision, double precision, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nearby_pois(lat double precision, lng double precision, radius double precision DEFAULT 10, poi_type text DEFAULT NULL::text) RETURNS SETOF public.pois
    LANGUAGE sql STABLE
    AS $$
  select *
  from public.pois
  where "isActive" = true
    and (poi_type is null or type::text = poi_type)
    and st_dwithin(
      st_setsrid(st_makepoint(longitude::double precision, latitude::double precision), 4326)::geography,
      st_setsrid(st_makepoint(lng, lat), 4326)::geography,
      radius * 1000
    )
  order by st_distance(
    st_setsrid(st_makepoint(longitude::double precision, latitude::double precision), 4326)::geography,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography
  );
$$;


--
-- Name: trails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trails (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    distance numeric(10,2) NOT NULL,
    difficulty public.trail_difficulty DEFAULT 'moderate'::public.trail_difficulty NOT NULL,
    geojson jsonb,
    geometry public.geometry(LineString,4326),
    "estimatedDuration" integer,
    "elevationGain" integer,
    "imageUrls" text[],
    region text,
    "averageRating" numeric(2,1),
    "reviewCount" integer DEFAULT 0 NOT NULL,
    "startLatitude" numeric(10,7),
    "startLongitude" numeric(10,7),
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "videoUrl" text
);


--
-- Name: nearby_trails(double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nearby_trails(lat double precision, lng double precision, radius double precision DEFAULT 50) RETURNS SETOF public.trails
    LANGUAGE sql STABLE
    AS $$
  select *
  from public.trails
  where "isActive" = true
    and "startLatitude" is not null
    and "startLongitude" is not null
    and st_dwithin(
      st_setsrid(st_makepoint("startLongitude"::double precision, "startLatitude"::double precision), 4326)::geography,
      st_setsrid(st_makepoint(lng, lat), 4326)::geography,
      radius * 1000
    )
  order by st_distance(
    st_setsrid(st_makepoint("startLongitude"::double precision, "startLatitude"::double precision), 4326)::geography,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography
  );
$$;


--
-- Name: offline_packages(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offline_packages() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select jsonb_build_object(
    'trails', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', id,
        'name', name,
        'size', 0
      ) order by name)
      from public.trails
      where "isActive" = true
    ), '[]'::jsonb)
  );
$$;


--
-- Name: quiz_category_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quiz_category_stats() RETURNS TABLE(category text, "quizCount" integer)
    LANGUAGE sql STABLE
    AS $$
  select q.category::text, count(*)::int
  from public.quizzes q
  where q."isActive" = true
  group by q.category
  order by q.category;
$$;


--
-- Name: resolve_sos_alert(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_sos_alert(alert_id uuid) RETURNS public.sos_alerts
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  saved public.sos_alerts;
begin
  if not public.is_admin() then
    raise exception 'Admin role required';
  end if;

  update public.sos_alerts
  set status = 'resolved', "resolvedAt" = now()
  where id = alert_id
  returning * into saved;

  return saved;
end;
$$;


--
-- Name: quiz_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quiz_scores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "userId" uuid NOT NULL,
    category public.quiz_category,
    "totalScore" integer DEFAULT 0 NOT NULL,
    "quizzesCompleted" integer DEFAULT 0 NOT NULL,
    "correctAnswers" integer DEFAULT 0 NOT NULL,
    "totalQuestions" integer DEFAULT 0 NOT NULL,
    "bestPercentage" double precision DEFAULT 0 NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "lastPlayedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: submit_quiz_score(integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_quiz_score(score integer, correct_answers integer, total_questions integer, category text DEFAULT NULL::text) RETURNS public.quiz_scores
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  target_user uuid := auth.uid();
  target_category public.quiz_category := nullif(category, '')::public.quiz_category;
  existing_id uuid;
  pct double precision := 0;
  saved public.quiz_scores;
begin
  if target_user is null then
    raise exception 'Authentication required';
  end if;

  if total_questions > 0 then
    pct := (correct_answers::double precision / total_questions::double precision) * 100;
  end if;

  select id
  into existing_id
  from public.quiz_scores
  where "userId" = target_user
    and (
      (target_category is null and category is null)
      or category = target_category
    )
  limit 1;

  if existing_id is null then
    insert into public.quiz_scores (
      "userId", category, "totalScore", "quizzesCompleted",
      "correctAnswers", "totalQuestions", "bestPercentage", "lastPlayedAt"
    )
    values (
      target_user, target_category, score, 1,
      correct_answers, total_questions, pct, now()
    )
    returning * into saved;
  else
    update public.quiz_scores
    set
      "totalScore" = "totalScore" + score,
      "quizzesCompleted" = "quizzesCompleted" + 1,
      "correctAnswers" = "correctAnswers" + correct_answers,
      "totalQuestions" = "totalQuestions" + total_questions,
      "bestPercentage" = greatest("bestPercentage", pct),
      "lastPlayedAt" = now()
    where id = existing_id
    returning * into saved;
  end if;

  perform public.unlock_quiz_badges(target_user);
  return saved;
end;
$$;


--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new."updatedAt" = now();
  return new;
end;
$$;


--
-- Name: unlock_quiz_badges(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unlock_quiz_badges(target_user uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  total_score integer;
  cat record;
begin
  select coalesce(sum("totalScore"), 0)
  into total_score
  from public.quiz_scores
  where "userId" = target_user;

  if total_score >= 100 then
    insert into public.quiz_badges ("userId", key, label, description, icon, color, threshold)
    values (target_user, 'quiz_rookie_100', 'Quiz Rookie', 'Atteindre 100 points en quiz.', 'military_tech', '#66BB6A', 100)
    on conflict ("userId", key) do nothing;
  end if;

  if total_score >= 300 then
    insert into public.quiz_badges ("userId", key, label, description, icon, color, threshold)
    values (target_user, 'quiz_explorer_300', 'Quiz Explorer', 'Atteindre 300 points en quiz.', 'emoji_events', '#42A5F5', 300)
    on conflict ("userId", key) do nothing;
  end if;

  if total_score >= 600 then
    insert into public.quiz_badges ("userId", key, label, description, icon, color, threshold)
    values (target_user, 'quiz_master_600', 'Quiz Master', 'Atteindre 600 points en quiz.', 'workspace_premium', '#FFA726', 600)
    on conflict ("userId", key) do nothing;
  end if;

  for cat in
    select category, "totalScore"
    from public.quiz_scores
    where "userId" = target_user
      and category is not null
      and "totalScore" >= 100
  loop
    insert into public.quiz_badges (
      "userId", key, label, description, icon, color, threshold, category
    )
    values (
      target_user,
      'quiz_' || cat.category::text || '_100',
      'Expert ' || cat.category::text,
      'Atteindre 100 points dans la categorie ' || cat.category::text || '.',
      'verified',
      '#26A69A',
      100,
      cat.category
    )
    on conflict ("userId", key) do nothing;
  end loop;
end;
$$;


--
-- Name: user_activity_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_activity_stats() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select jsonb_build_object(
    'trailsStarted', count(*) filter (where type = 'trail_started'),
    'trailsCompleted', count(*) filter (where type = 'trail_completed'),
    'poisVisited', count(*) filter (where type = 'poi_visited'),
    'quizzesAnswered', count(*) filter (where type = 'quiz_answered'),
    'downloads', count(*) filter (where type = 'download')
  )
  from public.activities
  where "userId" = auth.uid();
$$;


--
-- Name: user_quiz_summary(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_quiz_summary() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with scores as (
    select *
    from public.quiz_scores
    where "userId" = auth.uid()
  ),
  totals as (
    select
      coalesce(sum("totalScore"), 0)::int as "totalScore",
      coalesce(sum("quizzesCompleted"), 0)::int as "quizzesCompleted",
      coalesce(sum("correctAnswers"), 0)::int as "correctAnswers",
      coalesce(sum("totalQuestions"), 0)::int as "totalQuestions",
      coalesce(max("bestPercentage"), 0)::double precision as "bestPercentage"
    from scores
  )
  select jsonb_build_object(
    'totals', jsonb_build_object(
      'totalScore', totals."totalScore",
      'quizzesCompleted', totals."quizzesCompleted",
      'correctAnswers', totals."correctAnswers",
      'totalQuestions', totals."totalQuestions",
      'averagePercentage',
        case when totals."totalQuestions" > 0
          then round(((totals."correctAnswers"::numeric / totals."totalQuestions"::numeric) * 100), 2)
          else 0
        end,
      'bestPercentage', totals."bestPercentage"
    ),
    'categoryScores', coalesce((select jsonb_agg(to_jsonb(scores.*)) from scores), '[]'::jsonb),
    'badges', coalesce((
      select jsonb_agg(to_jsonb(quiz_badges.*) order by "unlockedAt")
      from public.quiz_badges
      where "userId" = auth.uid()
    ), '[]'::jsonb)
  )
  from totals;
$$;


--
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "userId" uuid NOT NULL,
    type public.activity_type NOT NULL,
    "trailId" uuid,
    "poiId" uuid,
    metadata jsonb,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: emergency_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emergency_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    subtitle text,
    phone text,
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: offline_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offline_cache (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "userId" uuid NOT NULL,
    "resourceType" public.cache_resource_type NOT NULL,
    "resourceId" text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    "downloadedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "expiresAt" timestamp with time zone,
    "sizeBytes" bigint DEFAULT 0 NOT NULL
);


--
-- Name: partner_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partner_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    business_name text NOT NULL,
    category text NOT NULL,
    description text NOT NULL,
    phone text NOT NULL,
    email text NOT NULL,
    address text,
    status text DEFAULT 'pending'::text,
    admin_note text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT partner_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    role public.user_role DEFAULT 'user'::public.user_role NOT NULL,
    "firstName" text,
    "lastName" text,
    "avatarUrl" text,
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: quiz_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quiz_badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "userId" uuid NOT NULL,
    key text NOT NULL,
    label text NOT NULL,
    description text,
    icon text,
    color text,
    threshold integer NOT NULL,
    category public.quiz_category,
    "unlockedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: quizzes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quizzes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    question text NOT NULL,
    answers jsonb NOT NULL,
    "correctAnswerIndex" integer NOT NULL,
    explanation text,
    category public.quiz_category,
    "imageUrl" text,
    "trailId" uuid,
    "poiId" uuid,
    points integer DEFAULT 10 NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: trail_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trail_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    trail_id uuid NOT NULL,
    user_id uuid NOT NULL,
    user_name text NOT NULL,
    user_avatar text,
    rating numeric(2,1) NOT NULL,
    text text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT trail_reviews_rating_check CHECK (((rating >= (1)::numeric) AND (rating <= (5)::numeric)))
);


--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    badge_key text NOT NULL,
    label text NOT NULL,
    description text,
    icon text,
    color text,
    earned_at timestamp with time zone DEFAULT now()
);


--
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: emergency_contacts emergency_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emergency_contacts
    ADD CONSTRAINT emergency_contacts_pkey PRIMARY KEY (id);


--
-- Name: local_services local_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.local_services
    ADD CONSTRAINT local_services_pkey PRIMARY KEY (id);


--
-- Name: offline_cache offline_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offline_cache
    ADD CONSTRAINT offline_cache_pkey PRIMARY KEY (id);


--
-- Name: partner_requests partner_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_requests
    ADD CONSTRAINT partner_requests_pkey PRIMARY KEY (id);


--
-- Name: pois pois_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pois
    ADD CONSTRAINT pois_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_key UNIQUE (email);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: quiz_badges quiz_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_badges
    ADD CONSTRAINT quiz_badges_pkey PRIMARY KEY (id);


--
-- Name: quiz_badges quiz_badges_userId_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_badges
    ADD CONSTRAINT "quiz_badges_userId_key_key" UNIQUE ("userId", key);


--
-- Name: quiz_scores quiz_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_scores
    ADD CONSTRAINT quiz_scores_pkey PRIMARY KEY (id);


--
-- Name: quizzes quizzes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quizzes
    ADD CONSTRAINT quizzes_pkey PRIMARY KEY (id);


--
-- Name: sos_alerts sos_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sos_alerts
    ADD CONSTRAINT sos_alerts_pkey PRIMARY KEY (id);


--
-- Name: trail_reviews trail_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trail_reviews
    ADD CONSTRAINT trail_reviews_pkey PRIMARY KEY (id);


--
-- Name: trails trails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trails
    ADD CONSTRAINT trails_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_user_id_badge_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_badge_key_key UNIQUE (user_id, badge_key);


--
-- Name: local_services_location_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX local_services_location_gist ON public.local_services USING gist (public.st_setsrid(public.st_makepoint((longitude)::double precision, (latitude)::double precision), 4326)) WHERE ((latitude IS NOT NULL) AND (longitude IS NOT NULL));


--
-- Name: pois_location_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pois_location_gist ON public.pois USING gist (public.st_setsrid(public.st_makepoint((longitude)::double precision, (latitude)::double precision), 4326));


--
-- Name: pois_trailid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pois_trailid_idx ON public.pois USING btree ("trailId");


--
-- Name: quiz_scores_user_category_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quiz_scores_user_category_unique ON public.quiz_scores USING btree ("userId", category) WHERE (category IS NOT NULL);


--
-- Name: quiz_scores_user_general_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quiz_scores_user_general_unique ON public.quiz_scores USING btree ("userId") WHERE (category IS NULL);


--
-- Name: trails_start_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trails_start_gist ON public.trails USING gist (public.st_setsrid(public.st_makepoint(("startLongitude")::double precision, ("startLatitude")::double precision), 4326)) WHERE (("startLatitude" IS NOT NULL) AND ("startLongitude" IS NOT NULL));


--
-- Name: local_services touch_local_services_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_local_services_updated_at BEFORE UPDATE ON public.local_services FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: pois touch_pois_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_pois_updated_at BEFORE UPDATE ON public.pois FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: profiles touch_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: sos_alerts touch_sos_alerts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_sos_alerts_updated_at BEFORE UPDATE ON public.sos_alerts FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: trails touch_trails_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_trails_updated_at BEFORE UPDATE ON public.trails FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: activities activities_poiId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT "activities_poiId_fkey" FOREIGN KEY ("poiId") REFERENCES public.pois(id) ON DELETE SET NULL;


--
-- Name: activities activities_trailId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT "activities_trailId_fkey" FOREIGN KEY ("trailId") REFERENCES public.trails(id) ON DELETE SET NULL;


--
-- Name: activities activities_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT "activities_userId_fkey" FOREIGN KEY ("userId") REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: offline_cache offline_cache_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offline_cache
    ADD CONSTRAINT "offline_cache_userId_fkey" FOREIGN KEY ("userId") REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: partner_requests partner_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_requests
    ADD CONSTRAINT partner_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: pois pois_trailId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pois
    ADD CONSTRAINT "pois_trailId_fkey" FOREIGN KEY ("trailId") REFERENCES public.trails(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: quiz_badges quiz_badges_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_badges
    ADD CONSTRAINT "quiz_badges_userId_fkey" FOREIGN KEY ("userId") REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: quiz_scores quiz_scores_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_scores
    ADD CONSTRAINT "quiz_scores_userId_fkey" FOREIGN KEY ("userId") REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: quizzes quizzes_poiId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quizzes
    ADD CONSTRAINT "quizzes_poiId_fkey" FOREIGN KEY ("poiId") REFERENCES public.pois(id) ON DELETE SET NULL;


--
-- Name: quizzes quizzes_trailId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quizzes
    ADD CONSTRAINT "quizzes_trailId_fkey" FOREIGN KEY ("trailId") REFERENCES public.trails(id) ON DELETE SET NULL;


--
-- Name: sos_alerts sos_alerts_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sos_alerts
    ADD CONSTRAINT "sos_alerts_userId_fkey" FOREIGN KEY ("userId") REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: trail_reviews trail_reviews_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trail_reviews
    ADD CONSTRAINT trail_reviews_trail_id_fkey FOREIGN KEY (trail_id) REFERENCES public.trails(id) ON DELETE CASCADE;


--
-- Name: trail_reviews trail_reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trail_reviews
    ADD CONSTRAINT trail_reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_badges user_badges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: trails Anyone can delete trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can delete trails" ON public.trails FOR DELETE USING (true);


--
-- Name: trails Anyone can insert trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can insert trails" ON public.trails FOR INSERT WITH CHECK (true);


--
-- Name: trail_reviews Anyone can read reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can read reviews" ON public.trail_reviews FOR SELECT USING (true);


--
-- Name: trails Anyone can read trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can read trails" ON public.trails FOR SELECT USING (true);


--
-- Name: trails Anyone can update trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can update trails" ON public.trails FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: activities Public delete activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete activities" ON public.activities FOR DELETE USING (true);


--
-- Name: local_services Public delete local_services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete local_services" ON public.local_services FOR DELETE USING (true);


--
-- Name: offline_cache Public delete offline_cache; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete offline_cache" ON public.offline_cache FOR DELETE USING (true);


--
-- Name: pois Public delete pois; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete pois" ON public.pois FOR DELETE USING (true);


--
-- Name: profiles Public delete profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete profiles" ON public.profiles FOR DELETE USING (true);


--
-- Name: quiz_scores Public delete quiz_scores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete quiz_scores" ON public.quiz_scores FOR DELETE USING (true);


--
-- Name: quizzes Public delete quizzes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete quizzes" ON public.quizzes FOR DELETE USING (true);


--
-- Name: sos_alerts Public delete sos_alerts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete sos_alerts" ON public.sos_alerts FOR DELETE USING (true);


--
-- Name: trails Public delete trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete trails" ON public.trails FOR DELETE USING (true);


--
-- Name: activities Public insert activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert activities" ON public.activities FOR INSERT WITH CHECK (true);


--
-- Name: local_services Public insert local_services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert local_services" ON public.local_services FOR INSERT WITH CHECK (true);


--
-- Name: offline_cache Public insert offline_cache; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert offline_cache" ON public.offline_cache FOR INSERT WITH CHECK (true);


--
-- Name: pois Public insert pois; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert pois" ON public.pois FOR INSERT WITH CHECK (true);


--
-- Name: profiles Public insert profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert profiles" ON public.profiles FOR INSERT WITH CHECK (true);


--
-- Name: quiz_scores Public insert quiz_scores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert quiz_scores" ON public.quiz_scores FOR INSERT WITH CHECK (true);


--
-- Name: quizzes Public insert quizzes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert quizzes" ON public.quizzes FOR INSERT WITH CHECK (true);


--
-- Name: sos_alerts Public insert sos_alerts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert sos_alerts" ON public.sos_alerts FOR INSERT WITH CHECK (true);


--
-- Name: trails Public insert trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert trails" ON public.trails FOR INSERT WITH CHECK (true);


--
-- Name: activities Public read activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read activities" ON public.activities FOR SELECT USING (true);


--
-- Name: local_services Public read local_services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read local_services" ON public.local_services FOR SELECT USING (true);


--
-- Name: offline_cache Public read offline_cache; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read offline_cache" ON public.offline_cache FOR SELECT USING (true);


--
-- Name: pois Public read pois; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read pois" ON public.pois FOR SELECT USING (true);


--
-- Name: profiles Public read profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read profiles" ON public.profiles FOR SELECT USING (true);


--
-- Name: quiz_scores Public read quiz_scores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read quiz_scores" ON public.quiz_scores FOR SELECT USING (true);


--
-- Name: quizzes Public read quizzes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read quizzes" ON public.quizzes FOR SELECT USING (true);


--
-- Name: sos_alerts Public read sos_alerts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read sos_alerts" ON public.sos_alerts FOR SELECT USING (true);


--
-- Name: trails Public read trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read trails" ON public.trails FOR SELECT USING (true);


--
-- Name: activities Public update activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update activities" ON public.activities FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: local_services Public update local_services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update local_services" ON public.local_services FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offline_cache Public update offline_cache; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update offline_cache" ON public.offline_cache FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: pois Public update pois; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update pois" ON public.pois FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: profiles Public update profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update profiles" ON public.profiles FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quiz_scores Public update quiz_scores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update quiz_scores" ON public.quiz_scores FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quizzes Public update quizzes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update quizzes" ON public.quizzes FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: sos_alerts Public update sos_alerts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update sos_alerts" ON public.sos_alerts FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: trails Public update trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update trails" ON public.trails FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: trail_reviews Users can insert own reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own reviews" ON public.trail_reviews FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_badges Users insert own badges; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users insert own badges" ON public.user_badges FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: partner_requests Users insert own requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users insert own requests" ON public.partner_requests FOR INSERT WITH CHECK (((auth.uid() = user_id) OR (user_id IS NULL)));


--
-- Name: user_badges Users see own badges; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users see own badges" ON public.user_badges FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: partner_requests Users see own requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users see own requests" ON public.partner_requests FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

--
-- Name: sos_alerts admin resolve sos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin resolve sos" ON public.sos_alerts FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: local_services admin write local services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin write local services" ON public.local_services TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: pois admin write pois; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin write pois" ON public.pois TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: quizzes admin write quizzes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin write quizzes" ON public.quizzes TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: trails admin write trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin write trails" ON public.trails TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: emergency_contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: emergency_contacts emergency_contacts_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY emergency_contacts_read ON public.emergency_contacts FOR SELECT USING (true);


--
-- Name: emergency_contacts emergency_contacts_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY emergency_contacts_write ON public.emergency_contacts TO authenticated, anon USING (true) WITH CHECK (true);


--
-- Name: local_services; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.local_services ENABLE ROW LEVEL SECURITY;

--
-- Name: offline_cache; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offline_cache ENABLE ROW LEVEL SECURITY;

--
-- Name: partner_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.partner_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: pois; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles select own or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "profiles select own or admin" ON public.profiles FOR SELECT TO authenticated USING (((id = auth.uid()) OR public.is_admin()));


--
-- Name: profiles profiles update own or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "profiles update own or admin" ON public.profiles FOR UPDATE TO authenticated USING (((id = auth.uid()) OR public.is_admin())) WITH CHECK (((id = auth.uid()) OR public.is_admin()));


--
-- Name: pois public read active pois; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "public read active pois" ON public.pois FOR SELECT TO authenticated, anon USING ((("isActive" = true) OR public.is_admin()));


--
-- Name: quizzes public read active quizzes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "public read active quizzes" ON public.quizzes FOR SELECT TO authenticated, anon USING ((("isActive" = true) OR public.is_admin()));


--
-- Name: trails public read active trails; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "public read active trails" ON public.trails FOR SELECT TO authenticated, anon USING ((("isActive" = true) OR public.is_admin()));


--
-- Name: local_services public read active verified local services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "public read active verified local services" ON public.local_services FOR SELECT TO authenticated, anon USING (((("isActive" = true) AND ("isVerified" = true)) OR public.is_admin()));


--
-- Name: quiz_badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quiz_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: quiz_scores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quiz_scores ENABLE ROW LEVEL SECURITY;

--
-- Name: quizzes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;

--
-- Name: sos_alerts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;

--
-- Name: trail_reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.trail_reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: trails; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.trails ENABLE ROW LEVEL SECURITY;

--
-- Name: user_badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: sos_alerts users create own sos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users create own sos" ON public.sos_alerts FOR INSERT TO authenticated WITH CHECK (("userId" = auth.uid()));


--
-- Name: activities users insert own activities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users insert own activities" ON public.activities FOR INSERT TO authenticated WITH CHECK ((("userId" = auth.uid()) OR public.is_admin()));


--
-- Name: quiz_scores users insert own quiz scores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users insert own quiz scores" ON public.quiz_scores FOR INSERT TO authenticated WITH CHECK ((("userId" = auth.uid()) OR public.is_admin()));


--
-- Name: offline_cache users manage own offline cache; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users manage own offline cache" ON public.offline_cache TO authenticated USING ((("userId" = auth.uid()) OR public.is_admin())) WITH CHECK ((("userId" = auth.uid()) OR public.is_admin()));


--
-- Name: activities users read own activities or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users read own activities or admin" ON public.activities FOR SELECT TO authenticated USING ((("userId" = auth.uid()) OR public.is_admin()));


--
-- Name: quiz_badges users read own badges or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users read own badges or admin" ON public.quiz_badges FOR SELECT TO authenticated USING ((("userId" = auth.uid()) OR public.is_admin()));


--
-- Name: quiz_scores users read own quiz scores or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users read own quiz scores or admin" ON public.quiz_scores FOR SELECT TO authenticated USING ((("userId" = auth.uid()) OR public.is_admin()));


--
-- Name: sos_alerts users read own sos or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users read own sos or admin" ON public.sos_alerts FOR SELECT TO authenticated USING ((("userId" = auth.uid()) OR public.is_admin()));


--
-- Name: quiz_scores users update own quiz scores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users update own quiz scores" ON public.quiz_scores FOR UPDATE TO authenticated USING ((("userId" = auth.uid()) OR public.is_admin())) WITH CHECK ((("userId" = auth.uid()) OR public.is_admin()));


--
-- PostgreSQL database dump complete
--

\unrestrict sXrYjAvfhCMcfQjcjYI8Lbayim1t4I1zhecepJ4p2Muw6DDuf6ZJuDhAvamkai7

