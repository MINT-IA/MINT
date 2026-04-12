# Coding Conventions

**Analysis Date:** 2026-04-05

## Naming Conventions

**Files (Flutter/Dart):**
- `snake_case.dart` for all files: `avs_calculator.dart`, `coach_profile_provider.dart`, `pulse_screen.dart`
- Screens: `{feature}_screen.dart` (e.g., `pulse_screen.dart`, `expat_screen.dart`, `donation_screen.dart`)
- Services: `{feature}_service.dart` (e.g., `coaching_service.dart`, `budget_living_engine.dart`)
- Tests: `{feature}_test.dart` mirroring source (e.g., `avs_calculator_test.dart`)
- Providers: `{feature}_provider.dart` (e.g., `coach_profile_provider.dart`)
- Models: `{feature}.dart` or `{feature}_models.dart` (e.g., `coach_profile.dart`, `arbitrage_models.dart`)
- Widgets: `{feature}.dart` or descriptive name (e.g., `mint_surface.dart`, `cap_card.dart`)

**Files (Python/Backend):**
- `snake_case.py` for all files
- Endpoints: `{feature}.py` in `app/api/v1/endpoints/` (e.g., `coach_chat.py`, `retirement.py`)
- Services: `{feature}_service.py` in `app/services/` (e.g., `billing_service.py`, `donation_service.py`)
- Tests: `test_{feature}.py` in `tests/` (e.g., `test_retirement.py`, `test_compliance_guard.py`)
- Schemas: `{feature}.py` in `app/schemas/` (e.g., `profile.py`, `coach_chat.py`)

**Classes (Dart):**
- `PascalCase` for classes: `AvsCalculator`, `CoachProfileProvider`, `MintSurface`
- Prefix `Mint` for design system widgets: `MintSurface`, `MintCountUp`, `MintEntrance`
- Prefix `MintColors` for color constants (static class)
- Enums: `PascalCase` with `camelCase` values: `MintSurfaceTone.porcelaine`, `ProfileDataSource.userInput`
- Private enums scoped to file: prefix with underscore `_ActiveGoal`

**Classes (Python):**
- `PascalCase` for classes: `ComplianceGuard`, `AvsEstimationService`, `CoachContext`
- Pydantic models: `PascalCase` (e.g., `ProfileBase`, `CoachChatRequest`)
- Python Enums: `PascalCase` class, `snake_case` values: `HouseholdType.single`, `Goal.optimize_taxes`

**Functions/Methods:**
- Dart: `camelCase` — `computeMonthlyRente()`, `loadFromWizard()`, `buildCoachContext()`
- Python: `snake_case` — `compute_minimal_profile()`, `build_system_prompt()`, `validate()`
- Static calculator methods: `ClassName.methodName()` — `AvsCalculator.computeMonthlyRente()`

**Variables:**
- Dart: `camelCase` for locals/fields, `_camelCase` for private, `SCREAMING_SNAKE` not used
- Python: `snake_case` for locals/fields, `SCREAMING_SNAKE_CASE` for module-level constants
- Constants (Dart): `camelCase` top-level const — `lppSeuilEntree = 22680.0`, `avsRenteMaxMensuelle`
- Constants (Python): `SCREAMING_SNAKE_CASE` — `AVS_RENTE_MAX_MENSUELLE`, `LPP_SEUIL_ENTREE`

## Flutter Conventions

**Widget Structure:**
- Screens are `StatefulWidget` or `StatelessWidget` depending on local state needs
- Use `Provider` for shared state (never raw `StatefulWidget` for shared data)
- Access providers via `context.watch<T>()` (reactive) or `context.read<T>()` (one-shot)
- Use `context.read<T>()` before any `await` to avoid stale context
- Screens wrap content in `Scaffold` with standard white `AppBar` (exception: Pulse uses gradient)

**Screen Organization:**
- `lib/screens/` organized by feature domain: `coach/`, `pulse/`, `arbitrage/`, `budget/`, etc.
- Main navigation tabs in `lib/screens/main_tabs/`: `explore_tab.dart`, `mint_coach_tab.dart`, `mint_home_screen.dart`
- 3-tab shell: Aujourd'hui (Pulse) | Coach | Explorer + ProfileDrawer (endDrawer)

