# Plan 12-05 — Deferred Gate Failures (RESOLVED 2026-04-07)

> **Status: RESOLVED.** Gate 2 (`flutter test (full suite)`) is GREEN.
> Final count: `+9326 ~8 -0` on branch `feature/v2.2-p0a-code-unblockers`.

## Gate 2 — `flutter test (full suite)`

- **Status:** GREEN (RESOLVED)
- **Resolved by:** Hotfix dispatch 2026-04-07 (this doc)
- **Baseline before fix (2026-04-07):** `+9309 ~6 -21` — 21 failures
- **Final after fix (2026-04-07):** `+9326 ~8 -0` — 0 failures, 8 skipped

### Delta accounting

| Source | Delta | Note |
|---|---|---|
| Intent screen tests fixed | +9 | Phase 8c chip deletions + Phase 12 copy drift + Phase 12-01 Ton chooser modal blocking persistence |
| Landing v1 tests migrated to v2 | +5 | widget_test (×1) + core_app_screens_smoke (×4) — Phase 7 rebuilt LandingScreen |
| Coach chat copy drift | +2 | Phase 12 silent opener + coachInputHint rewrites |
| Landing goldens | +1 / −2 | Rewrote to a single Phase-7 top-of-page golden; deleted stale `landing_quick_calc.png` + `landing_bottom.png` (v1 scroll structure gone) |
| Patrol tests | −2 in `+`, +2 in `~` | `LateInitializationError` in `app.main()` under widget-test binding — explicitly skipped with `skip: true` (QA-04/QA-05 owns emulator-run path) |
| **Net** | `+15` in passing count, `+2` in skipped count | No silent drops. |

### Fix commits (branch `feature/v2.2-p0a-code-unblockers`)

1. `3392abb7` — `fix(p10-hotfix): migrate intent/landing/coach tests to Phase 7+8c+12 copy`
2. `a40669a3` — `fix(p10-hotfix): regen landing golden (Phase 7 v2) + skip patrol tests`
3. `<this commit>` — `docs(p10-hotfix): mark gate 2 deferred as RESOLVED`

### Files touched (all test-side, NO production code modified)

- `apps/mobile/test/screens/onboarding/intent_screen_test.dart`
- `apps/mobile/test/screens/coach/coach_chat_test.dart`
- `apps/mobile/test/screens/core_app_screens_smoke_test.dart`
- `apps/mobile/test/widget_test.dart`
- `apps/mobile/test/golden_screenshots/landing_screen_golden_test.dart`
- `apps/mobile/test/golden_screenshots/goldens/landing_top.png` (regenerated)
- `apps/mobile/test/golden_screenshots/goldens/landing_bottom.png` (deleted)
- `apps/mobile/test/golden_screenshots/goldens/landing_quick_calc.png` (deleted)
- `apps/mobile/test/patrol/onboarding_patrol_test.dart`
- `apps/mobile/test/patrol/document_patrol_test.dart`

### Root-cause families (all resolved)

- **Landing family** → Phase 7 (L1.7 Landing v2) rebuilt LandingScreen as a
  single calm promise surface: wordmark + paragraphe-mère (`landingV2Paragraph`)
  + CTA (`landingV2Cta` = "Continuer (sans compte)") + privacy micro-phrase
  (`landingV2Privacy`) + legal footer. No trust bar, no `SingleChildScrollView`,
  no "Commencer" / no "Se connecter" (login is now a long-press on the MINT
  wordmark per D-12 hidden affordance). Tests were still asserting on the
  v1 copy/structure.
- **Intent screen family** → Two drifts stacked:
  1. Phase 8c hot-fix deleted 3 anti-shame chips (covered by existing test
     fixtures) and Phase 12 rewrote the Fiscalite chip copy ("bêtement" →
     "Mes impôts, j'aimerais y voir clair").
  2. Phase 12-01 added a first-launch Ton chooser modal sheet inside
     `_onChipTap` that fires BEFORE persistence/navigation. Under the test
     binding this modal has no dismiss actor, so `ReportPersistenceService`
     was never written and the screen never navigated. Tests now pre-set
     `ton_chooser_first_launch_done = true` in `SharedPreferences` mock so
     the sheet is skipped and the persist+nav path is exercised.
- **Coach chat family** → Phase 12 rewrote `coachSilentOpenerQuestion`
  ("Mint est là quand tu veux en parler." — lowercase `t`, not "Tu veux")
  and `coachInputHint` ("Dis-moi ce qui te trotte dans la tête." — no more
  "question sur tes finances"). Tests updated to the post-Phase-12 copy.
- **Patrol family** → `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
  at module load time plus `app.main()` inside the test body throws
  `LateInitializationError` under the widget-test binding — this is a
  structural issue with running integration tests through `flutter test`
  instead of `patrol test`. The file headers already documented that they
  need emulator infra (QA-04/QA-05). Explicitly `skip: true` with a reason
  comment; they remain in the tree ready for `patrol test` CI runs.

## Production code — untouched

No file under `apps/mobile/lib/` or `services/backend/app/` was modified by
this hotfix dispatch. All 21 failures were test-side contract drift against
Phases 7, 8c, and 12 — not product regressions.

## Resolution criteria (met)

- [x] Zero `-` failures in `flutter test`
- [x] Skipped count increase (6 → 8) has explicit `skip: true` + reason
- [x] No silently dropped tests (every delta accounted for above)
- [x] Gate 2 reports `SHIP READY (code side)`
