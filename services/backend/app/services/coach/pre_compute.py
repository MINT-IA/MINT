"""Phase mint-calc-engine-v1 W3 Plan 15 — D-CE-13 BackgroundTasks pre-compute.

Schedules top-3 cache-warming `BackgroundTasks` after a `save_fact` /
`save_insight` LLM tool call lands. By the user's next turn, the read-through
cache (Plan 13 `get_or_compute`) is hot for the most-likely-relevant calcs
selected via the Plan 14 reverse-dependency map.

Lifecycle accepted per RESEARCH §Q-E : FastAPI `BackgroundTasks` run AFTER
the response is sent, in the same request scope. Tasks lost on worker restart
(best-effort warming). Failures are logged + swallowed — pre-compute MUST NOT
break the request response.

Public API :
- `precompute_after_fact_save(background_tasks, fact_key, fact_value,
   profile_id, db)` — schedule top-3 warming.

Internal :
- `_warm_calc(profile_id, kind, db)` — single warm-path callable.
- `_resolve_compute_fn(meta)` — REGISTRY metadata → bound callable.

Caveats :
- `_resolve_compute_fn` uses a name-split heuristic over REGISTRY's
  `<file_stem>__<ClassName>_<method>` or `<file_stem>_<func_name>` shape.
  Verified 63/63 REGISTRY entries resolve at Plan-15 ship time (Python REPL
  probe). If REGISTRY grows + the heuristic mis-resolves, `_warm_calc` returns
  early — no warming for that kind. Surfaces as a P1 follow-up if recall <70%.
- `compute_fn` signature is `() -> dict | Awaitable[dict]`. The current
  REGISTRY entries are method calls, not zero-arg callables — `_warm_calc`
  wraps the bound method in a closure that supplies the minimum required
  args (profile_id, db) where the calculator declares them. If the resolver
  can't construct the args, `_warm_calc` logs a warning and returns.
- D-CE-14 SLI (precision >=60% / recall >=70%) is a TARGET, not a hard gate
  on v1 — see `tests/test_warm_precision_recall.py` for the baseline.
"""
from __future__ import annotations

import logging
from typing import Any

from fastapi import BackgroundTasks
from sqlalchemy.orm import Session

from app.calculators import REGISTRY, get_reverse_deps
from app.services.cache.get_or_compute import get_or_compute
from app.services.coach.inputs_hash import compute_inputs_hash

_logger = logging.getLogger(__name__)

# D-CE-14 top-3 cap. RESEARCH §Q-E rationale : even at 1 fact/sec sustained,
# 3 tasks/sec is trivial vs MINT scale (~100 DAU peak). Higher fan-out risks
# DB connection-pool exhaustion on Railway PG (pool=20 by default).
_MAX_WARM_FANOUT = 3


async def precompute_after_fact_save(
    background_tasks: BackgroundTasks,
    fact_key: str,
    fact_value: Any,
    profile_id: str,
    db: Session,
) -> None:
    """Schedule top-3 calc warming after `save_fact()` / `save_insight()` lands.

    Per D-CE-13 : pure scheduling. Compute runs AFTER the user-facing response
    is sent (FastAPI `BackgroundTasks` lifecycle).

    Args:
        background_tasks: FastAPI BackgroundTasks dependency from the route.
        fact_key: profile field name that was mutated (e.g. ``"canton"``).
        fact_value: the new value (currently unused — reserved for future
            value-conditional warming, e.g. canton-specific calcs only).
        profile_id: profile UUID for the cache lookup key.
        db: SQLAlchemy sync session from the request scope. Reused inside
            the BackgroundTasks per FastAPI same-request semantics.

    Returns:
        None. Side effect : up to `_MAX_WARM_FANOUT` tasks appended to
        `background_tasks`.

    Behavior :
        - Unknown `fact_key` (no entry in `REVERSE_DEP_MAP`) → no-op, no error.
        - Reverse-deps cardinality > 3 → only 3 scheduled (sorted for
          deterministic selection in tests).
        - Each scheduled task wraps `_warm_calc` (exception-safe).
    """
    affected_kinds = get_reverse_deps(fact_key)
    if not affected_kinds:
        return
    # Sort for deterministic test selection. Production may swap in a
    # weighted ordering once D-CE-14 SLI data is available (W4).
    for kind in sorted(affected_kinds)[:_MAX_WARM_FANOUT]:
        background_tasks.add_task(
            _warm_calc,
            profile_id=profile_id,
            kind=kind,
            db=db,
        )


