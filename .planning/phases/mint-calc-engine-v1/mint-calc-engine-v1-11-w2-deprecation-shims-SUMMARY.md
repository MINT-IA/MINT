---
phase: mint-calc-engine-v1
plan: 11
subsystem: backend.services.segments
tags: [scope-correction, w0-audit-fix, deferred, w2-wave-close]
dependency_graph:
  requires: [01]
  provides: [W0-AUDIT-MATRIX-correction, deferred-items.S12-API-consolidation]
  affects: [services/backend/app/services/independant_service.py, services/backend/app/services/frontalier_service.py, .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md, .planning/phases/mint-calc-engine-v1/deferred-items.md]
tech_stack:
  added: []
  patterns: [scope-correction, sister-services-vs-duplicates]
key_files:
  created: []
  modified:
    - services/backend/app/services/independant_service.py
    - services/backend/app/services/frontalier_service.py
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md
    - .planning/phases/mint-calc-engine-v1/deferred-items.md
decisions:
  - id: D-CE-10-reclassification
    summary: "W0-AUDIT-MATRIX rows 32+35 reclassified — root services are NOT shims, they are S12 sister services with monolithic APIs (S12 vs S18/S23 functional/granular split). Naive shim would break segments.py."
  - id: defer-S12-API-consolidation
    summary: "Real API consolidation (monolithic vs functional/granular) deferred to a future plan after Wave 3 — requires panel synthesis, naming collision resolution, 5-caller migration."
metrics:
  duration_minutes: 12
  completed_date: 2026-05-16
  commits: 2
  tests_added: 0
  tests_total: 7136
  files_modified: 4
  files_created: 0
---

# Phase mint-calc-engine-v1 Plan 11: W2 Deprecation-Shims Summary

**One-liner :** Plan delivered the architectural value its mechanical task list could not — caught and corrected a W0-AUDIT-MATRIX misclassification (rows 32+35) before it shipped broken `from <canonical> import *` shims into `segments.py`, then documented the real S12-vs-S18/S23 API consolidation question as a deferred plan.

## Objective vs Outcome

| Dimension | Original PLAN objective | Outcome (scope correction) |
|-----------|------------------------|----------------------------|
| Mechanical task | Replace 2 root files with 1-line `from app.services.{independants,expat.frontalier_service} import *` shims emitting `DeprecationWarning` | NOT EXECUTED — pre-flight grep proved both shims would break callers |
| Test artifact | Create `test_independant_shim.py` + `test_frontalier_shim.py` (3 tests each) | NOT CREATED — nothing to test (no shim shipped) |
| Real deliverable | (none in original PLAN) | W0-AUDIT-MATRIX reclassification + S12-lineage docstrings + deferred-items entry « S12-API-consolidation » |

The mechanical objective was unachievable because **the premise was false**. The W0 audit had labelled two Sprint S12 services as « deprecated shims » when they are in fact canonical sister services. The orchestrator confirmed Option A (scope correction) after the checkpoint return.

## Why The Naive Shim Was Impossible (Pre-flight Findings)

Two independent failure modes, both confirmed by Read + grep at execution time:

### 1. `independant_service.py` — import-time break

ROOT `services/backend/app/services/independant_service.py` exposes :

```python
class IndependantInput        # services/backend/app/services/independant_service.py:72
class IndependantResult       # services/backend/app/services/independant_service.py:84
class IndependantService      # services/backend/app/services/independant_service.py:114
   .analyze(input_data) -> IndependantResult   # line 194
DISCLAIMER                    # module-level constant, line 100
# Module-level aliases (imported by callers):
AVS_FULL_RATE, AVS_MINIMUM_CONTRIBUTION,
PLAFOND_3A_INDEPENDANT_MAX, PLAFOND_3A_SALARIE  # lines 26-35 (aliased imports)
```

Canonical `services/backend/app/services/independants/__init__.py:37-48` exposes :

```python
__all__ = [
    "calculer_cotisation_avs", "AvsCotisationResult",
    "simuler_ijm", "IjmResult",
    "calculer_3a_independant", "Pillar3aIndepResult",
    "simuler_dividende_vs_salaire", "DividendeVsSalaireResult",
    "simuler_lpp_volontaire", "LppVolontaireResult",
]
```

`from app.services.independants import *` would import **zero** of the symbols required by callers. `segments.py:29` would raise `ImportError: cannot import name 'IndependantService' from 'app.services.independant_service'` at FastAPI app boot.

### 2. `frontalier_service.py` — same-name-different-API runtime trap

ROOT `services/backend/app/services/frontalier_service.py` exposes :

