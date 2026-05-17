---
phase: mint-calc-engine-v1
plan: 15
wave: 3
title: W3 — BackgroundTasks pre-compute on save_fact/save_insight (D-CE-13 + D-CE-14 SLI)
type: execute
depends_on: [13, 14]
files_modified:
  - services/backend/app/services/coach/pre_compute.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_pre_compute_background.py
  - services/backend/tests/test_warm_precision_recall.py
autonomous: true
requirements: [D-CE-13, D-CE-14]
estimated_duration: 4
must_haves:
  truths:
    - "`precompute_after_fact_save` schedules top-3 BackgroundTasks for the most-relevant calcs after `save_fact`/`save_insight` LLM tool call"
    - "Top-3 selection uses `REVERSE_DEP_MAP[fact_key]` (Plan 14)"
    - "Compute path uses `get_or_compute` (Plan 13) — cache populated for next turn"
    - "SLI tests: precision ≥60% / recall ≥70% on synthetic profile mutations"
    - "BackgroundTasks lifecycle accepted: best-effort warming, lost on worker restart"
  artifacts:
    - path: services/backend/app/services/coach/pre_compute.py
      provides: "precompute_after_fact_save + _warm_calc"
      min_lines: 60
    - path: services/backend/tests/test_pre_compute_background.py
      provides: "BackgroundTasks scheduling tests"
      min_lines: 80
    - path: services/backend/tests/test_warm_precision_recall.py
      provides: "D-CE-14 SLI test"
      min_lines: 50
  key_links:
    - from: services/backend/app/services/coach/pre_compute.py
      to: services/backend/app/calculators/_registry.py
      via: "REVERSE_DEP_MAP[fact_key] selects affected calcs"
      pattern: "REVERSE_DEP_MAP|get_reverse_deps"
    - from: services/backend/app/api/v1/endpoints/coach_chat.py
      to: services/backend/app/services/coach/pre_compute.py
      via: "save_fact handler calls precompute_after_fact_save"
      pattern: "precompute_after_fact_save"
---

<objective>
Ship the D-CE-13 post-commit pre-compute. When the narrator's `save_fact`/`save_insight` tool call lands, top-3 most-relevant calcs are pre-warmed in the background — by the user's next turn, cache is hot.

Purpose: D-CE-13 + D-CE-14. Vague B « parallel with discoverability AFTER 1 week obs ». FastAPI BackgroundTasks lifecycle accepted (best-effort).

Output: pre_compute module + coach_chat wiring + 2 test files including SLI.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/services/cache/get_or_compute.py
@services/backend/app/calculators/_registry.py
@services/backend/app/api/v1/endpoints/coach_chat.py
</context>

<interfaces>
<!-- RESEARCH §Q-E lines 712-748 verbatim -->

```python
# services/backend/app/services/coach/pre_compute.py
async def precompute_after_fact_save(
    background_tasks: BackgroundTasks,
    fact_key: str,
    fact_value: object,
    profile_id: str,
    db: Session,
) -> None:
    affected_kinds = get_reverse_deps(fact_key)
    if not affected_kinds:
        return
    for kind in list(affected_kinds)[:3]:  # cap fan-out to top-3
        background_tasks.add_task(_warm_calc, profile_id=profile_id, kind=kind, db=db)


async def _warm_calc(profile_id: str, kind: str, db: Session) -> None:
    # Resolve compute_fn from registry, build inputs_hash, call get_or_compute.
    ...
```

Coach narrator wire site: `services/backend/app/api/v1/endpoints/coach_chat.py` — find where `save_fact` tool result is processed (probably in `_handle_tool_call` or `_execute_internal_tool`). Add BackgroundTasks call right after `ProfileModel.data` is committed.
</interfaces>

<tasks>

