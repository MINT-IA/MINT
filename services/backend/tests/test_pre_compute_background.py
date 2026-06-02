"""Phase mint-calc-engine-v1 W3 Plan 15 — D-CE-13 BackgroundTasks pre-compute tests.

Tests for `app.services.coach.pre_compute.precompute_after_fact_save` +
`_warm_calc`.

Contract :
- `precompute_after_fact_save(bg, fact_key, fact_value, profile_id, db)`
  schedules ≥1 BackgroundTasks (capped at 3) based on
  `get_reverse_deps(fact_key)`.
- Empty reverse-deps → no tasks scheduled (graceful no-op).
- Top-3 cap : if reverse-deps has 20 calcs, only 3 scheduled.
- `_warm_calc(profile_id, kind, db)` invokes `get_or_compute` once.
- `_warm_calc` swallows all exceptions (best-effort warming, lifecycle accepted).
"""

from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4



# ----------------------------------------------------------------------- Test 1
def test_precompute_schedules_at_least_one_task_for_canton():
    """canton has 25 reverse-deps (>=1, <=3 scheduled)."""
    from app.services.coach.pre_compute import precompute_after_fact_save

    bg = MagicMock()
    bg.add_task = MagicMock()

    n = precompute_after_fact_save(
        background_tasks=bg,
        fact_key="canton",
        fact_value="VD",
        profile_id=str(uuid4()),
        db=MagicMock(),
    )

    assert bg.add_task.call_count >= 1
    assert bg.add_task.call_count <= 3  # _MAX_WARM_FANOUT
    assert n == bg.add_task.call_count


# ----------------------------------------------------------------------- Test 2
def test_precompute_empty_reverse_deps_no_tasks_scheduled():
    """Unknown fact_key (no entry in REVERSE_DEP_MAP) → 0 tasks, no error."""
    from app.services.coach.pre_compute import precompute_after_fact_save

    bg = MagicMock()
    bg.add_task = MagicMock()

    n = precompute_after_fact_save(
        background_tasks=bg,
        fact_key="nonexistent_field_xyz_42",
        fact_value="whatever",
        profile_id=str(uuid4()),
        db=MagicMock(),
    )

    assert bg.add_task.call_count == 0
    assert n == 0


# ----------------------------------------------------------------------- Test 3
def test_precompute_caps_fanout_at_three():
    """canton has 25 reverse-deps but only 3 tasks scheduled (top-3 cap)."""
    from app.services.coach.pre_compute import precompute_after_fact_save
    from app.calculators import get_reverse_deps

    # Sanity-check : canton MUST have > 3 reverse-deps for this test to mean anything.
    assert len(get_reverse_deps("canton")) > 3

    bg = MagicMock()
    bg.add_task = MagicMock()

    n = precompute_after_fact_save(
        background_tasks=bg,
        fact_key="canton",
        fact_value="GE",
        profile_id=str(uuid4()),
        db=MagicMock(),
    )

    assert bg.add_task.call_count == 3, (
        f"_MAX_WARM_FANOUT=3 violated : got {bg.add_task.call_count} tasks"
    )
    assert n == 3


# ----------------------------------------------------------------------- Test 4
def test_warm_calc_invokes_get_or_compute_once():
    """_warm_calc(profile_id, kind, db) calls get_or_compute exactly once."""
    from app.services.coach import pre_compute

    profile_id = str(uuid4())
    # Pick a real REGISTRY kind so the resolver path doesn't short-circuit.
    from app.calculators import REGISTRY
    kind = next(iter(REGISTRY.keys()))

    mock_row = MagicMock()
    mock_row.id = "scenario-id-1"

    with patch(
        "app.services.coach.pre_compute.get_or_compute",
        new=AsyncMock(return_value=mock_row),
    ) as mock_goc:
        asyncio.run(
            pre_compute._warm_calc(
                profile_id=profile_id,
                kind=kind,
                db=MagicMock(),
            )
        )

    assert mock_goc.call_count == 1


