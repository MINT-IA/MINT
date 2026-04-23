# Architecture

**Analysis Date:** 2026-04-22

## Pattern Overview

**Overall:** Client-server monorepo with a chat-central, coach-as-narrator architecture. Flutter mobile app (read-only financial lucidity tool) communicates with a FastAPI backend over REST. All financial calculations are pure functions in a shared Flutter library. The coach (Claude AI) is the primary UI surface — screens are summoned by the coach, not the other way around.

**Key Characteristics:**
- Chat is the entry point; simulator screens are "canvases" surfaced from conversation
- Financial math is centralized in `lib/services/financial_core/` — no duplication across screens or services
- Backend is stateless computation + LLM orchestration; state lives in SQLite/PostgreSQL per user
- Provider pattern for Flutter state; GoRouter with 147-route registry for navigation
- 3-tier LLM chain: on-device SLM → BYOK cloud → static fallback templates

## Layers

**Flutter Presentation (Screens + Widgets):**
- Purpose: UI rendering, user interaction, navigation
- Location: `apps/mobile/lib/screens/`, `apps/mobile/lib/widgets/`
- Contains: Screen widgets organized by domain (coach, aujourdhui, mon_argent, explore, arbitrage, lpp_deep, pillar_3a_deep, mortgage, etc.)
- Depends on: Providers, services, financial_core, router
- Used by: End user via GoRouter

**Flutter State (Providers):**
- Purpose: Reactive state management via Provider package
- Location: `apps/mobile/lib/providers/`
- Contains: `ProfileProvider`, `CoachProfileProvider`, `AuthProvider`, `BudgetProvider`, `ByokProvider`, `MintStateProvider`, `FinancialPlanProvider`, `HouseholdProvider`, `BiographyProvider`, `TimelineProvider`, `LocaleProvider`, `SubscriptionProvider`
- Depends on: Models, services
- Used by: Screens via `context.watch<T>()` / `context.read<T>()`

**Flutter Services:**
- Purpose: Business logic, API calls, calculations, AI orchestration
- Location: `apps/mobile/lib/services/`
- Contains: `ApiService` (HTTP), `AuthService`, `CoachOrchestrator` (LLM tier chain), `ContextInjectorService` (system prompt assembly), `ComplianceGuard`, coach sub-services, financial calculators
- Depends on: `financial_core/`, models, constants, backend API
- Used by: Providers, screens

**Financial Core (Source of Truth):**
- Purpose: All Swiss-law financial calculations — immutable pure functions
- Location: `apps/mobile/lib/services/financial_core/`
- Contains: `AvsCalculator`, `LppCalculator`, `TaxCalculator`, `CrossPillarCalculator`, `FriCalculator`, `HousingCostCalculator`, `ArbitrageEngine`, `MonteCarloService`, `ConfidenceScorer`, `BayesianEnricher`, `CoachReasoner`, `TornadoSensitivityService`, `WithdrawalSequencingService`, `CoupleOptimizer`
- Depends on: Nothing (pure Dart, no Flutter imports)
- Used by: All simulator screens, projection services, backend parity checks
- ADR: `decisions/ADR-20260223-unified-financial-engine.md`

**Flutter Router:**
- Purpose: Declarative navigation with auth scoping
- Location: `apps/mobile/lib/app.dart` (router definition, 1857 lines), `apps/mobile/lib/router/`, `apps/mobile/lib/routes/`
- Contains: GoRouter with `ScopedGoRoute` (public/onboarding/authenticated scopes), `StatefulShellRoute.indexedStack` for 4-tab shell, legacy redirect map (43 call-sites), `AnalyticsRouteObserver` + `SentryNavigatorObserver`
- Key abstractions: `RouteScope` enum (`apps/mobile/lib/router/route_scope.dart`), `ScopedGoRoute` (`apps/mobile/lib/router/scoped_go_route.dart`), `ScreenRegistry` (`apps/mobile/lib/services/navigation/screen_registry.dart`)

**FastAPI Backend:**
- Purpose: LLM orchestration, user data persistence, Swiss calculation APIs, RAG knowledge base
- Location: `services/backend/app/`
- Contains: 60+ endpoint modules under `app/api/v1/endpoints/`, domain services under `app/services/`
- Depends on: SQLAlchemy (SQLite dev / PostgreSQL prod), Anthropic Claude API, ChromaDB (RAG), Redis (rate limiting)
- Used by: Flutter via `ApiService`, admin tooling

