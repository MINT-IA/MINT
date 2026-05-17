---
phase: mint-calc-engine-v1
plan: 05
wave: 1
title: W1 — Calc registry AST scaffold (D-CE-11 + D-CE-14 seed)
type: execute
depends_on: [01]
files_modified:
  - tools/generate_calc_registry.py
  - services/backend/app/calculators/__init__.py
  - services/backend/app/calculators/_registry.py
  - services/backend/tests/test_calc_registry.py
autonomous: true
requirements: [D-CE-09, D-CE-11, D-CE-20]
estimated_duration: 4
must_haves:
  truths:
    - "`tools/generate_calc_registry.py` walks `services/backend/app/services/` and emits ≥40 calc entries (≥50 ideally — confirms baseline parity with W0 audit 57 calculators)"
    - "`services/backend/app/calculators/_registry.py` contains a `REGISTRY: dict[str, CalculatorMetadata]` with ≥40 entries"
    - "Each registry entry has `name`, `file`, `profile_fields_needed`, `life_events_served`, `output_type` keys per D-CE-11"
    - "Open question Q2 resolved: registry freshness is CI-only (lefthook adds in W2 only if drift becomes a problem)"
  artifacts:
    - path: tools/generate_calc_registry.py
      provides: "AST scanner over services/backend/app/services/ producing _registry.py"
      min_lines: 80
    - path: services/backend/app/calculators/_registry.py
      provides: "Generated CalculatorMetadata + REGISTRY dict + REVERSE_DEP_MAP seed"
      min_lines: 100
  key_links:
    - from: tools/generate_calc_registry.py
      to: services/backend/app/services/
      via: "ast.walk on each *.py file"
      pattern: "ast.parse|ast.walk|FunctionDef"
    - from: services/backend/app/calculators/_registry.py
      to: services/backend/app/services/
      via: "REGISTRY entry 'file' field references relative path"
      pattern: "services/backend/app/services"
---

