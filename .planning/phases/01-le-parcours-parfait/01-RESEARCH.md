# Phase 1: Le Parcours Parfait - Research

**Researched:** 2026-04-06
**Domain:** Flutter onboarding flow wiring, auth integration, coach AI check-in, integration testing
**Confidence:** HIGH

## Summary

Phase 1 is primarily a **wiring and state-handling** phase, not a greenfield build. All 7 screens in Lea's golden path already exist (`promise_screen`, `login_screen`/`register_screen`, `intent_screen`, `quick_start_screen`, `chiffre_choc_screen`, coach tab). The critical work is: (1) rewiring the navigation chain so these screens flow sequentially without dead ends, (2) adding magic link auth (currently absent -- only email+password exists), (3) creating standardized loading/error/empty state widgets, (4) ensuring the coach check-in uses VD regional voice with the 4-layer insight engine, and (5) writing an integration test for the full Lea journey.

The biggest risk is the **magic link auth** requirement (PATH-02). Neither the Flutter app nor the FastAPI backend currently implement magic link authentication. The backend uses JWT tokens with email+password registration/login only. Magic link requires either a new backend endpoint (`/auth/magic-link/send` + `/auth/magic-link/verify`) or integration with a third-party auth service (Firebase Auth, Supabase Auth). This is the only net-new backend feature in Phase 1.

**Primary recommendation:** Wire existing screens into a linear golden path, implement magic link auth as a backend+frontend feature, create 2 missing state widgets (`MintLoadingState`, `MintErrorState`), and write `lea_golden_path_test.dart` as a service-level integration test (not widget E2E -- consistent with existing test patterns in `test/journeys/`).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Landing entry point: refine existing `promise_screen.dart` as the landing page with value prop + CTA (no new screen)
- Auth method priority: magic link primary (email-only, zero password friction), Apple Sign-In secondary (iOS), email+password as fallback -- per PATH-02
- Auth->onboarding transition: auto-redirect after auth success -- check `isMiniOnboardingCompleted` flag in ReportPersistenceService -> route to `intent_screen` or `home` (NOTE: CONTEXT.md used `hasCompletedOnboarding` aspirationally but the actual codebase flag is `ReportPersistenceService.isMiniOnboardingCompleted()`)
- Magic link delay handling: inline "Pas recu ? Renvoyer" with 30s countdown timer, then reveal email+password fallback option
- Screen sequence: `intent_screen` (life event selection) -> `quick_start_screen` (age, revenu, canton) -> `chiffre_choc_screen` (premier eclairage) -- reuse existing 3 screens
- Input collection: single `quick_start_screen` with 3 modern inputs -- CupertinoPicker for age, tap-to-type for revenu, canton dropdown -- per feedback on modern inputs (no sliders)
- Premier eclairage generation: backend call with intent + 3 inputs -> coach generates firstJob-specific insight using 4-layer engine (factual -> human -> personal -> questions to ask)
- Post-premier eclairage: auto-navigate to plan generation (financial plan based on firstJob intent) -> then check-in prompt as a coach message
- VD regional voice: `RegionalVoiceService.forCanton('VD')` injects Romande voice into coach system prompt -- existing pattern
- Check-in prompt: coach sends first message -- biography-aware, ends with user-initiated action suggestion (e.g., "Tu veux qu'on regarde ton 3a ?") -- never imperative
- Integration test: single `lea_golden_path_test.dart` covering mock auth -> onboarding -> premier eclairage -> plan -> check-in message
- Error/loading/empty states: standardized `MintLoadingState`, `MintErrorState` (retry button), `MintEmptyState` widgets applied to every screen in the path

