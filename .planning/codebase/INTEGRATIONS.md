# External Integrations

**Analysis Date:** 2026-04-05

## APIs & External Services

### Anthropic Claude API (Coach AI)
- **Purpose:** Server-side AI coaching - generates personalized financial education responses with tool calling
- **SDK:** `anthropic` Python SDK (>=0.40.0) - `services/backend/pyproject.toml`
- **Model:** `claude-sonnet-4-20250514` (configurable via `COACH_MODEL` env var) - `services/backend/app/core/config.py:47`
- **Auth:** `ANTHROPIC_API_KEY` env var (set in Railway dashboard)
- **Quota:** 30 requests/user/day (free tier) via `COACH_DAILY_QUOTA` - `services/backend/app/core/config.py:49`
- **Max tokens:** 500 per response via `COACH_MAX_TOKENS` - `services/backend/app/core/config.py:48`
- **Endpoints:** `services/backend/app/api/v1/endpoints/coach.py`, `services/backend/app/api/v1/endpoints/coach_chat.py`

### BYOK LLM Client (User-provided keys)
- **Purpose:** Users can bring their own API key for chat (privacy-first model)
- **Supported providers:** Claude, OpenAI, Mistral - `services/backend/app/services/rag/llm_client.py:22`
- **Default models:** claude-sonnet-4-5-20250929, gpt-4o, mistral-large-latest - `services/backend/app/services/rag/llm_client.py:16-20`
- **Auth:** User provides API key per-request (MINT never stores keys)
- **Flutter client:** `apps/mobile/lib/services/coach_llm_service.dart` - providers: openai, anthropic, mistral

### Stripe (Billing - Web/Android)
- **Purpose:** Subscription checkout + billing portal + webhooks
- **Auth:** `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` env vars - `services/backend/app/core/config.py:40-41`
- **Endpoints:** `services/backend/app/api/v1/endpoints/billing.py`
- **Products:**
  - Starter monthly/annual: `STRIPE_PRICE_STARTER_MONTHLY`, `STRIPE_PRICE_STARTER_ANNUAL`
  - Premium monthly/annual: `STRIPE_PRICE_PREMIUM_MONTHLY`, `STRIPE_PRICE_PREMIUM_ANNUAL`
  - Couple+ monthly/annual: `STRIPE_PRICE_COUPLE_PLUS_MONTHLY`, `STRIPE_PRICE_COUPLE_PLUS_ANNUAL`
- **Webhook:** `POST /api/v1/billing/webhooks/stripe` - signature verification via `Stripe-Signature` header

### Apple In-App Purchase (iOS Billing)
- **Purpose:** iOS subscription management via StoreKit
- **Flutter SDK:** `in_app_purchase: ^3.2.0` - `apps/mobile/pubspec.yaml`
- **Products:**
  - `ch.mint.starter.monthly`
  - `ch.mint.premium.monthly`
  - `ch.mint.couple_plus.monthly`
  - `ch.mint.coach.monthly` (legacy)
- **Auth:** `APPLE_WEBHOOK_SHARED_SECRET` env var
- **Service:** `apps/mobile/lib/services/ios_iap_service.dart`

### Sentry (Error Tracking)
- **Purpose:** Error tracking + performance monitoring (production/staging only)
- **Backend SDK:** `sentry-sdk[fastapi]: >=2.0.0` - `services/backend/app/main.py:23-30`
- **Flutter SDK:** `sentry_flutter: ^8.0.0` - `apps/mobile/lib/main.dart:6`
- **Auth:** `SENTRY_DSN` (backend env var), `SENTRY_DSN_MOBILE` (GitHub secret, injected via `--dart-define`)
- **Config:** traces_sample_rate=0.1, profiles_sample_rate=0.1, send_default_pii=False (nLPD compliance)

### SMTP (Transactional Email)
- **Purpose:** Password reset, email verification
- **Auth:** `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` env vars
- **Config:** `services/backend/app/core/config.py:85-88`
- **Feature gate:** `EMAIL_SEND_ENABLED` (default: false)
- **From:** `no-reply@mint.ch`

## On-Device AI (SLM)

### Gemma 3n E4B (On-Device)
- **Purpose:** Privacy-first on-device inference - zero network traffic during AI generation
- **Model:** Gemma 3n E4B IT (~4.4 GB on disk) via Google MediaPipe
- **Flutter SDK:** `flutter_gemma: ^0.11.16` - `apps/mobile/pubspec.yaml`
- **Engine:** `apps/mobile/lib/services/slm/slm_engine.dart`
- **Download:** `apps/mobile/lib/services/slm/slm_download_service.dart`
- **Auth:** `HUGGINGFACE_TOKEN` (GitHub secret, for gated model download only - NOT embedded in binary)
- **Priority chain** (in CoachNarrativeService):
  1. SLM on-device (if model downloaded + initialized)
  2. BYOK cloud LLM (if API key configured)
  3. Static templates (always available)

## Data Storage

### PostgreSQL (Production)
- **Connection:** `DATABASE_URL` env var - `services/backend/app/core/config.py:17`
- **ORM:** SQLAlchemy 2.0 - `services/backend/app/core/database.py`
- **Migrations:** Alembic - `services/backend/alembic/`
- **Driver:** psycopg2-binary
- **Dev fallback:** SQLite (`sqlite:///./mint.db`)

