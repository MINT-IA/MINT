# Architecture

**Analysis Date:** 2026-04-05

## Pattern Overview

**Overall:** Client-heavy mobile app (Flutter) with a REST API backend (FastAPI). The Flutter app contains most business logic via a shared `financial_core/` library of pure calculators. The backend serves as data persistence layer, AI coach orchestration, and API gateway for document parsing, RAG, and compliance.

**Key Characteristics:**
- Flutter app runs calculations client-side using `financial_core/` pure functions
- Backend is source of truth for constants and regulatory parameters (synced to client via `RegulatorySyncService`)
- Coach AI layer uses a 3-tier priority chain: on-device SLM (Gemma 3n) -> BYOK cloud LLM (Claude) -> fallback templates
- All LLM output passes through `ComplianceGuard` before reaching users
- Provider-based state management with 14 `ChangeNotifierProvider` instances in root `MultiProvider`
- GoRouter with ~70 canonical routes + legacy redirects

## Layers

**Presentation Layer (Flutter Screens):**
- Purpose: UI rendering, user interaction, route handling
- Location: `apps/mobile/lib/screens/`
- Contains: 40+ screen files organized by domain (coach, arbitrage, disability, mortgage, etc.)
- Depends on: Providers, Services, Widgets, Models
- Used by: GoRouter in `apps/mobile/lib/app.dart`

**State Management (Providers):**
- Purpose: Shared reactive state across screens
- Location: `apps/mobile/lib/providers/`
- Contains: 14 providers (auth, profile, coach_profile, budget, byok, document, subscription, household, mint_state, locale, user_activity, slm, onboarding, coach_entry_payload)
- Depends on: Services, Models
- Used by: Screens via `context.watch<T>()` and `context.read<T>()`

**Service Layer (Flutter):**
- Purpose: Business logic, API communication, calculations
- Location: `apps/mobile/lib/services/`
- Contains: 93+ service files across root and subdirectories (coach/, llm/, financial_core/, confidence/, etc.)
- Depends on: Models, Constants, ApiService
- Used by: Providers and Screens

**Financial Core (Shared Calculators):**
- Purpose: Pure, deterministic financial calculations used by ALL projection services
- Location: `apps/mobile/lib/services/financial_core/`
- Contains: 17 calculator/model files (AVS, LPP, tax, arbitrage, Monte Carlo, confidence, tornado sensitivity, withdrawal sequencing)
- Depends on: Constants only (pure functions)
- Used by: All projection services, forecaster, report generators. Barrel export via `financial_core.dart`
- ADR: `decisions/ADR-20260223-unified-financial-engine.md`

**Widget Library:**
- Purpose: Reusable UI components
- Location: `apps/mobile/lib/widgets/`
- Contains: 245+ widget files in 20 subdirectories (arbitrage, coach, common, dashboard, educational, fiscal, premium, pulse, visualizations, wizard, etc.)
- Depends on: Theme, Models
- Used by: Screens

**API Gateway (Backend):**
- Purpose: REST endpoints, auth, data persistence, AI orchestration
- Location: `services/backend/app/api/v1/endpoints/`
- Contains: 55+ endpoint modules
- Depends on: Services, Schemas, Models, Core
- Used by: Flutter ApiService via HTTP

**Backend Services:**
- Purpose: Server-side business logic, AI integration, document processing
- Location: `services/backend/app/services/`
- Contains: 29+ root service files + 16 subdirectory modules (arbitrage/, coach/, confidence/, rag/, retirement/, fiscal/, etc.)
- Depends on: Schemas, Models, external APIs (Anthropic, Stripe)
- Used by: API endpoints

**Backend Schemas (Pydantic):**
- Purpose: Request/response validation, API contracts
- Location: `services/backend/app/schemas/`
- Contains: 40+ schema files with Pydantic v2 models (camelCase aliases)
- Used by: Endpoints and Services

**Backend Models (SQLAlchemy):**
- Purpose: Database ORM models
- Location: `services/backend/app/models/`
- Contains: 16 model files (user, profile, scenario, session, document, household, billing, consent, snapshot, etc.)
- Depends on: SQLAlchemy Base from `app/core/database.py`
- Used by: Services via DB sessions

