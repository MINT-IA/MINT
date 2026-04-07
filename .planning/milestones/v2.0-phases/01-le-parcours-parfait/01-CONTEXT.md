# Phase 1: Le Parcours Parfait - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

A new user (Léa: 22, VD, firstJob) flows from landing to first check-in prompt without friction, dead ends, or broken states. This phase wires the existing screens (auth, onboarding, chiffre_choc, coach) into a flawless golden path and adds missing states (loading, error, empty) plus an integration test covering the full journey.

Requirements: PATH-01, PATH-02, PATH-03, PATH-04, PATH-05, PATH-06

</domain>

<decisions>
## Implementation Decisions

### Auth Flow & Entry Point
- Landing entry point: refine existing `promise_screen.dart` as the landing page with value prop + CTA (no new screen)
- Auth method priority: magic link primary (email-only, zero password friction), Apple Sign-In secondary (iOS), email+password as fallback — per PATH-02
- Auth→onboarding transition: auto-redirect after auth success — check `hasCompletedOnboarding` flag in CoachProfileProvider → route to `intent_screen` or `home`
- Magic link delay handling: inline "Pas reçu ? Renvoyer" with 30s countdown timer, then reveal email+password fallback option

### Onboarding → Premier Éclairage Flow
- Screen sequence: `intent_screen` (life event selection) → `quick_start_screen` (age, revenu, canton) → `chiffre_choc_screen` (premier éclairage) — reuse existing 3 screens
- Input collection: single `quick_start_screen` with 3 modern inputs — CupertinoPicker for age, tap-to-type for revenu, canton dropdown — per feedback on modern inputs (no sliders)
- Premier éclairage generation: backend call with intent + 3 inputs → coach generates firstJob-specific insight using 4-layer engine (factual → human → personal → questions to ask)
- Post-premier éclairage: auto-navigate to plan generation (financial plan based on firstJob intent) → then check-in prompt as a coach message

### Coach & Testing
- VD regional voice: `RegionalVoiceService.forCanton('VD')` injects Romande voice into coach system prompt — existing pattern
- Check-in prompt: coach sends first message — biography-aware, ends with user-initiated action suggestion (e.g., "Tu veux qu'on regarde ton 3a ?") — never imperative
- Integration test: single `lea_golden_path_test.dart` covering mock auth → onboarding → premier éclairage → plan → check-in message
- Error/loading/empty states: standardized `MintLoadingState`, `MintErrorState` (retry button), `MintEmptyState` widgets applied to every screen in the path

### Claude's Discretion
- Exact premier éclairage content for firstJob intent (must pass 4-layer engine)
- Plan generation screen layout and content
- Specific error messages and empty state copy (in ARB files)
- Integration test mock strategy and assertion granularity

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `screens/onboarding/intent_screen.dart` — life event selection (exists, likely needs wiring refinement)
- `screens/onboarding/quick_start_screen.dart` — 3 inputs (exists, may need modern input upgrade)
- `screens/onboarding/chiffre_choc_screen.dart` — premier éclairage display (exists)
- `screens/onboarding/promise_screen.dart` — can serve as landing page
- `screens/auth/login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`, `verify_email_screen.dart` — auth flow exists
- `screens/main_tabs/mint_home_screen.dart` — Aujourd'hui tab (post-onboarding destination)
- `screens/main_tabs/mint_coach_tab.dart` — Coach tab (check-in destination)
- `providers/coach_profile_provider.dart` — superset model for all simulators and coach
- `services/regional_voice_service.dart` — canton-based voice injection (exists per CLAUDE.md)

### Established Patterns
- GoRouter for navigation (no Navigator.push)
- Provider for state management (CoachProfileProvider, AuthProvider, ProfileProvider)
- `context.read<T>()` before any await
- MintColors.* for all colors, Montserrat/Inter for fonts
- All user-facing strings via AppLocalizations (6 ARB files)

### Integration Points
- GoRouter routes: `/promise`, `/login`, `/register`, `/onboarding/intent`, `/onboarding/quick-start`, `/onboarding/chiffre-choc`, `/home`
- Auth state: `AuthProvider` guards routes, redirects unauthenticated users
- Backend: `/api/v1/coach/chat` for premier éclairage generation, `/api/v1/profile` for profile creation
- Coach system prompt: `claude_coach_service.py` with REGIONAL IDENTITY section

</code_context>

<specifics>
## Specific Ideas

- Léa persona: 22 years old, canton VD, firstJob intent — this is the canonical test persona for Phase 1
- The path must complete within 5 minutes total (PATH-03)
- VD regional voice must use "septante/nonante" and pragmatic, détendu tone
- Coach 4-layer engine: (1) Factual extraction → (2) Human translation → (3) Personal perspective → (4) Questions to ask before signing
- Every screen must handle loading, error, and empty states gracefully — no blank screens, no unhandled exceptions (PATH-05)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
