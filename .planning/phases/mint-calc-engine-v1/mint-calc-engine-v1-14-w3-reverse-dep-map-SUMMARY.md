---
phase: mint-calc-engine-v1
plan: 14
subsystem: backend / calculators / reverse-dep map
tags: [d-ce-14, w3, reverse-dep-map, kills-two-birds, override-5, pre-compute-prep, contract-tests]
description: W3 Plan 14 ships the D-CE-14 reverse-dep map test contract locking the API Plan 15 (BackgroundTasks pre-compute) consumes. REVERSE_DEP_MAP itself was already shipped by Plan 05 ("kills two birds" per Override #5).
requires:
  - mint-calc-engine-v1-05 (REVERSE_DEP_MAP + get_reverse_deps shipped via AST walker)
  - mint-calc-engine-v1-13 (get_or_compute consumer of pre-compute downstream)
provides:
  - services/backend/tests/test_reverse_deps.py — 7 contract tests locking the D-CE-14 API shape
  - Q4 doctrine resolution noted (direct deps only in v1)
affects:
  - Plan 15 BackgroundTasks pre-compute (will iterate get_reverse_deps(mutated_field) to select downstream cache rows to invalidate)
  - Plan 16 GC job (will compact superseded chains driven by reverse-dep cascades)
  - D-CE-14 SLO downstream (mint_calc_warm.recall ≥ 70% target ; if missed, Q4 follow-up adds derived-field coupling)
tech-stack:
  added: []
  patterns:
    - "Test-only plan locking pre-existing API contract — when an earlier plan ships infrastructure as a side product ('kills two birds'), the later plan's job is the test surface, not the prod code"
    - "Override #5 'kills two birds' validated end-to-end : Plan 05 AST walker emits both REGISTRY (D-CE-11) and REVERSE_DEP_MAP (D-CE-14) from the same scan ; Plan 14 confirms no code dedup needed"
key-files:
  created:
    - services/backend/tests/test_reverse_deps.py (223 LOC, 7 tests)
  modified: []
decisions:
  - "PLAN.md Test 5 had an inverted assertion. Plan claimed 'REVERSE_DEP_MAP keys ⊆ _PROFILE_SAFE_FIELDS (no drift)' — but the two sets describe DIFFERENT concerns. _PROFILE_SAFE_FIELDS (56 fields) is the LLM-coach PII whitelist ; REVERSE_DEP_MAP keys (146 fields) are internal calculator profile_fields_needed including intermediates like taux_marginal, a3a_maxed, rendement_3a that have no place in LLM context. Only 7 fields overlap by design (age, canton, conjoint_age, conjoint_salary, has_debt, marital_status, primary_focus). Reformulated Test 5 to assert the well-formed property : intersection non-empty + must-have anchors (canton, age) present in the bridge intersection."
  - "AC1 of PLAN.md acceptance asks 'grep -c REVERSE_DEP_MAP in _registry.py ≥ 3' ; actual is 2 (declaration + helper body usage). The 'maybe export' 3rd reference is in app/calculators/__init__.py, not _registry.py — functionally equivalent re-export pattern. Cosmetic AC drift, no functional impact."
  - "Q4 resolution kept at v1 floor : direct deps only. Derived-field coupling (e.g. marital_status → tax_bracket → lpp_rachat) deferred to follow-up triggered by W4 SLI mint_calc_warm.recall < 70%. Aligns with VALIDATION.md fallback."
  - "Plan 14 is test-only — Plan 05 already shipped REVERSE_DEP_MAP + get_reverse_deps. Test artifact pattern : an earlier plan emits infrastructure as a side product (Override #5 'kills two birds') ; the named follow-up plan's job is the explicit test surface + doctrine doc, not duplicating prod work."
patterns-established:
  - "Test surface for infrastructure shipped as a side product : the pattern documents which earlier plan emitted the prod code, then ships dedicated contract tests + Q-doctrine resolution. Future Plans 18 (banned-verb lint runtime gate) and 19 (profile-safe-fields parity) may follow the same shape."
requirements-completed: [D-CE-14]
metrics:
  duration_min: 8
  tasks_completed: 2
  tests_added: 7
  tests_passed_after: 7172
  tests_passed_before: 7165
  test_delta: "+7 (7 new test_reverse_deps tests ; zero regressions, zero new skips, zero new xfails)"
  completed_date: "2026-05-17"
---

# Phase mint-calc-engine-v1 Plan 14 : W3 Reverse-dep Map Contract Tests Summary

W3 Plan 14 ships the D-CE-14 reverse-dep map dedicated test surface (7 contract tests, 223 LOC) locking the API shape Plan 15 BackgroundTasks pre-compute consumes. The map itself (`REVERSE_DEP_MAP: Dict[str, Set[str]] = {...}` with 146 fields ; `canton → 25 calcs` ; `age → 6 calcs`) was already shipped by Plan 05 per Override #5 "kills two birds" — the same AST walker emits both `REGISTRY` and `REVERSE_DEP_MAP`. Plan 14 is therefore test-only + Q4 doctrine resolution ; zero production code changes.

## One-liner

D-CE-14 reverse-dep map contract locked by 7 tests (canton ≥20, age ≥5, unknown returns set(), idempotent --check, no orphan calc names) ; PLAN.md Test 5 inverted-assertion deviation reframed ; full regression 7165 → 7172 (+7, zero regressions) ; Plan 15 BackgroundTasks pre-compute now has a stable consumption surface.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | test_reverse_deps.py — 7 D-CE-14 contract tests | GREEN (7/7 pass against Plan 05 scaffold) | `2b1eb5f4` |
| 2 | Engram + Q4 resolution + SUMMARY | GREEN (engram #139, Q4 v1 floor doctrine documented) | pending (this docs commit) |

## Files Created / Modified

**Created** (1 file, 223 LOC) :

- `services/backend/tests/test_reverse_deps.py` (223 LOC, 7 tests) — D-CE-14 reverse-dep map contract tests with detailed module docstring explaining the Test 5 reformulation rationale.

**Modified** : none.

Plan 05's auto-generated artifact (`services/backend/app/calculators/_registry.py`) was NOT modified — `--check` already exits 0, meaning the map is fresh.

## Verification Evidence (0-TRUST §9.6, citations only)

| Claim | Evidence |
|-------|----------|
| `services/backend/tests/test_reverse_deps.py` exists (223 LOC, 7 tests) | `wc -l services/backend/tests/test_reverse_deps.py` → `223 services/backend/tests/test_reverse_deps.py` ; pytest collects 7 tests |
| 7/7 contract tests green | `cd services/backend && python3 -m pytest tests/test_reverse_deps.py -q -x` → `7 passed in 0.28s` |
| REVERSE_DEP_MAP non-empty (146 fields) | `python3 -c "from app.calculators import REVERSE_DEP_MAP; print(len(REVERSE_DEP_MAP))"` → `146` |
| canton anchor has 25 dependent calcs (≥20 floor) | `python3 -c "from app.calculators import REVERSE_DEP_MAP; print(len(REVERSE_DEP_MAP.get('canton', set())))"` → `25` |
| age anchor has 6 dependent calcs (≥5 floor) | `python3 -c "from app.calculators import REVERSE_DEP_MAP; print(len(REVERSE_DEP_MAP.get('age', set())))"` → `6` |
| get_reverse_deps(unknown) returns set() | `python3 -c "from app.calculators import get_reverse_deps; print(repr(get_reverse_deps('nonexistent_field_xyz_42')))"` → `set()` |
| Generator --check exits 0 (idempotent) | `python3 tools/generate_calc_registry.py --check` → `OK : registry is fresh.` ; `echo $?` → `0` |
| Every calc name in REVERSE_DEP_MAP values ∈ REGISTRY.keys() | T7 green ; orphan check returns empty dict at runtime |
| canton+age present in REVERSE_DEP_MAP ∩ _PROFILE_SAFE_FIELDS bridge | T5 green ; intersection contains 7 fields ≥ floor of 5 |
| Full regression : 7172 passed (+7 vs Plan 13 baseline 7165) | Pre-Plan-14 : `7165 passed, 63 skipped, 3 xfailed`. Post-Plan-14 : `7172 passed, 63 skipped, 3 xfailed, 1 warning in 115.25s`. Delta = exactly +7 (the 7 new tests). Zero regressions. |
| banned_terms_python lint clean | `python3 tools/checks/banned_terms_python.py services/backend/tests/test_reverse_deps.py` → exit 0, no stdout |
| accent_lint_fr backend clean | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0 |
| Engram observation persisted | `engram save ... --project mint --type architecture --topic_key mint-calc-engine-v1:w3-plan-14:reverse-dep-map` → `Memory saved: #139` |
| Task 1 commit chain | `2b1eb5f4 test(mint-calc-engine-v1-14): D-CE-14 reverse-dep map contract — 7 tests` ; docs commit pending |

## Sample API Probe (citation for Plan 15 consumer)

```
$ python3 -c "from app.calculators import REGISTRY, REVERSE_DEP_MAP, get_reverse_deps
print('REGISTRY=', len(REGISTRY))
print('REVERSE_DEP_MAP=', len(REVERSE_DEP_MAP))
print('canton deps=', sorted(REVERSE_DEP_MAP['canton'])[:3])
print('age deps=', sorted(REVERSE_DEP_MAP['age'])[:3])
print('nonexistent=', get_reverse_deps('nonexistent_field_xyz_42'))"

REGISTRY= 63
REVERSE_DEP_MAP= 146
canton deps= ['affordability_service__AffordabilityService_calculate_affordability', ...]
age deps= ['calculator__UnemploymentCalculator_calculate', ...]
nonexistent= set()
```

Plan 15 BackgroundTasks consumer template (reference) :

```python
from app.calculators import get_reverse_deps
from app.services.cache import get_or_compute

async def on_profile_field_mutation(field_name: str, profile_id: int, db, ...):
    for calc_name in get_reverse_deps(field_name):  # static map, O(1)
        # ... schedule pre-compute via get_or_compute(profile_id, calc_name, ...)
```

## Deviations from Plan

### Rule 1 — Auto-fixed bugs

**1. [Rule 1 - Bug] PLAN.md Test 5 had an inverted assertion**

- **Found during** : Task 1 RED pre-check (probed `REVERSE_DEP_MAP.keys() vs _PROFILE_SAFE_FIELDS` set intersection before writing the test).
- **Issue** : PLAN.md Test 5 reads « REVERSE_DEP_MAP keys are all valid profile field names from _PROFILE_SAFE_FIELDS canonical list at coach_chat.py:875 (no drift). » This assertion cannot pass because the two sets describe different concerns :
  - `_PROFILE_SAFE_FIELDS` (56 fields) = LLM-coach PII whitelist : narrow set of user-facing fields safe to pass to Claude (age, canton, monthly_income, ...).
  - `REVERSE_DEP_MAP` keys (146 fields) = internal calculator `profile_fields_needed` declarations including intermediate values like `taux_marginal`, `a3a_maxed`, `rendement_3a`, `potentiel_rachat_lpp` — none of which belong in LLM context.
  - Intersection : 7 fields by design (age, canton, conjoint_age, conjoint_salary, has_debt, marital_status, primary_focus).
- **Fix** : Reformulated Test 5 to assert the well-formed property — the bridge intersection (a) contains the must-have anchor fields (`canton`, `age`) and (b) is non-trivial (≥5 fields). This is what Plan 15 BackgroundTasks pre-compute actually relies on : the subset of mutation-eligible LLM-driven profile fields that also have downstream calc dependencies.
- **Files modified** : `services/backend/tests/test_reverse_deps.py` (Test 5 + detailed module docstring explaining the reframing).
- **Verification** : T5 green ; intersection = {age, canton, conjoint_age, conjoint_salary, has_debt, marital_status, primary_focus} = 7 fields ≥ floor of 5.
- **Committed in** : `2b1eb5f4` (Task 1).

**2. [Rule 1 - Bug, cosmetic] PLAN.md AC1 expected ≥3 `REVERSE_DEP_MAP` refs in `_registry.py` ; actual is 2**

- **Found during** : Task 1 acceptance criteria sweep.
- **Issue** : PLAN.md AC1 « `grep -c "REVERSE_DEP_MAP" services/backend/app/calculators/_registry.py` returns ≥3 (declaration + helper + maybe export) ». Actual count is 2 — declaration at line 475 + helper body usage at line 1034. The « maybe export » 3rd reference is in `app/calculators/__init__.py` (the package-level re-export), not in `_registry.py` itself.
- **Fix** : None needed — functionally equivalent. The export route is via `__init__.py` re-export, which is the standard Python package shape (PEP 8 / private-`_module.py` + public `__init__.py` re-export). Cosmetic AC drift, no functional impact.
- **Files modified** : none.
- **Verification** : `grep -rn "REVERSE_DEP_MAP" services/backend/app/calculators/` → 4 references total (2 in `_registry.py`, 2 in `__init__.py` for the import + `__all__` listing).

### Rule 2-4 deviations

None. No missing critical functionality (Rule 2) — Plan 05 shipped the production surface. No blocking issues (Rule 3). No architectural escalation (Rule 4).

## Q4 Resolution (« Reverse-dep-map handling of derived fields »)

Per VALIDATION.md Q4 fallback : **DIRECT DEPS ONLY in v1**. Derived-field coupling (transitive deps) deferred to follow-up triggered by W4 SLI `mint_calc_warm.recall < 70%`.

Example of deferred coupling : `marital_status` mutation theoretically affects `lpp_rachat_calculator` via tax bracket reshaping ; in v1 we only invalidate calcs that declare `marital_status` directly in their `profile_fields_needed`. If Plan 17 metrics surface a recall miss-rate above the threshold, follow-up adds either (a) a hand-curated derived-coupling table or (b) an auto-discovered graph via static call-tree analysis.

## Threat Surface Notes

Plan 14 `<threat_model>` STRIDE entries (no new threat surface) :

- **T-mint-calc-14-01 Tampering manual REVERSE_DEP_MAP edit** → **mitigated**. Test T6 asserts `--check` idempotency ; any hand edit fails CI immediately.
- **T-mint-calc-14-02 Information disclosure dep-map content** → **accepted**. Map contains internal calc names + profile field names — no user data, no PII.
- **T-mint-calc-14-03 DoS reverse-dep lookup** → **accepted**. `get_reverse_deps(field)` is O(1) dict lookup ; no DoS surface.
- **T-mint-calc-14-04 LSFin** → **accepted**. No financial claim surface ; the map is plumbing.

## Deployment Notes (carried forward to Plan 15)

- **No deploy step** : Plan 14 is test-only. CI runs `pytest tests/` on next push to `dev` ; the 7 new tests gate the contract.
- **Plan 15 wire-up** : the BackgroundTasks consumer signature is documented in this SUMMARY ("Sample API Probe" section). Plan 15 will import `from app.calculators import get_reverse_deps` and iterate the returned set, dispatching `get_or_compute()` per calc.
- **Generator `--check` CI wiring still deferred** : Plan 05 Q2 TODO ("add `python3 tools/generate_calc_registry.py --check` step to `.github/workflows/backend-tests.yml`") remains unchanged. Plan 17 (metrics counters) or Plan 18 (banned-verb lint runtime gate) are still the likely landing spot.

## What I Have NOT Done (caveats / 0-TRUST §9.6)

- Did NOT modify production code. REVERSE_DEP_MAP + get_reverse_deps already shipped by Plan 05. Plan 14 is test-only.
- Did NOT wire `tools/generate_calc_registry.py --check` into `.github/workflows/backend-tests.yml`. Plan 05 Q2 TODO remains. Adding this gate is on the Plan 17/18 backlog.
- Did NOT verify map exhaustiveness against W0-AUDIT-MATRIX field-by-field. The 146-field count is heuristic-derived ; calculators that declare `profile_fields_needed` dynamically (none found at scan time) would be silently missed.
- Did NOT touch Plan 15 BackgroundTasks consumer code — wire-up is Plan 15's scope.
- Did NOT add derived-field coupling — Q4 v1 floor doctrine is direct deps only.
- Did NOT open a PR. Plan 14 ships direct on `dev` per current GSD sequential model. Per CLAUDE.md §9.5 « PR opened ≠ shipped » — also test code only, no user-visible behavior change.
- Did NOT merge `dev → staging`. Wave 3 staging promotion happens after Plan 16 (GC job) closes the wave.
- Did NOT run Maestro G1. Plan 14 has no UI surface, no endpoint added.
- Did NOT call MCP `mem_save` tool — not exposed in this session's tool list. Engram CLI fallback used per `<mint_infra_contract>` ; observation **#139** persisted.
- Per CLAUDE.md §9 : tests green ≠ feature working. The D-CE-14 reverse-dep selection is NOT user-visible until Plan 15 BackgroundTasks pre-compute consumes `get_reverse_deps()`.

## Engram

Observation **#139** persisted via CLI fallback :

```
engram save "D-CE-14 W3 Plan 14 reverse-dep map test contract shipped" \
  --project mint --type architecture \
  --topic_key mint-calc-engine-v1:w3-plan-14:reverse-dep-map
```

`prior_finding_refs` documented in body : Plan 05 obs (registry scaffold ; `calc_engine:w1:calc_registry_ast_scaffolded` — not currently surfaced in `engram search` against this DB), Plan 13 obs #138 (cache `get_or_compute` consumer), #131 (Plan 09 Concern A), #129 (Plan 07 ToolRegistryAdapter), #127 (W1 complete), #118 (phase planned).

## Self-Check : PASSED

Verified before SUMMARY commit :

1. `services/backend/tests/test_reverse_deps.py` exists → `[ -f ... ] && echo FOUND` returned FOUND (223 LOC).
2. Commit `2b1eb5f4` (test contract) reachable → present in `git log --oneline -3` immediately before this SUMMARY commit.
3. 7/7 tests green → `pytest tests/test_reverse_deps.py -q -x` → `7 passed in 0.28s`.
4. Full regression 7172 → cited verbatim above with +7 delta vs Plan 13 baseline 7165.
5. Generator `--check` exits 0 → idempotency verified, no `_registry.py` drift.
6. Engram observation #139 persisted via CLI fallback (MCP `mem_save` not exposed in this session's tool list, expected).
7. banned_terms_python clean + accent_lint_fr backend clean.
8. 0-TRUST §9.1-9.7 honored : every « green » / « shipped » claim above carries a citation (file path, command output, or pytest result).

## Next Plan

**Plan 15 — W3 BackgroundTasks pre-compute** wires `get_reverse_deps(mutated_field)` into a FastAPI BackgroundTasks dispatcher that issues `get_or_compute()` calls for each downstream calc, populating the D-CE-12 cache for next-request warm hits. The reverse-dep map contract this plan locks is the API surface Plan 15 consumes ; the cache layer Plan 13 shipped is the storage surface ; together they form the read-through + pre-compute spine of Wave 3.