<task id="W3-04-01" type="auto" tdd="true">
  <name>Task 1: precompute_after_fact_save + _warm_calc</name>
  <files>services/backend/app/services/coach/pre_compute.py, services/backend/tests/test_pre_compute_background.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-E lines 700-748
    - services/backend/app/services/cache/get_or_compute.py
    - services/backend/app/calculators/_registry.py
    - services/backend/app/api/v1/endpoints/coach_chat.py (find save_fact + save_insight tool handlers)
  </read_first>
  <behavior>
    - Test 1: `precompute_after_fact_save(bg, "canton", "VD", profile_id, db)` schedules ≥1 background task (and ≤3).
    - Test 2: Empty `REVERSE_DEP_MAP[fact_key]` → no tasks scheduled (graceful).
    - Test 3: Top-3 cap enforced — if `REVERSE_DEP_MAP[fact_key]` has 20 calcs, only 3 scheduled.
    - Test 4: `_warm_calc(profile_id, "lpp_rachat", db)` calls `get_or_compute` once and writes a cache row.
    - Test 5: Worker restart mid-task → no error in caller (lifecycle acceptance).
  </behavior>
  <action>
    Verbatim from RESEARCH §Q-E:

    ```python
    # services/backend/app/services/coach/pre_compute.py
    """Phase mint-calc-engine-v1 W3 — D-CE-13 + D-CE-14 BackgroundTasks pre-compute."""
    import logging
    from typing import Any
    from fastapi import BackgroundTasks
    from sqlalchemy.orm import Session

    from app.calculators import get_reverse_deps, REGISTRY
    from app.services.cache.get_or_compute import get_or_compute
    from app.services.coach.inputs_hash import compute_inputs_hash

    _logger = logging.getLogger(__name__)
    _MAX_WARM_FANOUT = 3   # D-CE-14 top-3 cap


    async def precompute_after_fact_save(
        background_tasks: BackgroundTasks,
        fact_key: str,
        fact_value: Any,
        profile_id: str,
        db: Session,
    ) -> None:
        """Schedule top-3 calc warming after save_fact() / save_insight() lands.

        Per D-CE-13: pure scheduling. Compute happens AFTER user-facing response sent.
        Lifecycle accepted: BackgroundTasks lost on worker restart (best-effort).
        """
        affected_kinds = get_reverse_deps(fact_key)
        if not affected_kinds:
            return
        for kind in sorted(list(affected_kinds))[:_MAX_WARM_FANOUT]:
            background_tasks.add_task(
                _warm_calc,
                profile_id=profile_id,
                kind=kind,
                db=db,
            )


    async def _warm_calc(profile_id: str, kind: str, db: Session) -> None:
        """Singleflight-protected warm-path."""
        try:
            meta = REGISTRY.get(kind)
            if meta is None:
                _logger.warning(f"_warm_calc: unknown kind {kind!r}")
                return
            # Resolve compute_fn from REGISTRY metadata
            # (e.g. dynamic import of services/.../<file>)
            compute_fn = _resolve_compute_fn(meta)
            if compute_fn is None:
                return
            # Build inputs_hash from current profile state
            inputs_hash = compute_inputs_hash(profile_id, meta["profile_fields_needed"], db)
            await get_or_compute(profile_id, kind, inputs_hash, compute_fn, db)
        except Exception as e:
            _logger.warning(f"_warm_calc({kind}, {profile_id}) failed: {e}")
            # NEVER raise — pre-compute is best-effort.


    def _resolve_compute_fn(meta: dict[str, Any]):
        """Dynamically import the calc service function from REGISTRY metadata."""
        # meta["file"] = "app/services/arbitrage/allocation_annuelle.py"
        # meta["name"] = "allocation_annuelle_compute_allocation_annuelle"
        import importlib
        module_path = meta["file"].replace("/", ".").replace(".py", "")
        if module_path.startswith("app."):
            module_path = module_path
        else:
            module_path = "app." + module_path
        try:
            mod = importlib.import_module(module_path)
            # function name = part of meta["name"] after first underscore beyond file stem
            # Heuristic: meta["name"] is "<file_stem>_<func_name>" → split off file_stem
            file_stem = meta["file"].split("/")[-1].replace(".py", "")
            func_name = meta["name"].replace(f"{file_stem}_", "", 1)
            return getattr(mod, func_name, None)
        except Exception:
            return None
    ```

    5 tests in `test_pre_compute_background.py`. Use `unittest.mock.AsyncMock` for `get_or_compute` and `fastapi.BackgroundTasks` mock.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_pre_compute_background.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 5 tests green
    - `grep -c "_MAX_WARM_FANOUT = 3" services/backend/app/services/coach/pre_compute.py` returns 1
    - `grep -c "background_tasks.add_task" services/backend/app/services/coach/pre_compute.py` returns ≥1
  </acceptance_criteria>
  <done>pre_compute module live</done>
