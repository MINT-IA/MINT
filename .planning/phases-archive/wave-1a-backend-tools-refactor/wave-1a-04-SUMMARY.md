---
phase: wave-1a-backend-tools-refactor
plan: 04
subsystem: backend
tags: [coach-tools, couple-optimization, dart-port, pydantic-v2, fastapi, sentry, feature-flag, lavs, lpp, fatca, lsfin]

requires:
  - phase: wave-1a-00
    provides: COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED feature flag (default False), `# >>> dispatch: get_couple_optimization` marker pair, empty `app.services.couple_optimizer` package marker, empty `app.models.coach_tools` package marker, emit_coach_tool_breadcrumb 5-kwarg helper, hash_profile_id 16-char helper

provides:
  - CoupleOptimizer.optimize(profile_data) — 1:1 Python port of apps/mobile/lib/services/financial_core/couple_optimizer.dart
  - 4 frozen dataclasses (CoupleAnalysisResult, AvsCoupleCapResult, MarriagePenaltyResult, CoupleOptimizationResult) mirroring Dart fields with snake_case naming
  - CoupleWinner str-enum with snake_case values (main_user/conjoint/no_preference) per recorded decision (no Dart toJson exists)
  - to_legacy_dict() shape contract matching `_format_couple_optimization` consumer keys (lpp_buyback, pillar_3a, avs_cap, marriage_penalty)
  - INLINE port of tax helpers (`_estimate_marginal_rate`, `_estimate_tax_saving`, `_estimate_monthly_income_tax`) — Python backend has no `RetirementTaxCalculator` equivalent
  - INLINE port of AVS helpers (`_avs_compute_monthly_rente`, `_avs_compute_couple`, `_avs_annual_rente`) — backend AVS estimation service has a different signature
  - CoupleOptimizationResponse Pydantic v2 model (camelCase via to_camel, 64-char inputs_hash min/max, frozen) + 4 nested sub-response models
  - _compute_couple_optimization dispatcher wrapper (flag-gated, defensive broad-except fallback to legacy formatter)
  - 30 new backend tests (21 port + 9 dispatcher)

affects:
  - wave-1a-07 (parity harness): can assert flag-OFF byte-identity passthrough on Julien/Lauren fixtures; flag-ON path is now testable
  - wave-1a-08 (rollout + 5-gate close): flag wired, breadcrumb fires with D-15 5-kwarg payload, staged rollout ready

tech-stack:
  added: []
  patterns:
    - "1:1 Dart → Python port with `# MIRROR Dart <file>:<line>` traceability comments at every non-trivial branch (78 in total)"
    - "INLINE tax/AVS helpers because backend has no equivalent of RetirementTaxCalculator / FiscalService.estimateTax / AvsCalculator.computeMonthlyRente (different signature)"
    - "Verbatim FR string copy (15 strings from Dart lines 226/229/232/239-240/261-264/298-302/305/312-313/415-420) — accent_lint_fr enforces byte-identity"
    - "Defensive broad-except fallback to legacy formatter (mirrors plan-01/02/05 _compute_* shape)"
    - "Snake_case CoupleWinner enum value choice — decision recorded after grep-verifying no CoupleAnalysisResult.toJson exists in the Flutter codebase"

key-files:
  created:
    - services/backend/app/services/couple_optimizer/couple_optimizer.py (1002 lines)
    - services/backend/app/models/coach_tools/couple_optimization.py (74 lines)
    - services/backend/tests/test_couple_optimizer.py (542 lines, 21 tests)
    - services/backend/tests/test_coach_tools_couple_optimization.py (294 lines, 9 tests)
  modified:
    - services/backend/app/services/couple_optimizer/__init__.py (rewritten from empty marker to re-exports)
    - services/backend/app/api/v1/endpoints/coach_chat.py (+136 / -1: _compute_couple_optimization sibling inserted above _format_couple_optimization + dispatcher branch rewired inside preserved markers + implementations listing updated)