### Claude's Discretion
- Exact premier eclairage content for firstJob intent (must pass 4-layer engine)
- Plan generation screen layout and content
- Specific error messages and empty state copy (in ARB files)
- Integration test mock strategy and assertion granularity

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PATH-01 | Lea (22, VD, firstJob) completes full golden path: landing -> auth -> onboarding intent -> premier eclairage -> financial plan -> first check-in prompt | Existing screens verified; navigation wiring gaps identified; intent_screen currently exits to `/home?tab=0` instead of `quick_start_screen` -- needs rewiring |
| PATH-02 | User can authenticate via magic link (primary) or Apple Sign-In (secondary), with email+password as fallback | Magic link is NET NEW -- neither backend nor frontend implement it. Apple Sign-In also absent. email+password exists. |
| PATH-03 | Onboarding collects intent + 3 inputs (age, revenu, canton) and delivers premier eclairage within 5 minutes total | `quick_start_screen` already collects these 3 inputs; `chiffre_choc_screen` displays premier eclairage; backend `/api/v1/onboarding/minimal-profile` endpoint exists |
| PATH-04 | Coach responses for firstJob intent are contextual, use VD regional voice (septante/nonante), and pass 4-layer insight engine | `RegionalVoiceService` exists with VD mapping; `claude_coach_service.py` has REGIONAL_MAP with VD entry; 4-layer engine needs explicit system prompt section |
| PATH-05 | Every screen in Lea's path has loading states, error states, empty states, and smooth transitions | `MintEmptyState` exists; `MintLoadingState` and `MintErrorState` do NOT exist -- must be created |
| PATH-06 | Integration test covers full Lea journey and fails if any link breaks | `test/journeys/firstjob_journey_test.dart` exists but tests IntentRouter+CapSequence only, not the full path; need new `lea_golden_path_test.dart` |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Branch flow**: feature/* -> dev (squash). Never push to staging/main directly.
- **Before ANY code modification**: `git branch --show-current` + `git status`
- **Testing**: minimum 10 unit tests per service file; golden couple tests; `flutter analyze` (0 issues) + `flutter test` + `pytest tests/ -q` before merge
- **GoRouter only**: no `Navigator.push`
- **Provider only**: no raw StatefulWidget for shared data
- **All strings via AppLocalizations**: 6 ARB files (fr, en, de, es, it, pt)
- **MintColors.* only**: never hardcode hex
- **Fonts**: Montserrat (headings), Inter (body) -- Outfit deprecated
- **context.read<T>() before await**: safety pattern
- **Backend = source of truth** for constants and formulas
- **Pure functions** for all backend calculations
- **Pydantic v2** with camelCase alias
- **Financial calculations via financial_core/** only -- never duplicate
- **Compliance**: no banned terms, disclaimer + sources + premier_eclairage + alertes in every output
- **French diacritics mandatory** in ARB files
- **Non-breaking space** before `!`, `?`, `:`, `;`, `%`

## Standard Stack

### Core (already in project -- no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | 3.41.4 | Mobile framework | Project standard [VERIFIED: `flutter --version`] |
| Dart | 3.11.1 | Language | Project standard [VERIFIED: `dart --version`] |
| go_router | (in pubspec) | Navigation | Project standard, all routes defined in `app.dart` [VERIFIED: codebase grep] |
| provider | (in pubspec) | State management | Project standard, all providers in `lib/providers/` [VERIFIED: codebase grep] |
| flutter_secure_storage | (in pubspec) | Auth token storage | Used by `AuthService` for JWT tokens [VERIFIED: `auth_service.dart`] |
| shared_preferences | (in pubspec) | Onboarding persistence | Used by `OnboardingProvider` and `ReportPersistenceService` [VERIFIED: codebase grep] |
| FastAPI | 0.128.0 | Backend API | Project standard [VERIFIED: `pip3 show fastapi`] |
| Python | 3.9.6 | Backend runtime | Project standard [VERIFIED: `python3 --version`] |

### New Dependencies Needed

| Library | Purpose | When to Use |
|---------|---------|-------------|
| None for magic link (if self-hosted) | Backend sends email with token, verifies on return | Self-hosted JWT-based magic link requires only existing stack + email sending |
| `sign_in_with_apple` (Flutter) | Apple Sign-In on iOS | PATH-02 secondary auth method [ASSUMED] |

**No new major dependencies required.** Magic link can be implemented with the existing JWT auth system + an email sending service. Apple Sign-In requires the `sign_in_with_apple` Flutter package.

## Architecture Patterns

### Current Navigation Flow (BROKEN for Lea's path)

```
Current: LandingScreen (/) -> /auth/register -> /home?tab=0
                                                  ^ direct to home, skipping onboarding

IntentScreen: /onboarding/intent -> computes premier eclairage locally -> /home?tab=0
                                                                         ^ skips quick_start AND chiffre_choc screen
```

**Problem**: `intent_screen.dart` currently does ALL computation inline (`_onChipTap`) and navigates directly to `/home?tab=0`. It never routes through `quick_start_screen` or `chiffre_choc_screen`. The "golden path" per CONTEXT.md requires:

```
Target: / (landing) -> /auth/login (magic link) -> /onboarding/intent -> /onboarding/quick-start -> /onboarding/chiffre-choc -> /plan -> /home?tab=1 (coach check-in)
```

### Pattern 1: Linear Onboarding Pipeline

**What:** Wire screens into a strict linear sequence using GoRouter navigation. Each screen has a single forward exit and handles its own loading/error/empty states.

**When to use:** The entire Phase 1 golden path.

**Implementation approach:**
```
intent_screen -> go('/onboarding/quick-start', extra: {intent: chipKey})
quick_start_screen -> go('/onboarding/chiffre-choc', extra: {age, salary, canton, intent})
chiffre_choc_screen -> go('/plan', extra: {profile, insight})
plan_screen -> go('/home?tab=1')
```

Each transition passes data forward via GoRouter `extra`. No global state mutation until the end of the pipeline (when CoachProfileProvider is updated). [VERIFIED: this is consistent with how `chiffre_choc_screen` already receives data via `GoRouterState.of(context).extra`]

### Pattern 2: Auth Guard with Onboarding Check

**What:** After auth success, check whether onboarding is completed. Route to `/onboarding/intent` for new users, `/home` for returning users.

**Current state:** `app.dart` redirect function only guards protected routes. It does NOT check onboarding status. The `RegisterScreen._handleRegister()` navigates to `/home` after success. [VERIFIED: `register_screen.dart` line 56+]

**Required change:** After auth success, check `ReportPersistenceService.isMiniOnboardingCompleted()`. If false, route to `/onboarding/intent`. If true, route to `/home`.

### Pattern 3: Standardized State Widgets

**What:** Three reusable widgets for loading, error, and empty states -- used consistently across all onboarding screens.

**Current state:**
- `MintEmptyState` EXISTS at `widgets/common/mint_empty_state.dart` [VERIFIED]
- `MintLoadingState` does NOT exist [VERIFIED: grep found 0 class definitions]
- `MintErrorState` does NOT exist [VERIFIED: grep found 0 class definitions]
- Some screens use ad-hoc loading (e.g., `MintLoadingSkeleton` in `chiffre_choc_screen`) [VERIFIED]

**Implementation:** Create `MintLoadingState` and `MintErrorState` in `widgets/common/`, matching the API of `MintEmptyState` (icon + title + subtitle + optional CTA). Per UI-SPEC: `MintLoadingState` uses CircularProgressIndicator, `MintErrorState` uses Icons.error_outline with "Reessayer" CTA.

### Pattern 4: Magic Link Auth Flow

**What:** Backend generates a time-limited token, sends it via email, user clicks link to verify.

**Current state:** Backend has `/auth/register` (email+password+JWT) and `/auth/login` (email+password+JWT). No magic link endpoints exist. No email sending infrastructure. [VERIFIED: `auth.py` endpoints, `auth_service.dart`]

**Required new endpoints:**
- `POST /api/v1/auth/magic-link/send` -- takes email, generates token, sends email
- `POST /api/v1/auth/magic-link/verify` -- takes token, returns JWT

**Email delivery options:**
1. **Resend** (SaaS) -- simple API, good for transactional emails [ASSUMED]
2. **SendGrid** -- enterprise option [ASSUMED]
3. **SMTP direct** -- simplest for MVP, less deliverability [ASSUMED]

**Flutter side:** Deep link handler to intercept magic link URL and call verify endpoint.

### Anti-Patterns to Avoid

- **Inline computation in navigation screens**: `intent_screen._onChipTap()` currently does too much (compute premier eclairage, seed CapMemory, build payload). In the new flow, intent_screen should ONLY store the intent and navigate forward. Computation happens in `quick_start_screen` -> `chiffre_choc_screen`.
- **Skipping screens in the pipeline**: Never `context.go('/home')` from mid-pipeline. Each screen must exit to the next screen in sequence.
- **Mutating CoachProfileProvider mid-flow**: Only update the profile at the END of the pipeline (after plan generation), not during intermediate screens.
- **Hardcoded loading indicators**: Always use `MintLoadingState`, never inline `CircularProgressIndicator`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Email delivery for magic link | Custom SMTP client | Resend / SendGrid API | Deliverability, bounce handling, rate limiting |
| Apple Sign-In | Custom OAuth flow | `sign_in_with_apple` package | Apple's specific requirements (nonce, identity token format) |
| Token generation | Custom random strings | `secrets.token_urlsafe()` (Python) | Cryptographic randomness, standard practice |
| Deep link handling | Custom URL scheme parsing | `app_links` / `uni_links` package | Platform-specific deep link registration |
| Loading/error state widgets | Per-screen ad-hoc states | `MintLoadingState` / `MintErrorState` | Consistency, single change point |

## Common Pitfalls

### Pitfall 1: Intent Screen Dual Behavior
**What goes wrong:** `intent_screen.dart` currently computes premier eclairage AND navigates to home in a single `_onChipTap`. Changing it to navigate to `quick_start_screen` instead will break the existing behavior for users who skip quick_start.
**Why it happens:** The screen was designed as a standalone onboarding shortcut, not as step 1 of a pipeline.
**How to avoid:** Keep the old behavior behind a flag or route parameter. If `intent_screen` is reached from the golden path (post-auth), it navigates to `quick_start_screen`. If reached from elsewhere, it preserves current behavior.
**Warning signs:** Existing tests in `firstjob_journey_test.dart` break after refactoring.

### Pitfall 2: Quick Start Screen Already Navigates to /home
**What goes wrong:** `quick_start_screen.dart` currently saves profile and navigates to `/home?tab=0` (line 276). In the new flow, it must navigate to `/onboarding/chiffre-choc` instead.
**Why it happens:** The screen was built as the final onboarding step, not a mid-pipeline step.
**How to avoid:** Add a route parameter or extra flag (`fromGoldenPath: true`) that controls the exit destination. Or refactor to always exit to chiffre-choc during onboarding, and use a different route for profile editing.
**Warning signs:** User completes quick_start and lands on home instead of seeing premier eclairage.

### Pitfall 3: hasCompletedOnboarding Flag Ambiguity
**What goes wrong:** The codebase uses `ReportPersistenceService.isMiniOnboardingCompleted()` to check onboarding status. But this flag is set in `intent_screen._onChipTap()` (line 177), BEFORE the user reaches quick_start or chiffre_choc. So a user who taps an intent chip but abandons the flow will appear "onboarded" on next launch.
**Why it happens:** The flag was designed for the old flow where intent_screen WAS the final onboarding step.
**How to avoid:** Move the `setMiniOnboardingCompleted(true)` call to the END of the pipeline (after plan generation or check-in), not intent_screen.
**Warning signs:** Abandoned users skip to home on relaunch.

### Pitfall 4: Chiffre Choc Screen Data Dependencies
**What goes wrong:** `chiffre_choc_screen.dart` reads data from `GoRouterState.of(context).extra` (line 79). If the extra map is null or missing keys, it redirects to `/onboarding/intent` (line 82). This means ANY navigation error in the pipeline will bounce the user back to intent.
**Why it happens:** Defensive fallback designed for direct deep-link access.
**How to avoid:** Ensure `quick_start_screen` always passes the correct extra map when navigating to chiffre-choc. Add an assertion in tests.
**Warning signs:** User bounces back to intent screen after completing quick_start.

### Pitfall 5: Regional Voice Not in 4-Layer Format
**What goes wrong:** The coach system prompt in `claude_coach_service.py` has regional voice markers (REGIONAL_MAP for VD: "Ironie seche, detendu") but does NOT explicitly structure responses as 4-layer insight engine output (factual extraction -> human translation -> personal perspective -> questions to ask).
**Why it happens:** The 4-layer engine is defined in `docs/MINT_IDENTITY.md` but not yet wired into the system prompt template.
**How to avoid:** Add explicit 4-layer formatting instructions to the system prompt when generating premier eclairage for onboarding.
**Warning signs:** Coach responds in free-form instead of structured 4-layer format.

### Pitfall 6: Magic Link Deep Link on iOS vs Android
**What goes wrong:** iOS requires Associated Domains entitlement + apple-app-site-association file. Android requires intent filters + assetlinks.json. Missing either breaks magic link on that platform.
**Why it happens:** Deep links are platform-specific and require server-side configuration.
**How to avoid:** Configure deep links for BOTH platforms. Use `flutter_app_links` or similar. Test on both simulators.
**Warning signs:** Magic link works in browser but doesn't open the app.

## Code Examples

### Existing RegionalVoiceService Usage (verified pattern)
```dart
// Source: apps/mobile/lib/services/voice/regional_voice_service.dart
// Already exists -- forCanton maps VD to romande region
final flavor = RegionalVoiceService.forCanton('VD');
// flavor.promptAddition contains VD-specific system prompt text
// flavor.localExpressions includes "septante", "nonante", etc.
```
[VERIFIED: `regional_voice_service.dart` exists with SwissRegion enum and RegionalFlavor class]

### Existing Backend Premier Eclairage Endpoint
```python
# Source: services/backend/app/api/v1/endpoints/onboarding.py
# POST /api/v1/onboarding/minimal-profile
# Input: age, gross_salary, canton (+ optional enrichment fields)
# Output: MinimalProfileResponse with financial snapshot
```
[VERIFIED: `onboarding.py` lines 59-60]

### Existing Coach System Prompt Regional Map
```python
# Source: services/backend/app/services/coach/claude_coach_service.py
REGIONAL_MAP = {
    "VD": "Tu es de Vaud. Ironie seche, detendu. Expressions : 'ouais bon', 'c'est pas faux'. Comparaisons avec les prix a Morges, le Flon, le TL.",
    # ...
}
```
[VERIFIED: `claude_coach_service.py` lines 58-65]

### GoRouter Extra Pattern (existing)
```dart
// Source: apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart
final extra = GoRouterState.of(context).extra;
if (extra is! Map<String, dynamic>) {
  if (mounted) context.go('/onboarding/intent');
  return;
}
final age = extra['age'] as int? ?? 35;
final grossSalary = (extra['grossSalary'] as num?)?.toDouble() ?? 80000;
final canton = extra['canton'] as String? ?? 'ZH';
```
[VERIFIED: `chiffre_choc_screen.dart` lines 79-89]

### Integration Test Pattern (from existing journeys)
```dart
// Source: apps/mobile/test/journeys/firstjob_journey_test.dart
// Service-level integration tests -- not widget E2E
// Uses: IntentRouter.forChipKey(), ChiffreChocSelector.select(), CapSequenceEngine.build()
// Mocks: SharedPreferences.setMockInitialValues({})
// Asserts: mapping != null, choc.value > 0, sequence steps correct
```
[VERIFIED: `firstjob_journey_test.dart` exists with this pattern]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `chiffre_choc` (legacy term) | `premier_eclairage` | 2026-04-05 (MINT_IDENTITY.md) | All new code must use `premier_eclairage` -- existing `chiffre_choc_screen.dart` filename is kept for backward compat but new strings use the new term |
| Slider inputs | CupertinoPicker / tap-to-type | CLAUDE.md feedback | `quick_start_screen` still uses `MintPremiumSlider` import -- must be replaced with CupertinoPicker |
| Intent -> home directly | Intent -> quick_start -> chiffre_choc -> plan -> coach | Phase 1 | Current `intent_screen._onChipTap` must be refactored |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Magic link can be self-hosted using existing JWT infrastructure + email sending service (Resend/SendGrid) | Architecture Patterns / Pattern 4 | If the project uses Firebase Auth or Supabase, the approach differs significantly |
| A2 | `sign_in_with_apple` is the correct Flutter package for Apple Sign-In | Standard Stack | Low risk -- this is the standard package, but version should be verified before implementation |
| A3 | Deep link handling for magic link requires `app_links` or `uni_links` package | Don't Hand-Roll | If the app already has deep link handling configured, a new package may not be needed |
| A4 | Email sending service is not yet configured in the backend | Architecture Patterns | If there's already an email service (for verification emails), it can be reused |
| A5 | The plan generation screen (Screen 6 in UI-SPEC) does not exist yet and must be created | Architecture Patterns | If a similar screen exists, it may only need adaptation |

## Open Questions (RESOLVED)

1. **Email sending infrastructure** -- RESOLVED
   - Decision: Use **Resend** as email sending service. No existing email sending code found in codebase (email_verified field exists on User model but no sending mechanism). Resend is the simplest option for transactional magic link emails.
   - Implementation: Plan 01-02 Task 1 creates `magic_link_service.py` with Resend API integration. If `RESEND_API_KEY` is not set, service logs warning and skips email send (dev mode fallback). User setup documented in Plan 01-02 frontmatter.

2. **Apple Sign-In entitlements** -- RESOLVED
   - Decision: Apple Sign-In is implemented in **Plan 01-05** (Wave 2, depends on Plan 01-02). It is NOT deferred -- it is a locked PATH-02 requirement.
   - Implementation: Plan 01-05 adds `sign_in_with_apple` package, configures iOS entitlements, creates `AppleSignInService`, adds backend `/auth/apple/verify` endpoint. Includes a `checkpoint:human-verify` task for iOS testing since Apple Sign-In requires real device/simulator with Apple ID.
   - User setup: Apple Developer account must have "Sign in with Apple" capability enabled on the App ID.

3. **Plan generation screen** -- RESOLVED
   - Decision: **Locally-generated plan card list** based on firstJob intent. The screen does NOT call a dedicated backend endpoint for plan generation -- it uses a hardcoded checklist structure per intent type.
   - Rationale: Backend `/api/v1/first-job/checklist` may or may not exist; generating plan steps locally (per Claude's discretion in CONTEXT.md) avoids a backend dependency. If the endpoint exists, the executor may use it instead.
   - Implementation: Plan 01-03 Task 2 creates `plan_screen.dart` with locally-defined step cards for firstJob: "Comprendre ton premier salaire", "Configurer ton 3a", "Verifier ta couverture assurance", "Connaitre tes droits AVS".

4. **4-layer insight engine implementation** -- RESOLVED
   - Decision: 4-layer structure is a **behind-the-scenes prompt instruction**, NOT visible to the user as labeled sections. The coach presents 4-layer content as **natural narrative** -- the user experiences a flowing response, not "Layer 1: ..., Layer 2: ...".
   - Rationale: Per MINT voice system (calme, precis, fin, rassurant), labeled sections feel clinical. Natural narrative matches the intimate, conversational tone.
   - Implementation: Plan 01-03 Task 2 adds 4-layer formatting instructions to `claude_coach_service.py` system prompt with explicit "Present as natural narrative, NOT as labeled sections" directive.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) + pytest 8.x |
| Config file | `apps/mobile/pubspec.yaml` (Flutter) / `services/backend/pytest.ini` or inline |
| Quick run command | `cd apps/mobile && flutter test test/journeys/` |
| Full suite command | `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PATH-01 | Full golden path completion | integration | `flutter test test/journeys/lea_golden_path_test.dart` | Wave 0 |
| PATH-02 | Magic link + Apple + password auth | unit | `flutter test test/auth/magic_link_test.dart` | Wave 0 |
| PATH-03 | 3 inputs collected, premier eclairage within 5min | unit + timing | `flutter test test/services/onboarding_edge_cases_test.dart` | Partial (exists but needs Lea scenario) |
| PATH-04 | VD regional voice + 4-layer engine | unit | `pytest tests/test_coach_firstjob.py` | Wave 0 |
| PATH-05 | Loading/error/empty states on all screens | widget | `flutter test test/widgets/state_widgets_test.dart` | Wave 0 |
| PATH-06 | Integration test fails CI if chain breaks | integration | `flutter test test/journeys/lea_golden_path_test.dart` | Wave 0 (same as PATH-01) |

### Sampling Rate
- **Per task commit:** `flutter test test/journeys/ && flutter analyze`
- **Per wave merge:** Full suite: `flutter test && python3 -m pytest tests/ -q`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/journeys/lea_golden_path_test.dart` -- covers PATH-01, PATH-06
- [ ] `test/auth/magic_link_test.dart` -- covers PATH-02
- [ ] `test/widgets/state_widgets_test.dart` -- covers PATH-05 (MintLoadingState, MintErrorState)
- [ ] `tests/test_coach_firstjob.py` (backend) -- covers PATH-04 (4-layer engine + VD voice + firstJob context)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Magic link token expiry (15min), rate limiting (5/min on send), JWT with refresh tokens via `AuthService` |
| V3 Session Management | yes | Existing JWT + flutter_secure_storage (Keychain/Keystore) -- no changes needed |
| V4 Access Control | no | Onboarding is pre-auth or immediately post-auth -- no role-based access |
| V5 Input Validation | yes | Age 18-99, salary > 0, canton from fixed enum -- validated client-side + Pydantic v2 server-side |
| V6 Cryptography | yes | Magic link token must use `secrets.token_urlsafe()` (Python stdlib) -- never hand-roll |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Magic link token brute force | Tampering | Rate limit `/auth/magic-link/verify` (5/min), token >= 32 bytes, single-use |
| Magic link interception (email) | Information Disclosure | Token expires in 15 min, HTTPS only, single-use invalidation |
| Onboarding data injection | Tampering | Pydantic v2 validation on backend, client-side range checks |
| Apple Sign-In nonce replay | Spoofing | Use `sign_in_with_apple` which handles nonce generation |

## Sources

### Primary (HIGH confidence)
- Codebase grep: `intent_screen.dart`, `quick_start_screen.dart`, `chiffre_choc_screen.dart`, `promise_screen.dart` -- all screen files read and analyzed
- Codebase grep: `auth_provider.dart`, `auth_service.dart`, `auth.py` -- auth system fully mapped
- Codebase grep: `regional_voice_service.dart`, `claude_coach_service.py` -- coach voice system verified
- Codebase grep: `onboarding.py` -- backend onboarding endpoints verified
- Codebase grep: `app.dart` -- GoRouter routes fully mapped (lines 153-907)
- Codebase grep: `firstjob_journey_test.dart` -- existing integration test pattern verified

### Secondary (MEDIUM confidence)
- `01-UI-SPEC.md` -- UI design contract for Phase 1 (already approved per STATE.md)
- `01-CONTEXT.md` -- user decisions from discuss phase

### Tertiary (LOW confidence)
- Magic link implementation details (A1) -- based on standard JWT patterns, not verified against project-specific auth architecture
- Apple Sign-In package recommendation (A2) -- standard Flutter package, version not checked

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all verified from codebase and CLI tools
- Architecture: HIGH -- all screens, routes, and services read from source code
- Pitfalls: HIGH -- identified from actual code analysis (navigation exits, flag timing, data dependencies)
- Magic link auth: MEDIUM -- net-new feature, implementation approach is standard but not verified against project constraints

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable -- existing codebase, no fast-moving dependencies)