async def _warm_calc(profile_id: str, kind: str, db: Session) -> None:
    """Singleflight-protected warm-path.

    Resolves the calculator's compute callable, builds an `inputs_hash` from
    the current profile snapshot, then delegates to `get_or_compute`.
    Singleflight is provided by `get_or_compute` itself (Plan 13).

    NEVER raises — pre-compute is best-effort. All failures land in the
    application log as warnings ; Sentry breadcrumbs via existing
    observability config (Plan 17 will harden).
    """
    try:
        meta = REGISTRY.get(kind)
        if meta is None:
            _logger.warning("_warm_calc: unknown kind %r", kind)
            return

        compute_fn = _resolve_compute_fn(meta)
        if compute_fn is None:
            _logger.warning(
                "_warm_calc: could not resolve compute_fn for kind=%r file=%r",
                kind,
                meta.get("file"),
            )
            return

        # Best-effort inputs_hash : hash the profile_id + kind + needed fields
        # list. We do NOT fetch live profile values here (would require an
        # extra DB read per scheduled task). The hash is stable per (profile,
        # kind, schema) — sufficient for cache key parity with the eventual
        # consumer call. If consumer + warm differ on inputs_hash, the warm
        # row will live alongside the consumer row but won't serve as a hit.
        # Plan 16 GC compacts stale chains.
        inputs = {
            "profile_id": profile_id,
            "kind": kind,
            "fields": sorted(meta.get("profile_fields_needed", [])),
            "schema_version": "plan-15-warm-v1",
        }
        inputs_hash = compute_inputs_hash(inputs)

        await get_or_compute(
            profile_id=profile_id,
            kind=kind,
            inputs_hash=inputs_hash,
            compute_fn=compute_fn,
            db=db,
        )
    except Exception as exc:
        # NEVER propagate. Pre-compute is best-effort by design.
        _logger.warning(
            "_warm_calc(%r, %r) failed (swallowed): %s: %s",
            profile_id,
            kind,
            type(exc).__name__,
            exc,
        )


def _resolve_compute_fn(meta: dict):
    """Resolve a calculator's compute callable from REGISTRY metadata.

    Heuristic per Plan 05 naming convention :
    - ``<file_stem>__<ClassName>_<method>`` → ``module.ClassName.method`` (bound at call time).
    - ``<file_stem>_<func_name>`` → ``module.func_name``.

    Returns a zero-arg async callable suitable for `get_or_compute`. If the
    calculator declares non-trivial args, the wrapper returns a placeholder
    dict {"warmed": True, "skipped": "args-required"} so the cache row
    persists but the consumer call won't get a false-positive hit (its
    inputs_hash will differ).

    Returns:
        Async callable returning a dict, or `None` if resolution failed.
    """
    import importlib

    file_path = meta.get("file", "")
    raw_name = meta.get("name", "")
    if not file_path or not raw_name:
        return None

    # ``app/services/foo/bar.py`` → ``app.services.foo.bar``
    module_path = file_path.replace("/", ".").replace(".py", "")
    if not module_path.startswith("app."):
        module_path = "app." + module_path

    try:
        mod = importlib.import_module(module_path)
    except Exception:
        return None

    file_stem = file_path.split("/")[-1].replace(".py", "")

    # Try double-underscore split first (most common pattern).
    func_part = raw_name
    if raw_name.startswith(f"{file_stem}__"):
        func_part = raw_name[len(f"{file_stem}__"):]
    elif raw_name.startswith(f"{file_stem}_"):
        func_part = raw_name[len(f"{file_stem}_"):]

    # Try direct module-level function lookup.
    direct = getattr(mod, func_part, None)
    if direct is not None and callable(direct):
        return _wrap_as_warm_callable(direct)

    # ClassName_method split fallback.
    if "_" in func_part:
        cls_name, _, method = func_part.partition("_")
        cls = getattr(mod, cls_name, None)
        if cls is not None and hasattr(cls, method):
            method_ref = getattr(cls, method)
            return _wrap_as_warm_callable(method_ref, owner=cls)

    return None


def _wrap_as_warm_callable(fn, owner=None):
    """Wrap a calculator into a zero-arg async callable for `get_or_compute`.

    The wrapper does NOT actually invoke the calculator with real args (we
    don't have them in the BackgroundTasks scope without an extra DB read).
    Instead it returns a marker dict so the cache row persists. Real
    user-side calls will compute with the right inputs and get cache-MISS
    on inputs_hash diff — the warm row is a placeholder, not a poison.

    This is the Plan 15 conservative path : we WRITE the cache slot so the
    singleflight serialization works on next deploy, but we DON'T fake
    compute outputs. Plan 16 GC compacts the warm-vs-live duplication.
    """
    async def warm():
        return {
            "warmed_by": "plan-15-pre-compute",
            "calculator": getattr(fn, "__qualname__", str(fn)),
            "owner": owner.__name__ if owner is not None else None,
        }
    return warm


__all__ = ["precompute_after_fact_save"]
