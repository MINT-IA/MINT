# Codebase Structure

**Analysis Date:** 2026-04-05

## Directory Layout

```
MINT/
├── apps/
│   └── mobile/                  # Flutter app (iOS/Android/Web)
│       ├── lib/
│       │   ├── constants/       # Centralized Swiss constants
│       │   ├── data/            # Data layer (budget/)
│       │   ├── domain/          # Domain layer (budget/)
│       │   ├── l10n/            # i18n ARB files (6 languages)
│       │   ├── models/          # Data models (25 files)
│       │   ├── providers/       # Provider state management (14 files)
│       │   ├── screens/         # Screens by module (~40 files + subdirs)
│       │   ├── services/        # Business logic (~93 root + subdirs)
│       │   ├── theme/           # MintColors, text styles, spacing
│       │   ├── utils/           # Formatters, mixins
│       │   └── widgets/         # Reusable widgets (245+ files in 20 subdirs)
│       ├── test/                # Flutter tests (372 files)
│       ├── ios/                 # iOS platform config
│       ├── android/             # Android platform config
│       └── web/                 # Web platform config
├── services/
│   └── backend/                 # FastAPI Python backend
│       ├── app/
│       │   ├── api/v1/endpoints/  # REST endpoints (55 modules)
│       │   ├── constants/       # Swiss regulatory constants
│       │   ├── core/            # Config, DB, auth, rate limiting
│       │   ├── models/          # SQLAlchemy ORM (16 models)
│       │   ├── routes/          # (legacy, now empty)
│       │   ├── schemas/         # Pydantic v2 schemas (40+ files)
│       │   ├── services/        # Business logic (29 root + 16 subdirs)
│       │   └── utils/           # Backend utilities
│       ├── tests/               # pytest suite (120 files)
│       ├── alembic/             # DB migrations
│       ├── data/chromadb/       # RAG vector store data
│       ├── migrations/          # Additional migration scripts
│       └── scripts/             # Utility scripts
├── docs/                        # Strategy, specs, design docs (60+ files)
├── decisions/                   # Architecture Decision Records (7 ADRs)
├── visions/                     # Product vision docs (5 files)
├── education/
│   └── inserts/                 # Educational content (concepts, FAQ, cantons)
├── legal/                       # CGU, Privacy, Disclaimer, Mentions legales
├── .claude/                     # Agent skills, hooks, workflows
│   ├── skills/                  # 50+ agent skill definitions
│   ├── hooks/                   # GSD workflow hooks (JS)
│   ├── agents/                  # Agent configurations
│   └── worktrees/               # Agent worktree checkouts
├── .github/workflows/           # CI/CD (ci.yml, deploy-backend.yml, testflight.yml, etc.)
└── .planning/                   # GSD planning documents
```

## Directory Purposes

**`apps/mobile/lib/screens/`:**
- Purpose: All app screens organized by feature domain
- Contains: Dart screen widgets, one file per screen
- Key subdirectories:
  - `main_tabs/` — 3 main tabs: `mint_home_screen.dart`, `mint_coach_tab.dart`, `explore_tab.dart`
  - `coach/` — Coach-related: chat, recap, retirement dashboard, decaissement, succession
  - `onboarding/` — Onboarding flow: `intent_screen.dart`, `quick_start_screen.dart`, `chiffre_choc_screen.dart`
  - `arbitrage/` — Side-by-side comparisons: rente vs capital, location vs propriete
  - `mortgage/` — Affordability, amortization, EPL, SARON vs fixed
  - `lpp_deep/` — LPP deep-dives: rachat, libre passage, EPL
  - `pillar_3a_deep/` — 3a comparator, real return, staggered withdrawal, retroactive
  - `explore/` — 7 thematic hubs: retraite, famille, travail, logement, fiscalite, patrimoine, sante
  - `disability/` — Gap analysis, insurance, self-employed
  - `debt_prevention/` — Debt ratio, repayment, help resources
  - `document_scan/` — OCR scan, AVS guide, extraction review, impact
  - `auth/` — Login, register, forgot password, verify email
  - `profile/` — Financial summary, data transparency
  - `budget/` — Budget container
  - `household/` — Household management, invitation acceptance
  - `open_banking/` — Hub, transactions, consents (feature-flagged)

