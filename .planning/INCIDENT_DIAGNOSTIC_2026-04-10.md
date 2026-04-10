# MINT Incident Diagnostic — 2026-04-10

## Context
After 24h of agent-driven changes, MINT is in a degraded state. 7 deep audit agents traced every code path end-to-end. This document is the input for the GSD recovery project.

## INCIDENT 1 — Coach AI is silent (P0)

**Root cause**: Flutter calls `/api/v1/rag/query` (BYOK-only, no server-key fallback). The backend endpoint `/api/v1/coach/chat` HAS server-side `ANTHROPIC_API_KEY` fallback but Flutter NEVER calls it.

**Chain**:
- SLM (Gemma 3n): `slmPluginReady=false` by default → skipped on most devices
- BYOK: Only activates if user entered their own API key in settings
- Fallback: Static template "Coach indisponible"
- Result: Without BYOK key configured → no AI, just templates

**Files**:
- `apps/mobile/lib/services/coach/coach_orchestrator.dart:221-223` — BYOK guard
- `apps/mobile/lib/services/rag_service.dart:197` — calls /rag/query only
- `services/backend/app/api/v1/endpoints/coach_chat.py:1100-1114` — has server-key fallback (never called)
- `services/backend/app/services/rag/llm_client.py:50` — rejects empty api_key

**Fix direction**: Either make Flutter call `/coach/chat` when no BYOK key, or add server-key fallback to `/rag/query`.

---

## INCIDENT 2 — Auth is a facade (P0)

### 2a. Logout doesn't logout
- `widgets/profile_drawer.dart:141` — does `context.go('/')` WITHOUT calling `AuthProvider.logout()`
- Tokens, conversations, BYOK keys all persist after "logout"
- `AuthProvider.logout()` exists (line 420) and properly purges everything — just never called

### 2b. checkAuth() never called on cold start
- `auth_provider.dart:93-121` — `checkAuth()` exists, restores token from SecureStorage
- NEVER called anywhere in the app (zero call sites found)
- On app restart: `_isLoggedIn = false` even with valid JWT in storage
- User appears logged out every time they restart the app

### 2c. Login hidden
- Only accessible via long-press on MINT wordmark (landing_screen.dart:98)
- No visible login button on landing screen
- Design choice (D-12) but effectively hides auth from users

---

## INCIDENT 3 — 12 dead routes (P1)

| Dead Route | Referenced In | Should Be |
|---|---|---|
| `/documents/capture` | action_opportunity_detector.dart:48 | `/scan` |
| `/profile/consent` | settings_sheet.dart:34, screen_registry.dart:1042, profile_drawer.dart:110 | create or → `/profile/privacy-control` |
| `/profile/data-transparency` | profile_drawer.dart:122 | create or remove |
| `/profile/privacy` | progress_milestone_detector.dart:63 | `/profile/privacy-control` |
| `/bilan-retraite` | intent_router.dart:45 | `/retraite` |
| `/prevoyance-overview` | intent_router.dart:51 | no equivalent |
| `/fiscalite-overview` | intent_router.dart:57 | `/fiscal` |
| `/achat-immobilier` | intent_router.dart:63 | `/hypotheque` |
| `/life-events` | intent_router.dart:69 | no equivalent |
| `/retirement/projection` | hero_stat_resolver.dart:64 | `/retraite` |
| `/onboarding/quick?section=profile` | 3 contextual services | query param lost in redirect |
| `/profile/bilan` (flat path) | app.dart:930 redirect | nested under /profile only |

---

## INCIDENT 4 — Financial calculations wrong (P0)

3 golden couple tests FAIL:

| Test | Expected | Actual | Delta |
|---|---|---|---|
| LPP Julien rente | 33'892 CHF/an | 45'954 CHF/an | +35.6% |
| LPP Lauren balance @65 | 153'000 CHF | 203'570 CHF | +33.1% |
| Taux remplacement couple | 65.5% | 44.75% | -31.7% |

**Root cause**: Bug in `lpp_calculator.dart` when `bonificationRateOverride` (CPE Plan Maxi 24%) is combined with `salaireAssureOverride`. Projected balances inflated ~35%, cascading to replacement rate via ForecasterService.

**What passes**: AVS (all), capital withdrawal tax, 3a tax savings, constants sanity check, FATCA blocking.

**File**: `apps/mobile/lib/services/financial_core/lpp_calculator.dart` lines 67-123

---

## INCIDENT 5 — Branch desync (P1)

- staging and dev are 674 commits ahead of main
- sync-branches workflow uses FF-only with soft-fail → divergence accumulates silently
- Last 9 commits (CI credential fixes for Fastlane Match) on feature/cso-security-fixes, not yet merged to dev

---

## SECONDARY FINDINGS

### Data / State
- Minimal profile auto-created (VD, 35yo, 0 income) for anonymous users → shadows real profile on login (P1)
- 3-6 orphan providers initialized but never consumed (P2)
- Feature flags not persisted to disk → reset on cold start (P2)
- Conversations local-only, no cloud backup (P2)

### Backend
- Reengagement consent in-memory only → lost on server restart (P1)
- ~35 endpoints (26%) without dedicated tests (P2)
- Coach narrative endpoints always return `used_fallback=True` (P1)

### Navigation
- safePop() used 30+ times — masks missing back stacks (P2)
- No tab bar, no home screen — everything redirects to /coach/chat (design choice)

### Financial
- Monte Carlo (1000 sims) functional but orphaned — called by 1 screen only (P2)
- Withdrawal sequencing, tornado sensitivity: complete but no UI (P2)

### UX
- Hardcoded French strings in tone chips ("Doux", "Direct", "Sans filtre") (P2)
- Inconsistent keyboard policy — no global unfocus wrapper (P2)

---

## WHAT WORKS (verified)

- AVS calculations (rente, couple, 13th, gaps, deferral) — all golden tests pass
- Capital withdrawal tax (progressive brackets, married discount) — pass
- Constants sync (Flutter ↔ backend, 2025/2026 values) — verified
- Confidence scorer (11 components, Bayesian, 86 usages) — well wired
- Design system (MintColors, MintTextStyles, MintSpacing) — 0 hardcoded colors
- i18n (5 languages, ARB files, majority of screens) — good
- Compliance guard (5 layers, PII scrubbing, disclaimer injection) — functional
- Token security (JWT in SecureStorage, BYOK in SecureStorage) — proper
- CI pipeline (7 workflows, accessibility/readability gates) — healthy

---

## COMPILATION STATE

- `flutter analyze`: 0 errors
- `flutter test`: 9256 pass, 11 fail, 6 skipped
- Backend tests: not run in this audit (Railway deployed)

---

## PROJECT GOAL

Recover MINT to a state where a real user can:
1. Open the app
2. Talk to an AI coach that actually responds with intelligence
3. Get correct financial insights
4. Navigate without hitting dead ends
5. Log in, log out, and have their state persist

Verification: Creator (Julien) cold-starts the app on his iPhone and walks through each flow.
