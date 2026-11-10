# Fintech Brain v3 — Backend Setup Guide

Complete step-by-step: Google Auth + NVIDIA NIM + Supabase shared cache in ~30 minutes.

---

## Architecture

```
Flutter app
   │
   ├─ Google Sign-In  ──► Supabase Auth (session JWT)
   │
   └─ API calls (with JWT) ──► Supabase Edge Functions
                                       │
                          ┌────────────┴─────────────┐
                          │                           │
                   articles_cache              NVIDIA NIM
                    (Postgres)              (only on miss)
                   cache hit? ──► free
```

---

## Step 1 — Create Supabase project

1. Go to https://supabase.com → **New project**
2. Name: `fintech-brain`, region: **ap-south-1** (Mumbai — best latency from India)
3. Wait ~2 min. Then **Project Settings → API** → copy:
   - `Project URL` → paste into `lib/services/supabase_service.dart` → `url`
   - `anon public` key → paste as `anonKey`

---

## Step 2 — Run the database schema

1. Supabase → **SQL Editor → New query**
2. Paste entire contents of `supabase/migrations/001_init.sql`
3. Click **Run** — creates all tables, RLS policies, and the new-user trigger

---

## Step 3 — NVIDIA NIM free API key

1. Go to https://build.nvidia.com → sign in (free)
2. Search `meta/llama-3.1-8b-instruct` → **Get API Key** (starts with `nvapi-`)
3. Set secrets via Supabase CLI:

```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF   # Settings → General

supabase secrets set NVIDIA_NIM_API_KEY=nvapi-xxxxxxxxxx
supabase secrets set NVIDIA_NIM_MODEL=meta/llama-3.1-8b-instruct
```

**Other free NIM models:** `mistralai/mistral-7b-instruct-v0.3`, `google/gemma-7b`

---

## Step 4 — Deploy edge functions

```bash
supabase functions deploy enrich-article
supabase functions deploy ai-chat
supabase functions deploy generate-briefs
```

Verify: Supabase → **Edge Functions** — all three show as deployed.

---

## Step 5 — Enable Google Sign-In

### 5a. Google Cloud Console
1. https://console.cloud.google.com → APIs & Services → Credentials
2. Create **two** OAuth 2.0 Client IDs:

**Web application** (for Supabase Auth):
- Redirect URI: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
- Copy Client ID + Secret

**Android**:
- Package: `com.example.fintech_brain`
- SHA-1 (debug): `cd android && ./gradlew signingReport`

**iOS**: Download `GoogleService-Info.plist` → drag into Xcode under Runner/

### 5b. Supabase → Authentication → Providers → Google
- Enable → paste Web Client ID + Secret

### 5c. Flutter — fill in `lib/services/supabase_service.dart`
```dart
static const String url = 'https://YOUR_PROJECT.supabase.co';
static const String anonKey = 'YOUR_ANON_KEY';
static const String googleWebClientId = 'XXXXXXXX.apps.googleusercontent.com';
```

### 5d. iOS — update `ios/Runner/Info.plist`
Replace `YOUR_CLIENT_ID` with `REVERSED_CLIENT_ID` from `GoogleService-Info.plist`:
```xml
<string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
```

### 5e. Supabase → Authentication → URL Configuration
Add redirect URL:
```
io.supabase.fintechbrain://login-callback/
```

---

## Step 6 — Run

```bash
flutter pub get
flutter run
```

---

## Cost estimate on free tiers

| Service | Free limit | Typical usage (20 beta users) |
|---|---|---|
| Supabase | 500 MB DB, 500K edge fn calls/month | ~600 calls/day → fine |
| NVIDIA NIM | ~1,000 req/day | 4–10/day (cache handles the rest) |
| Google Sign-In | Unlimited <1M users | Fine |

**Cache math:** 20 users × 4 articles = 80 potential NIM calls per morning.
Because summaries are cached per-article, only the **first** user to see each article
triggers a NIM call. Total = 4 calls instead of 80. **95% savings.**

---

## Manual test (curl)

```bash
TOKEN="eyJ..."  # from Supabase → Auth → Users → pick user → JWT

curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/enrich-article" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-rbi-upi-001",
    "title": "RBI raises UPI Lite offline limit to Rs 1,000",
    "url": "https://rbi.org.in",
    "rawContent": "The Reserve Bank of India has doubled the per-transaction cap...",
    "source": "RBI", "topic": "Payments", "type": "rbiCircular",
    "estimatedMinutes": 5, "userHistory": "payments, regulation"
  }'
```

First call: `{"cached":false, "summary":"...60 words..."}`
Second call: `{"cached":true, "summary":"...same 60 words, zero NIM tokens..."}`

---

## Project file structure

```
fintech_brain/
├── lib/
│   ├── main.dart                     ← AuthGate wires Google sign-in
│   ├── screens/auth_screen.dart      ← NEW: Google sign-in screen
│   └── services/
│       ├── supabase_service.dart     ← NEW: Supabase init + Google auth
│       ├── ai_service.dart           ← Calls edge functions (no device keys)
│       └── article_repository.dart   ← Syncs profile/stats to Supabase
│
└── supabase/
    ├── migrations/001_init.sql       ← Tables + RLS + new-user trigger
    └── functions/
        ├── _shared/cors.ts           ← CORS headers helper
        ├── _shared/nim.ts            ← NVIDIA NIM client
        ├── enrich-article/index.ts   ← 60-word summary, shared cache
        ├── ai-chat/index.ts          ← Inline chat, 30/day rate limit
        └── generate-briefs/index.ts  ← AI filler, cached by date+interests
```