```python
class FrontalierInput      # line 225
class FrontalierResult     # line 239
class FrontalierService    # line 271
   .analyze(FrontalierInput) -> FrontalierResult  # line 278
PAYS_FRONTALIERS = {"FR","DE","IT","AT","LI"}     # line 44
COUNTRY_RULES: Dict[str, dict] = {...}            # line 57
```

Canonical `services/backend/app/services/expat/frontalier_service.py:378` exposes a class with the **same name** but **completely different methods** :

```python
class FrontalierService:
    def calculate_source_tax(...) -> SourceTaxResult       # line 391
    def check_quasi_resident(...) -> QuasiResidentResult   # line 496
    def simulate_90_day_rule(...) -> NinetyDayRuleResult   # line 570
    def compare_social_charges(...) -> SocialChargesComparison  # line 646
    def estimate_lamal_option(...) -> LamalOptionResult    # line 736
```

`from app.services.expat.frontalier_service import *` would **silently replace** `segments.py:34`'s `_frontalier_service = FrontalierService()` with the S23 class. The next call `_frontalier_service.analyze(input_data)` (line 99) would raise `AttributeError: 'FrontalierService' object has no attribute 'analyze'` at the first `/api/v1/segments/frontalier/simulate` request — a silent-at-import, loud-at-runtime trap. Unit tests catch nothing because `test_segments.py` already imports `FrontalierService` from `app.services.frontalier_service` directly, so the shim would test itself green while production breaks.

## Caller Sites (Full Audit, 5 Sites)

Grep `services/backend/ apps/ tools/` on 2026-05-16T21:35Z :

| File:line | Imports | Breakage under naive shim |
|---|---|---|
| `services/backend/app/api/v1/endpoints/segments.py:28` | `from app.services.frontalier_service import FrontalierService, FrontalierInput` | `AttributeError` at runtime on `.analyze()` (homonymous class collision) |
| `services/backend/app/api/v1/endpoints/segments.py:29` | `from app.services.independant_service import IndependantService, IndependantInput` | `ImportError` at boot (`IndependantService` not in canonical S18 `__all__`) |
| `services/backend/tests/test_segments.py:22-26` | `from app.services.frontalier_service import (FrontalierService, FrontalierInput, PAYS_FRONTALIERS,)` | `ImportError` at boot (`PAYS_FRONTALIERS` not in S23 module — S23 has no `PAYS_FRONTALIERS` set) |
| `services/backend/tests/test_segments.py:27-34` | `from app.services.independant_service import (IndependantService, IndependantInput, AVS_FULL_RATE, AVS_MINIMUM_CONTRIBUTION, PLAFOND_3A_INDEPENDANT_MAX, PLAFOND_3A_SALARIE,)` | `ImportError` at boot (none of those symbols in S18 `__all__`) |
| `services/backend/tests/test_independant_service.py:21-25` | `from app.services.independant_service import (IndependantInput, IndependantService, DISCLAIMER,)` | `ImportError` at boot (none of those symbols in S18 `__all__`) |

External callers (`apps/`, `tools/`) : grep clean, 0 matches.

## What This Plan Actually Shipped

### 1. W0-AUDIT-MATRIX rows 32 + 35 reclassified

`.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` line 140 (was) :

```
| 32 | independant_service (shim) | independant_service.py (root) | n/a | … | Deprecated shim ; routes to independants/ (D-CE-10) |
```

After Plan 11 patch (same line 140, expanded) :

```
| 32 | independant_service (S12) | independant_service.py (root) | (consumed by /api/v1/segments/independant/simulate via app.api.v1.endpoints.segments) | … | **NOT a duplicate** — sister service from Sprint S12 (« segments sociologiques »). Exposes monolithic IndependantService.analyze(IndependantInput) -> IndependantResult + 4 module-level constants (AVS_FULL_RATE, AVS_MINIMUM_CONTRIBUTION, PLAFOND_3A_INDEPENDANT_MAX, PLAFOND_3A_SALARIE) + DISCLAIMER. Canonical independants/ (Sprint S18) exposes a different functional API (5 calculer_* functions + 5 *Result dataclasses, no class). Future consolidation requires API design decision (monolithic class vs functional split). **Reclassified 2026-05-16 via Plan 11 scope correction.** See .planning/deferred-items.md entry « S12-API-consolidation ». |
```

Row 35 patched in parallel (audit-matrix line 148, was) :

```
| 35 | frontalier_service (root) | frontalier_service.py (deprecated) | n/a | … | Deprecated shim ; to be removed (D-CE-10) |
```

After patch :