**`apps/mobile/lib/services/`:**
- Purpose: All business logic, API calls, calculations
- Contains: Service classes (mostly static or singleton)
- Key subdirectories:
  - `financial_core/` — 17 pure calculator files (AVS, LPP, tax, arbitrage, Monte Carlo, confidence, tornado, withdrawal sequencing). Barrel export: `financial_core.dart`
  - `coach/` — 25 files: orchestrator, compliance guard, hallucination detector, fallback templates, prompt registry, context injector, conversation memory, voice chat, JITAI nudge, goal tracker, RAG retrieval
  - `llm/` — 3 files: failover, provider health, response quality monitor
  - `slm/` — On-device SLM engine (Gemma 3n)
  - `confidence/` — Enhanced confidence service
  - `voice/` — Voice config and services
  - `memory/` — Conversation memory
  - `nudge/` — JITAI nudge service
  - `lifecycle/` — User lifecycle engine
  - `simulators/` — Simulator services
  - `navigation/` — Navigation helpers
- Key root files: `api_service.dart` (HTTP client), `auth_service.dart`, `feature_flags.dart`, `regulatory_sync_service.dart`, `snapshot_service.dart`, `coach_llm_service.dart`

**`apps/mobile/lib/providers/`:**
- Purpose: Reactive state containers (ChangeNotifier pattern)
- Contains: 14 provider files + `budget/` subdirectory
- Key files:
  - `auth_provider.dart` — JWT auth state
  - `profile_provider.dart` — User profile state
  - `coach_profile_provider.dart` — Coach profile (central data model)
  - `budget/budget_provider.dart` — Budget state (proxy of CoachProfileProvider)
  - `mint_state_provider.dart` — Computed financial state (proxy of CoachProfileProvider)
  - `onboarding_provider.dart` — Onboarding progress
  - `byok_provider.dart` — Bring Your Own Key (LLM API key)
  - `subscription_provider.dart` — Billing/subscription state
  - `locale_provider.dart` — Language preference
  - `household_provider.dart` — Household/couple data
  - `slm_provider.dart` — On-device SLM state

**`apps/mobile/lib/widgets/`:**
- Purpose: Reusable UI components across screens
- Contains: 245+ widget files in 20 subdirectories
- Key subdirectories: `common/`, `coach/`, `dashboard/`, `educational/`, `premium/`, `pulse/`, `visualizations/`, `wizard/`, `arbitrage/`, `confidence/`, `profile/`, `report/`, `simulators/`

**`apps/mobile/lib/models/`:**
- Purpose: Data classes for app-wide use
- Contains: 25 model files
- Key files: `coach_profile.dart`, `profile.dart`, `session.dart`, `financial_report.dart`, `coach_entry_payload.dart`, `response_card.dart`, `wizard_question.dart`

**`apps/mobile/lib/constants/`:**
- Purpose: Centralized Swiss regulatory constants
- Contains: `social_insurance.dart` (LPP/AVS/3a thresholds), `navigation_constants.dart`

**`apps/mobile/lib/theme/`:**
- Purpose: Design system tokens
- Contains: `colors.dart` (MintColors palette), `mint_text_styles.dart`, `mint_spacing.dart`, `mint_motion.dart`

**`apps/mobile/lib/l10n/`:**
- Purpose: Internationalization strings
- Contains: 6 ARB files: `app_fr.arb` (template), `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`, `app_pt.arb`

**`services/backend/app/api/v1/endpoints/`:**
- Purpose: FastAPI route handlers
- Contains: 55 endpoint modules
- Key files: `auth.py`, `profiles.py`, `coach_chat.py`, `coach.py`, `retirement.py`, `arbitrage.py`, `mortgage.py`, `fiscal.py`, `lpp_deep.py`, `pillar_3a_deep.py`, `confidence.py`, `document_parser.py`, `rag.py`, `budget.py`, `admin.py`

**`services/backend/app/services/`:**
- Purpose: Server-side business logic
- Contains: 29 root service files + 16 subdirectory modules
- Key subdirectories:
  - `coach/` — Claude coach service, tools, compliance guard, hallucination detector, structured reasoning, prompt registry, fallback templates
  - `rag/` — Vector store (ChromaDB), ingester, retriever, orchestrator, hybrid search, knowledge catalog, cantonal knowledge
  - `arbitrage/` — Rente vs capital, location vs propriete, allocation annuelle, rachat vs marche
  - `confidence/` — Enhanced confidence models and service
  - `retirement/` — AVS estimation, LPP conversion, retirement budget
  - `fiscal/` — Tax calculation services
  - `mortgage/` — Mortgage calculation services
  - `debt_prevention/` — Debt analysis services
  - `docling/` — Document processing with extractors and templates
  - `document_parser/` — Document parsing services

