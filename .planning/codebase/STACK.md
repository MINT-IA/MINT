# Technology Stack

**Analysis Date:** 2026-04-05

## Languages

**Primary:**
- Dart (SDK ^3.6.0) - Flutter mobile app (`apps/mobile/`)
- Python (>=3.10, runtime 3.12) - FastAPI backend (`services/backend/`)

**Secondary:**
- YAML - CI/CD workflows, config
- Ruby - Fastlane iOS build (`apps/mobile/ios/`)
- Bash - Scripts (`scripts/`)

## Runtime

**Environment:**
- Flutter 3.27.4 (pinned in CI)
- Python 3.12 (Dockerfile + CI)
- Gunicorn + Uvicorn workers (production ASGI)

**Package Manager:**
- Flutter pub (pubspec.yaml lockfile: `apps/mobile/pubspec.lock`)
- pip with setuptools (pyproject.toml: `services/backend/pyproject.toml`)

## Frameworks

**Core:**
- Flutter 3.27.4 - Cross-platform mobile (iOS/Android/Web) - `apps/mobile/`
- FastAPI >=0.109.0 - REST API backend - `services/backend/`
- Pydantic v2 >=2.6.0 - Data validation, settings, schema serialization (camelCase alias)
- SQLAlchemy >=2.0.0 - ORM / database layer
- Alembic >=1.13.0 - Database migrations (`services/backend/alembic/`)

**Testing:**
- pytest >=8.0.0 + pytest-asyncio + pytest-cov - Backend tests (`services/backend/tests/`)
- flutter_test (SDK) - Flutter unit/widget tests (`apps/mobile/test/`)
- integration_test (SDK) - Flutter integration tests
- httpx >=0.24.0 - Backend test client
- diff-cover - PR changed-line coverage (>=80% gate)

**Build/Dev:**
- ruff >=0.1.0 - Python linting/formatting (line-length 88, target py310) - `services/backend/pyproject.toml [tool.ruff]`
- flutter_lints ^3.0.0 - Dart static analysis
- Fastlane - iOS build + TestFlight upload (`apps/mobile/ios/`)
- Docker multi-stage build - Production container (`services/backend/Dockerfile`)

## Key Dependencies

### Flutter (`apps/mobile/pubspec.yaml`)

**Critical:**
- `provider: ^6.1.1` - State management (app-wide)
- `go_router: ^13.2.0` - Declarative routing / deep links
- `http: ^1.2.0` - HTTP client for backend API
- `flutter_secure_storage: ^9.0.0` - Secure token/key storage
- `shared_preferences: ^2.3.2` - Local settings + cache persistence

**AI/LLM:**
- `flutter_gemma: ^0.11.16` - On-device SLM inference (Gemma 3n E4B, ~4.4 GB)
- `flutter_tts: ^4.2.0` - Text-to-speech (accessibility)
- `speech_to_text: ^7.0.0` - Voice input

**UI/Charts:**
- `google_fonts: ^6.1.0` - Montserrat (headings) + Inter (body)
- `fl_chart: ^0.70.0` - Financial charts (CustomPainter-based)
- `confetti: ^0.7.0` - Gamification celebrations

**Documents/OCR:**
- `google_mlkit_text_recognition: ^0.15.0` - On-device OCR for document scanning
- `pdf: ^3.10.8` - PDF generation
- `printing: ^5.12.0` - PDF printing/sharing
- `file_picker: ^8.0.0` - Document import
- `image_picker: ^1.1.2` - Camera/gallery access

**Billing:**
- `in_app_purchase: ^3.2.0` - Apple IAP / Google Play billing
- `in_app_purchase_platform_interface: ^1.4.0` - Platform abstraction

**Infrastructure:**
- `sentry_flutter: ^8.0.0` - Error tracking + performance monitoring
- `flutter_local_notifications: ^18.0.1` - Local push notifications
- `intl: any` - i18n (pinned by flutter_localizations SDK)
- `uuid: ^4.0.0` - Unique identifiers
- `url_launcher: ^6.2.0` - External link handling

### Backend (`services/backend/pyproject.toml`)