```
| 35 | frontalier_service (S12) | frontalier_service.py (root) | (consumed by /api/v1/segments/frontalier/simulate via app.api.v1.endpoints.segments) | … | **NOT a duplicate** — sister service from Sprint S12 … Sister expat/frontalier_service.py (Sprint S23) defines a class with the same name FrontalierService but a completely different surface … Homonymous classes, incompatible APIs … **Reclassified 2026-05-16 via Plan 11 scope correction.** See .planning/deferred-items.md entry « S12-API-consolidation ». |
```

### 2. Module-level docstrings on both root files

Both root files now bear S12-lineage docstrings as the first block in the file :

- `services/backend/app/services/independant_service.py:1-37` — new docstring explicitly references the S18 `app.services.independants` functional API as the sister surface and points to `deferred-items.md` entry « S12-API-consolidation ».
- `services/backend/app/services/frontalier_service.py:1-49` — new docstring explicitly flags the S23 homonymous `FrontalierService` class in `app.services.expat.frontalier_service` (different methods : `calculate_source_tax`, `check_quasi_resident`, etc.) to prevent future import confusion.

Zero behavioral change. The classes, methods, constants, dataclasses, and module structure of both files are byte-identical except for the docstring prefix.

### 3. `.planning/deferred-items.md` entry « S12-API-consolidation »

New entry (`.planning/deferred-items.md:3-37`) lists :

- The misclassification context with audit-matrix line references (140 + 148)
- The real consolidation question per domain (independants : monolithic class vs functional split / frontaliers : monolithic vs granular + naming collision on `FrontalierService`)
- The 5 caller sites that would need migration in a real consolidation
- The required design artifacts (panel synthesis, semantic decision on `lacunes`/`urgences`/`checklist`, naming-collision resolution)
- Why this scope correction is the right outcome vs forcing the shim or bloating Plan 11 into a 2-3-plan refactor
- A second entry tracking the pre-existing banned-term meta-mentions in the « Ethical requirements » docstring blocks (out-of-scope per `<deviation_rules>` SCOPE BOUNDARY)

Status : **OPEN — schedule after Wave 3** (composite index migration) and before any future « calc engine consolidation » milestone.

## Why The Original PLAN Premise Failed