**`services/backend/app/core/`:**
- Purpose: Framework infrastructure
- Contains: `config.py` (Settings via pydantic-settings), `database.py` (SQLAlchemy engine/session), `auth.py` (JWT verification), `rate_limit.py` (slowapi), `logging_config.py`

**`services/backend/app/models/`:**
- Purpose: SQLAlchemy ORM models
- Contains: 16 model files
- Key files: `user.py`, `profile_model.py`, `scenario.py`, `session_model.py`, `document.py`, `household.py`, `billing.py`, `snapshot.py`, `regulatory_parameter.py`, `consent.py`, `banking_consent.py`, `auth_security.py`, `token_blacklist.py`

**`services/backend/app/schemas/`:**
- Purpose: Pydantic v2 request/response models
- Contains: 40+ schema files with camelCase aliases
- Pattern: `ConfigDict(populate_by_name=True)`, `alias_generator=to_camel`

## Key File Locations

**Entry Points:**
- `apps/mobile/lib/main.dart`: Flutter app bootstrap (init services, Sentry, runApp)
- `apps/mobile/lib/app.dart`: GoRouter definition (~70 routes), MintApp widget with MultiProvider (14 providers), theme
- `services/backend/app/main.py`: FastAPI app creation, middleware stack, lifespan handler, RAG auto-ingest
- `services/backend/app/api/v1/router.py`: API router mounting all 55 endpoint modules under `/api/v1`

**Configuration:**
- `services/backend/app/core/config.py`: Backend Settings (env vars: DATABASE_URL, JWT, Anthropic, Stripe, Apple IAP, Sentry, Redis)
- `apps/mobile/lib/services/feature_flags.dart`: Client feature flags (refreshed from backend)
- `services/backend/app/services/feature_flags.py`: Server feature flags
- `.github/workflows/ci.yml`: CI pipeline (flutter analyze, flutter test, pytest)
- `apps/mobile/pubspec.yaml`: Flutter dependencies
- `services/backend/requirements.txt` or `setup.py`: Python dependencies

**Core Logic:**
- `apps/mobile/lib/services/financial_core/financial_core.dart`: Barrel export for all calculators
- `apps/mobile/lib/services/financial_core/avs_calculator.dart`: AVS (1st pillar) calculations
- `apps/mobile/lib/services/financial_core/lpp_calculator.dart`: LPP (2nd pillar) calculations
- `apps/mobile/lib/services/financial_core/tax_calculator.dart`: Tax calculations (LIFD)
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart`: Side-by-side scenario comparison
- `apps/mobile/lib/services/financial_core/monte_carlo_service.dart`: Stochastic projections
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart`: 4-axis confidence scoring
- `apps/mobile/lib/services/coach/coach_orchestrator.dart`: Coach AI priority chain (1090 lines)
- `apps/mobile/lib/services/coach/compliance_guard.dart`: AI output compliance filter
- `services/backend/app/services/coach/claude_coach_service.py`: System prompt builder
- `services/backend/app/services/coach/coach_tools.py`: Tool definitions for Claude
- `apps/mobile/lib/services/api_service.dart`: HTTP client with auth, error handling

**Navigation:**
- `apps/mobile/lib/app.dart` L161-974: GoRouter with all routes
- `apps/mobile/lib/screens/main_navigation_shell.dart`: 3-tab shell + ProfileDrawer

**Testing:**
- `apps/mobile/test/`: 372 Flutter test files
- `apps/mobile/test/financial_core/`: Financial calculator tests
- `apps/mobile/test/services/`: Service-level tests (coach, llm, confidence, etc.)
- `apps/mobile/test/screens/`: Screen widget tests
- `apps/mobile/test/golden/`: Golden test data (Julien + Lauren couple)
- `services/backend/tests/`: 120 pytest files

## Naming Conventions

**Files:**
- Flutter: `snake_case.dart` (e.g., `coach_orchestrator.dart`, `mint_home_screen.dart`)
- Python: `snake_case.py` (e.g., `claude_coach_service.py`, `enhanced_confidence_service.py`)
- Screen suffix: `*_screen.dart`
- Service suffix: `*_service.dart` or `*_calculator.dart` or `*_engine.dart`
- Provider suffix: `*_provider.dart`
- Test suffix: `*_test.dart` (Flutter), `test_*.py` (Python)

**Directories:**
- Flutter screens: by domain (`coach/`, `arbitrage/`, `mortgage/`, `onboarding/`)
- Backend services: by domain, matching endpoint structure (`coach/`, `arbitrage/`, `retirement/`)
- Tests mirror source structure

