# External Integrations

**Analysis Date:** 2026-04-22

## APIs & External Services

**AI / LLM:**
- Anthropic Claude API — primary coach AI (chat, tool-calling, vision)
  - SDK: `anthropic >=0.40.0,<1.0.0` (`services/backend/pyproject.toml`)
  - Auth: `ANTHROPIC_API_KEY` env var
  - Default model: `claude-sonnet-4-20250514` (config: `COACH_MODEL`)
  - MVP economy model: `claude-haiku-4-5-20251001` (activated via `MINT_LLM_TIER=mvp`)
  - Max tokens: 350 (hardcapped, `COACH_MAX_TOKENS`), daily quota 30 messages/user free tier
  - Entry: `services/backend/app/services/llm/router.py` (LLMRouter), `services/backend/app/services/llm/tier.py`

- AWS Bedrock (eu-central-1 / Frankfurt) — optional nLPD-compliant inference fallback
  - SDK: `boto3 >=1.34,<2.0` (optional `kms` extra)
  - Auth: `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (boto3 standard chain)
  - Models: `anthropic.claude-sonnet-4-5-20251022-v1:0` / `anthropic.claude-haiku-4-5-20251022-v1:0`
  - Override env: `MINT_BEDROCK_SONNET_MODEL_ID`, `MINT_BEDROCK_HAIKU_MODEL_ID`, `MINT_BEDROCK_REGION`
  - Entry: `services/backend/app/services/llm/bedrock_client.py`
  - Routing modes: `OFF` (default), `SHADOW`, `PRIMARY_BEDROCK` (via `FlagsService`)

- OpenAI — RAG embeddings only (not coach)
  - Auth: `OPENAI_API_KEY` env var (optional, degrades gracefully)
  - Usage: `services/backend/app/services/rag/` (insight embedder, vector store ingestion)
  - Degradation: warning logged in staging/production if missing, no crash

**Open Banking:**
- bLink (SIX Financial Information AG) — Swiss Open Banking standard
  - Status: SANDBOX (mock data); production requires FINMA + bLink contract
  - Auth: `BLINK_API_URL` env var
  - Entry: `services/backend/app/services/open_banking/blink_connector.py`
  - Read-only: account listing, transaction history, balances
  - Companion: `services/backend/app/services/open_banking/account_aggregator.py`, `transaction_categorizer.py`, `consent_manager.py`

**Future / Planned Connectors (not yet implemented):**
- `CAISSE_PENSION_API_URL` — institutional pension fund API (env var stub in config)
- `AVS_INSTITUTIONAL_API_URL` — AVS institutional API (env var stub in config)

## Data Storage

**Databases:**
- PostgreSQL — production/staging (mandatory; SQLite rejected at startup in non-dev)
  - Connection: `DATABASE_URL` env var
  - ORM: SQLAlchemy 2.x, `services/backend/app/core/database.py`
  - Migrations: Alembic, `services/backend/alembic/`
  - Pool: `pool_size=20`, `max_overflow=20`, `pool_recycle=3600`, `pool_pre_ping=True`
- SQLite — local development/testing only (`mint.db` in project root, ephemeral on Railway)
  - Client: SQLAlchemy with `check_same_thread=False`

**Mobile Local Storage:**
- Encrypted SQLite via `sqflite_sqlcipher ^3.1.0+1` — conversation memory, profile cache
- `flutter_secure_storage ^9.0.0` — JWT + refresh tokens (iOS Keychain, Android Keystore/EncryptedSharedPreferences)
- `shared_preferences ^2.3.2` — analytics consent, session IDs, feature flags

**Vector Store:**
- ChromaDB (local) — RAG knowledge base (`services/backend/app/services/rag/vector_store.py`)
  - Collection: `mint_knowledge`
  - Persistence: `./data/chromadb` (env: `CHROMADB_PERSIST_DIR`)
  - Embeddings: built-in `all-MiniLM-L6-v2` via ONNX (no sentence-transformers needed)
  - Production note: requires Railway persistent volume at `/data` — lost on deploy without it

**Caching:**
- Redis — rate limiting (`slowapi`)
  - Connection: `REDIS_URL` env var
  - Fallback: in-memory when `REDIS_URL` is empty (dev/CI)

## Authentication & Identity

**Custom JWT Auth (backend):**
- `pyjwt >=2.8.0` — token signing (HS256)
- `passlib[bcrypt]` — password hashing
- Tokens stored in iOS Keychain / Android Keystore via `flutter_secure_storage`
- Entry: `services/backend/app/services/auth_service.py`, `services/backend/app/services/auth_security_service.py`
- Config: `JWT_SECRET_KEY`, `JWT_ALGORITHM=HS256`, `JWT_EXPIRY_HOURS=24`
- Email verification: `AUTH_REQUIRE_EMAIL_VERIFICATION` (forced `true` in production)

**Apple Sign-In (iOS):**
- SDK: `sign_in_with_apple ^6.1.0` (`apps/mobile/pubspec.yaml`)
  - Nonce-based flow; backend verifies via `POST /api/v1/auth/apple/verify`
  - Entry: `apps/mobile/lib/services/apple_sign_in_service.dart`

**Magic Links:**
- Backend sends email magic links for passwordless auth
  - Entry: `services/backend/app/services/magic_link_service.py`

## Monitoring & Observability

**Error Tracking:**
- Sentry — both mobile and backend
  - Mobile SDK: `sentry_flutter 9.14.0` (`apps/mobile/pubspec.yaml`)
  - Backend SDK: `sentry-sdk[fastapi]==2.53.0` (pinned)
  - Backend auth: `SENTRY_DSN` env var (only initialized when set)
  - Config: `traces_sample_rate=0.1`, `profiles_sample_rate=0.1`, `send_default_pii=False` (nLPD)
  - Initialized in `services/backend/app/main.py` before request handling

**Structured Logging:**
- Custom logging setup: `services/backend/app/core/logging_config.py`
- `LoggingMiddleware` injects `trace_id` per request (via `trace_id_var` ContextVar)
- Log level: `LOG_LEVEL` env var (default `INFO`)

**Rate Limiting:**
- `slowapi` wraps `limits` library, backed by Redis (or in-memory)
- Applied at route level via `limiter` in `services/backend/app/core/rate_limit.py`

## CI/CD & Deployment

**Hosting:**
- Railway — backend (Dockerfile build)
  - Staging: `https://mint-staging.up.railway.app/api/v1`
  - Production: `https://mint-production-3a41.up.railway.app/api/v1` (or `https://api.mint.ch/api/v1`)
  - Config: `services/backend/railway.json` (healthcheck: `GET /api/v1/health`, timeout 15s)
