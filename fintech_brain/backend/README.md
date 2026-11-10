# Fintech Brain — Backend (Shared AI Cache)

This is the **minimal backend** for the v6 closed-beta release. Its only
job: cache AI-generated article summaries so that **the AI runs once per
article, not once per user**.

```
User A opens app → article X not cached → app asks local Ollama →
  generates 60-word summary → saves to Supabase cache
User B opens app → article X cached → instant, free, no AI call
User C, D, E... → all instant, free
```

During the **testing phase**, AI generation happens via **Ollama running on
your laptop** — the Flutter app calls Ollama directly (not the edge
function), then writes the result to the shared Supabase cache. Once this
works end-to-end, swap the AI call to a cloud provider (Gemini/Grok/OpenAI)
**inside `ollama_service.dart` only** — the cache layer doesn't change.

---

## 1. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → New Project (free tier is
   plenty for 20 beta users).
2. Note down, from **Project Settings → API**:
   - `Project URL` → e.g. `https://abcxyz.supabase.co`
   - `anon public` key
   - `service_role` key (keep secret — only used by the edge function)

## 2. Run the migration

In the Supabase dashboard → **SQL Editor** → paste the contents of
`supabase/migrations/0001_init.sql` → Run.

This creates:
- `article_cache` — the shared summary cache (no PII)
- `feed_events` — lightweight anonymous usage analytics
- `cache_stats` — a view showing "AI calls saved" (great VC metric)

## 3. Deploy the edge function

Install the Supabase CLI if you haven't:
```bash
npm install -g supabase
```

From the `backend/` folder:
```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy cache-summary --no-verify-jwt
```

Set the service role key as a secret (needed by the function):
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
supabase secrets set SUPABASE_URL=https://<your-project-ref>.supabase.co
```

Your function is now live at:
```
https://<your-project-ref>.supabase.co/functions/v1/cache-summary
```

## 4. Configure the Flutter app

Edit `lib/config/app_config.dart`:
```dart
static const supabaseFunctionUrl =
  'https://<your-project-ref>.supabase.co/functions/v1/cache-summary';
static const supabaseAnonKey = '<your-anon-public-key>';
```

The anon key is safe to ship in the app — RLS policies restrict it to
read/insert on `article_cache` and insert-only on `feed_events`.

## 5. Set up Ollama for testing

On your laptop:
```bash
ollama pull llama3.2        # or any model you prefer
ollama serve                # runs on http://localhost:11434
```

Find your laptop's LAN IP (so your phone/emulator can reach it):
```bash
# macOS / Linux
ipconfig getifaddr en0   # or: hostname -I

# Windows
ipconfig
```

In the app → **Profile → AI Engine**, set the Ollama URL to:
- Android emulator: `http://10.0.2.2:11434`
- Physical phone on same Wi-Fi: `http://<your-laptop-LAN-IP>:11434`

Tap **Test connection** — it should go green.

## 6. Check the dashboard

Query `cache_stats` anytime in the SQL editor:
```sql
select * from cache_stats;
```

`ai_calls_saved` is your headline number for investors / your own sanity:
it's literally "AI calls we did NOT have to pay for."

## 7. Swapping AI providers later

Everything AI-related lives in `lib/services/ollama_service.dart`. To
switch to Gemini/Grok/OpenAI:
1. Add the new API call inside that file (or create
   `cloud_ai_service.dart` with the same method signatures).
2. Update `article_repository.dart`'s one call site.
3. The cache layer, schema, and edge function need **zero changes** —
   `ai_provider` / `ai_model` columns already track which engine produced
   each cached summary.