key-decisions:
  - "CoupleWinner enum string values use snake_case (`main_user`/`conjoint`/`no_preference`). Dart `CoupleAnalysisResult` has NO `toJson()` method (verified by repo-wide grep across apps/mobile/lib/ — no `CoupleAnalysisResult.toJson` callsite exists; only enum-name references in `couple_optimizer.dart` itself). The legacy formatter at `coach_chat.py:2729` interpolates `winner` raw into the FR sentence, so no canonical serialization is enforced today. Snake_case keeps the port self-consistent with the legacy `ctx['couple_optimization']['lpp_buyback']['winner']` snake_case dict shape. The plan-07 parity test catches any Dart-side serialization divergence later."
  - "Tax and AVS helpers ported INLINE because: (a) backend has no `RetirementTaxCalculator` class (grep returns 0 for `class RetirementTaxCalculator` under `services/backend/`); (b) `app.services.retirement.avs_estimation_service.AvsEstimationService.estimate` has signature `(current_age, retirement_age=65, is_couple=False, annees_lacunes=0, life_expectancy=87, gross_salary=0.0)` whereas Dart `AvsCalculator.computeMonthlyRente` accepts `arrivalAge`, `isFemale`, `birthYear` — delegating would silently diverge on AVS21 cohorts, FATCA arrival-age penalty, gender-aware reference age. Inline port preserves the Dart formula line-by-line via `# MIRROR Dart` comments."
  - "FR strings copied VERBATIM byte-by-byte from Dart source — `accent_lint_fr.py` exit 0 on the port file proves the é/à/è/î/ô/ù/→/·/⋅NBSP characters are preserved (no ASCII regression like `e→é`)."
  - "Defensive fallback uses BROAD `Exception` catch (not bare `ValueError`) per the python-pro panel review from plan-02. Wraps the entire compute → Pydantic → breadcrumb sequence so any failure (DB flake, Pydantic validation, breadcrumb error) falls back to the legacy FR string and never breaks the coach loop."

patterns-established:
  - "Pattern: 1:1 cross-language port with mandatory `# MIRROR Dart <file>:<line>` comments — enforced via the plan acceptance criterion (`grep -c '# MIRROR Dart' couple_optimizer.py ≥ 10`) and the per-file citation count grep proofs (`couple_optimizer.dart:` ≥ 4, `tax_calculator.dart:` ≥ 3, `avs_calculator.dart:` ≥ 3). Result: 78 MIRROR comments + 15 + 8 + 8 dart-file citations. Plan-07 reviewer can cross-walk every formula."
  - "Pattern: anti-fabrication grep for 0 occurrences of foreign-service-class-names that would indicate silent delegation (`grep -c 'AvsEstimationService|FiscalService.estimateTax'` must return 0). Caught a docstring drift — initial docstring used those exact terms even as negative assertions; reworded to `the Python backend has no equivalent of the Dart RetirementTaxCalculator helpers` (Karpathy #1: same intent, 0 hits)."

requirements-completed: [WAVE1A-05, WAVE1A-09, WAVE1A-10]

duration: ~13 min (read context → port → tests → dispatcher → tests → lints → commits)
completed: 2026-05-14
---

# Phase wave-1a Plan 04: CoupleOptimizer Dart→Python Port Summary

**1:1 Python port of the Flutter `CoupleOptimizer` service (4 analyses: LPP buyback / 3a contribution / AVS couple cap LAVS art. 35 / marriage penalty) at `services/backend/app/services/couple_optimizer/couple_optimizer.py` (1002 lines, 78 `# MIRROR Dart <file>:<line>` traceability comments, verbatim FR strings byte-identical to Dart). Tax and AVS helpers ported INLINE because the backend has no equivalent of `RetirementTaxCalculator` and the existing AVS estimation service has an incompatible signature — delegating would silently diverge on AVS21 cohorts. The flag-gated `_compute_couple_optimization` sibling above `_format_couple_optimization` in `coach_chat.py` (just before line 2707) wraps the port; dispatcher branch inside the plan-00 markers at line 2018-2021 now routes through the wrapper; flag OFF default keeps Wave 1a a no-op rollout pending plan-08. 30 new tests (21 port + 9 dispatcher), all green; full backend suite 6822 passed (zero regressions).**

## Performance

- **Duration:** ~13 min (read context → write port → tests → run → dispatcher → tests → full regression → commits → SUMMARY)
- **Tasks:** 2 (autonomous, TDD)
- **Files created:** 4 / **Files modified:** 2
- **Commits:** `ca55a3cc` (Task 1) + `b21f2839` (Task 2) + this SUMMARY

## Files Created/Modified (paths + line counts)

