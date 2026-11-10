-- ═══════════════════════════════════════════════════════════════
-- Fintech Brain — Shared AI Summary Cache
-- ─────────────────────────────────────────────────────────────
-- One row per unique article (keyed by a hash of its URL).
-- The FIRST user to read a given article triggers AI generation
-- (via Ollama during testing, swappable to Gemini/Grok/OpenAI
-- later). Every subsequent user gets a free, instant cache hit.
-- This is the core cost-control mechanism: AI generation cost
-- scales with UNIQUE ARTICLES, not with USERS or USER×READS.
-- ═══════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

create table if not exists article_cache (
  id              uuid primary key default gen_random_uuid(),
  article_key     text unique not null,        -- sha1(url)
  title           text not null,
  url             text not null,
  source          text,
  topic           text,
  article_type    text,
  estimated_minutes int default 5,
  summary         text,                        -- 60-word AI summary
  why_it_matters  text,                         -- 1-sentence career relevance
  ai_provider     text,                         -- 'ollama' | 'gemini' | 'grok' | etc
  ai_model        text,
  hit_count       int not null default 0,       -- how many users served from cache
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_article_cache_key on article_cache (article_key);
create index if not exists idx_article_cache_created on article_cache (created_at desc);

-- ─────────────────────────────────────────────────────────────
-- Daily feed log — lightweight analytics (also doubles as the
-- "what's trending" signal for future personalization / VC metrics)
-- ─────────────────────────────────────────────────────────────
create table if not exists feed_events (
  id           bigint generated always as identity primary key,
  device_id    text not null,          -- anonymous installation id
  article_key  text not null references article_cache(article_key),
  event_type   text not null,          -- 'served' | 'read' | 'saved' | 'skipped'
  created_at   timestamptz not null default now()
);

create index if not exists idx_feed_events_device on feed_events (device_id, created_at desc);
create index if not exists idx_feed_events_article on feed_events (article_key);

-- ─────────────────────────────────────────────────────────────
-- Row Level Security
-- This is a shared anonymous cache — anon key can read/write
-- article_cache (no PII stored) and insert feed_events.
-- No one can read OTHER devices' feed_events (device_id filter
-- enforced at query time by the edge function, not by RLS,
-- since anon key has no auth.uid()). Keep this table free of
-- anything sensitive.
-- ─────────────────────────────────────────────────────────────
alter table article_cache enable row level security;
alter table feed_events    enable row level security;

create policy "anon can read cache"
  on article_cache for select
  to anon
  using (true);

create policy "anon can insert cache"
  on article_cache for insert
  to anon
  with check (true);

create policy "anon can update cache hit_count"
  on article_cache for update
  to anon
  using (true);

create policy "anon can insert feed events"
  on feed_events for insert
  to anon
  with check (true);

-- ─────────────────────────────────────────────────────────────
-- Helper view — cheap "is this app being used" dashboard query
-- ─────────────────────────────────────────────────────────────
create or replace view cache_stats as
select
  count(*)                                   as total_unique_articles,
  sum(hit_count)                             as total_cache_hits,
  coalesce(sum(hit_count) - count(*), 0)     as ai_calls_saved,
  count(distinct ai_provider)                as providers_used,
  max(created_at)                            as last_article_cached
from article_cache;
