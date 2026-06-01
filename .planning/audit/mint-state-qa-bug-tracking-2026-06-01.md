# MINT QA and Bug Tracking — 2026-06-01

TL;DR: the right approach is not one huge "run everything" pass. The optimized workflow is cyclic: clean generated artifacts, run fast mechanical gates, run targeted regression suites for the touched truth paths, run the full suite to discover wider debt, classify failures into deterministic bugs vs. harness/golden drift, then rerun only the failing slices. This pass found the current salvage/profile patch green on targeted tests, but the repository-wide Flutter gates are still red.

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
| Targeted Maestro | `flow_empty_state_cascade`, `salvage01_retraite_onboarding_coach`, `flow_fatca_3a_gate` | PASS | FATCA passed after `clearState: true`. |
| Global Flutter analyze | `cd apps/mobile && flutter analyze` | FAIL | 248 existing issues. Touched-file analyze is clean. |
| Global Flutter tests | `cd apps/mobile && flutter test` and JSON rerun | FAIL | 9712 done, 9697 success, 24 skipped, 15 errors across 8 files. |

## Bug and Risk Table

| ID | Severity | Area | Evidence | Finding | Status | Next action |
|---|---:|---|---|---|---|---|
| QA-001 | P1 | Flutter full suite | `flutter test`: 15 errors across 8 files | Repository-wide mobile suite is red. Targeted salvage/profile tests pass, but full-suite release confidence is blocked. | Open | Fix or quarantine each failing slice below, then rerun full suite. |
| QA-002 | P1 | Budget/report data truth | `test/screens/advisor_banking_smoke_test.dart`, `test/app_rapport_route_budget_test.dart` | Both expect text containing `5'000`; current report path does not render it. This is a data propagation/read-model risk for Budget -> Rapport. | Open | Inspect `FinancialReportScreenV2` budget fallback and `/rapport` persisted budget loading. |
| QA-003 | P1 | Profile persistence tests | `test/services/coach/report_persistence_premier_eclairage_test.dart` | Three tests fail with `Binding has not yet been initialized` from `ServicesBinding.instance`. | Open | Add proper `TestWidgetsFlutterBinding.ensureInitialized()` or refactor storage test harness. |
| QA-004 | P1 | Onboarding FATCA answer | `test/screens/onboarding/us_tax_person_screen_test.dart` | Tapping Yes/No leaves provider value `null` instead of true/false. | Open | Verify whether the screen writes the canonical key or if the test targets stale provider shape. |
| QA-005 | P2 | Nudge age/date logic | `test/services/nudge/nudge_engine_test.dart` | Birthday milestone does not fire for age 50 and all milestone ages. | Open | Audit date-of-birth vs. age-only logic; this connects to the user concern that a birth date is needed, not only age. |
| QA-006 | P2 | Golden baselines | Golden tests | `julien_swiss_us_tax_person.png`, `lauren_expat_us_waitlist.png`, and landing masters differ. Landing drift is large, persona drift is small. | Open | Visually inspect generated failure images; update baselines only if the UI change is intentional. |
| QA-007 | P1 | Maestro regression quality | `bug__S005__landing_anonymous_cta_to_home.yaml` | The flow tapped anonymous CTA, then forced `mintapp:///home`; it could pass while the CTA route was broken. | Fixed in this pass | Removed the deep link; the flow must now reach home through the app path. |
| QA-008 | P1 | Maestro coverage | `tools/simulator/maestro_sweep.sh` | `default`/`perfect` could pass without FATCA coverage. | Fixed in this pass | `default` and `perfect` now include `flow_fatca_3a_gate`. |
| QA-009 | P2 | Static analysis debt | `flutter analyze`: 248 issues | Global analyzer is red, with examples in anonymous chat and test files. | Open | Triage separately; do not mix with salvage commit unless directly related. |
| QA-010 | P2 | Test artifacts | `apps/mobile/test/goldens/failures/*` | Full/golden test runs modify tracked failure PNGs. | Controlled | Restored before commit; keep these out unless deliberately updating goldens. |

## Current Push Policy

The clean expert move is a feature branch push with this report and the targeted fixes. Do not push these commits as a staging release candidate while `flutter test` and global `flutter analyze` are red. After the open P1s are fixed, rerun: targeted salvage/profile tests, failing-slice tests, full Flutter suite, iOS sim build, and Maestro default/perfect/fatca.
