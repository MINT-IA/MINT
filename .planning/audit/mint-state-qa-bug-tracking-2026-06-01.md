# MINT QA and Bug Tracking — 2026-06-01

TL;DR: the right approach is not one huge "run everything" pass. The optimized workflow is cyclic: clean generated artifacts, run fast mechanical gates, run targeted regression suites for the touched truth paths, run the full suite to discover wider debt, classify failures into deterministic bugs vs. harness/golden drift, then rerun only the failing slices. This pass found the current salvage/profile patch green on targeted tests, and four non-golden failing slices stayed fixed in the full Flutter suite. Repository-wide release status remains red: full Flutter tests now fail only on 6 goldens, and global analyze still reports 248 existing issues.

## Optimized Workflow

1. Clean the worktree before and after tests.
2. Run mechanical gates first: ARB parity, locator audit, shell syntax, `git diff --check`.
3. Run targeted tests for touched code: profile truth, coach opener, financial summary, onboarding seal failure.
4. Run the full Flutter suite once to discover global failures.
5. Rerun only failing files with expanded output to classify root causes.
6. Run iOS simulator build plus targeted Maestro flows for user-critical paths.
7. Push only a feature branch while global gates are red; do not push to staging/dev as a release candidate until blockers are fixed or explicitly accepted.

## Evidence Matrix

| Gate | Command | Result | Notes |
|---|---|---:|---|
| ARB parity | `validate_arb_parity` | PASS | 6 locales, 6841 keys each. |
| l10n generation | `cd apps/mobile && flutter gen-l10n` | PASS | Generated delegates without error. |
| Targeted analyze | `flutter analyze lib/models/coach_profile.dart lib/screens/coach/coach_chat_screen.dart lib/screens/profile/financial_summary_screen.dart test/models/coach_profile_age_or_null_test.dart test/screens/coach/coach_chat_test.dart test/screens/profile/financial_summary_screen_test.dart` | PASS | No issues found. |
| Targeted salvage/profile tests | `flutter test test/models/coach_profile_age_or_null_test.dart test/screens/coach/coach_chat_test.dart test/screens/profile/financial_summary_screen_test.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart test/router/coach_route_archetype_guard_test.dart test/providers/coach_profile_provider_secure_failure_test.dart` | PASS | 87 pass, 5 skipped. |
| Maestro locator audit | `python3 tools/checks/maestro_locator_audit.py` | PASS | 35 flows scanned, 1 skipped, 308 locators. |
| Maestro script syntax + diff check | `bash -n tools/simulator/maestro_sweep.sh && git diff --check` | PASS | No syntax or whitespace drift. |
| iOS sim build/install | `flutter build ios --simulator --debug ... && xcrun simctl install ...` | PASS | Passed after earlier xattr/codesign cleanup. |
| Targeted Maestro | `flow_empty_state_cascade`, `salvage01_retraite_onboarding_coach`, `flow_fatca_3a_gate` | PASS targeted | FATCA passed only as a dedicated expat_us-seeded gate; do not count it inside normal-user default/perfect sweeps. |
| Targeted changed-file analyze | `flutter analyze lib/services/nudge/nudge_engine.dart test/app_rapport_route_budget_test.dart test/screens/advisor_banking_smoke_test.dart test/screens/onboarding/us_tax_person_screen_test.dart test/services/coach/report_persistence_premier_eclairage_test.dart test/services/nudge/nudge_engine_test.dart` | PASS | No issues found. |
| Full Flutter tests after fixes | `cd apps/mobile && flutter test --reporter=expanded` | FAIL | 9047 pass, 24 skipped, 6 failures. All remaining failures are goldens. |
| Global Flutter analyze after fixes | `cd apps/mobile && flutter analyze` | FAIL | 248 existing issues. Touched-file analyze is clean. |

## Bug and Risk Table

| ID | Severity | Area | Evidence | Finding | Status | Next action |
|---|---:|---|---|---|---|---|
| QA-001 | P1 | Flutter full suite | Full rerun after fixes: 9047 pass, 24 skipped, 6 failures | Repository-wide mobile suite is still red, but the non-golden failures from QA-002..QA-005 are closed in the full run. | Open | Resolve or explicitly quarantine QA-006 goldens; then rerun full suite. |
| QA-002 | P1 | Budget/report data truth | `test/screens/advisor_banking_smoke_test.dart`, `test/app_rapport_route_budget_test.dart` | Tests expected `5'000` while fixtures provided no income source. No prod hardcode added; fixtures now use real source fields. | Fixed | Targeted reruns passed and full suite no longer fails here. |
| QA-003 | P1 | Profile persistence tests | `test/services/coach/report_persistence_premier_eclairage_test.dart` | Three tests failed because `clearDiagnostic()` reaches secure storage without initialized Flutter binding. | Fixed | Targeted file passed 12/12 and full suite no longer fails here. |
| QA-004 | P1 | Onboarding FATCA answer | `test/screens/onboarding/us_tax_person_screen_test.dart` | `q_us_tax_person` is sensitive; the test did not mock secure storage, so fail-closed persistence rebuilt an empty profile. | Fixed | Targeted file passed 5/5 and full suite no longer fails here. |
| QA-005 | P2 | Nudge age/date logic | `test/services/nudge/nudge_engine_test.dart` | Birthday milestone used `profile.ageOrNull`, which reads wall-clock time instead of injected `now`. | Fixed | Nudge file passed 33/33 and full suite no longer fails here. |
| QA-006 | P1 | Golden baselines | Full Flutter suite: 6 golden failures | `julien_swiss_us_tax_person.png`, `lauren_expat_us_waitlist.png`, and landing masters differ. Landing drift is large, persona drift is small. | Open | Visually inspect generated failure images; update baselines only if the UI change is intentional. |
| QA-007 | P1 | Maestro regression quality | `bug__S005__landing_anonymous_cta_to_home.yaml` | The flow tapped anonymous CTA, then forced `mintapp:///home`; it could pass while the CTA route was broken. | Fixed in this pass | Removed the deep link; the flow must now reach home through the app path. |
| QA-008 | P1 | Maestro FATCA coverage | `tools/simulator/maestro_sweep.sh` | `flow_fatca_3a_gate` requires an expat_us seeded build. Including it in `default`/`perfect` made the normal-user sweep structurally incoherent. | Fixed as dedicated gate | `default`/`perfect` exclude FATCA again; run `--tier fatca` only against an expat_us build. |
| QA-009 | P2 | Static analysis debt | `flutter analyze`: 248 issues | Global analyzer is red, with examples in anonymous chat and test files. | Open | Triage separately; do not mix with salvage commit unless directly related. |
| QA-010 | P2 | Test artifacts | `apps/mobile/test/goldens/failures/*` | Full/golden test runs modify tracked failure PNGs. | Controlled | Restored before commit; keep these out unless deliberately updating goldens. |

## Current Push Policy

The clean expert move is a feature branch push with this report and the targeted fixes. Do not push these commits as a staging release candidate while `flutter test` and global `flutter analyze` are red. After the open P1s are fixed, rerun: targeted salvage/profile tests, failing-slice tests, full Flutter suite, iOS sim build, Maestro `default`/`perfect` on the normal build, and Maestro `fatca` on an expat_us seeded build.