### ChromaDB (RAG Vector Store)
- **Purpose:** Vector embeddings for education content RAG retrieval
- **Optional dependency:** `pip install ".[rag]"` - `services/backend/pyproject.toml:39-44`
- **Persistence:** `services/backend/data/chromadb/` (local file-based)
- **Auto-ingest:** Education inserts from `education/inserts/` on startup if store is empty - `services/backend/app/main.py:194-247`
- **Service files:** `services/backend/app/services/rag/` (vector_store.py, ingester.py, retriever.py, orchestrator.py, hybrid_search_service.py)

### Redis (Rate Limiting)
- **Purpose:** Rate limiting backend (optional)
- **Connection:** `REDIS_URL` env var (empty = in-memory fallback)
- **Library:** slowapi - `services/backend/app/core/rate_limit.py`

### Flutter Local Storage
- **SharedPreferences:** Settings, cache, regulatory sync data - `shared_preferences: ^2.3.2`
- **Flutter Secure Storage:** Auth tokens, API keys - `flutter_secure_storage: ^9.0.0`
- **Static assets:** `apps/mobile/assets/config/` - tax_scales.json, pillar_3a_limits.json, commune_multipliers.json, personas.json

## OCR & Document Processing

### Google ML Kit Text Recognition (On-Device)
- **Purpose:** OCR scanning of financial documents (LPP certificates, tax forms)
- **Flutter SDK:** `google_mlkit_text_recognition: ^0.15.0` - `apps/mobile/pubspec.yaml`
- **Usage:** `apps/mobile/lib/screens/onboarding/steps/step_ocr_upload.dart`
- **Processing:** On-device (no cloud upload)

### PDF Processing (Backend)
- **Purpose:** PDF text extraction for document ingestion
- **Library:** `pdfplumber: >=0.11.0` (optional docling dependency)
- **Install:** `pip install ".[docling]"` - `services/backend/pyproject.toml:46-48`

## Future/Planned Integrations (Feature-Flagged)

### bLink Open Banking
- **Status:** Feature-flagged (`FF_ENABLE_BLINK_PRODUCTION`)
- **Config:** `BLINK_API_URL` env var - `services/backend/app/core/config.py:76`
- **Purpose:** Swiss Open Banking standard for account data import

### Caisse Pension API
- **Status:** Feature-flagged (`FF_ENABLE_CAISSE_PENSION_API`)
- **Config:** `CAISSE_PENSION_API_URL` env var - `services/backend/app/core/config.py:77`
- **Purpose:** Institutional pension fund data access

### AVS Institutional API
- **Status:** Feature-flagged (`FF_ENABLE_AVS_INSTITUTIONAL`)
- **Config:** `AVS_INSTITUTIONAL_API_URL` env var - `services/backend/app/core/config.py:78`
- **Purpose:** Direct AVS/AHV data access

## CI/CD & Deployment

### GitHub Actions
- **CI:** `.github/workflows/ci.yml` - runs on push to dev/staging/main + PRs
  - Backend: pytest + pip-audit + OpenAPI contract check + Alembic migration check
  - Flutter: 3-shard parallel (services/widgets/screens) + flutter analyze
  - Gate: all shards must pass
- **Deploy:** `.github/workflows/deploy-backend.yml` - Railway deploy on PR merge to staging/main
- **TestFlight:** `.github/workflows/testflight.yml` - manual dispatch, Fastlane beta upload
- **Web:** `.github/workflows/web.yml`
- **Play Store:** `.github/workflows/play-store.yml`

### Railway (Backend Hosting)
- **Staging:** mint-staging.up.railway.app
- **Production:** mint-production-3a41.up.railway.app
- **Deploy method:** Auto-deploy from GitHub on push (NOT `railway up` CLI - loses env vars)
- **Config:** `services/backend/railway.json` - Dockerfile builder, healthcheck at `/api/v1/health`
- **Pre-deploy:** Alembic migration script (`scripts/railway_pre_deploy_migrate.py`)

### App Store Connect / TestFlight
- **Purpose:** iOS beta distribution
- **Auth:** App Store Connect API key (base64 .p8), Match certificates
- **Runner:** macos-15 (GitHub Actions)
- **Secrets:** `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`, `MATCH_GIT_URL`, `MATCH_PASSWORD`

## Authentication & Identity

### Custom JWT Auth
- **Implementation:** Custom JWT-based auth (not a third-party provider)
- **Backend:** `services/backend/app/api/v1/endpoints/auth.py`
- **Flutter:** `apps/mobile/lib/services/auth_service.dart`
- **Algorithm:** HS256 - `services/backend/app/core/config.py:21`
- **Expiry:** 24 hours - `services/backend/app/core/config.py:22`
- **Password hashing:** passlib + bcrypt
- **Email verification:** Configurable via `AUTH_REQUIRE_EMAIL_VERIFICATION` (forced in production)

## Environment Configuration

### Required env vars (production):
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET_KEY` - Must NOT be default (fail-fast in production)
- `ANTHROPIC_API_KEY` - Claude coach AI
- `SENTRY_DSN` - Error tracking
- `CORS_ORIGINS` - Comma-separated allowed origins
- `ENVIRONMENT` - "production" or "staging"

### Optional env vars:
- `REDIS_URL` - Rate limiting (in-memory fallback)
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` - Stripe billing
- `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD` - Email
- `BLINK_API_URL` - Open Banking (future)

### Secrets location:
- Railway dashboard (staging + production environments)
- GitHub Secrets (CI/CD workflows)
- Never in code or `.env` files committed to git

## Webhooks & Callbacks

### Incoming:
- `POST /api/v1/billing/webhooks/stripe` - Stripe payment events
- Apple StoreKit server notifications (via `APPLE_WEBHOOK_SHARED_SECRET`)

### Outgoing:
- None detected

---

*Integration audit: 2026-04-05*