## Data Flow

**User Input to Financial Projection:**

1. User enters data on screen (e.g., salary, age, canton)
2. Screen reads `CoachProfileProvider` for existing data (auto-fill via `ProfileAutoFillMixin`)
3. Screen calls service method (e.g., `RetirementProjectionService`)
4. Service delegates to `financial_core/` calculators (pure functions)
5. `ConfidenceScorer` computes 4-axis confidence (completeness x accuracy x freshness x understanding)
6. Results displayed with confidence band, disclaimer, and sources

**Coach Chat Flow:**

1. User sends message in `CoachChatScreen` (`apps/mobile/lib/screens/coach/coach_chat_screen.dart`)
2. `CoachOrchestrator` (`apps/mobile/lib/services/coach/coach_orchestrator.dart`) manages priority chain:
   - Tier 1: SLM on-device (Gemma 3n via `SlmEngine`) - 30s timeout
   - Tier 2: BYOK cloud LLM via `CoachLlmService` -> backend `/api/v1/coach/chat` endpoint
   - Tier 3: `FallbackTemplates` (always available, no LLM)
3. Backend `claude_coach_service.py` builds system prompt with user context, regional voice, compliance rules
4. `coach_tools.py` provides tool definitions (route_to_screen, compute_*, etc.)
5. `ComplianceGuard` validates output (both client-side and server-side)
6. `HallucinationDetector` checks for fabricated numbers
7. Response displayed with response cards and suggested actions

**API Communication:**

1. `ApiService` (`apps/mobile/lib/services/api_service.dart`) is the HTTP client
2. Base URL resolved at startup via `ApiService.ensureReachableBaseUrl()`
3. JWT auth with token refresh on app resume
4. All endpoints under `/api/v1/` prefix
5. Pydantic v2 schemas with camelCase aliases for JSON serialization

**State Management:**

- Root `MultiProvider` in `MintApp.build()` (`apps/mobile/lib/app.dart` L1020-1088)
- `CoachProfileProvider` is the central profile state - loaded from wizard/SharedPreferences
- `BudgetProvider` and `MintStateProvider` are proxy-dependent on `CoachProfileProvider`
- Auth state in `AuthProvider` with JWT token management
- `FeatureFlags` loaded from backend + periodic refresh (6h interval)

## Key Abstractions

**Financial Core Calculators:**
- Purpose: Single source of truth for all Swiss financial calculations
- Examples: `apps/mobile/lib/services/financial_core/avs_calculator.dart`, `lpp_calculator.dart`, `tax_calculator.dart`, `arbitrage_engine.dart`, `monte_carlo_service.dart`
- Pattern: Static pure functions, no side effects, legally referenced (LAVS, LPP, LIFD)
- Rule: ALL consumers must import `financial_core.dart`, NEVER reimplement calculations

**CoachProfile:**
- Purpose: Central user data model shared across all screens and projections
- Examples: `apps/mobile/lib/models/coach_profile.dart`, `apps/mobile/lib/providers/coach_profile_provider.dart`
- Pattern: ChangeNotifier with SharedPreferences persistence, loaded at app start

**ComplianceGuard:**
- Purpose: Validates all AI-generated text against Swiss financial compliance rules
- Examples: `apps/mobile/lib/services/coach/compliance_guard.dart`, `services/backend/app/services/coach/compliance_guard.py`
- Pattern: Pre-delivery filter on both client and server side

**EnhancedConfidence:**
- Purpose: 4-axis confidence score (completeness x accuracy x freshness x understanding) attached to ALL projections
- Examples: `apps/mobile/lib/services/financial_core/confidence_scorer.dart`, `services/backend/app/services/confidence/enhanced_confidence_service.py`
- Pattern: Geometric mean of 4 axes, enrichment prompts for improvement, uncertainty band when < 70%

**Feature Flags:**
- Purpose: Server-driven feature gating with local defaults
- Examples: `apps/mobile/lib/services/feature_flags.dart`, `services/backend/app/services/feature_flags.py`
- Pattern: Refreshed from backend on startup + every 6 hours. Gates: OpenBanking, ExpertTier, AdminScreens, PensionFundConnect