**Import Organization (Dart):**
1. `dart:` SDK imports
2. `package:flutter/` framework imports
3. `package:` third-party packages (provider, go_router, shared_preferences)
4. `package:mint_mobile/` project imports — organized by layer:
   - `models/`
   - `providers/`
   - `services/`
   - `constants/`
   - `theme/`
   - `l10n/`
   - `widgets/`
   - `utils/`

**State Management (Provider):**
- All providers extend `ChangeNotifier` — `lib/providers/`
- Key providers: `CoachProfileProvider`, `ProfileProvider`, `MintStateProvider`, `AuthProvider`
- `CoachProfileProvider` is the superset model used by all simulators and coach
- `ProfileProvider` syncs with backend API (source of truth for persisted data)
- Provider instances created in top-level `MultiProvider` in app root

**Navigation:**
- GoRouter exclusively — never use `Navigator.push`
- Route definitions in centralized router config
- Deep-link compatible: `/home?tab=3` for ProfileDrawer

**Theme System:**
- Colors: `MintColors.*` from `lib/theme/colors.dart` — NEVER hardcode hex values
- Text styles: `MintTextStyles` from `lib/theme/mint_text_styles.dart`
- Spacing: `MintSpacing` from `lib/theme/mint_spacing.dart`
- Motion: `MintMotion` from `lib/theme/mint_motion.dart`
- Fonts: Montserrat (headings), Inter (body) via `GoogleFonts`
- WCAG AA contrast compliance on all text colors

**Design System Widgets:**
- Premium widgets in `lib/widgets/premium/`: `MintSurface`, `MintCountUp`, `MintEntrance`
- `MintSurface` with tone enum (`porcelaine`, `craie`, `sauge`, `bleu`, `peche`, `blanc`)
- Deprecated: `MintGlassCard`, `MintPremiumButton`, `Outfit` font — do not use

## Backend Conventions

**API Endpoint Pattern:**
- FastAPI `APIRouter()` per feature domain in `app/api/v1/endpoints/`
- Docstring at top of file listing all routes, sprint reference, and legal sources
- Rate limiting via `@limiter.limit()` decorator from `slowapi`
- Auth via `Depends(require_current_user)` dependency injection
- Stateless computation endpoints — pure functions, no side effects on most routes
- Standard disclaimer string included in all financial computation responses

**Schema Pattern (Pydantic v2):**
- Request/Response models in `app/schemas/` per domain
- `ConfigDict(populate_by_name=True)` with `alias_generator = to_camel` for camelCase JSON
- `Optional[T] = None` for optional fields with `Field(None, ge=0, le=10_000_000)` validators
- Enums as `str, Enum` for JSON serialization

**Service Layer Pattern:**
- Pure functions preferred: deterministic, stateless, testable
- Services instantiated per-request or as singletons (no shared mutable state)
- All financial calculations delegate to centralized services (never inline formulas)
- Compliance guard validates all LLM output before user display — 5-layer pipeline
- Docstrings include legal references (LAVS art. X, LPP art. Y, LIFD art. Z)

**Backend Directory Structure:**
- `app/api/v1/endpoints/` — REST route handlers
- `app/services/` — Business logic organized by domain (subdirs: `coach/`, `retirement/`, `fiscal/`, etc.)
- `app/schemas/` — Pydantic request/response models
- `app/models/` — SQLAlchemy ORM models
- `app/core/` — Cross-cutting: auth, database, rate limiting
- `app/constants/` — Swiss law constants (facade on `RegulatoryRegistry`)

## Shared Conventions

**Error Handling (Flutter):**
- `ApiException` with typed `ApiErrorCode` enum for i18n-friendly error mapping
- `try/catch` with specific exception types, not bare `catch`
- Offline detection: `ApiException.offline()` factory method
- `.firstOrNull` instead of `.first` to avoid runtime exceptions on empty collections

**Error Handling (Backend):**
- `HTTPException` from FastAPI with appropriate status codes
- `try/except` with specific exception types
- Validation errors auto-handled by Pydantic v2

