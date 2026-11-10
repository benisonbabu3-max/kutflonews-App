# 🧠 Fintech Brain

> Your daily fintech knowledge feeder. 10 minutes a day, 300+ pieces of domain knowledge in 11 months.

---

## What it does

- **Morning & evening push notifications** — reminders to read your daily dose
- **AI-curated daily feed** — 4 articles per day: one RBI/regulatory, one product blog, one news, one research/LinkedIn
- **"Why this matters" hook** — Gemini/Grok explains each article's relevance to Indian fintech careers
- **RSS + AI fill-in** — pulls real articles from RBI, NPCI, Inc42, YourStory, Entrackr; AI generates briefs when RSS is sparse
- **Fintech Brain vault** — save anything interesting; spaced repetition nudges after 7 days
- **Streak counter** — daily streaks with milestone celebrations
- **Topic balance tracker** — see if you're overloading on payments and neglecting lending/regulation

---

## Setup (15 minutes)

### 1. Install Flutter
```bash
# Follow official guide:
https://docs.flutter.dev/get-started/install
```

### 2. Get your free API keys

**Gemini (Google AI Studio) — Free:**
1. Go to https://aistudio.google.com/apikey
2. Sign in with Google
3. Click "Create API Key"
4. Copy the key

**Grok (xAI) — Free tier:**
1. Go to https://console.x.ai/
2. Create account
3. Go to API Keys → Create key
4. Copy the key

### 3. Configure the app

```bash
# Clone / download the project
cd fintech_brain

# Copy the env template
cp .env.example .env

# Edit .env and paste your keys:
# GEMINI_API_KEY=AIza...your_key_here
# GROK_API_KEY=xai-...your_key_here
nano .env
```

Alternatively, you can enter keys directly in the app under **Settings → AI API Keys** (stored securely in SharedPreferences).

### 4. Run the app

```bash
# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build release APK (Android)
flutter build apk --release

# Build for iOS (needs Mac + Xcode)
flutter build ios --release
```

---

## Project structure

```
lib/
├── main.dart                    # App entry, navigation shell
├── models/
│   ├── article.dart             # Article model + Hive annotations
│   ├── article.g.dart           # Hive generated adapter
│   └── user_stats.dart          # Streak, progress tracking
├── services/
│   ├── ai_service.dart          # Gemini primary, Grok fallback
│   ├── rss_service.dart         # RSS feeds (RBI, NPCI, Inc42, etc.)
│   ├── article_repository.dart  # Combines RSS + AI, manages storage
│   └── notification_service.dart # Morning/evening push notifications
├── screens/
│   ├── feed_screen.dart         # Today's curated feed
│   ├── vault_screen.dart        # Saved articles + search
│   ├── progress_screen.dart     # Stats, topic chart, streak
│   └── settings_screen.dart     # API keys, notification toggle
├── widgets/
│   └── article_card.dart        # Reusable article card with actions
└── utils/
    └── theme.dart               # Colors, typography, AppTheme
```

---

## RSS feeds included

| Source | Type | Topic |
|--------|------|-------|
| RBI.org.in | RBI circulars | Regulation |
| NPCI.org.in | NPCI press releases | Payments |
| Inc42.com | Startup news | Startup News |
| Entrackr.com | Fintech news | Startup News |
| YourStory.com | Startup stories | Startup News |
| Fintech Global | Research | Infra/Tech |
| Fintech Times | News | Payments |
| Medium/fintech | Product blogs | Infra/Tech |

---

## Free tier API limits

| API | Free limit | Notes |
|-----|-----------|-------|
| Gemini 1.5 Flash | 15 req/min, 1M tokens/day | More than enough for 4 articles/day |
| Grok Beta | See console.x.ai | Used as fallback only |

The app uses ~8–12 AI calls per day (enriching 4 articles + optionally generating 2 briefs). Well within free limits.

---

## Customization

**Add more RSS feeds** — edit `rss_service.dart`, add entries to `_feeds` list.

**Change notification times** — edit `notification_service.dart`, change `hour` in `scheduleDailyReminders()`.

**Adjust daily article count** — edit `article_repository.dart`, change `.take(4)` in `_buildDailyFeed()`.

**Add topics** — extend the `topicCounts` logic in `user_stats.dart` and `AppColors.topicColor()` in `theme.dart`.

---

## Tech stack (all free & open source)

| Package | Purpose |
|---------|---------|
| `hive` + `hive_flutter` | Local storage (fast, no SQL) |
| `shared_preferences` | Settings, stats |
| `http` | API calls |
| `webfeed` + `xml` | RSS parsing |
| `flutter_local_notifications` | Push notifications |
| `fl_chart` | Progress charts |
| `shimmer` | Loading skeletons |
| `url_launcher` | Open articles in browser |
| `share_plus` | Share articles |
| `flutter_dotenv` | API key management |

---

## License

MIT — use, modify, share freely.
