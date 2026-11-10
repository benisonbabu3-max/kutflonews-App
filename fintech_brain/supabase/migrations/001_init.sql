-- ════════════════════════════════════════════════════════════════════════
-- Fintech Brain v3 — Initial schema
-- Run this in Supabase SQL Editor (or via `supabase db push`)
-- ════════════════════════════════════════════════════════════════════════

-- ─── PROFILES ──────────────────────────────────────────────────────────────
-- One row per user. Created automatically on first sign-in via trigger.
create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  name            text not null default '',
  email           text not null default '',
  role            text not null default '',
  location        text not null default '',
  career_goal     text not null default '',
  interests       text[] not null default array['Payments','Regulation','Product'],
  notify_morning  boolean not null default true,
  notify_evening  boolean not null default true,
  morning_hour    int not null default 8,
  evening_hour    int not null default 21,
  ai_enrichment   boolean not null default true,
  ai_inline       boolean not null default true,
  ai_briefs       boolean not null default true,
  ai_weekly_digest boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Auto-create a profile row when a new user signs up via Google OAuth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', 'User'),
    coalesce(new.email, '')
  )
  on conflict (id) do nothing;

  insert into public.user_stats (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ─── ARTICLES CACHE (shared across ALL users) ─────────────────────────────
-- This is THE cost-saving table. AI summaries are generated ONCE per
-- article and reused by every user who sees that article.
create table if not exists public.articles_cache (
  id                text primary key,        -- sha256(title + '|' + url)
  title             text not null,
  url               text not null,
  source            text not null default '',
  topic             text not null default 'General',
  type              text not null default 'news',
  estimated_minutes int not null default 5,
  raw_content       text not null default '',
  summary           text not null default '',     -- 60-word AI summary
  why_it_matters    text not null default '',
  enriched_at       timestamptz,                   -- null = not yet enriched
  published_at      timestamptz not null default now(),
  created_at        timestamptz not null default now()
);

alter table public.articles_cache enable row level security;

-- Everyone (authenticated) can READ the shared cache
create policy "Authenticated users read article cache"
  on public.articles_cache for select
  to authenticated
  using (true);

-- Only the service role (edge functions) can write — enforced by
-- NOT granting insert/update to `authenticated`. Edge functions use
-- the service-role key which bypasses RLS entirely.


-- ─── PER-USER ARTICLE STATE (vault, read status) ──────────────────────────
create table if not exists public.user_articles (
  user_id          uuid not null references auth.users(id) on delete cascade,
  article_id       text not null references public.articles_cache(id) on delete cascade,
  is_read          boolean not null default false,
  is_saved         boolean not null default false,
  saved_at         timestamptz,
  last_reviewed_at timestamptz,
  shown_at         timestamptz not null default now(),
  primary key (user_id, article_id)
);

alter table public.user_articles enable row level security;

create policy "Users manage own article state"
  on public.user_articles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ─── USER STATS (streak, totals, topic mastery) ───────────────────────────
create table if not exists public.user_stats (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  streak         int not null default 0,
  total_read     int not null default 0,
  total_saved    int not null default 0,
  last_read_date date,
  topic_counts   jsonb not null default '{}'::jsonb,
  updated_at     timestamptz not null default now()
);

alter table public.user_stats enable row level security;

create policy "Users manage own stats"
  on public.user_stats for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ─── AI USAGE LOG (monitor NVIDIA NIM free-tier consumption) ──────────────
create table if not exists public.ai_usage_log (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users(id) on delete set null,
  kind       text not null,             -- 'enrich' | 'chat' | 'brief'
  cache_hit  boolean not null default false,
  article_id text,
  created_at timestamptz not null default now()
);

alter table public.ai_usage_log enable row level security;

create policy "Users read own usage"
  on public.ai_usage_log for select
  using (auth.uid() = user_id);

-- Inserts come from edge functions via service-role key (bypasses RLS)


-- ─── INDEXES ───────────────────────────────────────────────────────────────
create index if not exists idx_user_articles_user   on public.user_articles(user_id);
create index if not exists idx_user_articles_saved  on public.user_articles(user_id, is_saved) where is_saved = true;
create index if not exists idx_articles_cache_topic on public.articles_cache(topic);
create index if not exists idx_ai_usage_user_date    on public.ai_usage_log(user_id, created_at);

-- ════════════════════════════════════════════════════════════════════════
-- Done. Next: deploy edge functions (see supabase/functions/), set secrets:
--   supabase secrets set NVIDIA_NIM_API_KEY=nvapi-xxxxx
--   supabase secrets set NVIDIA_NIM_MODEL=meta/llama-3.1-8b-instruct
-- ════════════════════════════════════════════════════════════════════════
