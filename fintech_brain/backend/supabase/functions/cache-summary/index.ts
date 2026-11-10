// ═══════════════════════════════════════════════════════════════
// Fintech Brain — cache-summary Edge Function
// ─────────────────────────────────────────────────────────────
// POST /functions/v1/cache-summary
//
// Actions (in JSON body):
//
// 1. { "action": "get", "article_key": "<sha1-of-url>" }
//    → Returns cached summary if it exists (and bumps hit_count).
//    → { found: true, summary, whyItMatters, source, ... }
//    → { found: false }  if not cached yet
//
// 2. { "action": "save", "article_key": "...", "title": "...",
//       "url": "...", "summary": "...", "whyItMatters": "...",
//       "source": "...", "topic": "...", "articleType": "...",
//       "estimatedMinutes": 5, "aiProvider": "ollama",
//       "aiModel": "llama3.2" }
//    → Upserts the cache row. First writer wins for the summary
//      text (so concurrent first-reads don't thrash), but
//      hit_count still increments.
//    → { saved: true }
//
// 3. { "action": "event", "device_id": "...", "article_key": "...",
//       "event_type": "served" | "read" | "saved" | "skipped" }
//    → Lightweight analytics log. Fire-and-forget from the app.
//    → { logged: true }
//
// 4. { "action": "stats" }
//    → Returns aggregate cache_stats view (for a tiny admin
//      dashboard / VC-friendly "look how cheap this is" metric).
// ═══════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const action = body.action as string;

  switch (action) {
    case "get":      return await handleGet(body);
    case "save":     return await handleSave(body);
    case "event":    return await handleEvent(body);
    case "stats":    return await handleStats();
    default:
      return json({ error: `Unknown action: ${action}` }, 400);
  }
});

// ── GET ──────────────────────────────────────────────────────────
async function handleGet(body: Record<string, unknown>) {
  const articleKey = body.article_key as string;
  if (!articleKey) return json({ error: "article_key required" }, 400);

  const { data, error } = await supabase
    .from("article_cache")
    .select("*")
    .eq("article_key", articleKey)
    .maybeSingle();

  if (error) return json({ error: error.message }, 500);
  if (!data) return json({ found: false });

  // Bump hit_count (fire and forget — don't block the response)
  supabase
    .from("article_cache")
    .update({ hit_count: (data.hit_count ?? 0) + 1 })
    .eq("article_key", articleKey)
    .then(() => {})
    .catch(() => {});

  return json({
    found: true,
    title: data.title,
    summary: data.summary,
    whyItMatters: data.why_it_matters,
    source: data.source,
    topic: data.topic,
    articleType: data.article_type,
    estimatedMinutes: data.estimated_minutes,
    aiProvider: data.ai_provider,
    hitCount: (data.hit_count ?? 0) + 1,
  });
}

// ── SAVE ─────────────────────────────────────────────────────────
async function handleSave(body: Record<string, unknown>) {
  const articleKey = body.article_key as string;
  if (!articleKey) return json({ error: "article_key required" }, 400);

  // Check if it already exists — first writer wins on content,
  // we just bump hit_count if someone else already cached it.
  const { data: existing } = await supabase
    .from("article_cache")
    .select("article_key, hit_count")
    .eq("article_key", articleKey)
    .maybeSingle();

  if (existing) {
    await supabase
      .from("article_cache")
      .update({ hit_count: (existing.hit_count ?? 0) + 1 })
      .eq("article_key", articleKey);
    return json({ saved: true, alreadyCached: true });
  }

  const { error } = await supabase.from("article_cache").insert({
    article_key: articleKey,
    title: body.title ?? "",
    url: body.url ?? "",
    source: body.source ?? "",
    topic: body.topic ?? "",
    article_type: body.articleType ?? "",
    estimated_minutes: body.estimatedMinutes ?? 5,
    summary: body.summary ?? "",
    why_it_matters: body.whyItMatters ?? "",
    ai_provider: body.aiProvider ?? "unknown",
    ai_model: body.aiModel ?? "",
    hit_count: 1,
  });

  if (error) return json({ error: error.message }, 500);
  return json({ saved: true, alreadyCached: false });
}

// ── EVENT (analytics) ───────────────────────────────────────────
async function handleEvent(body: Record<string, unknown>) {
  const { error } = await supabase.from("feed_events").insert({
    device_id: body.device_id ?? "unknown",
    article_key: body.article_key ?? "",
    event_type: body.event_type ?? "served",
  });
  if (error) return json({ error: error.message }, 500);
  return json({ logged: true });
}

// ── STATS ────────────────────────────────────────────────────────
async function handleStats() {
  const { data, error } = await supabase.from("cache_stats").select("*").maybeSingle();
  if (error) return json({ error: error.message }, 500);
  return json(data ?? {});
}
