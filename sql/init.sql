create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

-- core tables
create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text unique not null,
  description text,
  total_questions int default 0,
  created_by uuid,
  created_at timestamptz default now()
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid references public.quizzes(id) on delete cascade,
  text text not null,
  explanation text,
  position int not null,
  image_path text,
  time_limit_seconds int,
  created_at timestamptz default now()
);

create table if not exists public.options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.questions(id) on delete cascade,
  text text not null,
  is_correct boolean default false
);

create table if not exists public.users (
  id bigint primary key,
  username text,
  first_name text,
  last_name text,
  preferred_lang text check (preferred_lang in ('en','gu','hi')),
  created_at timestamptz default now()
);

create table if not exists public.attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid references public.quizzes(id),
  user_id bigint references public.users(id),
  score int default 0,
  current_position int default 1,
  started_at timestamptz default now(),
  finished_at timestamptz
);

create table if not exists public.answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid references public.attempts(id) on delete cascade,
  question_id uuid references public.questions(id),
  option_id uuid references public.options(id),
  is_correct boolean default false,
  answered_at timestamptz default now()
);

-- tags & i18n
create table if not exists public.question_tags (
  question_id uuid references public.questions(id) on delete cascade,
  tag text,
  primary key (question_id, tag)
);

create table if not exists public.question_i18n (
  question_id uuid references public.questions(id) on delete cascade,
  lang text check (lang in ('en','gu','hi')),
  text text,
  explanation text,
  primary key (question_id, lang)
);

-- roles & streaks
create table if not exists public.profiles (
  user_id uuid primary key,
  email text unique,
  role text check (role in ('admin','editor')) default 'editor'
);

create table if not exists public.streaks (
  user_id bigint primary key,
  last_played_date date,
  current_streak int default 0,
  best_streak int default 0
);

-- indexes
create index if not exists idx_questions_quiz_pos on public.questions(quiz_id, position);
create index if not exists idx_options_question on public.options(question_id);
create index if not exists idx_answers_attempt on public.answers(attempt_id);
create index if not exists idx_qtags_tag on public.question_tags(tag);

-- RPCs
create or replace function public.increment_attempt_score(p_attempt_id uuid)
returns void language sql as $$
  update public.attempts set score = score + 1 where id = p_attempt_id;
$$;

create or replace function public.advance_attempt_position(p_attempt_id uuid)
returns void language sql as $$
  update public.attempts set current_position = current_position + 1 where id = p_attempt_id;
$$;

-- Leaderboards
create or replace view public.leaderboard_view as
select a.id as attempt_id, a.quiz_id, q.title as quiz_title, a.user_id,
       coalesce(u.username, (u.first_name || ' ' || coalesce(u.last_name,''))) as display_name,
       a.score, a.started_at, a.finished_at
from public.attempts a
join public.users u on u.id = a.user_id
join public.quizzes q on q.id = a.quiz_id;

create or replace view public.leaderboard_best_view as
with best as (
  select a.user_id, a.quiz_id, max(a.score) as best_score, min(a.finished_at) as first_finish
  from public.attempts a
  group by a.user_id, a.quiz_id
)
select b.quiz_id, q.title as quiz_title, b.user_id,
       coalesce(u.username, (u.first_name || ' ' || coalesce(u.last_name,''))) as display_name,
       b.best_score as score, b.first_finish as finished_at
from best b
join public.users u on u.id = b.user_id
join public.quizzes q on q.id = b.quiz_id;