<objective>
Ship the calc registry SCAFFOLDING. D-CE-11 mandates per-calculator metadata (name + file + profile_fields_needed + life_events_served + output_type) auto-generated from AST scan. D-CE-09 mandates registry-now / physical-consolidation-later (Strangler fig). D-CE-14 reverse-dep map is a SIDE PRODUCT of the same scan (« kills two birds » per Override #5).

Purpose: foundation artifact that W2 ToolRegistryAdapter consumes, W3 reverse-dep map consumes, W4 metrics labelling consumes. Ship the generator + first-pass artifact + tests proving ≥40 entries.

Output: 1 generator script + 1 generated registry module + 1 calculators package init + 1 test file. NO physical move of existing service files (D-CE-09 Phase A).

**Note: Open Q2 (lefthook freshness vs CI-only) is resolved here as CI-only. Adding a lefthook hook becomes a W2 task IF the registry shows drift in W2 PR-1.**
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md
@services/backend/app/services/
</context>

<interfaces>
<!-- Generator skeleton from RESEARCH §Q-G lines 975-1095 -->

```python
# tools/generate_calc_registry.py
import ast
from pathlib import Path

ROOT = Path("services/backend/app/services")
CALCULATOR_FUNC_PREFIXES = ("compute_", "simulate_", "compare_")

def find_calculators_in_module(path: Path) -> list[dict]: ...
def _scan_for_lucidity_marker(node: ast.FunctionDef, source: str) -> str: ...
def _heuristic_life_events_from_module(path: Path) -> list[str]: ...
def generate_registry() -> dict[str, dict]: ...
def generate_reverse_dep_map(registry: dict[str, dict]) -> dict[str, set[str]]: ...
```

CalculatorMetadata TypedDict / Pydantic shape (D-CE-11):
```python
class CalculatorMetadata(TypedDict):
    name: str
    file: str
    profile_fields_needed: list[str]
    life_events_served: list[str]
    output_type: Literal["L1", "L2", "L3", "L4"]
```

Life-event mapping (RESEARCH §Q-G line 1051-1063):
- `lpp_deep/` → `["retirement", "buyback"]`
- `family/` → `["family", "marriage"]`
- `mortgage/` → `["housing"]`
- `fiscal/` → `["taxes"]`
- `expat/` → `["cross_border"]`
- `independants/` → `["independent"]`
- `retirement/` → `["retirement"]`
- `debt_prevention/` → `["debt"]`
- `arbitrage/` → `["cross_cutting"]`
- `unemployment/` → `["career"]`
</interfaces>

<tasks>

<task id="W1-05-00" type="auto" tdd="false">
  <name>Task 0: Baseline scan — confirm W0 expected count vs reality</name>
  <files>(read-only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md (57 calculators expected, broken down across 11+ domains)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-G
  </read_first>
  <action>
    Before writing the scanner, run a manual baseline to set the expectation. Run these greps:

    1. `find services/backend/app/services -name "*.py" -not -name "_*" -not -name "__init__.py" | wc -l` — count of service modules.
    2. `grep -rE "^def (compute_|simulate_|compare_)" services/backend/app/services/ | wc -l` — module-level functions matching D-CE-11 calc-prefix heuristic.
    3. `grep -rE "^def (compute_|simulate_|compare_)" services/backend/app/services/ | sed 's/services\/backend\/app\/services\///' | head -30` — print first 30 hits to eyeball matches against W0 audit.

    Per D-CE-20 per-wave deepening, spot-check 5 services that the heuristic might MISS:
    - Class-method calculators (e.g. `class FooCalculator:\n    def compute(self, ...)`).
    - Service files with non-prefix function names (e.g. `def estimate_avs_rente(...)`).

    If the heuristic catches ≥50 of the 57 W0-audit calculators, ship as-is. If it catches <40, document the gap in this plan's SUMMARY (the AST scanner is a v1 best-effort artifact — D-CE-09 « registry-now / consolidate-later » means we expect drift to surface after W2 starts using the registry).
  </action>
  <verify>
    <automated>grep -rE "^def (compute_|simulate_|compare_)" services/backend/app/services/ | wc -l</automated>
  </verify>
  <acceptance_criteria>
    - Baseline count documented (executor records the number in SUMMARY).
    - If count < 40, executor surfaces a NOTE in SUMMARY: « AST heuristic catches X of W0's 57 calculators. Diff vs W0 audit captured ; W2 may need broader heuristic (class method scan / arbitrary function name list). »
  </acceptance_criteria>
  <done>Baseline count obtained, gap to W0 audit quantified</done>
</task>

<task id="W1-05-01" type="auto" tdd="true">
  <name>Task 1: AST scanner generator</name>
  <files>tools/generate_calc_registry.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-G (lines 975-1095)
    - services/backend/app/services/arbitrage/allocation_annuelle.py (sample module — function signatures)
    - services/backend/app/services/lpp_deep/rachat_echelonne_service.py (sample module)
    - services/backend/app/services/family/naissance_service.py (sample module with multi-fn structure)
  </read_first>
  <behavior>
    - Test 1: `find_calculators_in_module(Path("services/backend/app/services/arbitrage/allocation_annuelle.py"))` returns a list with at least 1 entry whose `name` ends with `_compute_allocation_annuelle` (or canonical equivalent) and `file` is `app/services/arbitrage/allocation_annuelle.py`.
    - Test 2: `generate_registry()` returns ≥40 entries (per Task 0 baseline).
    - Test 3: `generate_reverse_dep_map(registry)` returns a dict where keys are profile-field names and values are sets of calc names. For known field `canton`, the set contains ≥20 calcs (canton is in ~half the W0 calcs).
    - Test 4: `_heuristic_life_events_from_module(Path("services/backend/app/services/lpp_deep/rachat_echelonne_service.py"))` returns `["retirement", "buyback"]`.
    - Test 5: Running `python3 tools/generate_calc_registry.py --print` outputs valid Python module code (parseable by `ast.parse`).
  </behavior>
  <action>
    Create `tools/generate_calc_registry.py` matching RESEARCH §Q-G lines 975-1095 verbatim. Key points:

    1. Iterate `Path("services/backend/app/services").rglob("*.py")`. Skip `__init__.py` + `_*.py` files.
    2. For each file: `ast.parse(source, filename=str(path))`, walk tree, collect FunctionDefs matching `CALCULATOR_FUNC_PREFIXES = ("compute_", "simulate_", "compare_")`.
    3. For each match: emit dict `{"name": f"{path.stem}_{node.name}", "file": str(path.relative_to(Path("services/backend"))), "profile_fields_needed": <arg_names>, "life_events_served": <heuristic mapping>, "output_type": <_scan_for_lucidity_marker>}`.
    4. CLI behavior:
       - `python3 tools/generate_calc_registry.py` (no args) → WRITE to `services/backend/app/calculators/_registry.py`.
       - `python3 tools/generate_calc_registry.py --print` → STDOUT the generated module.
       - `python3 tools/generate_calc_registry.py --check` → diff against current `_registry.py`, exit 1 on drift.
    5. Generated module template:
       ```python
       # AUTO-GENERATED by tools/generate_calc_registry.py — DO NOT EDIT MANUALLY.
       # Regenerate: python3 tools/generate_calc_registry.py
       # CI check: python3 tools/generate_calc_registry.py --check (exits 1 on drift)
       from typing import TypedDict, Literal


       class CalculatorMetadata(TypedDict):
           name: str
           file: str
           profile_fields_needed: list[str]
           life_events_served: list[str]
           output_type: Literal["L1", "L2", "L3", "L4"]


       REGISTRY: dict[str, CalculatorMetadata] = {
           "allocation_annuelle_compute_allocation_annuelle": {
               "name": "allocation_annuelle_compute_allocation_annuelle",
               "file": "app/services/arbitrage/allocation_annuelle.py",
               "profile_fields_needed": ["montant_disponible", "canton", "is_property_owner", "taux_hypothecaire", "rendement_3a"],
               "life_events_served": ["cross_cutting"],
               "output_type": "L1",
           },
           # ... ~40-50 more entries
       }


       REVERSE_DEP_MAP: dict[str, set[str]] = {
           "canton": {"allocation_annuelle_compute_allocation_annuelle", "succession_simulator_compute_succession", ...},
           "age": {...},
           # ...
       }


       def get_calculator(name: str) -> CalculatorMetadata:
           if name not in REGISTRY:
               raise KeyError(f"Calculator '{name}' not in registry. Re-run tools/generate_calc_registry.py.")
           return REGISTRY[name]


       def get_reverse_deps(field_name: str) -> set[str]:
           return REVERSE_DEP_MAP.get(field_name, set())
       ```

    Lucidity marker scanner: scan for `# @lucidity: L<N>` magic-comment in the 5 lines above each FunctionDef (RESEARCH §Q-G line 1027-1034). Default `L1` if none found.
  </action>
  <verify>
    <automated>python3 tools/generate_calc_registry.py --print | python3 -c "import ast, sys; ast.parse(sys.stdin.read()); print('PARSEABLE')"</automated>
  </verify>
  <acceptance_criteria>
    - `tools/generate_calc_registry.py` exists, ≥80 lines
    - `python3 tools/generate_calc_registry.py --print | head -30` shows valid Python module syntax
    - `python3 tools/generate_calc_registry.py --print | python3 -c "import ast, sys; ast.parse(sys.stdin.read())"` exits 0 (parseable)
    - `python3 tools/generate_calc_registry.py --print | grep -c "REGISTRY:" ` returns 1
    - `grep -c "CALCULATOR_FUNC_PREFIXES" tools/generate_calc_registry.py` returns ≥1
    - `grep -c "@lucidity" tools/generate_calc_registry.py` returns ≥1
  </acceptance_criteria>
  <done>Generator script written + parseable output</done>
</task>

<task id="W1-05-02" type="auto" tdd="true">
  <name>Task 2: Generate registry artifact + tests (D-CE-11)</name>
  <files>services/backend/app/calculators/__init__.py, services/backend/app/calculators/_registry.py, services/backend/tests/test_calc_registry.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-G
    - tools/generate_calc_registry.py (just created)
  </read_first>
  <behavior>
    - Test 1: `len(REGISTRY) >= 40`.
    - Test 2: Every entry has all 5 keys (name + file + profile_fields_needed + life_events_served + output_type).
    - Test 3: Every `file` field points to an actual existing file (`Path(entry["file"]).is_file()` — relative to `services/backend/`).
    - Test 4: `output_type` is one of `{"L1", "L2", "L3", "L4"}`.
    - Test 5: `len(REVERSE_DEP_MAP) >= 5` (at minimum: canton, age, salary, is_property_owner, marital_status).
    - Test 6: `REVERSE_DEP_MAP["canton"]` is a non-empty set.
    - Test 7: `get_calculator("nonexistent")` raises KeyError.
    - Test 8: Freshness — `python3 tools/generate_calc_registry.py --check` exits 0 immediately after generation (idempotent).
  </behavior>
  <action>
    **Step A**: Create `services/backend/app/calculators/__init__.py`:
    ```python
    """Phase mint-calc-engine-v1 — D-CE-11 calc registry.

    AUTO-GENERATED. Do NOT edit `_registry.py` manually.
    Regenerate: `python3 tools/generate_calc_registry.py`
    Freshness check: `python3 tools/generate_calc_registry.py --check`
    """
    from app.calculators._registry import (
        REGISTRY,
        REVERSE_DEP_MAP,
        CalculatorMetadata,
        get_calculator,
        get_reverse_deps,
    )

    __all__ = [
        "REGISTRY",
        "REVERSE_DEP_MAP",
        "CalculatorMetadata",
        "get_calculator",
        "get_reverse_deps",
    ]
    ```

    **Step B**: Run `python3 tools/generate_calc_registry.py` to GENERATE `services/backend/app/calculators/_registry.py`. Commit the generated file.

    **Step C**: Write `services/backend/tests/test_calc_registry.py` with the 8 tests from `<behavior>`. Use `from app.calculators import REGISTRY, REVERSE_DEP_MAP, get_calculator`.

    DO NOT manually edit `_registry.py` — only the generator + tests are hand-written. If a test fails because the generator missed a calc, fix the GENERATOR, regenerate, recommit.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_calc_registry.py -q -x && python3 tools/generate_calc_registry.py --check</automated>
  </verify>
  <acceptance_criteria>
    - `services/backend/app/calculators/_registry.py` exists, ≥100 lines
    - `python3 -c "from app.calculators import REGISTRY; print(len(REGISTRY))"` returns a number ≥40
    - `python3 -c "from app.calculators import REGISTRY; assert all(k in v for v in REGISTRY.values() for k in ['name','file','profile_fields_needed','life_events_served','output_type']); print('OK')"` prints `OK`
    - `cd services/backend && python3 -m pytest tests/test_calc_registry.py -q -x` exits 0 with 8 tests passed
    - `python3 tools/generate_calc_registry.py --check` exits 0 (idempotent re-run shows no diff)
    - `python3 tools/checks/banned_terms_python.py tools/generate_calc_registry.py services/backend/tests/test_calc_registry.py` exits 0
  </acceptance_criteria>
  <done>Registry artifact generated + 8 tests green + idempotent regeneration confirmed</done>
</task>

<task id="W1-05-99" type="auto" tdd="false">
  <name>Task 3: Open Q2 resolution + engram save</name>
  <files>(decision + engram)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md Open Q2 (pre-commit lefthook freshness vs CI-only)
  </read_first>
  <action>
    **Q2 resolution** : Default `CI-only` per VALIDATION.md fallback (lefthook adds friction; registry can regenerate lazily on every CI run via `python3 tools/generate_calc_registry.py --check`). Add CI workflow note in SUMMARY:
    « TODO Plan W2-XX: add `python3 tools/generate_calc_registry.py --check` to `.github/workflows/backend-tests.yml` after backend tests step. »

    Engram save:
    - `topic_key: calc_engine:w1:calc_registry_scaffold`
    - `type: architecture`
    - `prior_finding_refs: [Plan 01 obs_id, panel synthesis #103, W0 audit obs (the 57 calculators)]`
    - Content: « Registry scaffold ships at `app/calculators/_registry.py` via `tools/generate_calc_registry.py`. ~X calcs detected by `compute_/simulate_/compare_` heuristic out of 57 W0 audit. Diff documented in SUMMARY. W2 ToolRegistryAdapter consumes `REGISTRY` ; W3 reverse-dep map consumes `REVERSE_DEP_MAP`. Q2 resolved: CI-only freshness check (no lefthook in v1). »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite exits 0
    - Engram saved
    - SUMMARY documents Q2 resolution + CI workflow TODO + heuristic-coverage delta vs W0 audit
  </acceptance_criteria>
  <done>Registry scaffold live, Q2 resolved, ready for W2 consumption</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| AST scanner read | Read-only on services/backend source files |
| Generated _registry.py write | Code path only; never executed at request time as user data |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-05-01 | Tampering | _registry.py manually edited | mitigate | `--check` mode + CI gate flags drift. Generated file header warns. |
| T-mint-calc-05-02 | Information disclosure | profile_fields_needed list | accept | Lists FIELD NAMES (canonical safe-field list from coach_chat.py), not values. Public-safe. |
| T-mint-calc-05-03 | DoS | AST scan latency on import | accept | Generator runs at build time, NOT per-request. `_registry.py` import is a flat dict load. |
| T-mint-calc-05-04 | Spoofing | calc name collision | mitigate | Naming convention `<file_stem>_<func_name>` makes collision near-impossible across the 11 domain folders. Test 1 verifies. |
| T-mint-calc-05-05 | LSFin | banned-term scan on generator output | mitigate | Generator emits identifier names only ; banned-terms-python lint runs on the file. |
</threat_model>

<verification>
- 8 tests green
- ≥40 registry entries (≥50 ideal)
- Idempotent regeneration
- Q2 resolved (CI-only)
- Heuristic-coverage delta vs W0 audit documented in SUMMARY
</verification>

<success_criteria>
- `from app.calculators import REGISTRY, REVERSE_DEP_MAP, get_calculator` succeeds
- `len(REGISTRY) >= 40`
- `python3 tools/generate_calc_registry.py --check` exits 0
- Engram observation persisted
</success_criteria>

<risks>
- **Heuristic miss rate.** The `compute_/simulate_/compare_` prefix heuristic may catch fewer than W0's 57 calculators (some services use `def estimate_X(...)` or class methods). If gap >30%, surface to orchestrator at end of Task 1 — may need a broader heuristic OR a manual « calculator allowlist » fallback.
- **Generated file in git.** `_registry.py` is auto-generated but COMMITTED. Reviewers may flag it as « should be gitignored ». Counter: D-CE-09 mandates registry-as-artifact for runtime import + CI freshness check needs a checked-in baseline. Document this in SUMMARY.
- **CI freshness check not wired yet.** Plan 05 ships the `--check` CLI but does NOT wire it to GitHub Actions. That's a 1-line addition in a W2 plan or W4 lints plan. Track as TODO.
- **Output type defaults to L1.** Services that don't declare `# @lucidity: L<N>` magic comment get `L1`. W2 may want to retrofit `# @lucidity` comments to existing services — but that's adjacent work (Karpathy #3). Not in W1 scope.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-05-w1-calc-registry-SUMMARY.md`. Include:
- Engram obs_id
- Registry entry count (and gap vs W0 audit 57)
- Q2 resolution (CI-only)
- TODO: wire `--check` to GitHub Actions in W2 or W4
</output>