**Critical:**
- `fastapi: >=0.109.0,<1.0.0` - Web framework
- `pydantic: >=2.6.0,<3.0.0` - Schema validation
- `pydantic-settings: >=2.1.0,<3.0.0` - Environment config
- `sqlalchemy: >=2.0.0,<3.0.0` - Database ORM
- `alembic: >=1.13.0,<2.0.0` - Schema migrations
- `psycopg2-binary: >=2.9.9,<3.0.0` - PostgreSQL driver

**AI/LLM:**
- `anthropic: >=0.40.0,<1.0.0` - Claude API client (coach AI)

**Auth/Security:**
- `pyjwt: >=2.8.0,<3.0.0` - JWT token handling
- `passlib[bcrypt]: >=1.7.4,<2.0.0` - Password hashing
- `bcrypt: >=4.0,<5.0` - Bcrypt backend
- `slowapi: >=0.1.9,<1.0.0` - Rate limiting (429 responses)
- `defusedxml: >=0.7.0,<1.0.0` - Safe XML parsing

**Infrastructure:**
- `uvicorn[standard]: >=0.27.0,<1.0.0` - ASGI server
- `gunicorn: >=22.0.0,<24.0.0` - Production process manager (2 workers)
- `sentry-sdk[fastapi]: >=2.0.0,<3.0.0` - Error tracking
- `tenacity: >=8.2.0,<10.0.0` - Retry logic
- `email-validator: >=2.0.0,<3.0.0` - Email format validation

**Optional (RAG):**
- `chromadb: >=0.5.5` - Vector database for RAG knowledge base
- `openai: >=1.30.0` - OpenAI embeddings (RAG pipeline)
- `tiktoken: >=0.7.0` - Token counting
- `pdfplumber: >=0.11.0` - PDF text extraction (docling)

## Configuration

**Environment:**
- Backend config via pydantic-settings: `services/backend/app/core/config.py`
- Template: `services/backend/.env.example` (58 vars)
- `.env` file present at project root (secrets - never read)
- Flutter build-time config via `--dart-define` (API_BASE_URL, SENTRY_DSN)
- Static config assets: `apps/mobile/assets/config/` (tax_scales.json, pillar_3a_limits.json, personas.json, commune_multipliers.json)

**Feature Flags (backend `config.py`):**
- `FF_ENABLE_COUPLE_PLUS_TIER` - Couple subscription tier
- `FF_ENABLE_SLM_NARRATIVES` - On-device SLM narratives
- `FF_ENABLE_DECISION_SCAFFOLD` - Decision framework
- `FF_VALEUR_LOCATIVE_2028_REFORM` - Tax reform toggle
- `FF_SAFE_MODE_DEGRADED` - Degraded mode
- `FF_ENABLE_BLINK_PRODUCTION` - bLink Open Banking
- `FF_ENABLE_CAISSE_PENSION_API` - Pension fund API
- `FF_ENABLE_EXPERT_TIER` - Expert (human advisor) tier
- `FF_ENABLE_ADMIN_SCREENS` - Admin panel
- `FF_ENABLE_AVS_INSTITUTIONAL` - AVS institutional API

**Build:**
- `services/backend/pyproject.toml` - Python build config + ruff + pytest
- `apps/mobile/pubspec.yaml` - Flutter dependencies
- `services/backend/Dockerfile` - Multi-stage Docker build (python:3.12-slim)
- `services/backend/railway.json` - Railway deploy config
- `services/backend/Procfile` - Process definition (gunicorn + pre-deploy migration)

## Platform Requirements

**Development:**
- Flutter SDK 3.27.4
- Python 3.10+ (3.12 recommended)
- Xcode (latest stable) for iOS builds
- PostgreSQL (or SQLite for local dev via `DATABASE_URL=sqlite:///./mint.db`)

**Production:**
- Railway (PaaS) - Backend hosting (staging + production)
- Docker container (python:3.12-slim)
- PostgreSQL database
- TestFlight - iOS beta distribution
- App Store Connect API for automated uploads

## i18n

**Approach:** Flutter ARB files
- 6 languages: fr (template), en, de, es, it, pt
- Location: `apps/mobile/lib/l10n/`
- Generate command: `flutter gen-l10n`
- Access: `AppLocalizations.of(context)!.key`

---

*Stack analysis: 2026-04-05*