**Backend Services:**
- Purpose: Domain logic per life event + cross-cutting infrastructure
- Location: `services/backend/app/services/`
- Contains: `claude_coach_service.py`, `coach_context_builder.py`, `compliance_guard.py`, `auth_service.py`, `billing_service.py`, RAG vector store (`rag/`), LLM router (`llm/router.py`), domain clusters (retirement, mortgage, lpp_deep, fiscal, expat, family, etc.)

## Data Flow

**Chat Flow (primary user path):**

1. User types in `CoachChatScreen` (`apps/mobile/lib/screens/coach/coach_chat_screen.dart`)
2. `ContextInjectorService` (`apps/mobile/lib/services/coach/context_injector_service.dart`) assembles system prompt block from lifecycle phase, conversation memory, user goals, CAP sequence progress
3. `CoachOrchestrator` (`apps/mobile/lib/services/coach/coach_orchestrator.dart`) routes through 3-tier chain: SLM (gated by `FeatureFlags.slmPluginReady`) → BYOK (`CoachLlmService`) → `FallbackTemplates`
4. For authenticated users, `CoachChatApiService` POSTs to `/api/v1/coach/chat`
5. Backend `claude_coach_service.py` builds system prompt, calls Anthropic Claude via `LLMRouter` (`services/backend/app/services/llm/router.py`)
6. LLM response may include tool calls (`chat_tool_dispatcher.dart` handles locally, or backend `coach_tools.py` handles server-side)
7. `ComplianceGuard` validates output (both client-side `compliance_guard.dart` and server-side `compliance_guard.py`)
8. Response rendered in `CoachMessageBubble` widget; tool calls may summon simulator canvases via `MintNav`

**Projection Flow (simulator screens):**

1. Screen reads `CoachProfileProvider` for pre-filled user data
2. Calls pure functions in `financial_core/` (e.g., `AvsCalculator.computeMonthlyRente()`, `LppCalculator.projectOneMonth()`)
3. Results displayed with `EnhancedConfidence` score + uncertainty band
4. Optional: backend API call for richer scenario narration (`/api/v1/scenario/`)

**Profile Sync Flow:**

1. `AuthService` handles JWT login/refresh, stores tokens in `flutter_secure_storage`
2. `ApiService.ensureReachableBaseUrl()` selects staging vs. production endpoint at startup
3. Profile fetched from `/api/v1/profiles/` and stored in `CoachProfileProvider`
4. `RegulatorySyncService` (`apps/mobile/lib/services/regulatory_sync_service.dart`) loads Swiss constants (AVS limits, LPP rates) from disk cache, then fetches fresh from `/api/v1/regulatory`

**State Management:**
- Global: `MultiProvider` tree instantiated in `MintApp` (in `apps/mobile/lib/app.dart`)
- Navigation state: `StatefulShellRoute.indexedStack` preserves each tab's widget tree
- Persistence: `SharedPreferences` for lightweight state, `flutter_secure_storage` for JWT, backend SQLite/PostgreSQL for user data

## Key Abstractions

**CoachOrchestrator:**
- Purpose: Single entry-point for all LLM generation; privacy-first tier chain
- Location: `apps/mobile/lib/services/coach/coach_orchestrator.dart`
- Pattern: Tier 1 (SLM on-device, `SlmEngine`) → Tier 2 (BYOK cloud, `CoachLlmService`) → Tier 3 (`FallbackTemplates`). `ComplianceGuard` applied to ALL tiers.

**ScreenRegistry / RoutePlanner:**
- Purpose: Declarative map of all MINT surfaces with behavior class and readiness requirements
- Location: `apps/mobile/lib/services/navigation/screen_registry.dart`, `apps/mobile/lib/services/navigation/route_planner.dart`
- Pattern: Each screen entry has an intent tag, `ScreenBehavior` (A=directAnswer, B=decisionCanvas, C=roadmapFlow, D=captureUtility, E=conversationPure), and minimum profile fields for `ReadinessGate`

**financial_core:**
- Purpose: Swiss financial law calculations, single source of truth
- Location: `apps/mobile/lib/services/financial_core/financial_core.dart` (barrel export)
- Pattern: Static pure functions only. `AvsCalculator.computeMonthlyRente(profile)` — never re-implement inline.

**LLMRouter (backend):**
- Purpose: Flag-driven routing between Anthropic direct, AWS Bedrock primary, and Bedrock shadow
- Location: `services/backend/app/services/llm/router.py`
- Pattern: `LLMRequest` → `LLMRouter.invoke()` → `RouteMode` (OFF/SHADOW/PRIMARY_BEDROCK) resolved per user from `flags_service`