W0-AUDIT-MATRIX rows 32 + 35 (built 2026-05-15, line 131 header reads « Independants / Self-Employed (5 calculators + 1 duplicate) ») assumed file-name duplication implied semantic duplication. The audit walker did not Read the file contents or grep callers, so it labelled any module-name-vs-package-name overlap as a candidate D-CE-10 shim target. This is the **second** D-CE-10 misclassification surfaced in Wave 2 (the first was unrelated, caught in Plan 09 deviation #2 substring scan). The pattern suggests the W0 audit pass should be re-run with a Read-based duplicate check before any further D-CE-10 plans.

## Deviations from Plan

### Scope correction (architectural override per `<deviation_protocol>`)

**Trigger** : pre-flight grep (Task 0) proved the plan's core mechanical premise (« 1-line `from X import *` shims with re-export coverage ») was impossible without first consolidating the S12 vs S18/S23 APIs, which is itself a 2-3-plan architectural effort.

**Action taken** : returned checkpoint to orchestrator with 3 options (A reclassify / B defer / C consolidate). Orchestrator confirmed Option A (scope correction). Executed end-to-end : audit-matrix reclassification + docstrings + deferred-items entry + STATE + ROADMAP + HTML.

**Auto-fixed issues** : 0 (the entire plan was a scope correction, not an inline auto-fix).

**Out-of-scope items logged to deferred-items.md** : pre-existing banned-term meta-mentions in the « Ethical requirements » docstrings of both root files (lines independant:34 + frontalier:46). Pre-Plan-11 in HEAD (verified via `git show HEAD:services/backend/app/services/independant_service.py | grep garanti` → line 18 pre-edit). The Edit only pushed those lines from 18 → 34 and 26 → 46. Out of Plan 11 scope.

## Verification

### Mechanical gates (deterministic citations, 0-trust §9.6)

| Gate | Command | Output | Evidence |
|------|---------|--------|----------|
| Regression suite | `cd services/backend && python3 -m pytest tests/ -q` | **`7136 passed, 62 skipped, 3 xfailed, 1 warning in 114.01s`** | exact baseline preserved (Plan 10 closed at 7136 ; no tests added/removed by Plan 11) |
| FR accent lint | `python3 tools/checks/accent_lint_fr.py --scope backend` | **exit 0** | new docstrings use ASCII (consistent with existing docstring style in both files) |
| LSFin banned-terms | `python3 tools/checks/banned_terms_python.py services/backend/app/services/{independant,frontalier}_service.py` | exit 1 — 2 pre-existing meta-mentions at independant:34 + frontalier:46 (« NEVER use "garanti"... » in « Ethical requirements » docstring block, pre-Plan-11 verified via `git show HEAD:`) | out-of-scope per SCOPE BOUNDARY ; logged to deferred-items.md |
| Grep callers (post-plan, sanity) | `grep -rn "from app.services.independant_service\|from app.services.frontalier_service" services/backend/ apps/ tools/` | 5 hits, all unchanged (segments.py:28-29, test_segments.py:22-27, test_independant_service.py:21) | naive shim NOT shipped → callers continue to work via the existing S12 root modules |

### USER VALUE DELIVERED

Zero end-user-visible change. The scope correction is **infrastructure-level** : it prevents a future agent (human or LLM) from forcing the broken D-CE-10 shim, and it documents the real consolidation question. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev` branch, no PR opened by this plan).

### What I HAVE NOT done (CLAUDE.md §9.6 caveats)

- **DID NOT consolidate** the S12 vs S18/S23 APIs — that's a future plan (panel synthesis + design + migration of 5 callers). Tracked in deferred-items.md.
- **DID NOT delete** either root file. Both remain canonical S12 services.
- **DID NOT create** any shim. The « shim » concept is provably wrong for these two files at this time.
- **DID NOT modify** any caller (`segments.py`, `test_segments.py`, `test_independant_service.py`). Behavioral parity preserved.
- **DID NOT fix** the pre-existing « garanti » docstring meta-mentions (lines independant:34 + frontalier:46). Out of scope ; logged to deferred-items.md.
- **DID NOT run** Maestro G1 sim flow — there is no UI surface to verify (this plan touches docstrings + planning artifacts only).
- **DID NOT open** a PR. Direct commits on `dev` branch as with every other Plan in this phase.
- **DID NOT push** to remote. Local `dev` only.
- **DID NOT verify** via `engram mem_search` upstream the absence of prior conflicting decisions — engram CLI ran `search "D-CE-10 deprecation shim independant frontalier"` returned « No memories found » at execution start (engram observation #134 saved post-checkpoint).
- **DID NOT re-run** the W0 audit pass with the new duplicate-detection heuristic. The matrix correction is row-32-and-35-local. A broader audit re-run is a future plan if other D-CE-10 plans are written.

## Commits

| sha | message | scope |
|---|---|---|
| `0a15dd63` | `docs(mint-calc-engine-v1-11): S12 lineage docstrings on root segments services` | services/backend/app/services/{independant,frontalier}_service.py (docstrings only) |
| (pending) | `docs(mint-calc-engine-v1-11): scope-correction — reclassify W0 rows 32+35 + SUMMARY + STATE + ROADMAP` | .planning/ artifacts |

## Engram

**Observation #134** (saved 2026-05-16T21:35Z via `engram` CLI fallback) — title : « D-CE-10 Plan 11 deprecation shims BLOCKED: API mismatch ». Captured the pre-flight diagnostic before the orchestrator decision. Topic key `mint-calc-engine-v1:w2-plan-11:deprecation-shims-blocked`, type `architecture`.

**Observation pending** (this SUMMARY) — to be saved via `mem_save` MCP if exposed, else CLI fallback. Topic key `mint-calc-engine-v1:w2-plan-11:scope-correction-shipped`, type `architecture`, `prior_finding_refs` citing #103 (Wave 1/2 architecture synthesis), #128 (Wave 1 closure), #134 (this plan's blocked diagnostic). Body : « Plan 11 closed as scope correction. W0-AUDIT-MATRIX rows 32+35 reclassified — root services are sister S12 services, not duplicates. S12-API-consolidation deferred to a future plan with the open design questions (monolithic vs functional, naming collision on FrontalierService class). 7136 backend tests preserved. Zero behavioral change. »

## Self-Check: PASSED

- [x] `.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` line 140 reclassified — `grep -n "Reclassified 2026-05-16 via Plan 11" .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` returns 2 hits
- [x] Same file line 148 reclassified — same grep above
- [x] `services/backend/app/services/independant_service.py:4-18` carries new S12-lineage docstring — Read-verified
- [x] `services/backend/app/services/frontalier_service.py:4-22` carries new S12-lineage docstring with explicit `FrontalierService` collision warning — Read-verified
- [x] `.planning/deferred-items.md` carries the « S12-API-consolidation » entry — Read-verified at lines 3-37
- [x] Commit `0a15dd63` exists — `git log --oneline -1` shows it as HEAD
- [x] Regression suite green — `7136 passed, 62 skipped, 3 xfailed, 1 warning in 114.01s`
- [x] No imports rewritten, no tests deleted, no shims created — `git diff HEAD~1` shows only docstring + planning-artifact additions
- [x] Engram observation #134 saved — engram CLI confirmed « Memory saved: #134 »
