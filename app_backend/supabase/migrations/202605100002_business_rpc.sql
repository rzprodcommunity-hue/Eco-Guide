create or replace function public.nearby_trails(
  lat double precision,
  lng double precision,
  radius double precision default 50
)
returns setof public.trails
language sql
stable
as $$
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

create or replace function public.nearby_pois(
  lat double precision,
  lng double precision,
  radius double precision default 10,
  poi_type text default null
)
returns setof public.pois
language sql
stable
as $$
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

create or replace function public.nearby_local_services(
  lat double precision,
  lng double precision,
  radius double precision default 50,
  service_category text default null
)
returns setof public.local_services
language sql
stable
as $$
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

create or replace function public.unlock_quiz_badges(target_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
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

create or replace function public.submit_quiz_score(
  score integer,
  correct_answers integer,
  total_questions integer,
  category text default null
)
returns public.quiz_scores
language plpgsql
security definer
set search_path = public
as $$
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

create or replace function public.user_quiz_summary()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
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

create or replace function public.quiz_category_stats()
returns table(category text, "quizCount" integer)
language sql
stable
as $$
  select q.category::text, count(*)::int
  from public.quizzes q
  where q."isActive" = true
  group by q.category
  order by q.category;
$$;

create or replace function public.create_sos_alert(
  latitude double precision,
  longitude double precision,
  message text default null,
  emergency_contact text default null
)
returns public.sos_alerts
language plpgsql
security definer
set search_path = public
as $$
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

create or replace function public.resolve_sos_alert(alert_id uuid)
returns public.sos_alerts
language plpgsql
security definer
set search_path = public
as $$
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

create or replace function public.admin_dashboard_overview()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
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

create or replace function public.user_activity_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
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

create or replace function public.offline_packages()
returns jsonb
language sql
stable
as $$
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