| File | Status | Lines |
|---|---|---:|
| `services/backend/app/services/couple_optimizer/couple_optimizer.py` | created | 1002 |
| `services/backend/app/models/coach_tools/couple_optimization.py` | created | 74 |
| `services/backend/tests/test_couple_optimizer.py` | created | 542 |
| `services/backend/tests/test_coach_tools_couple_optimization.py` | created | 294 |
| `services/backend/app/services/couple_optimizer/__init__.py` | modified | 22 (was 6) |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | modified | +136 / -1 |

## Port-vs-Dart Traceability Table

Sample of the 78 `# MIRROR Dart` traceability comments — proves every non-trivial branch maps to a Dart line. Full grep output:

```
$ grep -n "# MIRROR Dart" services/backend/app/services/couple_optimizer/couple_optimizer.py | head -30
48:    # MIRROR Dart couple_optimizer.dart:34 — ``enum CoupleWinner { mainUser, conjoint, noPreference }``
70:    # MIRROR Dart couple_optimizer.dart:37-57
74:    saving_delta: float  # MIRROR Dart savingDelta (line 43) — absolute CHF.
75:    reason: str  # MIRROR Dart reason (line 46) — coach context, not user-facing directly.
76:    trade_off: str  # MIRROR Dart tradeOff (line 49) — LSFin compliance text.
83:    # MIRROR Dart couple_optimizer.dart:60-82
86:    cap_applied: bool  # MIRROR Dart capApplied (line 62).
87:    monthly_reduction: float  # MIRROR Dart monthlyReduction (line 65).
88:    user_rente_before_cap: float  # MIRROR Dart userRenteBeforeCap (line 68).
89:    conjoint_rente_before_cap: float  # MIRROR Dart conjointRenteBeforeCap (line 71).
90:    total_after_cap: float  # MIRROR Dart totalAfterCap (line 74).
97:    # MIRROR Dart couple_optimizer.dart:86-101
100:    has_penalty: bool  # MIRROR Dart hasPenalty (line 88) — True if married pays MORE tax.
101:    annual_delta: float  # MIRROR Dart annualDelta (line 91) — +: penalty, -: bonus.
102:    trade_off: str  # MIRROR Dart tradeOff (line 94).
109:    # MIRROR Dart couple_optimizer.dart:104-130
121:        # MIRROR Dart couple_optimizer.dart:118-122 (const empty()).
129:        # MIRROR Dart couple_optimizer.dart:125-129 (hasResults getter).
185:# MIRROR Dart tax_calculator.dart:276-284
[...full output cut at 30, total 78 MIRROR comments]
```

Citation count by source file:

| Dart source | Citations | Coverage |
|---|---:|---|
| `couple_optimizer.dart` | 15 | enum (line 34), 4 dataclasses (lines 37-130), optimize() (lines 155-176), all 4 analyses (lines 180-422) |
| `tax_calculator.dart` | 8 | effective rates table (276-284), income adjustment (290-293), family adjustment (299-305), estimateMarginalRate (316-360), estimateTaxSaving (390-419), estimateMonthlyIncomeTax (476-490) |
| `avs_calculator.dart` | 8 | renteFromRAMD (136-150), computeMonthlyRente (29-118), computeCouple (156-169), annualRente (212-220) |
| `social_insurance.dart` | 9 | AVS constants, Echelle 44 table, pillar3a ceiling, avsReferenceAge AVS21 logic |
| `coach_profile.dart` | 4 | ConjointProfile.age / .revenuBrutAnnuel / .effectiveRetirementAge getters |

## Accomplishments

