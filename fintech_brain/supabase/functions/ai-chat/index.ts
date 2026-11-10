// ════════════════════════════════════════════════════════════════════════
// ai-chat — inline "Ask AI about this article" microservice.
//
// Per-user, conversational, NOT cached (every question is different).
// Rate-limited per user per day to protect the NVIDIA NIM free tier.
// ════════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, handleOptions, jsonResponse } from "../_shared/cors.ts";
import { callNim } from "../_shared/nim.ts";

const DAILY_CHAT_LIMIT = 30; // generous for testing; tune later

interface ChatRequest {
  articleId: string;
  articleTitle: string;
  articleSummary: string;
  question: string;
  history?: { role: "user" | "ai"; content: string }[];
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

    // Rate limit check — count today's chat calls for this user
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);
    const { count } = await supabase
      .from("ai_usage_log")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("kind", "chat")
      .gte("created_at", todayStart.toISOString());

    if ((count ?? 0) >= DAILY_CHAT_LIMIT) {
      return jsonResponse({
        answer: `You've used your ${DAILY_CHAT_LIMIT} free AI chats for today. ` +
          `This resets at midnight UTC. Thanks for exploring — come back tomorrow!`,
        limited: true,
      });
    }

    const body: ChatRequest = await req.json();
    if (!body.question?.trim()) {
      return jsonResponse({ error: "Missing question" }, 400);
    }

    const historyStr = (body.history ?? [])
      .slice(-6) // keep prompt small
      .map((m) => `${m.role === "user" ? "User" : "AI"}: ${m.content}`)
      .join("\n");

    const prompt = `You are a fintech expert assistant embedded in a learning app for Indian finance professionals.

Article being read: "${body.articleTitle}"
Article summary: "${body.articleSummary}"

Conversation so far:
${historyStr}
User: ${body.question}

Reply in 2-4 sentences. Be specific, practical, and focused on Indian fintech career relevance. No bullet points. Plain English.`;

    let answer: string;
    try {
      answer = await callNim(prompt, { temperature: 0.7, maxTokens: 350 });
    } catch (e) {
      console.error("NIM chat failed:", e);
      answer = "I couldn't reach the AI right now. Please try again in a moment.";
    }

    await supabase.from("ai_usage_log").insert({
      user_id: userId,
      kind: "chat",
      cache_hit: false,
      article_id: body.articleId ?? null,
    });

    return jsonResponse({
      answer,
      remaining: Math.max(0, DAILY_CHAT_LIMIT - (count ?? 0) - 1),
    });
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: String(err) }, 500);
  }
});