- Vercel — Flutter web app (`vercel.json`)
  - Preview: merged to `staging` branch
  - Production: merged to `main` branch

**CI Pipeline — GitHub Actions:**
- `ci.yml` — main test gate (push to dev/staging/main, PRs targeting same)
  - Smart path detection via `dorny/paths-filter`
  - Jobs: `changes`, `contracts-drift`, `readability` (ACCESS-06), backend pytest, Flutter analyze+test
  - Concurrency: cancels in-progress runs per ref
- `testflight.yml` — iOS TestFlight builds (macos-15, flutter 3.41.4)
  - Staging track: push to `staging` branch
  - Production track: push to `main` branch
  - Required secrets: `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`, `MATCH_GIT_URL`, `MATCH_PASSWORD`
- `deploy-backend.yml` — Railway deployment on PR merge
  - Staging: merge to `staging` + smoke tests
  - Production: merge to `main`
  - Required secrets: `PROJECT_STAGING_TOKEN`, `RAILWAY_TOKEN`, `RAILWAY_STAGING_SERVICE_ID`, `RAILWAY_SERVICE_ID`
- `web.yml` — Vercel deployment on PR merge to staging/main
- `play-store.yml` — Google Play Store deployment
- `sync-branches.yml` — branch synchronization automation
- `golden-document-flow.yml` — document processing CI validation

## Billing