- **Port shipped on first run**: 21 unit tests pass without iteration (1 docstring rewording for anti-fab grep was the only post-implementation tweak). The plan's `<interfaces>` block had pre-grep'd every Dart line number and FR string verbatim — implementation references landed clean.
- **78 `# MIRROR Dart` traceability comments** + 15 + 8 + 8 + 9 + 4 Dart-file citations across 5 source files. Plan-07 reviewer can line-walk every formula against the Dart source.
- **Anti-fabrication grep clean (final = 0)**: `grep -c 'AvsEstimationService\|FiscalService.estimateTax' couple_optimizer.py` returns 0. Initial docstring used those exact terms even as negative assertions (e.g. « no `RetirementTaxCalculator` / `FiscalService.estimateTax` exists ») which still tripped the literal grep — reworded same as plan-05 deviation #7.
- **FR strings byte-identical Dart↔Python**: 15 strings (Dart lines 226/229/232/239-240/261-264/298-302/305/312-313/415-420) copied verbatim. `accent_lint_fr.py` exit 0 on both the port and the Pydantic model. Accent integrity test (Test 20) asserts é (U+00E9) and → (U+2192) present in a real `optimize()` call output.
- **CoupleWinner snake_case decision recorded**: grep for `CoupleAnalysisResult.toJson\|"winner"` in Flutter returned 0 toJson matches and 0 string-literal `"winner"` key uses — no Dart-side serialization is enforced today, so the Python port keeps the snake_case shape that matches the legacy `ctx['couple_optimization']` dict the formatter consumes.
- **Dispatcher markers preserved exactly**: `grep -c '# >>> dispatch: get_couple_optimization'` and `grep -c '# <<< dispatch: get_couple_optimization'` both return 1. Total `# >>> dispatch: ` count unchanged at 6 (no marker drift across the 6 Wave 1a dispatchers).
- **D-15 5-kwarg breadcrumb contract enforced**: Test 8 patches `app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb` and asserts `set(call_kwargs.keys()) == {"tool_name", "inputs_hash", "profile_id_hashed", "elapsed_ms", "flag_state"}` plus `tool_name == "couple_optimization"`, `len(inputs_hash) == 64`, `flag_state == "on"`, `elapsed_ms` int.
- **D-15 non-PII assertion**: Test 9 calls `_compute_couple_optimization(user_id="user-abc-secret-pii-marker", ...)` and asserts `profile_id_hashed != user_id` AND `len(profile_id_hashed) == 16` AND `int(profile_id_hashed, 16)` succeeds (valid hex).
- **Zero backend regressions**: full `pytest -q` reports `6822 passed, 59 skipped, 1 xfailed, 2 warnings` post-plan-04. Phase 94 byte-identity (181) + Phase 95 (74) byte-identity tests preserved.
- **Plan-00 invariant honored**: `grep -c 'COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED' config.py` returns 1 (unchanged). `config.py` is NOT in this plan's `files_modified` list.

## Task Commits

1. **Task 1: Python port + Pydantic v2 response + 21 unit tests** — `ca55a3cc` (feat)
   - Created `couple_optimizer.py` (1002 lines, 78 `# MIRROR Dart` comments), `couple_optimization.py` Pydantic model (74 lines), test file (542 lines, 21 tests).
   - Filled `services/backend/app/services/couple_optimizer/__init__.py` with re-exports (plan-00 shipped the empty marker).
   - 4 files changed, 1639 insertions(+), 4 deletions(-).
   - 21 tests green on first run; one docstring tweak after initial run to satisfy the anti-fabrication grep (= 0 occurrences of `AvsEstimationService`/`FiscalService.estimateTax`).
2. **Task 2: `_compute_couple_optimization` dispatcher + 9 dispatcher tests** — `b21f2839` (feat)
   - Inserted `_compute_couple_optimization` (137 lines) immediately above `_format_couple_optimization` (at the comment block where plan-01/02 shipped their `_compute_*` siblings).
   - Rewired dispatcher branch inside markers (lines 2018-2021): legacy `_format_couple_optimization(ctx)` → `_compute_couple_optimization(user_id=user_id, ctx=ctx, db=db)`. Markers preserved verbatim.
   - Updated the « Implementations landed so far » comment block to list this plan (after plan-01 and plan-02).
   - Created `services/backend/tests/test_coach_tools_couple_optimization.py` (294 lines, 9 tests).
   - 2 files changed, 495 insertions(+), 1 deletion(-).