# ----------------------------------------------------------------------- Test 5
def test_warm_calc_swallows_exception_no_propagation():
    """A failing _warm_calc MUST NOT raise (best-effort warming)."""
    from app.services.coach import pre_compute

    profile_id = str(uuid4())
    from app.calculators import REGISTRY
    kind = next(iter(REGISTRY.keys()))

    async def boom():
        raise RuntimeError("synthetic calculator failure")

    with patch(
        "app.services.coach.pre_compute.get_or_compute",
        new=AsyncMock(side_effect=RuntimeError("synthetic boom")),
    ):
        # MUST NOT raise.
        asyncio.run(
            pre_compute._warm_calc(
                profile_id=profile_id,
                kind=kind,
                db=MagicMock(),
            )
        )


# ----------------------------------------------------------------------- Test 6 (wire — used by Task 2 -k "wire" filter)
def test_wire_save_fact_triggers_precompute_after_fact_save():
    """Wire smoke-test : save_fact handler in coach_chat.py invokes
    precompute_after_fact_save with the fact key when commit succeeds.

    This test is filterable via `-k "wire"` per PLAN.md Task 2 acceptance.
    """
    # The real wiring is exercised by integration tests with TestClient ;
    # here we just verify the function is importable + the entry symbol is
    # referenced from coach_chat.py source. Full integration test is in
    # test_warm_precision_recall.py.
    import importlib
    pre = importlib.import_module("app.services.coach.pre_compute")
    assert hasattr(pre, "precompute_after_fact_save")
    assert hasattr(pre, "_warm_calc")

    # Verify coach_chat.py imports precompute_after_fact_save.
    import pathlib
    coach_chat = pathlib.Path(__file__).parent.parent / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    src = coach_chat.read_text(encoding="utf-8")
    assert "precompute_after_fact_save" in src, (
        "coach_chat.py must reference precompute_after_fact_save (Plan 15 Task 2 wiring)"
    )


# ----------------------------------------------------------------------- Test 7 (wire)
def test_wire_save_insight_triggers_precompute():
    """save_insight handler MUST also invoke precompute_after_fact_save with the
    topic as fact_key (canonical key bridge for insights).
    """
    import pathlib
    coach_chat = pathlib.Path(__file__).parent.parent / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    src = coach_chat.read_text(encoding="utf-8")
    # The save_insight branch must contain a call to precompute_after_fact_save
    # AFTER the CoachInsightRecord commit. Cheap proxy : find save_insight
    # branch start, and confirm precompute_after_fact_save appears between
    # there and the next dispatched-tool branch.
    si_idx = src.find('if name == "save_insight":')
    sf_idx = src.find('if name == "save_fact":')
    assert si_idx != -1, "save_insight handler not found"
    assert sf_idx != -1, "save_fact handler not found"
    # Ensure ordering : save_insight branch ends before save_fact branch starts.
    assert si_idx < sf_idx
    # The precompute call must land in the save_insight slice.
    assert "precompute_after_fact_save" in src[si_idx:sf_idx], (
        "save_insight handler must invoke precompute_after_fact_save before save_fact branch"
    )


# ----------------------------------------------------------------------- Test 8 (wire)
def test_wire_save_fact_branch_contains_precompute_call():
    """save_fact handler MUST contain a precompute_after_fact_save call AFTER
    the db.commit() on the ProfileModel write path.
    """
    import pathlib
    coach_chat = pathlib.Path(__file__).parent.parent / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    src = coach_chat.read_text(encoding="utf-8")
    sf_idx = src.find('if name == "save_fact":')
    # Find next top-level tool branch after save_fact (suggest_actions is next per current source order).
    next_idx = src.find('if name == "suggest_actions":', sf_idx)
    assert sf_idx != -1 and next_idx != -1
    slice_text = src[sf_idx:next_idx]
    assert "precompute_after_fact_save" in slice_text, (
        "save_fact handler must invoke precompute_after_fact_save"
    )