## Entry Points

**Flutter App:**
- Location: `apps/mobile/lib/main.dart`
- Triggers: App launch (iOS/Android/Web)
- Responsibilities: Flutter binding init, portrait lock, API endpoint resolution, RegulatorySyncService disk load, SLM plugin init, FeatureFlags refresh, background data loading (3a limits, tax scales, communes, regulatory constants, snapshots), Sentry init, CoachOrchestrator registration, `runApp(MintApp())`

**Backend API:**
- Location: `services/backend/app/main.py`
- Triggers: Uvicorn server start
- Responsibilities: FastAPI app creation, middleware stack (GZip, CORS, security headers, logging, rate limiting), lifespan handler (DB table creation, connectivity check, RAG auto-ingest), Sentry init, router mounting at `/api/v1`

**GoRouter:**
- Location: `apps/mobile/lib/app.dart` L161-974
- Triggers: Navigation events
- Responsibilities: Route matching for ~70 routes, auth guard (redirect to register if unauthenticated), feature flag gates, legacy route redirects, redirect-loop protection

## Error Handling

**Strategy:** Multi-layer with graceful degradation

**Patterns:**
- `ApiException` with typed `ApiErrorCode` enum (offline, timeout, sessionExpired, serverError, unknown) for i18n-friendly error display
- Backend global exception handler catches unhandled exceptions, logs type+truncated message (nLPD: no PII), reports to Sentry
- Rate limiting returns 429 with `error_code: "rate_limited"` for machine-readable client handling
- Coach AI uses 3-tier fallback (SLM -> BYOK -> templates) so app works offline
- `ProviderHealthService` circuit breaker prevents hammering dead LLM providers
- Background data loading uses `.catchError()` with debug logging (non-blocking)
- GoRouter `errorBuilder` renders `_MintErrorScreen` for unmatched routes
- Scan/review routes redirect to `/scan` if required `state.extra` is missing

## Cross-Cutting Concerns

**Logging:**
- Backend: Python `logging` with structured config via `setup_logging()` in `app/core/logging_config.py`, `LoggingMiddleware` on all requests
- Flutter: `debugPrint` in debug mode only, no production logging framework
- Sentry: Both client (Dart, DSN via dart-define) and server (Python SDK, DSN via env var), `sendDefaultPii=false` for nLPD compliance

**Validation:**
- Backend: Pydantic v2 schemas with `ConfigDict(populate_by_name=True)` and `alias_generator=to_camel`
- Flutter: Service-level input validation, `ComplianceGuard` for AI output
- Auth: JWT with HS256, token blacklist model, email verification (configurable)

**Authentication:**
- JWT-based auth via `apps/mobile/lib/services/auth_service.dart` and `services/backend/app/core/auth.py`
- Global auth guard in GoRouter redirect (all routes require auth except landing, auth/*, onboarding/*)
- Token refresh on app resume via `ApiService.refreshTokenIfNeeded()`
- Rate limiting via slowapi with Redis (or in-memory fallback)
- Security headers: X-Content-Type-Options, X-Frame-Options, HSTS, CSP, Permissions-Policy

**Internationalization:**
- 6 languages: fr (template), en, de, es, it, pt
- ARB files in `apps/mobile/lib/l10n/`
- All user-facing strings via `AppLocalizations.of(context)!.key`
- French is primary, all new keys added to all 6 ARB files

**Compliance:**
- `ComplianceGuard` on ALL AI outputs (client + server)
- `HallucinationDetector` for fabricated numbers
- Banned terms list enforced in system prompt
- Required fields on every projection: disclaimer, sources, premier_eclairage, alertes
- No PII in logs (nLPD), no product recommendations (LSFin)

**Regional Voice:**
- `RegionalVoiceService.forCanton()` injects canton-specific personality into coach prompts
- Backend `claude_coach_service.py` has `REGIONAL_MAP` and `INTENSITY_MAP` for tone control
- Client `context_injector_service.dart` builds coach context with regional markers

---

*Architecture analysis: 2026-04-05*