</task>

<task id="W3-04-02" type="auto" tdd="true">
  <name>Task 2: Wire precompute_after_fact_save into coach_chat.py</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py (full file — find save_fact/save_insight tool handlers)
    - services/backend/app/services/coach/pre_compute.py (just created)
  </read_first>
  <behavior>
    - Test 1: When narrator emits `save_fact(key="canton", value="GE")` tool call, after ProfileModel.data is committed, `precompute_after_fact_save` is called with the fact key.
    - Test 2: BackgroundTasks dep injected into the coach_chat route handler.
    - Test 3: `save_insight` triggers same flow.
  </behavior>
  <action>
    Surgical patches in `coach_chat.py`:

    1. Add import: `from app.services.coach.pre_compute import precompute_after_fact_save`
    2. Add `background_tasks: BackgroundTasks = BackgroundTasks()` (or `Depends(BackgroundTasks)`) to the coach_chat route signature if not present.
    3. After `ProfileModel.data` commit on `save_fact` tool, call:
       ```python
       await precompute_after_fact_save(
           background_tasks=background_tasks,
           fact_key=tool_input["key"],
           fact_value=tool_input["value"],
           profile_id=str(profile.id),
           db=db,
       )
       ```
    4. Same for `save_insight` tool — same call with `fact_key=tool_input["insight_topic"]` or similar canonical key.

    DO NOT block on the call. BackgroundTasks scheduling is sync (`.add_task` is not await-bound — but the outer function is async).

    3 integration tests using TestClient — mock the narrator to emit specific tool calls and assert `precompute_after_fact_save` invoked.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_pre_compute_background.py -q -x -k "wire"</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "precompute_after_fact_save" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1
    - 3 integration tests green
    - Full backend suite green (no regression)
  </acceptance_criteria>
  <done>Pre-compute wired into narrator flow</done>
</task>

<task id="W3-04-03" type="auto" tdd="true">
  <name>Task 3: SLI tests — warm precision ≥60% / recall ≥70%</name>
  <files>services/backend/tests/test_warm_precision_recall.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-14 SLI
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md W3-04-02
  </read_first>
  <behavior>
    - Test 1 (synthetic precision): Run 20 synthetic profile-mutation scenarios. For each, simulate `save_fact(key, value)` + record which calcs warmed. After the « next turn » the same scenario requests a specific calc. Compute: `precision = (warmed calcs that were requested) / (warmed calcs total)`. Assert `precision >= 0.60`.
    - Test 2 (synthetic recall): Same scenarios. Compute: `recall = (warmed calcs that were requested) / (calcs requested total)`. Assert `recall >= 0.70`.
    - Test 3: Edge case — fact_key NOT in REVERSE_DEP_MAP (e.g. typo) → 0 calcs warmed, 0 calcs requested → precision/recall undefined; assert no error.
  </behavior>
  <action>
    Write a synthetic scenarios table mapping `(fact_key, next_turn_intent, expected_requested_calcs)`:

    ```python
    # services/backend/tests/test_warm_precision_recall.py
    """D-CE-14 SLI tests for warm precision ≥60% / recall ≥70%."""
    import pytest

    SYNTHETIC_SCENARIOS = [
        # (fact_key_set, next_turn_intent, expected_requested_calcs)
        ("canton", "taxes", ["wealth_tax", "fiscal_estimate", "succession_simulator"]),
        ("salary_gross_yearly", "retirement", ["lpp_projector", "avs_estimation", "pillar_3a_optimizer"]),
        ("is_property_owner", "housing", ["affordability", "imputed_rental", "amortization"]),
        # ... 17 more
    ]


    def test_warm_precision_ge_60(synthetic_pre_compute_run):
        """For each synthetic scenario: precision = warmed ∩ requested / warmed."""
        ratios = []
        for fact_key, _, expected_requested in SYNTHETIC_SCENARIOS:
            warmed = synthetic_pre_compute_run(fact_key)
            intersection = set(warmed) & set(expected_requested)
            if warmed:
                ratios.append(len(intersection) / len(warmed))
        avg_precision = sum(ratios) / len(ratios)
        assert avg_precision >= 0.60, f"D-CE-14 SLI failed: precision={avg_precision:.2f} < 0.60"


    def test_warm_recall_ge_70(synthetic_pre_compute_run):
        """For each synthetic scenario: recall = warmed ∩ requested / requested."""
        ratios = []
        for fact_key, _, expected_requested in SYNTHETIC_SCENARIOS:
            warmed = synthetic_pre_compute_run(fact_key)
            intersection = set(warmed) & set(expected_requested)
            if expected_requested:
                ratios.append(len(intersection) / len(expected_requested))
        avg_recall = sum(ratios) / len(ratios)
        assert avg_recall >= 0.70, f"D-CE-14 SLI failed: recall={avg_recall:.2f} < 0.70"
    ```

    SLI thresholds may not be met on v1 — if so, document gap in SUMMARY. Per CONTEXT.md, this is a quality bar to TRACK, not necessarily HIT on day 1.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_warm_precision_recall.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 3 tests run
    - SLI numbers documented in SUMMARY (pass or fail with delta-to-target)
  </acceptance_criteria>
  <done>SLI baseline established</done>
