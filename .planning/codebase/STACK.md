# Technology Stack

**Analysis Date:** 2026-04-22

## Languages

**Primary:**
- Dart 3.x — Flutter mobile/web app (`apps/mobile/`)
- Python 3.10+ — FastAPI backend (`services/backend/`)

**Secondary:**
- Shell/Bash — CI scripts, Railway pre-deploy migrate (`services/backend/scripts/`)

## Runtime

**Mobile:**
- Flutter 3.41.4 (pinned in CI: `subosito/flutter-action@v2` with `flutter-version: '3.41.4'`)
- Dart SDK constraint: `^3.6.0` (`apps/mobile/pubspec.yaml`)

**Backend:**
- Python `>=3.10` (`services/backend/pyproject.toml`)
- Uvicorn (ASGI) behind Gunicorn in production (`-w 2 -k uvicorn.workers.UvicornWorker`)

**Package Manager:**
- Flutter: `pub` (lockfile: `apps/mobile/pubspec.lock`)
- Python: `pip` / `setuptools` (lockfile: `services/backend/requirements-dev.txt`)

## Frameworks

**Core — Mobile:**
- `flutter` SDK — UI framework
- `go_router ^13.2.0` — declarative navigation (`apps/mobile/pubspec.yaml`)
- `provider ^6.1.1` — state management
- `flutter_localizations` — i18n (6 languages: fr/en/de/es/it/pt via `apps/mobile/lib/l10n/`)

**Core — Backend:**
- `FastAPI >=0.109.0,<1.0.0` — HTTP API framework (`services/backend/pyproject.toml`)
- `Pydantic v2 >=2.6.0,<3.0.0` — data validation, camelCase alias pattern
- `pydantic-settings >=2.1.0,<3.0.0` — environment config via `services/backend/app/core/config.py`
- `SQLAlchemy >=2.0.0,<3.0.0` — ORM
- `Alembic >=1.13.0,<2.0.0` — database migrations (`services/backend/alembic/`)

**Testing:**
- Flutter: `flutter_test` SDK + `integration_test` SDK
- Python: `pytest >=8.0.0` + `pytest-asyncio >=0.23.0` + `pytest-cov >=5.0.0`
- HTTP testing: `httpx >=0.24.0`
- Redis mock: `fakeredis >=2.20.0`

**Build/Dev:**
- `ruff >=0.1.0` — Python linter/formatter (`line-length = 88`, `target-version = py310`)
- `flutter_lints ^3.0.0` — Dart linting
- `flutter gen-l10n` — ARB code generation

## Key Dependencies

**AI/LLM:**
- `anthropic >=0.40.0,<1.0.0` — Claude API client (primary coach model: `claude-sonnet-4-20250514`, MVP tier: `claude-haiku-4-5-20251001`) via `services/backend/app/services/llm/`
- LLM tier switching via `MINT_LLM_TIER=mvp` env var → `services/backend/app/services/llm/tier.py`
- AWS Bedrock (eu-central-1 / Frankfurt) — optional nLPD-compliant inference path via `services/backend/app/services/llm/bedrock_client.py`
- OpenAI (optional) — RAG embeddings only; `OPENAI_API_KEY` required; degrades gracefully if absent

**Data & Storage:**
- `sqlalchemy` + `psycopg2-binary` — PostgreSQL in production (Railway), SQLite in dev
- `redis >=5.0,<6.0` — rate limiting (in-memory fallback if `REDIS_URL` empty)
- ChromaDB — local vector store for RAG knowledge base (`services/backend/app/services/rag/vector_store.py`), persisted at `./data/chromadb` (Railway volume)

**Mobile Storage:**
- `sqflite_sqlcipher ^3.1.0+1` — encrypted local SQLite (iOS/Android)
- `flutter_secure_storage ^9.0.0` — JWT tokens (iOS Keychain / Android Keystore)
- `shared_preferences ^2.3.2` — non-sensitive local prefs