**Logging:**
- Flutter: `debugPrint()` in debug mode only (gated by `kDebugMode`)
- Backend: Python `logging` module — `logger = logging.getLogger(__name__)` per file
- Sentry integration on both sides (`sentry_flutter`, `sentry-sdk[fastapi]`)
- NEVER log identifiable data (IBANs, names, SSN, employer)

**Constants Management:**
- Backend `RegulatoryRegistry` is the single source of truth for Swiss law constants
- Backend `app/constants/social_insurance.py` is a facade (bridge) that reads from `RegulatoryRegistry`
- Flutter `lib/constants/social_insurance.dart` provides offline fallback constants
- Flutter `reg()` helper reads from synced backend cache, falls back to local const
- All constants reference legal articles: `/// Salaire annuel minimum (LPP art. 7).`
- Annual update procedure: update `RegulatoryRegistry` -> auto-propagates -> update Flutter mirror

**i18n (NON-NEGOTIABLE):**
- 6 languages: fr (template), en, de, es, it, pt — ARB files in `lib/l10n/`
- ~10,344 lines in French template ARB
- ALL user-facing strings via `AppLocalizations.of(context)!.key` (alias `S`)
- New keys: add to ALL 6 ARB files, at END before closing `}`
- Run `flutter gen-l10n` after modifying ARB files
- French diacritics mandatory: e/e/e/o/u/c/a — ASCII "e" for accented = bug
- Non-breaking space (`\u00a0`) before `!`, `?`, `:`, `;`, `%`
- Banned terms in user-facing text: "garanti", "certain", "assure", "sans risque", "optimal", "meilleur", "parfait", "conseiller"

**Financial Core Library:**
- ALL financial calculations MUST use calculators from `lib/services/financial_core/`
- Barrel export: `lib/services/financial_core/financial_core.dart`
- Key calculators: `AvsCalculator`, `LppCalculator`, `TaxCalculator`, `ArbitrageEngine`, `ConfidenceScorer`, `MonteCarloService`
- Static pure methods: `AvsCalculator.computeMonthlyRente(...)` — no instance state
- NEVER create `_calculate*()` methods in consumer services — always delegate to `financial_core/`
- Every projection MUST include `EnhancedConfidence` score (4-axis: completeness x accuracy x freshness x understanding)

**Compliance in Every Output:**
- `disclaimer` — educational purpose, not financial advice, LSFin reference
- `sources` — legal references (LPP art. X, LIFD art. Y)
- `premier_eclairage` — first personalized insight (replaces legacy `chiffre_choc`)
- `alertes` — warnings when thresholds are crossed

## Code Style

**Formatting:**
- Dart: `dart format` (standard, no custom config)
- Python: `ruff` with `line-length = 88`, `target-version = "py310"`

**Linting:**
- Flutter: `package:flutter_lints` with `analysis_options.yaml`
  - `prefer_const_constructors: true`
  - `prefer_const_declarations: true`
  - `avoid_print: true`
  - Excludes: `archive/**`, `test/_archive/**`
- Python: `ruff` (configured in `pyproject.toml`)

**Comment Style:**
- Dart: `///` for doc comments on public APIs, `//` for inline. Reference legal articles.
- Python: triple-quote docstrings with sprint reference, legal sources, and rule reminders
- Both: Header blocks with `// ════════` or `# ═════════` separators for major sections
- Backend endpoint files: comprehensive module docstring listing all routes, architecture notes, and compliance references
- `TODO`/`FIXME` for known debt (tracked in CONCERNS.md)

**Documentation Headers (Backend Services):**
```python
"""
Service Name — Sprint SXX.

Description of purpose.

Sources:
    - LAVS art. XX
    - LPP art. YY
    - LIFD art. ZZ

Rules:
    - NEVER use banned terms
    - Educational tone
"""
```

**Documentation Headers (Flutter Calculators):**
```dart
/// Calculator name — pure static functions.
///
/// Legal basis: LAVS art. XX, LPP art. YY.
/// All computations are deterministic and stateless.
```

---

*Convention analysis: 2026-04-05*