**Apple In-App Purchase:**
- SDK: `in_app_purchase ^3.2.0` + `in_app_purchase_platform_interface ^1.4.0`
- Products: `ch.mint.starter.monthly`, `ch.mint.premium.monthly`, `ch.mint.couple_plus.monthly`
- Backend config: `APPLE_IAP_PRODUCT_*` env vars, `APPLE_WEBHOOK_SHARED_SECRET`
- Webhooks: backend validates Apple IAP receipts server-side
- Entry: `services/backend/app/services/billing_service.py`

**Stripe:**
- No SDK; raw HTTP via `urllib.request` in billing service
- Auth: `STRIPE_SECRET_KEY` env var
- Webhooks: `STRIPE_WEBHOOK_SECRET` (HMAC validation)
- Prices: `STRIPE_PRICE_STARTER_MONTHLY`, `STRIPE_PRICE_PREMIUM_MONTHLY`, `STRIPE_PRICE_COUPLE_PLUS_MONTHLY` (+ annual variants)
- Portal return URL: `BILLING_PORTAL_RETURN_URL` (default `https://mint.ch/profile`)
- Tiers: `free`, `starter`, `premium`, `couple_plus`

## Email

**SMTP (transactional):**
- Disabled by default (`EMAIL_SEND_ENABLED=False`)
- Config: `SMTP_HOST`, `SMTP_PORT=587`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_USE_TLS=True`
- Sender: `EMAIL_FROM` (default `no-reply@mint.ch`)
- Entry: `services/backend/app/services/email_service.py`
- Usage: email verification, magic links

## Privacy & Data Protection

**PII Scrubbing (optional, `privacy` extra):**
- Microsoft Presidio (`presidio-analyzer`, `presidio-anonymizer`) — NLP-based PII detection
- spaCy — language model backend
- Tesseract OCR — image PII masking
- Pyffx — format-preserving encryption
- Entry: `services/backend/app/services/privacy/`

**Envelope Encryption:**
- Per-user Data Encryption Keys (DEK) with crypto-shredding support
- Backends: AWS KMS (`MINT_KMS_KEY_ID` env var) or Fernet self-managed (`MINT_MASTER_KEY`)
- Entry: `services/backend/app/services/encryption/key_vault.py`, `services/backend/app/services/encryption/envelope.py`

## Webhooks & Callbacks

**Incoming:**
- Apple IAP webhook — subscription events (receipt validation)
- Stripe webhook — billing events (`STRIPE_WEBHOOK_SECRET` HMAC)
- Apple Sign-In callback — `POST /api/v1/auth/apple/verify`

**Outgoing:**
- None detected (analytics is privacy-first internal batching, no third-party pixel/webhook)

## Environment Configuration

**Required production env vars:**
- `DATABASE_URL` — PostgreSQL connection string (SQLite rejected at startup)
- `JWT_SECRET_KEY` — min 32 chars (enforced at startup)
- `ANTHROPIC_API_KEY` — coach AI
- `SENTRY_DSN` — error tracking
- `REDIS_URL` — rate limiting (in-memory fallback if absent)
- `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET` — billing
- `APPLE_WEBHOOK_SHARED_SECRET` — IAP validation
- `SMTP_HOST` + `SMTP_USERNAME` + `SMTP_PASSWORD` — email (if `EMAIL_SEND_ENABLED=true`)

**Optional production env vars:**
- `OPENAI_API_KEY` — RAG embeddings (warning logged if absent)
- `MINT_KMS_KEY_ID` — AWS KMS for DEK wrapping
- `MINT_LLM_TIER=mvp` — switches coach to Haiku economy model
- `BLINK_API_URL` — open banking sandbox/production
- `BEDROCK_EU_PRIMARY_ENABLED` / `BEDROCK_EU_SHADOW_ENABLED` — Bedrock routing
- `INTERNAL_ACCESS_ENABLED` + `INTERNAL_ACCESS_ALLOWLIST` — dev/TestFlight premium bypass

**Secrets location:**
- Railway environment variables (staging + production)
- GitHub Actions secrets (CI/CD keys, TestFlight certs, Vercel tokens)
- Local: `.env` file (never committed)

---

*Integration audit: 2026-04-22*
