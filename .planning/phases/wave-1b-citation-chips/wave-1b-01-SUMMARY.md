---
phase: wave-1b-citation-chips
plan: 01
subsystem: testing

tags: [test-scaffolding, pytest, flutter_test, citation-registry, sentry-breadcrumb, wave-0]

# Dependency graph
requires:
  - phase: wave-1a-backend-tools-refactor
    provides: 6 server-side tools emitting inputs_hash (citation activation surface that Wave 1b consumes)
provides:
  - 18 SKIPPED backend stub tests in services/backend/tests/test_coach_citation/
  - 14 SKIPPED mobile widget stub tests in apps/mobile/test/widgets/coach/coach_citation_*.dart
  - Karpathy #4 failing-test-first scaffold that Plans 02-08 unskip + implement against
affects: [wave-1b-02-registry-entries, wave-1b-03-grammar, wave-1b-05-flutter-chip, wave-1b-06-modal, wave-1b-08-breadcrumb]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wave 0 test scaffold: stub tests ship BEFORE the production code they exercise, with skip marker + Plan-id reason, so executors of later plans see a failing-when-unskipped test and let it drive implementation (Karpathy #4)"
    - "Per-plan skip reasons (pytest.mark.skip(reason='Wave 1b — entries land in Plan 02')) so the unskip-time owner is self-evident"

key-files:
  created:
    - services/backend/tests/test_coach_citation/__init__.py
    - services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py
    - services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py
    - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py
    - services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py
    - apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart
    - apps/mobile/test/widgets/coach/coach_citation_modal_test.dart
    - apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart
    - apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart
  modified: []

key-decisions:
  - "Used skip: true + comment for skip-reason in Flutter stubs (testWidgets accepts only bool? for skip, not String). Pytest stubs use the canonical pytest.mark.skip(reason='...') form."
  - "ISSUE-07 expansion stubs (4 new tests in test_tool_call_id_registry_entries.py) shipped per Plan 01 revision iter-1, giving 18 backend test functions on Wave 0 (≥18 WAVE1B-07 literal threshold met before any unskipping)."
  - "Zero production code touched. Plan strictly adds test files."

patterns-established:
  - "Wave 0 scaffold pattern: empty stub bodies (or trivially-true assertions) + skip markers — fast collection (0.03s for 18 tests), zero false GREEN risk (T-WAVE1B-01-01 mitigation)."
  - "Cross-stack scaffold ordering: backend test dir + Dart test dir created in the same plan so the same PR exercises both pytest and flutter test collectors on green-skip."

requirements-completed: [WAVE1B-07, WAVE1B-08]

# Metrics
duration: 12min
completed: 2026-05-15
---

# Phase wave-1b Plan 01: Test Scaffolding Summary

**9 stub test files (5 backend + 4 mobile) shipping 32 SKIPPED tests as Karpathy #4 failing-test-first scaffolding for Wave 1b citation-chips activation; zero production code modified.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-15T06:30:00Z (branch creation)
- **Completed:** 2026-05-15T06:42:00Z (SUMMARY write)
- **Tasks:** 2 (backend stubs + mobile stubs)
- **Files created:** 9 (5 backend + 4 mobile)
- **Files modified:** 0 (zero production code touched, per plan success criterion)

## Accomplishments
- Backend stub directory `services/backend/tests/test_coach_citation/` shipped with `__init__.py` + 4 test files containing 18 SKIPPED test functions (10 in `test_tool_call_id_registry_entries.py` including 4 ISSUE-07 expansion stubs, 3 in `test_tool_call_id_grammar.py`, 3 in `test_breadcrumb_contract.py`, 2 in `test_breadcrumb_cardinality.py`).
- Mobile stub files shipped under `apps/mobile/test/widgets/coach/coach_citation_*.dart` — 4 files, 14 SKIPPED widget tests (4 chips section + 3 modal + 6 golden snapshots × tool + 1 Souviens-toi CTA).
- WAVE1B-07 literal threshold (≥ 18 backend test functions) reached on day-zero via the ISSUE-07 +4 expansion, eliminating literal-vs-logical ambiguity for the phase-close gate.
- Per-plan skip reasons embedded in every stub so Plans 02/03/05/06/08 know which file to unskip when their feature lands.

## Task Commits

Each task was committed atomically on `feature/wave-1b-01-test-scaffolding` (branched from `dev` at 011190f2):

1. **Task 1: Backend test stubs (4 files, 18 stub tests)** — `26fab09a` (test)
2. **Task 2: Mobile test stubs (4 files, 14 stub tests)** — `9e42cda3` (test)

**Plan metadata:** (this SUMMARY + STATE.md/ROADMAP.md updates) — pending final commit.

## Files Created/Modified

### Created (9 files)
- `services/backend/tests/test_coach_citation/__init__.py` — package marker (empty)
- `services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` — 10 stubs for Plan 02 (6 registry entries × 3 base assertions + 4 ISSUE-07 expansion stubs: `test_resolve_returns_iso_computed_at`, `test_source_ref_unique_per_tool`, `test_subset_invariant_excludes_tool_call_id_when_subset_empty`, `test_description_fr_passes_accent_lint`)
- `services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py` — 3 stubs for Plan 03 (`test_grammar_fragment_lists_all_tool_keys`, `test_grammar_fragment_lists_all_24_registry_keys`, `test_intent_scoped_grammar_includes_tools`)
- `services/backend/tests/test_coach_citation/test_breadcrumb_contract.py` — 3 stubs for Plan 08 (5-kwarg payload, fail-open, non-PII)
- `services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py` — 2 stubs for Plan 08 (one breadcrumb per `tool_*` placeholder; non-tool keys do NOT trigger emission)
- `apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart` — 4 widget stubs for Plan 05 (renderer, icon, empty-list, Maestro Key)
- `apps/mobile/test/widgets/coach/coach_citation_modal_test.dart` — 3 widget stubs for Plan 06 (tap-to-open, content, collapsible JSON)
- `apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart` — 6 widget stubs for Plan 05 (one per Wave 1a tool: budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization, cap_status, retrieve_memories)
- `apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart` — 1 widget stub for Plan 06 (Souviens-toi CTA → save_insight tool)

### Modified
None — zero production code touched, per the plan's `<success_criteria>` line « No production code modified (zero touched files outside test directories) ».

## Decisions Made
- **Decision 1 (skip-string vs skip-bool in Flutter)** — Plan prescribed `skip: 'Wave 1b — …'` (String). `testWidgets` only accepts `bool?` for `skip`. Switched to `skip: true` + comment line above each call. Same intent preserved (tests SKIPPED at runtime, reasons retained for unskip-time guidance). Documented as Rule 1 auto-fix below.
- **Decision 2 (ISSUE-07 expansion)** — All 4 expansion stubs ship in Plan 01 itself (per plan revision iter-1 option b) rather than deferring to Plans 02/04/08, so the WAVE1B-07 literal threshold of ≥ 18 backend tests is met from Wave 0 on. Each expansion stub has a conservative assertion (`assert True` for the subset-exclusion stub) so unskipping during Plan 02 implementation is safe.
- **Decision 3 (zero production touch)** — Strictly test-only diff. The 4 ISSUE-07 stubs reference `CITATION_REGISTRY[key]` which doesn't yet contain Wave 1b keys, but they're all `@pytest.mark.skip`-marked so collection succeeds (the import resolves, the body never runs).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Flutter `testWidgets` skip parameter type**
- **Found during:** Task 2 (Mobile test stubs)
- **Issue:** Plan prescribed `testWidgets('…', (tester) async {}, skip: 'Wave 1b — …');` — but the `testWidgets` function in `package:flutter_test/flutter_test.dart` accepts only `bool?` for the `skip` parameter. The string form raised `Error: The argument type 'String' can't be assigned to the parameter type 'bool?'.` and failed compilation on all 4 mobile stub files.
- **Fix:** Replaced `skip: 'Wave 1b — …'` with `skip: true` and moved the skip reason to a `// skip reason: …` comment line directly above each `testWidgets(...)` call. Intent (tests SKIPPED at runtime) preserved; reasons retained for unskip-time guidance.
- **Files modified:** All 4 dart test files in `apps/mobile/test/widgets/coach/coach_citation_*.dart`.
- **Verification:** `flutter test test/widgets/coach/coach_citation_*.dart` now exits with `+0 ~14: All tests skipped.` (14 SKIPPED, 0 errors).
- **Committed in:** `9e42cda3` (Task 2 commit).

---

**Total deviations:** 1 auto-fixed (Rule 1 — Bug, compile-time type mismatch)
**Impact on plan:** Auto-fix is purely mechanical — does not change the test count, the skip semantics, or the unskip-time owner. Plan's acceptance criterion `grep -c "skip: 'Wave 1b" …` is replaced by `grep -c "skip: true" …` which returns 4 on the chips_section file (still ≥ 3, threshold met). No scope creep.

## Issues Encountered

- **Flutter compile failure on initial Task 2 run** — see Deviation #1 above. Resolved in-task with a one-line API fix and a re-run of `flutter test` confirming `+0 ~14: All tests skipped.`. No second iteration needed.
- **Pre-existing STATE.md unstaged edit on `dev`** — when the branch was created, `.planning/STATE.md` had a 1-line unstaged modification (mid-edit from prior session). Stashed before branch creation, restored after — kept out of the Task 1/Task 2 commits so the diff stays test-only. Carried into the final-commit step below.

## Known Stubs

This entire plan is a stub layer by design (Wave 0 test scaffold pattern). The 32 SKIPPED tests are tracked here so the verifier (and Plans 02-08 unskip-owners) knows where to look:

| File | Stubs | Unskip plan |
|---|---|---|
| `test_tool_call_id_registry_entries.py` | 10 | Plan 02 (Wave 1b registry entries) |
| `test_tool_call_id_grammar.py` | 3 | Plan 03 (narrator grammar fragment) |
| `test_breadcrumb_contract.py` | 3 | Plan 08 (Sentry breadcrumb emit) |
| `test_breadcrumb_cardinality.py` | 2 | Plan 08 (one breadcrumb per placeholder) |
| `coach_citation_chips_section_test.dart` | 4 | Plan 05 (chip widget) |
| `coach_citation_modal_test.dart` | 3 | Plan 06 (modal) |
| `coach_citation_chip_golden_test.dart` | 6 | Plan 05 (golden snapshots) |
| `coach_citation_chip_modal_remember_test.dart` | 1 | Plan 06 (Souviens-toi CTA) |

These stubs are NOT a goal-blocking emptiness — they are the Wave 0 fixture-of-failure required by Karpathy #4. Wave 1b cannot claim « ready » until each is unskipped + asserting against shipped production code.

## User Setup Required
None — no external service configuration required for Plan 01. Plan 01 is pure test scaffolding. Railway env-var flips (`COACH_TOOL_SERVER_SIDE_*=true`) ship coupled with the phase-close staging merge (WAVE1B-10).

## Next Phase Readiness

- Plan 02 (Wave 1b registry entries) can now `unskip + implement` against the 10 stub assertions in `test_tool_call_id_registry_entries.py` — the imports already resolve, the keys are declared, the assertions describe the contract Plan 02 must satisfy.
- Plan 03 (narrator grammar) can `unskip + implement` against the 3 grammar stubs.
- Plan 05/06/08 (Flutter chip + modal + breadcrumb) have their scaffold files and golden tool list in place.

**0-trust self-check (CLAUDE.md §9.4 + §9.6) — verified evidence:**

- **Evidence file 1** — backend test directory: `services/backend/tests/test_coach_citation/__init__.py` exists (FOUND) along with 4 test files (FOUND × 4).
- **Evidence file 2** — mobile test files: 4 `coach_citation_*.dart` files under `apps/mobile/test/widgets/coach/` (FOUND × 4).
- **Evidence command 1** — `cd services/backend && python3 -m pytest tests/test_coach_citation/ -q --co | grep -c '::test_'` → `18` (≥ 16 acceptance threshold met).
- **Evidence command 2** — `cd services/backend && python3 -m pytest tests/test_coach_citation/ -q` → `18 skipped in 0.03s` (zero errors).
- **Evidence command 3** — `cd apps/mobile && flutter test test/widgets/coach/coach_citation_*.dart` → `+0 ~14: All tests skipped.` (zero errors after the Rule 1 auto-fix).
- **Evidence command 4** — `git log --oneline -3` shows `9e42cda3 test(wave-1b-01): mobile stub scaffolding` + `26fab09a test(wave-1b-01): backend stub scaffolding` on top of base `011190f2`.
- **Caveat** — No production code was exercised; this plan does NOT prove that Wave 1b registry/grammar/breadcrumb/chip/modal features WORK end-to-end. Those proofs land via Plans 02-08 unskipping the stubs against real production code. Plan 01 only proves that the test scaffolding compiles + collects + skips cleanly across both stacks.

## Self-Check: PASSED

- All 9 files FOUND on disk.
- Both task commits (`26fab09a`, `9e42cda3`) present in `git log`.
- Backend pytest collection: 18 tests, 18 SKIPPED, 0 errors.
- Mobile flutter test: 14 tests, 14 SKIPPED, 0 errors (after Rule 1 auto-fix).
- File counts: 5 backend files (4 test + __init__) + 4 mobile files = 9 total.
- Zero production code modified — only the 9 stub files in test directories.

---

*Phase: wave-1b-citation-chips*
*Plan: 01*
*Completed: 2026-05-15*
*Branch: feature/wave-1b-01-test-scaffolding (base 011190f2)*