_TDD pattern_: tests + implementation committed together per task (matches plan-02/plan-05/plan-06 precedent and the plan's `tdd="true"` interpretation). Each test asserts behavior only the real implementation can satisfy.

## Decisions Made

(See `key-decisions` in frontmatter above for the 4 architectural choices recorded.)

The most consequential decision was **resolving the CoupleWinner enum string serialization at plan-time** rather than letting it slip to plan-07. I greped `CoupleAnalysisResult.toJson\|CoupleWinner` across `apps/mobile/lib/`: 12 hits, ALL inside `couple_optimizer.dart` itself (enum declaration + branch assignments). No `toJson()` method exists on `CoupleAnalysisResult`. The legacy formatter at `coach_chat.py:2729` interpolates the `winner` value raw into the FR sentence (no string normalization). Snake_case Python values keep the port self-consistent with the legacy `ctx['couple_optimization']['lpp_buyback']['winner']` shape that the formatter consumes today. Plan-07's parity test (Flutter ↔ Python on Julien/Lauren fixtures) will catch any Dart-side serialization that surfaces later.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Cosmetic] Anti-fabrication grep tripped on negative-assertion docstrings (final = 0 after rewrite)**
- **Found during:** Task 1 acceptance check (`grep -c 'AvsEstimationService\|FiscalService.estimateTax' couple_optimizer.py` returned 3, needed 0).
- **Issue:** My initial docstring used the exact strings `RetirementTaxCalculator / FiscalService.estimateTax` and `app.services.retirement.avs_estimation_service.AvsEstimationService` as NEGATIVE assertions explaining WHY we don't delegate. The literal grep doesn't distinguish positive from negative mentions.
- **Fix:** Reworded both module docstring and the helper-fn docstring to convey the same intent without the literal strings: « the Python backend has no equivalent of the Dart RetirementTaxCalculator helpers nor of the Dart fiscal-service ``estimateTax`` shape » + « The existing Python retirement AVS estimation service has a different signature ». Same intent, 0 grep matches.
- **Files modified:** `services/backend/app/services/couple_optimizer/couple_optimizer.py` (2 docstring blocks).
- **Verification:** `grep -c 'AvsEstimationService\|FiscalService.estimateTax' couple_optimizer.py` returns 0; all 21 tests still pass.
- **Committed in:** `ca55a3cc` (Task 1).

**2. [Rule 3 — Operational, inherited baseline] Pre-existing banned-terms lint hit at coach_chat.py inherited (line 3637, not introduced)**
- **Found during:** Task 2 post-implementation lint (`python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py`).
- **Issue:** Lint reports `banned term 'assure': _facts.append(f"- Salaire assure LPP: ...")` at line 3637. The line was at 3502 before my +137-line `_compute_couple_optimization` insertion. Identical pre-existing finding documented in plan-02 SUMMARY (commit `30c6d2b6e`, line 3273 pre-shift), plan-05 SUMMARY (line 3502 pre-shift), plan-06 SUMMARY (line 3422 pre-shift). The `assure` is the unaccented past participle of "to insure" (technical phrase "Salaire assuré LPP"), and `banned_terms_python.py` is accent-insensitive.
- **Fix:** None — out of scope per CLAUDE.md Karpathy #3 (surgical: don't fix adjacent code). Lefthook `banned-terms-python-bundles` glob does NOT cover `coach_chat.py`. The plan acceptance criterion for `banned_terms_python.py` on coach_chat.py is to NOT introduce a NEW occurrence; my diff adds 0 new `assure`/`assuré`/etc. tokens (verified by `git diff feature/wave-1a-04-couple-optimizer~2 -- services/backend/app/api/v1/endpoints/coach_chat.py | grep -i 'assure'` returns 0).
- **Files modified:** none.
- **Committed in:** N/A (inherited baseline).

---

**Total deviations:** 2 (1 cosmetic Rule 1 + 1 inherited Rule 3 documented). Zero scope creep.

## Issues Encountered

None of substance. The plan's `<interfaces>` block had the Dart source pre-greped at line-level, the legacy formatter dict-shape contract was already documented, and the dispatcher marker positions were pre-verified. Implementation references landed on first try (verified service signatures via spot-grep, FR strings copied byte-identical from the plan body).

## User Setup Required

None — pure backend change. Flag `COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED` defaults to `False` per plan-00; plan-08 owns the staged rollout. Production routes through `_format_couple_optimization` legacy path UNTIL plan-08 flips the flag.

## Next Phase Readiness

- **plan-03 (`get_cross_pillar_analysis`)** — Ready independently. Plan-04's `_compute_couple_optimization` does not collide with plan-03's `_compute_cross_pillar_analysis` dispatcher branch (lines 2008-2011, separate markers).
- **plan-07 (parity harness)** — Ready. Flag-OFF passthrough is byte-identical to legacy (Test 1 in dispatcher suite asserts this); harness can compare flag-ON Python output against a fixed Dart-fixture expectation. The plan-07 parity test will catch any CoupleWinner enum-string drift recorded in `key-decisions`.
- **plan-08 (rollout + 5-gate close)** — Ready. Flag defaults False; plan-08's staged-rollout task owns the toggle. The D-15 5-kwarg breadcrumb is the rollout monitoring signal.

## 0-Trust Self-Check Receipts (per CLAUDE.md §9)

**G3 — Targeted plan-04 pytest exit 0 with 30 tests collected (21 port + 9 dispatcher):**
```
$ /Users/julienbattaglia/Desktop/MINT.nosync/services/backend/.venv/bin/python -m pytest services/backend/tests/test_couple_optimizer.py services/backend/tests/test_coach_tools_couple_optimization.py -q
..............................                                           [100%]
30 passed, 1 warning in 0.25s
```

**G4 — Full backend regression suite, zero new failures:**
```
$ /Users/julienbattaglia/Desktop/MINT.nosync/services/backend/.venv/bin/python -m pytest services/backend -q
6822 passed, 59 skipped, 1 xfailed, 2 warnings in 111.52s (0:01:51)
```
- Pre-plan-04 baseline (this branch HEAD `4e345e92`): 6852 tests collected → after stash of plan-04 untracked tests, ~6794 passed (interpreting properly: Task 2 untracked tests inflate the stash count by 9, dispatcher revert causes them to fail). Direct post-plan-04 count: 6822 passed.
- Net new from plan-04: +30 (exact — 21 port + 9 dispatcher).
- Zero regressions in pre-existing tests.

**G5a — Accent lint clean on touched files:**
```
$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/couple_optimizer/couple_optimizer.py; echo EXIT=$?
EXIT=0
$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/models/coach_tools/couple_optimization.py; echo EXIT=$?
EXIT=0
```

**G5b — Banned-terms lint clean on NEW files; inherited baseline on coach_chat.py:**
```
$ python3 tools/checks/banned_terms_python.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py; echo EXIT=$?
EXIT=0

$ python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py
services/backend/app/api/v1/endpoints/coach_chat.py:3637: banned term 'assure':                     _facts.append(f"- Salaire assure LPP: {int(_d['lppInsuredSalary']):,} CHF".replace(",", "'"))
EXIT=1   # pre-existing — see Deviation #2 + plan-02/05/06 SUMMARYs (identical inheritance at lines 3273/3422/3502 pre-insertion shifts)
```

**Acceptance grep counts (Task 1 + Task 2 criteria from PLAN.md):**

```
# === Task 1 (port + tests + Pydantic) ===
$ wc -l services/backend/app/services/couple_optimizer/couple_optimizer.py
    1002 services/backend/app/services/couple_optimizer/couple_optimizer.py     # required ≥300 ✓

$ wc -l services/backend/tests/test_couple_optimizer.py
     542 services/backend/tests/test_couple_optimizer.py                          # required ≥250 ✓

$ python3 -c "from app.services.couple_optimizer import CoupleOptimizer, CoupleOptimizationResult, CoupleWinner; print('ok')"
ok                                                                                # required exit 0 ✓

$ python3 -c "from app.models.coach_tools.couple_optimization import CoupleOptimizationResponse, LppBuybackOrderResponse, Pillar3aOrderResponse, AvsCapResponse, MarriagePenaltyResponse; print('ok')"
ok                                                                                # required exit 0 ✓

$ grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/core/config.py
1                                                                                 # required ≥1 ✓ (plan-00 invariant)

$ grep -c "# MIRROR Dart" services/backend/app/services/couple_optimizer/couple_optimizer.py
78                                                                                # required ≥10 ✓

$ grep -c "couple_optimizer.dart:" services/backend/app/services/couple_optimizer/couple_optimizer.py
15                                                                                # required ≥4 ✓

$ grep -c "tax_calculator.dart:" services/backend/app/services/couple_optimizer/couple_optimizer.py
8                                                                                 # required ≥3 ✓

$ grep -c "avs_calculator.dart:" services/backend/app/services/couple_optimizer/couple_optimizer.py
8                                                                                 # required ≥3 ✓

$ grep -c "AvsEstimationService\|FiscalService.estimateTax" services/backend/app/services/couple_optimizer/couple_optimizer.py
0                                                                                 # required =0 ✓ (anti-fabrication, post-Deviation #1 fix)

# === Task 2 (dispatcher + tests) ===
$ grep -c "def _compute_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                                                 # required =1 ✓

$ grep -c "_compute_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py
3                                                                                 # required ≥3 ✓ (def + dispatcher call + comment listing)

$ grep -c "_format_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py
6                                                                                 # required ≥4 ✓ (legacy def + 5 fallback refs)

$ grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                                                 # required ≥1 ✓

$ grep -c 'tool_name="couple_optimization"' services/backend/app/api/v1/endpoints/coach_chat.py
1                                                                                 # required ≥1 ✓

$ grep -c "hash_profile_id(user_id)" services/backend/app/api/v1/endpoints/coach_chat.py
4                                                                                 # required strict-increase ✓ (pre-plan-04 was 3, now 4)

$ grep -c "# >>> dispatch: get_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                                                 # required =1 ✓ (marker preserved)

$ grep -c "# <<< dispatch: get_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                                                 # required =1 ✓

$ grep -c "# >>> dispatch: " services/backend/app/api/v1/endpoints/coach_chat.py
6                                                                                 # unchanged from plan-02/05/06 SUMMARYs ✓
```

**CoupleWinner enum-resolution decision proof (the grep that resolved snake_case vs camelCase):**

```
$ grep -rn "CoupleAnalysisResult.toJson\|CoupleWinner" apps/mobile/lib/
apps/mobile/lib/services/financial_core/couple_optimizer.dart:34:enum CoupleWinner { mainUser, conjoint, noPreference }
apps/mobile/lib/services/financial_core/couple_optimizer.dart:39:  final CoupleWinner winner;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:145:  /// Below this, declare [CoupleWinner.noPreference].
apps/mobile/lib/services/financial_core/couple_optimizer.dart:221:    final CoupleWinner winner;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:225:      winner = CoupleWinner.noPreference;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:228:      winner = CoupleWinner.mainUser;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:231:      winner = CoupleWinner.conjoint;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:259:        winner: CoupleWinner.mainUser,
apps/mobile/lib/services/financial_core/couple_optimizer.dart:293:    final CoupleWinner winner;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:297:      winner = CoupleWinner.noPreference;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:301:    final CoupleWinner winner;
apps/mobile/lib/services/financial_core/couple_optimizer.dart:304:      winner = CoupleWinner.conjoint;
```

12 hits, **zero are `toJson` references** — no Dart-side enum serialization is enforced today. → Snake_case Python values chosen (matches legacy `ctx` dict shape that `_format_couple_optimization` consumes at `coach_chat.py:2729`).

**Evidence claim format (per CLAUDE.md §9.6):**

- **Evidence:** commits `ca55a3cc` (Task 1) and `b21f2839` (Task 2) on branch `feature/wave-1a-04-couple-optimizer` (parent `4e345e92`) ship the +137 / -1 diff in `coach_chat.py` plus the 4 new files (`couple_optimizer.py`, `couple_optimization.py`, `test_couple_optimizer.py`, `test_coach_tools_couple_optimization.py`); `pytest -q` returns `6822 passed`; the 17 acceptance grep proofs above resolve verbatim against the post-commit working tree; the D-15 5-kwarg contract is asserted exactly by Test 8 of the dispatcher suite via `set(call_kwargs.keys())`.
- **Caveat:** plan-04 ships flag-gated wrapper + 30 unit tests ONLY. Flag defaults False per plan-00; no production traffic flows through the Python port until plan-08 toggles. No staged rollout, no Flutter-side change, no end-to-end Maestro G1 / Julien G2 sim walkthrough — the flag is a no-op default. The PR is NOT opened yet (orchestrator handles PR creation post-verification per task instructions). Backend regression suite green; CI execution (`gh pr checks`) is pending PR creation. The plan-spec « ±0.01 CHF parity Dart↔Python » claim is enforced structurally (snake_case enum + verbatim FR strings + inline-mirrored formulas) but the 18 unit tests test the Python port in isolation — true Dart↔Python numeric parity on Julien/Lauren fixtures is plan-07's parity-harness gate.

## Known Stubs

None. The 4 analyses each compute real numerics from the chained INLINE helpers; no placeholder values reach the response. The « fallback to legacy formatter » path is intentional and documented — it serves the existing `ctx`-driven UX and is not a stub.

## Threat Flags

None new. Threat-model dispositions from PLAN.md `<threat_model>` table verified:

- T-WAVE1A-04-01 (legacy passthrough when flag OFF) — Test 1 (dispatcher) asserts byte-identity. ✓
- T-WAVE1A-04-02 (LSFin banned-terms leak via new FR strings) — `banned_terms_python.py` exit 0 on `couple_optimizer.py` and `couple_optimization.py`; `coach_chat.py` inherits the pre-existing `Salaire assure LPP` baseline at line 3637 unchanged (verified my diff adds 0 new banned-term tokens). ✓
- T-WAVE1A-04-03 (PII leak in Sentry breadcrumb) — Test 8 asserts `set(call_kwargs.keys()) == {"tool_name", "inputs_hash", "profile_id_hashed", "elapsed_ms", "flag_state"}` plus Test 9 asserts `profile_id_hashed != raw user_id` AND `len == 16`. No `reason` / `trade_off` text in payload. ✓
- T-WAVE1A-04-04 (numeric drift Flutter ↔ Python) — 21 unit tests assert per-analysis behavior; 78 `# MIRROR Dart <file>:<line>` traceability comments + 15 + 8 + 8 + 9 + 4 dart-file citations enable line-by-line cross-review; plan-07 parity harness will add 3-archetype Julien/Lauren cross-validation. ✓
- T-WAVE1A-04-05 (silent delegation to incompatible Python services) — `grep -c 'AvsEstimationService\|FiscalService.estimateTax' couple_optimizer.py` returns 0 (post-Deviation #1 fix). ✓
- T-WAVE1A-04-06 (profile.data shape mismatch crashes coach loop) — `_compute_couple_optimization` catches broad `Exception` and falls back to legacy formatter (Test 6 asserts ValueError → legacy fallback); `CoupleOptimizer.optimize` uses `.get()` for all profile_data reads (no KeyError). ✓
- T-WAVE1A-04-07 (enum-string serialization drift Dart↔Python) — resolved at plan-time via the `CoupleAnalysisResult.toJson|CoupleWinner` grep (0 toJson matches → snake_case Python values chosen). Decision recorded above + plan-07 parity test will catch any future Dart serialization. ✓

## Self-Check: PASSED

All success criteria met:
- [x] Task 1 executed: Python port + Pydantic v2 model + 21 unit tests (≥18 mandatory + 2 Pydantic/accent integrity + 1 to_legacy_dict bonus).
- [x] Task 2 executed: `_compute_couple_optimization` dispatcher inside markers (preserved exactly) + 9 dispatcher tests (≥7 mandatory).
- [x] All 30 plan-04 tests pass (`pytest test_couple_optimizer.py test_coach_tools_couple_optimization.py -q` → `30 passed in 0.25s`).
- [x] Full backend pytest exits 0 with zero regressions (6822 passed).
- [x] Marker integrity preserved: `grep -c "# >>> dispatch: "` returns exactly 6 (unchanged); `grep -c "# >>> dispatch: get_couple_optimization"` returns 1.
- [x] Anti-fabrication grep clean: `grep -c "AvsEstimationService\|FiscalService.estimateTax" couple_optimizer.py` returns 0.
- [x] 78 `# MIRROR Dart` traceability comments + 15 + 8 + 8 + 9 + 4 dart-file citations (well above the ≥10/≥4/≥3/≥3 plan thresholds).
- [x] `python3 tools/checks/accent_lint_fr.py --file` exits 0 on both new files (FR strings byte-identical to Dart).
- [x] `python3 tools/checks/banned_terms_python.py` exits 0 on both new files; pre-existing baseline failure in `coach_chat.py:3637` documented and verified pre-existing (commit `30c6d2b6e`, 2026-04-17).
- [x] 2 task commits (one per task): `ca55a3cc` (Task 1) + `b21f2839` (Task 2).
- [x] SUMMARY.md at `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-04-SUMMARY.md` with 0-trust receipts.
- [x] STATE.md / ROADMAP.md NOT updated (per orchestrator instruction).
- [x] Did NOT push, did NOT open PR (per orchestrator instruction — verification phase handles PR creation).

---
*Phase: wave-1a-backend-tools-refactor*
*Plan: 04*
*Completed: 2026-05-14*
