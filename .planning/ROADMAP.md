# Roadmap: MINT Recovery

**Created:** 2026-04-10
**Core Value:** A real user can cold-start MINT, talk to AI coach, get correct insights, navigate without dead ends.
**Phases:** 8 (fine-grained, sequential)
**Execution:** Sequential (one plan at a time)
**Verification:** Device gate after each phase (flutter run --release on iPhone)

## Phase Overview

| Phase | Goal | Requirements | Depends on |
|-------|------|-------------|------------|
| 1 | Unblock CI/CD pipeline | INFRA-01, INFRA-02, INFRA-03 | — |
| 2 | Fix financial calculations | CALC-01..05 | — |
| 3 | Fix authentication | AUTH-01..04 | — |
| 4 | Wire coach AI to server key | COACH-01..04 | Phase 1 (needs working CI) |
| 5 | Fix dead routes (services) | NAV-01..05 | — |
| 6 | Fix dead routes (UI) | NAV-06..08 | Phase 5 |
| 7 | Device walkthrough gate | GATE-01..05 | Phase 1-6 |
| 8 | Commit uncommitted changes + cleanup | — | Phase 7 |

---

## Phase 1: Unblock CI/CD Pipeline

**Goal:** Get dev and staging branches green. TestFlight builds again.

**Why first:** Nothing can ship until CI works. The 9 credential fix commits on feature/cso-security-fixes need to reach dev/staging.

**Requirements:** INFRA-01, INFRA-02, INFRA-03

**Success criteria:**
- [ ] feature/cso-security-fixes PR merged to dev
- [ ] dev CI passes (flutter analyze + test + pytest)
- [ ] dev merged to staging
- [ ] staging CI passes
- [ ] TestFlight build triggered and succeeds
- [ ] staging → main sync initiated (resolve 674-commit divergence)

**Verification:** GitHub Actions green on dev and staging. TestFlight build in App Store Connect.

---

## Phase 2: Fix Financial Calculations

**Goal:** Golden couple Julien+Lauren — all 19 tests pass. LPP projections correct.

**Why second:** The core value proposition of MINT is financial insights. If the numbers are wrong, nothing else matters. This phase is independent of CI.

**Requirements:** CALC-01, CALC-02, CALC-03, CALC-04, CALC-05

**Success criteria:**
- [ ] Root cause identified in lpp_calculator.dart:67-123 (bonificationRateOverride + salaireAssureOverride interaction)
- [ ] Fix applied — LPP projection for CPE Plan Maxi yields correct values
- [ ] Test 2a: Julien LPP rente = ~33'892 CHF/an (±2%)
- [ ] Test 2b: Lauren LPP balance @65 = ~153'000 CHF (±5%)
- [ ] Test 4: Taux remplacement couple = ~65.5% (±2%)
- [ ] All 19 golden couple tests pass
- [ ] flutter test completes with 0 failures (currently 11)

**Verification:** `flutter test test/golden/golden_couple_validation_test.dart` — 19/19 pass.

---

## Phase 3: Fix Authentication

**Goal:** Login visible, logout purges data, auth state persists across restarts.

**Why:** Users can't trust an app where logout doesn't work and login is hidden.

**Requirements:** AUTH-01, AUTH-02, AUTH-03, AUTH-04

**Success criteria:**
- [ ] Landing screen has a visible, discoverable login entry point
- [ ] profile_drawer.dart logout calls AuthProvider.logout() before navigating
- [ ] AuthProvider.logout() purges: tokens, conversations, BYOK keys, coach memory, analytics
- [ ] main.dart or app.dart calls checkAuth() at startup to restore JWT from SecureStorage
- [ ] Route guard (GoRouter redirect) correctly reads restored auth state
- [ ] After login → restart app → user is still logged in
- [ ] After logout → tokens gone, BYOK keys gone, conversations gone

**Verification:** Manual test sequence: login → restart → still logged in → logout → restart → logged out, no data from previous session.

---

## Phase 4: Wire Coach AI to Server Key

**Goal:** User without BYOK key gets real AI responses via server-side Anthropic key.

**Why:** This is the #1 user-facing broken feature. Without this, the coach is a static template machine.

**Requirements:** COACH-01, COACH-02, COACH-03, COACH-04
**Depends on:** Phase 1 (need CI to deploy backend changes if any)

**Success criteria:**
- [ ] Flutter orchestrator has a "server-key" tier between BYOK and fallback
- [ ] When no BYOK key: Flutter calls /api/v1/coach/chat (which has ANTHROPIC_API_KEY fallback)
- [ ] OR: /api/v1/rag/query modified to accept empty api_key and use server key
- [ ] Response includes: text + sources + disclaimers + tool_calls
- [ ] ComplianceGuard validates server-key responses same as BYOK
- [ ] Coach system prompt covers all 18 life events, not just retirement
- [ ] Backend coach narrative endpoints return generated content (not always used_fallback=True)

