# Codebase Structure

**Analysis Date:** 2026-04-22

## Directory Layout

```
MINT/                              # Monorepo root
├── apps/
│   └── mobile/                    # Flutter app (iOS/Android/Web)
│       ├── lib/                   # All Dart source
│       │   ├── main.dart          # App entry point
│       │   ├── app.dart           # GoRouter + MultiProvider root (1857 lines)
│       │   ├── constants/         # App-wide constants (social_insurance.dart etc.)
│       │   ├── data/              # Static/bundled data (commune_data.dart, budget/)
│       │   ├── domain/            # Domain value types (budget/)
│       │   ├── l10n/              # Generated AppLocalizations (6 languages)
│       │   ├── l10n_regional/     # Canton-specific microcopy
│       │   ├── models/            # Dart data models (profile.dart, coach_profile.dart…)
│       │   ├── providers/         # Provider ChangeNotifiers (state management)
│       │   ├── router/            # RouteScope enum + ScopedGoRoute class
│       │   ├── routes/            # Route metadata types (Phase 32 registry)
│       │   ├── screens/           # Screen widgets by domain
│       │   ├── services/          # Business logic, API calls, AI orchestration
│       │   │   └── financial_core/ # ★ Pure financial calculators — source of truth
│       │   ├── theme/             # Colors, text styles, spacing tokens
│       │   ├── utils/             # Shared utilities (chf_formatter.dart…)
│       │   └── widgets/           # Reusable widget library by domain
│       ├── assets/                # Images, fonts, JSON data files
│       ├── l10n/                  # ARB source files (fr/en/de/es/it/pt)
│       ├── test/                  # Flutter unit + widget tests
│       └── integration_test/      # Integration test stubs
├── services/
│   └── backend/                   # FastAPI backend (Python)
│       ├── app/
│       │   ├── main.py            # FastAPI entry point
│       │   ├── api/v1/
│       │   │   ├── router.py      # Master API router (60+ modules)
│       │   │   └── endpoints/     # One file per domain (coach_chat.py, auth.py…)
│       │   ├── core/              # Config, DB, logging, rate limiting, Redis
│       │   ├── middleware/        # Encryption context middleware
│       │   ├── models/            # SQLAlchemy ORM models
│       │   ├── routes/            # Backend route metadata (Phase 32)
│       │   ├── schemas/           # Pydantic v2 request/response schemas
│       │   ├── services/          # Domain services (coach/, llm/, rag/, fiscal/, …)
│       │   └── utils/             # Shared utilities
│       └── tests/                 # pytest test suite
├── decisions/                     # Architecture Decision Records (ADRs)
├── docs/                          # Project docs, AGENTS specs, design system
│   └── AGENTS/                    # Role-scoped agent instructions
│       ├── flutter.md
│       ├── backend.md
│       └── swiss-brain.md
├── education/                     # RAG knowledge base (Swiss finance inserts)
├── tools/                         # CLI tools, lint scripts (accent_lint, route CLI)
├── scripts/                       # Dev/ops scripts
└── .planning/                     # All planning artifacts (phases, milestones…)
    └── codebase/                  # Codebase mapping documents (this file)
```

## Directory Purposes

**`apps/mobile/lib/services/financial_core/`:**
- Purpose: All Swiss financial math — pure static functions, zero Flutter dependency
- Contains: `AvsCalculator`, `LppCalculator`, `TaxCalculator`, `CrossPillarCalculator`, `FriCalculator`, `HousingCostCalculator`, `ArbitrageEngine`, `MonteCarloService`, `ConfidenceScorer`, `BayesianEnricher`, `CoupleOptimizer`, `TornadoSensitivityService`, `WithdrawalSequencingService`
- Key files: `apps/mobile/lib/services/financial_core/financial_core.dart` (barrel export), `avs_calculator.dart`, `lpp_calculator.dart`, `tax_calculator.dart`
- Rule: NEVER re-implement a `_calculate*()` function outside this directory