</task>

<task id="W3-04-99" type="auto" tdd="false">
  <name>Task 4: Full suite + engram</name>
  <files>(verification + engram)</files>
  <action>
    Engram save:
    - `topic_key: calc_engine:w3:pre_compute_background_tasks_D_CE_13`
    - `type: discovery`
    - `prior_finding_refs: [Plan 13 obs (cache), Plan 14 obs (reverse_dep_map), #103 panel synthesis D-CE-13 + D-CE-14, panel override #5]`
    - Content: « D-CE-13 BackgroundTasks pre-compute wired into coach_chat.py save_fact + save_insight. Top-3 fan-out cap. D-CE-14 SLI tests baseline: precision=X% (target 60%), recall=Y% (target 70%). PM reservation per CONTEXT.md: baseline measurement starts post-W4 metrics ship. Lifecycle accepted (best-effort warming). »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram saved
  </acceptance_criteria>
  <done>W3-04 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-15-01 | DoS | background task fan-out | mitigate | _MAX_WARM_FANOUT=3 cap. ~3 tasks per save_fact event. Even at 1 fact/sec sustained = 3 tasks/sec — trivial vs MINT scale (~100 DAU). |
| T-mint-calc-15-02 | Information disclosure | task arg leak (profile_id) | accept | profile_id passed in-process. No external surface. |
| T-mint-calc-15-03 | Tampering | warm-path compute corruption | mitigate | `_warm_calc` wraps `get_or_compute` (Plan 13 atomic). Failure logged + swallowed. |
| T-mint-calc-15-04 | Repudiation | warm task failure trace | mitigate | `_logger.warning` emits Sentry breadcrumb via existing observability config. |
| T-mint-calc-15-05 | Spoofing | save_fact key spoofing | accept | save_fact is narrator-emitted, server-side. No client write surface. |
</threat_model>

<success_criteria>
- pre_compute module + wire-up
- 5+3+3 = 11 tests
- SLI baselined (target precision 60% / recall 70%)
- BackgroundTasks lifecycle accepted
- Engram observation persisted
</success_criteria>

<risks>
- **SLI may not hit 60%/70% on v1.** Per PM reservation in CONTEXT.md. Document gap with delta-to-target ; W4 metrics + 1-month measurement informs revision.
- **`_resolve_compute_fn` import path heuristic.** Per Plan 05 caveat, AST scanner may have miscategorized function names. If `_resolve_compute_fn` returns None for >50% of calls, surface as P1 follow-up.
- **BackgroundTasks worker restart loss.** Accepted per RESEARCH §Q-E. Documented in module docstring + SUMMARY.
- **save_fact wiring fragility.** If coach_chat.py refactored, wiring may break. Test 1-3 of Task 2 catches.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-15-w3-pre-compute-background-tasks-SUMMARY.md` including SLI baseline numbers.
</output>
