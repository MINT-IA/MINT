# Phase 10: L1.8 Onboarding v2 - SUMMARY

**Completed:** 2026-04-08
**Status:** GREEN — 6/6 ROADMAP success criteria met, fully closed

## Plans
| # | Plan | Commits | Outcome |
|---|---|---|---|
| 10-01 | Pre-deletion audit | 1 | 5 MIGRATE / 2 DROP verdict, conditional GO with 2 mechanical extras |
| 10-02 | Delete + rewire + migrate (split into a/b/c) | 11 | -2348 LOC removed, redirect shim resolution, both contracts honored |
| 10-03 | E2E test + Flesch-Kincaid + jargon widget | 3 | E2E passes, FK gate B1 PASS, JargonText 4 tests green |
| 10-04 | Post-audit + GoRouter health | 2 | All 6 SC green, +4 tests net, -1 failure, audit ✅ |

**Total:** 17 execution commits + 1 PNG cleanup = 18 commits.

## Plan 10-02 split rationale
The original Plan 10-02 was rejected by the executor as "context-heavy, multi-hour, NON-NEGOTIABLE compile-clean intermediate states required". Split into 3 sub-plans by orchestrator:
- **10-02a** (rewire): intent_screen → /coach/chat + context_injector cleanup + coach_chat onboarding-done flag — 4 commits
- **10-02b** (delete screens): 5 screens deleted, redirect shim added for `/onboarding/quick`, premier_eclairage_card CTA fixed — 5 commits
- **10-02c** (delete provider): OnboardingProvider removed from MultiProvider + source deleted — 2 commits + 1 PNG cleanup

## Critical decisions locked mid-execution
1. **Navigation target = `/coach/chat`** (not `/home?tab=0`). Required rewriting 2 existing intent_screen tests.
2. **`setMiniOnboardingCompleted` ownership = `coach_chat_screen.dart`** (chat bootstrap), not intent_screen. The flag fires only on first chat entry from `_isFromOnboarding=true` payload — conversation is the only honest "onboarding done" signal.
3. **`/onboarding/quick` redirect shim** instead of migrating 14 call sites. Pure GoRouter redirect to `/coach/chat`. 8 lines of code, ships immediately, doctrine-compatible (chat IS the data entry).
4. **`premier_eclairage_card.dart:137` direct route** (not via shim) to `/coach/chat?source=premier_eclairage_intent` for semantic clarity.

## Key outcomes
- **5 screens deleted** (~2348 LOC): quick_start, premier_eclairage, instant_premier_eclairage, promise, plan
- **OnboardingProvider deleted** (220 LOC + co-located test 119 LOC)
- **State migrated:** birthYear/grossSalary/canton → CoachProfileProvider; chocType/chocValue → ReportPersistenceService; anxietyLevel + emotion DROPPED
- **Routes:** `/onboarding/quick` redirects to `/coach/chat`, all other deleted routes return 404 cleanly
- **GoRouter health test** verifies the new topology
- **Flesch-Kincaid CI gate** (Kandel-Moles French formula) ensures onboarding ARB strings stay at B1 level
- **JargonText widget** for tap-to-define on financial terms (LPP, AVS, etc.)
- **E2E integration test** validates the 2-screen golden path: landing → intent (1 chip) → /coach/chat in <20s

## Deviations
1. **10-02 split into 3 plans** mid-execution to avoid context exhaustion
2. **Redirect shim** not in the original plan — added to resolve `/onboarding/quick`'s 14+ live consumers without scope creep
3. **Kandel-Moles French FK formula** chosen over classic Flesch (mis-calibrated for French)
4. **FK prefix scope narrowed** to `intentScreen,intentChip,landingV2` (excludes legacy keys from deleted screens)
5. **JargonText reuses existing `glossary_service.dart`** instead of duplicating definitions
6. **Integration test uses stub `_CoachChatStub`** instead of full MintApp boot to avoid Claude/RAG flakiness
7. **4 golden screenshot failure PNGs** accidentally committed in 10-02c, cleaned up in commit `3bb0905f`

## Gate results (Phase 10 close)
- `flutter analyze lib/` 0 errors
- `flutter test` full suite: 9296 passed (+4 vs Phase 9 close), 10 failed (3 baseline allowlist + 7 unrelated pre-existing, 1 fewer than pre-Phase-10), 6 skipped
- `tools/checks/flesch_kincaid_fr.dart` PASS (4/4 scoreable strings ≥ B1)
- GoRouter health test 9/9 green
- E2E integration test 1/1 green
- Audit C3 verdict: PASS (post 9296 ≥ pre 9292)
- `git grep` for deleted symbols: zero executable references

## Branch state
`feature/v2.2-p0a-code-unblockers` — 122 commits ahead of dev.

## What Phase 10 unblocks
- **Phase 10.5** (Friction pass): the new 2-screen golden path is now testable on real Galaxy A14 — **T4 user touch arrives next**
- **Phase 11** (Krippendorff): unrelated, can run in parallel
- **Phase 12** (Ship gate): the user-facing UX is now coherent end-to-end

## Next
**Phase 10.5: Friction Pass** — Galaxy A14 walkthrough by Julien. **First real device user touch (T4).** Will require ~30 min of walkthrough + notes.