**`apps/mobile/lib/screens/`:**
- Purpose: One directory per domain feature area
- Contains: `coach/` (CoachChatScreen, ConversationHistoryScreen, RetirementDashboardScreen…), `aujourdhui/`, `mon_argent/`, `explore/`, `arbitrage/`, `lpp_deep/`, `pillar_3a_deep/`, `mortgage/`, `onboarding/`, `auth/`, `budget/`, `profile/`, `settings/`, `admin/`, `household/`, `document_scan/`, `independants/`, `disability/`…
- Key files: `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (chat entry), `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` (Tab 0), `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart` (Tab 1), `apps/mobile/lib/screens/explore/explorer_screen.dart` (Tab 3)

**`apps/mobile/lib/services/coach/`:**
- Purpose: All coach AI logic — context assembly, orchestration, compliance, memory
- Key files: `coach_orchestrator.dart` (3-tier LLM chain), `context_injector_service.dart` (system prompt builder), `compliance_guard.dart`, `conversation_memory_service.dart`, `prompt_registry.dart`, `intent_router.dart`, `chat_tool_dispatcher.dart`, `tool_call_parser.dart`

**`apps/mobile/lib/providers/`:**
- Purpose: Flutter Provider ChangeNotifiers, instantiated in `MultiProvider` tree in `apps/mobile/lib/app.dart`
- Key files: `profile_provider.dart`, `coach_profile_provider.dart` (primary user financial state), `auth_provider.dart`, `byok_provider.dart`, `mint_state_provider.dart`

**`apps/mobile/lib/router/`:**
- Purpose: Navigation primitives for Phase 32 route registry
- Key files: `route_scope.dart` (public/onboarding/authenticated enum), `scoped_go_route.dart` (GoRoute subclass with scope field)

**`apps/mobile/lib/routes/`:**
- Purpose: Route metadata types for Phase 32 health registry + admin UI
- Key files: `route_metadata.dart`, `route_category.dart`, `route_owner.dart`, `route_health_schema.dart`

**`apps/mobile/lib/widgets/`:**
- Purpose: Reusable widget library organized by domain
- Key subdirs: `coach/` (lightning_menu, coach_message_bubble, coach_app_bar), `arbitrage/`, `confidence/`, `dashboard/`, `budget/`, `pulse/` (CAP card system)

**`apps/mobile/lib/l10n/`:**
- Purpose: Generated Dart localization classes from ARB files
- Key file: `app_localizations.dart` (generated, never edit manually)
- Source ARBs: `apps/mobile/l10n/` — edit `.arb` files, then run `flutter gen-l10n`

**`services/backend/app/api/v1/endpoints/`:**
- Purpose: One FastAPI router per domain (60+ files)
- Key files: `coach_chat.py` (main chat endpoint), `auth.py`, `profiles.py`, `scenarios.py`, `retirement.py`, `fiscal.py`, `mortgage.py`, `onboarding.dart`, `admin.py`

**`services/backend/app/services/`:**
- Purpose: Domain business logic, LLM orchestration, RAG
- Key subdirs: `coach/` (claude_coach_service.py, compliance_guard.py, prompt_registry.py, coach_tools.py), `llm/` (router.py, bedrock_client.py, tier.py), `rag/` (vector_store.py, ingester.py, retriever.py), `compliance/`, `confidence/`, `fiscal/`, `retirement/`, `mortgage/`, `lpp_deep/`, `pillar_3a_deep/`

**`services/backend/app/core/`:**
- Purpose: Infrastructure — config, database, logging, rate limiting, Redis
- Key files: `config.py` (Settings via pydantic-settings), `database.py` (SQLAlchemy engine + `get_db()` dependency), `logging_config.py` (structured JSON + `LoggingMiddleware`)

**`services/backend/app/models/`:**
- Purpose: SQLAlchemy ORM models (persisted to SQLite/PostgreSQL)
- Key files: `user.py`, `profile_model.py`, `scenario.py`, `document.py`, `snapshot.py`, `household.py`, `consent.py`

**`services/backend/app/schemas/`:**
- Purpose: Pydantic v2 request/response schemas with camelCase aliases
- Key files: `coach_chat.py`, `auth.py`, `profiles.py`, `common.py`

**`decisions/`:**
- Purpose: Architecture Decision Records — read before major structural changes
- Key files: `ADR-20260223-unified-financial-engine.md` (financial_core mandate), `ADR-20260419-killed-gamification-layers.md`, `ADR-20260418-wave-order-daily-loop.md`

**`education/`:**
- Purpose: Swiss finance knowledge base — Markdown files auto-ingested into ChromaDB RAG on backend startup

## Key File Locations

**Entry Points:**
- `apps/mobile/lib/main.dart`: Flutter app bootstrap (error boundary, API URL selection, SLM init, feature flags)
- `apps/mobile/lib/app.dart`: GoRouter with all 147 routes + MultiProvider tree
- `services/backend/app/main.py`: FastAPI app with middleware stack + lifespan hooks
- `services/backend/app/api/v1/router.py`: All API route registrations

**Configuration:**
- `services/backend/app/core/config.py`: All backend settings via `pydantic-settings` (env-driven)
- `apps/mobile/pubspec.yaml`: Flutter dependencies (provider 6.1.1, go_router 13.2.0, sentry_flutter 9.14.0)
- `apps/mobile/lib/services/feature_flags.dart`: Runtime feature flags (SLM, Bedrock, kill-switches)
- `apps/mobile/lib/services/regulatory_sync_service.dart`: Swiss regulatory constants (AVS limits, LPP rates) with disk cache + backend refresh

**Core Logic:**
- `apps/mobile/lib/services/financial_core/financial_core.dart`: Barrel export for all calculators
- `apps/mobile/lib/services/coach/coach_orchestrator.dart`: LLM tier chain (SLM → BYOK → fallback)
- `apps/mobile/lib/services/coach/context_injector_service.dart`: System prompt assembly
- `services/backend/app/services/coach/claude_coach_service.py`: Backend system prompt builder
- `services/backend/app/services/llm/router.py`: Anthropic/Bedrock LLM router (singleton)
- `apps/mobile/lib/services/api_service.dart`: All HTTP calls to backend with JWT injection

**Testing:**
- `apps/mobile/test/`: Flutter tests (`flutter test`)
- `services/backend/tests/`: pytest suite (`pytest tests/ -q`)
- `services/backend/tests/fixtures/`: Golden test profiles (Julien + Lauren)

**Navigation:**
- `apps/mobile/lib/widgets/mint_shell.dart`: 4-tab `NavigationBar` shell (Aujourd'hui / Mon argent / Coach / Explorer)
- `apps/mobile/lib/services/navigation/screen_registry.dart`: 147-entry declarative route registry with behavior classes
- `apps/mobile/lib/services/navigation/mint_nav.dart`: Navigation helper for coach-driven screen routing
- `apps/mobile/lib/screens/admin/routes_registry_screen.dart`: Admin UI for route health (Phase 32)

## Naming Conventions

**Flutter Files:**
- Screens: `snake_case_screen.dart` (e.g., `coach_chat_screen.dart`, `lpp_deep_screen.dart`)
- Services: `snake_case_service.dart` or `snake_case_calculator.dart`
- Providers: `snake_case_provider.dart`
- Widgets: `snake_case_widget.dart` or descriptive `snake_case.dart`
- Models: `snake_case.dart` (no `_model` suffix in Flutter, unlike backend)

**Flutter Classes:**
- Screens: `PascalCaseScreen` extends `StatelessWidget` or `StatefulWidget`
- Providers: `PascalCaseProvider` extends `ChangeNotifier`
- Services: `PascalCaseService` (static methods) or `PascalCaseService()` (instantiated)
- Calculators: `PascalCaseCalculator` with static methods only

**Backend Files:**
- Endpoints: `snake_case.py` matching domain (e.g., `coach_chat.py`, `lpp_deep.py`)
- Services: `snake_case_service.py`
- Schemas: `snake_case.py` per domain, camelCase field aliases
- Models: `snake_case.py` (ORM), suffix `_model.py` where conflict exists

**Routes:**
- Flutter GoRouter paths: kebab-case French (`/rente-vs-capital`, `/rachat-lpp`, `/pilier-3a`)
- Backend API paths: kebab-case (`/api/v1/coach/chat`, `/api/v1/lpp-deep`, `/api/v1/3a-deep`)
- Intent tags (ScreenRegistry): snake_case (`rente_vs_capital`, `rachat_lpp`)

## Where to Add New Code

**New simulator screen (financial tool):**
- Implementation: `apps/mobile/lib/screens/<domain>/<screen_name>_screen.dart`
- Calculations: Add to `apps/mobile/lib/services/financial_core/` if reusable; import via `financial_core.dart` barrel
- Route: Add `ScopedGoRoute` in `apps/mobile/lib/app.dart`, register in `ScreenRegistry` at `apps/mobile/lib/services/navigation/screen_registry.dart`
- Backend endpoint (if needed): `services/backend/app/api/v1/endpoints/<domain>.py` + register in `services/backend/app/api/v1/router.py`
- Tests: `apps/mobile/test/<domain>_test.dart` + `services/backend/tests/test_<domain>.py`

**New life event flow:**
- Screen directory: `apps/mobile/lib/screens/<event_name>/`
- Backend service: `services/backend/app/services/<event_name>/`
- Backend endpoint: `services/backend/app/api/v1/endpoints/<event_name>.py`

**New Provider:**
- File: `apps/mobile/lib/providers/<name>_provider.dart`
- Register: Add to `MultiProvider` list in `apps/mobile/lib/app.dart` (search for `MultiProvider(providers:`)

**New backend service:**
- File: `services/backend/app/services/<domain>_service.py` or `services/backend/app/services/<domain>/`
- Schema: `services/backend/app/schemas/<domain>.py`

**New i18n string:**
- Edit: `apps/mobile/l10n/app_fr.arb` (primary) + all 5 other language ARBs
- Regenerate: `cd apps/mobile && flutter gen-l10n`
- Usage: `AppLocalizations.of(context)!.yourKey` — NEVER `Text('hardcoded string')`

**New financial constant (Swiss law):**
- Backend: `services/backend/app/services/regulatory/` + expose via `/api/v1/regulatory`
- Frontend cache: `apps/mobile/lib/services/regulatory_sync_service.dart` loads and caches

## Special Directories

**`.planning/`:**
- Purpose: All project planning — milestones, phases, handoffs, audits
- Generated: No
- Committed: Yes

**`apps/mobile/build/`:**
- Purpose: Flutter build output
- Generated: Yes
- Committed: No

**`services/backend/app/**/__pycache__/`:**
- Purpose: Python bytecode cache
- Generated: Yes
- Committed: No

**`education/`:**
- Purpose: RAG knowledge base — Swiss finance Markdown documents
- Generated: No
- Committed: Yes
- Note: Auto-ingested into ChromaDB on backend startup if vector store is empty

**`decisions/`:**
- Purpose: ADRs — read before any structural change to financial calculations or architecture
- Generated: No
- Committed: Yes

**`apps/mobile/l10n/`:**
- Purpose: Source ARB files for 6 languages (edit these, never the generated `lib/l10n/` files)
- Generated: No (source); `lib/l10n/` is generated
- Committed: Yes (both source ARBs and generated Dart)

---

*Structure analysis: 2026-04-22*