## Where to Add New Code

**New Screen:**
- Implementation: `apps/mobile/lib/screens/{domain}/{feature_name}_screen.dart`
- Route: Add GoRoute in `apps/mobile/lib/app.dart` in the appropriate section
- Widgets: `apps/mobile/lib/widgets/{domain}/`
- Tests: `apps/mobile/test/screens/{domain}/{feature_name}_screen_test.dart`

**New Financial Calculator:**
- Implementation: `apps/mobile/lib/services/financial_core/{calculator_name}.dart`
- Export: Add to `apps/mobile/lib/services/financial_core/financial_core.dart`
- Tests: `apps/mobile/test/financial_core/{calculator_name}_test.dart` or `apps/mobile/test/services/financial_core/`
- Rule: Must be pure function, no side effects, include legal references

**New Service (Flutter):**
- Implementation: `apps/mobile/lib/services/{service_name}.dart` or `apps/mobile/lib/services/{domain}/{service_name}.dart`
- Tests: `apps/mobile/test/services/{domain}/{service_name}_test.dart`
- Rule: Must use `financial_core/` for calculations, never reimplement

**New API Endpoint:**
- Endpoint: `services/backend/app/api/v1/endpoints/{domain}.py`
- Router: Register in `services/backend/app/api/v1/router.py`
- Schema: `services/backend/app/schemas/{domain}.py`
- Service: `services/backend/app/services/{domain}/` or `services/backend/app/services/{service_name}.py`
- Tests: `services/backend/tests/test_{domain}.py`

**New Provider:**
- Implementation: `apps/mobile/lib/providers/{name}_provider.dart`
- Registration: Add to MultiProvider in `apps/mobile/lib/app.dart` L1020-1088
- Tests: `apps/mobile/test/providers/{name}_provider_test.dart`

**New Model:**
- Flutter: `apps/mobile/lib/models/{name}.dart`
- Backend ORM: `services/backend/app/models/{name}.py` + register in `__init__.py`
- Backend Schema: `services/backend/app/schemas/{name}.py`

**New i18n Strings:**
- Add keys to ALL 6 ARB files in `apps/mobile/lib/l10n/` (fr is template)
- Add keys at END of file (before closing `}`)
- Run `flutter gen-l10n` after changes

**Utilities:**
- Flutter: `apps/mobile/lib/utils/`
- Backend: `services/backend/app/utils/`

## Special Directories

**`apps/mobile/test/golden/`:**
- Purpose: Golden test data (Julien + Lauren couple with known expected values)
- Generated: No (manually maintained reference data)
- Committed: Yes

**`apps/mobile/test/golden_screenshots/`:**
- Purpose: Golden screenshot tests
- Generated: Yes (by Flutter golden test framework)
- Committed: Yes (goldens/ reference images)

**`services/backend/data/chromadb/`:**
- Purpose: RAG vector store persistence (ChromaDB)
- Generated: Yes (auto-ingested from `education/inserts/` at startup)
- Committed: Partial (directory committed, data may be gitignored)

**`services/backend/alembic/`:**
- Purpose: Database migration scripts
- Generated: Via alembic CLI
- Committed: Yes

**`education/inserts/`:**
- Purpose: Educational content (concepts, FAQ, cantonal knowledge) used by RAG
- Generated: No (manually authored markdown)
- Committed: Yes

**`.claude/skills/`:**
- Purpose: Agent skill definitions for Claude Code workflows
- Generated: No
- Committed: Yes

**`.github/workflows/`:**
- Purpose: CI/CD pipeline definitions
- Contains: `ci.yml` (main CI), `deploy-backend.yml`, `testflight.yml`, `web.yml`, `play-store.yml`, `sync-branches.yml`
- Committed: Yes

## File Statistics

| Category | Count |
|----------|-------|
| Flutter source files (`apps/mobile/lib/`) | 652 |
| Flutter test files (`apps/mobile/test/`) | 372 |
| Backend source files (`services/backend/app/`) | 293 |
| Backend test files (`services/backend/tests/`) | 120 |
| API endpoint modules | 55 |
| Pydantic schema files | 40+ |
| SQLAlchemy model files | 16 |
| Financial core calculators | 17 |
| Coach service files (Flutter) | 25 |
| Provider files | 14 |
| Widget files | 245+ |
| i18n ARB files | 6 |
| GoRouter routes (approx) | ~70 canonical + ~15 legacy redirects |
| ADR documents | 7 |
| CI/CD workflows | 7 |

---

*Structure analysis: 2026-04-05*
