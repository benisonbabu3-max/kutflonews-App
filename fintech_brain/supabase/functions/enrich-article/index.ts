// ════════════════════════════════════════════════════════════════════════
// enrich-article — THE shared-cache microservice.
//
// Given an article (title/url/content), returns a 60-word AI summary and a
// "why this matters" line. If another user already triggered enrichment for
// the SAME article (same content hash), the cached result is returned
// instantly with ZERO NVIDIA NIM tokens spent.
//
// This single cache is what makes the free tier sustainable: 1000 users
// reading the same morning RBI circular costs 1 NIM call, not 1000.
// ════════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, handleOptions, jsonResponse } from "../_shared/cors.ts";
import { callNim, cleanJson } from "../_shared/nim.ts";

interface EnrichRequest {
  id: string;            // sha256(title + '|' + url) — computed client-side
  title: string;
  url: string;
  rawContent: string;
  source: string;
  topic: string;
  type: string;
  estimatedMinutes: number;
  userHistory?: string;  // comma-separated recent topics, for personalisation
}

Deno.serve(async (req: Request) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Verify the caller is a real signed-in user (using the anon client +
    // their JWT). We don't need their identity for caching, just that
    // they're authenticated — keeps the free tier from being scraped.
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData, error: userErr } = await anonClient.auth.getUser();
    if (userErr || !userData?.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
    const userId = userData.user.id;

    const body: EnrichRequest = await req.json();
    if (!body.id || !body.title) {
      return jsonResponse({ error: "Missing id or title" }, 400);
    }

    // 1. Check the shared cache first
    const { data: cached } = await supabase
      .from("articles_cache")
      .select("id, summary, why_it_matters, enriched_at")
      .eq("id", body.id)
      .maybeSingle();

    if (cached?.enriched_at && cached.summary) {
      await logUsage(supabase, userId, "enrich", true, body.id);
      return jsonResponse({
        summary: cached.summary,
        whyItMatters: cached.why_it_matters,
        cached: true,
      });
    }

    // 2. Not cached — ensure a row exists (upsert raw data first)
    await supabase.from("articles_cache").upsert({
      id: body.id,
      title: body.title,
      url: body.url,
      source: body.source,
      topic: body.topic,
      type: body.type,
      estimated_minutes: body.estimatedMinutes,
      raw_content: body.rawContent?.slice(0, 2000) ?? "",
    }, { onConflict: "id" });

    // 3. Generate the 60-word summary via NVIDIA NIM
    const snippet = (body.rawContent ?? "").slice(0, 800);
    const prompt = `You are a fintech expert helping an Indian finance professional build domain knowledge.
Article title: "${body.title}"
Article excerpt: "${snippet}"
User recent topics: ${body.userHistory ?? "general fintech"}

Reply ONLY with this JSON (no markdown, no extra text):
{"summary":"Write exactly 60 words summarising the key facts and implications of this article in plain English","whyItMatters":"1 sentence: specific career relevance for an Indian fintech PM"}`;

    let summary = "";
    let whyItMatters = "";
    try {
      const raw = await callNim(prompt, { temperature: 0.6, maxTokens: 400 });
      const parsed = JSON.parse(cleanJson(raw));
      summary = String(parsed.summary ?? "");
      whyItMatters = String(parsed.whyItMatters ?? "");
    } catch (e) {
      console.error("NIM enrichment failed:", e);
      // Graceful fallback — never leave the user with an empty card
      summary = `${body.title} — a development in Indian fintech relevant to ${body.topic}. ` +
        `Tap "Read full" to view the complete article on ${body.source} for full details and context.`;
      whyItMatters = `Relevant to your interest in ${body.topic}.`;
    }

    // 4. Write back to the shared cache so the NEXT user gets a free hit
    await supabase.from("articles_cache").update({
      summary,
      why_it_matters: whyItMatters,
      enriched_at: new Date().toISOString(),
    }).eq("id", body.id);

    await logUsage(supabase, userId, "enrich", false, body.id);

    return jsonResponse({ summary, whyItMatters, cached: false });
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: String(err) }, 500);
  }
});

async function logUsage(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  kind: string,
  cacheHit: boolean,
  articleId?: string,
) {
  try {
    await supabase.from("ai_usage_log").insert({
      user_id: userId,
      kind,
      cache_hit: cacheHit,
      article_id: articleId ?? null,
    });
  } catch (e) {
    console.error("usage log failed:", e);
  }
}