**Security & Auth:**
- `pyjwt >=2.8.0,<3.0.0` — JWT signing/validation
- `passlib[bcrypt]` + `bcrypt >=4.0,<5.0` — password hashing
- `cryptography >=42,<47` — Fernet envelope encryption (DEK lifecycle)
- `slowapi >=0.1.9` — rate limiting (wraps `limits` library)
- `defusedxml >=0.7.0` — safe XML parsing

**Privacy/PII (optional extras):**
- `presidio-analyzer` + `presidio-anonymizer` — PII detection (PRIV-03)
- `spacy >=3.7` — NLP for PII detection
- `pyffx` — format-preserving encryption
- `pytesseract` + `Pillow` — image PII masking

**Document Processing:**
- `pymupdf >=1.24` — PDF parsing
- `pyyaml >=6.0` — YAML config
- `sse-starlette >=2.1` — Server-Sent Events (streaming coach responses)

**Mobile UI:**
- `fl_chart ^0.70.0` — financial charts
- `flutter_markdown ^0.7.6` — coach message rendering
- `google_fonts ^6.3.3` — typography
- `pdf ^3.10.8` + `printing ^5.12.0` — export PDF
- `confetti ^0.7.0` — celebration animations
- `flutter_local_notifications ^18.0.1` — push notifications

**Mobile Device:**
- `speech_to_text ^7.0.0` — voice input
- `flutter_tts ^4.2.0` — text-to-speech
- `flutter_doc_scanner ^0.0.13` — native document scanning (VisionKit iOS)
- `image_picker ^1.1.2` + `file_picker ^8.0.0` — media picking

**Billing:**
- `in_app_purchase ^3.2.0` — Apple StoreKit (iOS IAP)
- Stripe via HTTP (no SDK; `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` env vars)

**Observability:**
- `sentry_flutter 9.14.0` — mobile error tracking (`apps/mobile/pubspec.yaml`)
- `sentry-sdk[fastapi]==2.53.0` — backend error tracking, pinned for header compatibility
- `jinja2 >=3.1,<4.0` — required by Sentry FastAPI integration (pinned after Railway boot incident 2026-04-21)

## Configuration

**Environment (Backend):**
- All config via `pydantic-settings` `BaseSettings` in `services/backend/app/core/config.py`
- `.env` file for local dev; Railway env vars for staging/production
- Key production requirements: `DATABASE_URL` (PostgreSQL), `JWT_SECRET_KEY` (≥32 chars), `ANTHROPIC_API_KEY`, `SENTRY_DSN`
- Fail-fast guards at startup: SQLite rejected in staging/production, short JWT key rejected

**Build (Mobile):**
- `--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1` for device builds (mandatory per MEMORY.md)
- `flutter gen-l10n` must run after ARB changes
- Regional ARB assets: `apps/mobile/lib/l10n_regional/` (vs, zh, ti dialects)

**Config Assets:**
- `apps/mobile/assets/config/pillar_3a_limits.json` — 3a contribution ceilings
- `apps/mobile/assets/config/tax_scales.json` + `tax_scales_2024.json` — cantonal tax tables
- `apps/mobile/assets/config/personas.json` — user archetypes
- `apps/mobile/assets/config/commune_multipliers.json` — commune tax multipliers

## Platform Requirements

**Development:**
- Flutter 3.41.4
- Python 3.10+
- PostgreSQL or SQLite (dev)
- Redis (optional, in-memory fallback)

**Production:**
- Railway (Dockerfile build) — `services/backend/railway.json`
- Gunicorn 2 workers, 120s timeout, port `$PORT`
- Pre-deploy migration: `python scripts/railway_pre_deploy_migrate.py`
- PostgreSQL required (SQLite rejected at startup)
- Railway persistent volume at `/data` for ChromaDB corpus

---

*Stack analysis: 2026-04-22*
