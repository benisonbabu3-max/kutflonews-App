// ════════════════════════════════════════════════════════════════════════
// generate-briefs — fills feed gaps when RSS returns too few articles.
//
// Cached per (date + topic-set) so all users with similar interests on the
// same day share the same generated briefs — another NIM-token saver.
// ════════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, handleOptions, jsonResponse } from "../_shared/cors.ts";
import { callNim, cleanJson } from "../_shared/nim.ts";

interface BriefsRequest {
  interests: string[];
  coveredTopics: string[];
  count: number;
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

    const body: BriefsRequest = await req.json();
    const interests = (body.interests ?? []).slice(0, 5).sort();
    const count = Math.min(body.count ?? 2, 4);
    const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

    // Cache key: date + sorted interest list — shared across users with
    // the same interest profile on the same day.
    const cacheId = `brief_${today}_${interests.join("-").toLowerCase().replace(/[^a-z0-9-]/g, "")}`;

    const { data: cached } = await supabase
      .from("articles_cache")
      .select("id, title, url, summary, why_it_matters, source, topic, type, estimated_minutes")
      .like("id", `${cacheId}%`);

    if (cached && cached.length >= count) {
      await logUsage(supabase, userId, "brief", true);
      return jsonResponse({ briefs: cached.slice(0, count).map(toBrief) });
    }

    // Generate fresh briefs via NIM
    const dateLabel = new Date().toLocaleDateString("en-IN", {
      weekday: "long", year: "numeric", month: "long", day: "numeric",
    });
    const prompt = `You are curating a daily fintech feed for an Indian fintech professional.
Date: ${dateLabel}. Their interests: ${interests.join(", ")}.
Already covered topics today: ${(body.coveredTopics ?? []).join(", ")}.

Generate ${count} fintech knowledge items on DIFFERENT topics from their interests.
Each summary must be exactly 60 words.

Reply ONLY with a JSON array (no markdown fences):
[{"title":"specific headline","summary":"exactly 60 word plain-English summary of the news or concept","whyItMatters":"1-sentence career relevance","topic":"Payments|Regulation|Product|AI & Tech|Geopolitics|Startups","type":"rbiCircular|npciUpdate|productBlog|news|research|geopolitics|career","source":"publisher","url":"https://...","estimatedMinutes":5}]`;

    let briefs: Brief[] = [];
    try {
      const raw = await callNim(prompt, { temperature: 0.8, maxTokens: 900 });
      briefs = JSON.parse(cleanJson(raw));
    } catch (e) {
      console.error("NIM briefs failed:", e);
      briefs = [];
    }

    // Cache each generated brief
    for (let i = 0; i < briefs.length; i++) {
      const b = briefs[i];
      const id = `${cacheId}_${i}`;
      await supabase.from("articles_cache").upsert({
        id,
        title: b.title ?? "Fintech update",
        url: b.url ?? "https://rbi.org.in",
        source: b.source ?? "AI Brief",
        topic: b.topic ?? "General",
        type: b.type ?? "news",
        estimated_minutes: b.estimatedMinutes ?? 5,
        summary: b.summary ?? "",
        why_it_matters: b.whyItMatters ?? "",
        enriched_at: new Date().toISOString(),
      }, { onConflict: "id" });
    }

    await logUsage(supabase, userId, "brief", false);

    return jsonResponse({
      briefs: briefs.map((b, i) => ({ ...toBrief(b), id: `${cacheId}_${i}` })),
    });
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: String(err) }, 500);
  }
});

interface Brief {
  id?: string; title?: string; url?: string; summary?: string;
  why_it_matters?: string; whyItMatters?: string; source?: string;
  topic?: string; type?: string; estimated_minutes?: number; estimatedMinutes?: number;
}

function toBrief(b: Brief) {
  return {
    id: b.id,
    title: b.title,
    url: b.url,
    summary: b.summary,
    whyItMatters: b.whyItMatters ?? b.why_it_matters,
    source: b.source,
    topic: b.topic,
    type: b.type,
    estimatedMinutes: b.estimatedMinutes ?? b.estimated_minutes,
  };
}

async function logUsage(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  kind: string,
  cacheHit: boolean,
) {
  try {
    await supabase.from("ai_usage_log").insert({ user_id: userId, kind, cache_hit: cacheHit });
  } catch (e) {
    console.error("usage log failed:", e);
  }
}