**Verification:** Open app without BYOK key configured → type "Comment optimiser mon 3e pilier ?" → get real AI response with sources and disclaimer. Then "Je vais acheter un appartement" → get real response about housing. Not templates.

---

## Phase 5: Fix Dead Routes (Services)

**Goal:** All routes emitted by backend services and contextual engines exist in app.dart.

**Why:** These are invisible — the app looks fine until a contextual card or intent chip sends you to a dead route.

**Requirements:** NAV-01, NAV-02, NAV-03, NAV-04, NAV-05

**Success criteria:**
- [ ] intent_router.dart: /bilan-retraite → /retraite, /fiscalite-overview → /fiscal, /achat-immobilier → /hypotheque, /prevoyance-overview → valid route or removed, /life-events → valid route or removed
- [ ] action_opportunity_detector.dart: /documents/capture → /scan
- [ ] progress_milestone_detector.dart: /profile/privacy → /profile/privacy-control
- [ ] hero_stat_resolver.dart: /retirement/projection → /retraite
- [ ] /onboarding/quick?section=profile → proper redirect that preserves intent (e.g., /coach/chat?prompt=profile or /data-block/revenu)
- [ ] Grep for all dead routes returns 0 matches

**Verification:** `grep -rn '/bilan-retraite\|/prevoyance-overview\|/fiscalite-overview\|/achat-immobilier\|/life-events\|/documents/capture\|/profile/privacy[^-]\|/retirement/projection' apps/mobile/lib/` returns nothing.

---

## Phase 6: Fix Dead Routes (UI)

**Goal:** Profile drawer and settings sheet — every menu item leads somewhere real.

**Why:** These are visible — user taps a menu item and gets "Page introuvable" or nothing happens.

**Requirements:** NAV-06, NAV-07, NAV-08
**Depends on:** Phase 5

**Success criteria:**
- [ ] profile_drawer.dart: /profile/consent either created as route or redirected to /profile/privacy-control
- [ ] profile_drawer.dart: /profile/data-transparency either created as route or removed from drawer
- [ ] settings_sheet.dart: /profile/consent fixed (same as drawer)
- [ ] screen_registry.dart: no entries for non-existent routes
- [ ] Every menu item in profile drawer navigates to a real screen

**Verification:** Open profile drawer, tap every single item — none leads to error or no-op.

---

## Phase 7: Device Walkthrough Gate

**Goal:** Creator (Julien) cold-starts app on iPhone and walks through every core flow.

**Why:** This is the only gate that matters. 9256 tests + audit ≠ app works. Device proves it.

**Requirements:** GATE-01, GATE-02, GATE-03, GATE-04, GATE-05
**Depends on:** Phase 1-6 all complete

**Success criteria:**
- [ ] `flutter run --release -d <iphone>` builds and installs successfully
- [ ] Cold start: landing screen loads, CTA visible
- [ ] Tap CTA → coach opens
- [ ] Type message → get AI response (not template), with sources
- [ ] Open profile drawer → tap each item → all navigate to real screens
- [ ] Login → restart app → still logged in
- [ ] Logout → all data cleared → back to landing
- [ ] Type financial question → get correct numbers (not inflated LPP)

**Verification:** Julien annotated screenshots or verbal confirmation of each checkpoint.

---

## Phase 8: Commit & Cleanup

**Goal:** All uncommitted changes properly committed, branch merged, clean state.

**Why:** There are 39 uncommitted files (safePop additions) plus all recovery fixes. Need clean git history.

**Success criteria:**
- [ ] All recovery fixes committed with clear messages
- [ ] safePop uncommitted changes reviewed and committed (or reverted if superseded)
- [ ] feature branch merged to dev via PR
- [ ] dev CI green
- [ ] No leftover debug code, no temporary hacks

**Verification:** `git status` clean, dev CI green, PR approved.

---

## Risk Register

| Risk | Mitigation |
|------|-----------|
| Coach wiring requires backend changes that break staging | Test on dev first, verify /health endpoint before merge |
| LPP fix cascades to other calculators | Run full test suite after fix, not just golden couple |
| Auth changes break existing login flows (magic link, Apple Sign-In) | Test each auth method individually |
| Route fixes break tests that reference old routes | Update tests alongside route fixes |
| Device gate reveals new issues not caught by audit | Budget Phase 7 for iteration, not just checkbox |

---
*Roadmap created: 2026-04-10*
*Last updated: 2026-04-10 after initialization*