**ScopedGoRoute:**
- Purpose: Encode auth requirements at route definition time (fail-closed default: authenticated)
- Location: `apps/mobile/lib/router/scoped_go_route.dart`
- Pattern: `ScopedGoRoute(path: '/...', scope: RouteScope.public, builder: ...)` — router redirect reads `topRoute.scope` instead of maintaining a prefix whitelist

## Entry Points

**Flutter App:**
- Location: `apps/mobile/lib/main.dart`
- Triggers: App launch (iOS/Android)
- Responsibilities: Install global error boundary, select API base URL, load disk caches (regulatory constants, snapshots), initialize SLM plugin, refresh feature flags, pre-initialize services, launch `MintApp` wrapped in `SentryWidget`

**MintApp / Router:**
- Location: `apps/mobile/lib/app.dart` (GoRouter definition + `MultiProvider` tree)
- Triggers: `runApp(MintApp())`
- Responsibilities: Provide all `ChangeNotifier` providers, define 147 GoRouter routes with scoped auth guards, mount 4-tab `StatefulShellRoute`, bind `_AuthRefreshNotifier` to `AuthProvider` for reactive redirects

**FastAPI Backend:**
- Location: `services/backend/app/main.py`
- Triggers: `uvicorn app.main:app`
- Responsibilities: DB table creation + connectivity check, RAG auto-ingest, SLO monitor background task, middleware stack (CORS, security headers, GZip, rate limiting, encryption context, logging), mount `api_router` at `/api/v1`

**Backend API Router:**
- Location: `services/backend/app/api/v1/router.py`
- Triggers: Imported by `main.py`
- Responsibilities: Register 60+ endpoint modules under versioned prefix `/api/v1`

## Error Handling

**Strategy:** Fail-open for non-critical services; fail-fast for DB connectivity; compliance errors always surface

**Patterns:**
- Flutter: `ApiException` with typed `ApiErrorCode` enum for i18n-mapped error messages (`apps/mobile/lib/services/api_service.dart`)
- Flutter: `ErrorBoundary` installed globally in `main.dart` via `installGlobalErrorBoundary()` (covers `PlatformDispatcher.onError`, `FlutterError.onError`, `Isolate.addErrorListener`)
- Backend: `global_exception_handler` returns `{"error_code": "internal_error", "trace_id": "..."}` — never leaks PII
- Backend: 3-tier trace ID resolution (inbound sentry-trace header → `LoggingMiddleware` ContextVar → fresh UUID)
- Coach tier chain: each tier `catchError`s and falls through to next tier; `FallbackTemplates` always available
- Startup services: all background loads use `.catchError()` — app launches even when backend unreachable

## Cross-Cutting Concerns

**Compliance:** `ComplianceGuard` enforced on every LLM output — client (`apps/mobile/lib/services/coach/compliance_guard.dart`) and server (`services/backend/app/services/coach/compliance_guard.py`). Banned terms list from LSFin enforced via static regex. `HallucinationDetector` in both layers.

**Logging:** Structured JSON logging on backend (`app/core/logging_config.py`), `LoggingMiddleware` adds `trace_id` to every request. Client uses `debugPrint` (debug mode) + Sentry breadcrumbs (production). `SentryNavigatorObserver` with `setRouteNameAsTransaction: true` adds route-path transaction to every Sentry issue.

**Validation:** Pydantic v2 with `camelCase` aliases on all backend schemas (via `model_config = ConfigDict(alias_generator=to_camel)`). Flutter models use `fromJson`/`toJson` matching backend camelCase contract.

**Authentication:** JWT (HS256, 24h expiry) stored in `flutter_secure_storage`. `AuthProvider` checks auth state on app start; router guards redirect unauthenticated users to `/auth/register?redirect=...`. Local anonymous mode (`isLocalMode`) allows financial calculations without account creation.

**Privacy:** nLPD compliance throughout — `sendDefaultPii = false` on Sentry, `maskAllText = true` on Sentry Replay, no PII in error logs (type name + truncated message only), `ContextInjectorService` anonymizes topics before injecting into LLM context.

**Feature Flags:** `FeatureFlags` (`apps/mobile/lib/services/feature_flags.dart`) fetched from `/api/v1/config` at startup (2s timeout) and every 6 hours. Backend `flags_service.py` with Redis backing (in-memory fallback). Used for SLM gating, Bedrock routing, narrative degradation flags.

---

*Architecture analysis: 2026-04-22*
