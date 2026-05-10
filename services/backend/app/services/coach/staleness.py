"""Phase 95 DAG-INVALIDATION — staleness derivation rule (DAG-03 backend half).

Pure-function module with ZERO imports beyond stdlib typing. Phase 96 W2
will call `staleness_high()` at projection read time from the
`arbitrage_engine` consumer and emit `staleness_iso = "high"` on the
corresponding `GroundingPackEntry`. Production read-path integration is
deferred to Phase 96 W2 per ROADMAP SC#2 scope decision (Phase 95 ships
the rule + tests ; Phase 96 wires it).

Per CONTEXT D-08 (`staleness_iso` field on GroundingPackEntry) + checker
BLOCKER-1 (2026-05-11) : extracted from test_staleness.py into a
production module so the rule is importable by downstream callers.

Rule semantics :
- stored_hash is None              -> stale (never computed before)
- stored_hash != current_hash      -> stale (inputs mutated since)
- stored_hash == current_hash      -> fresh
"""
from __future__ import annotations


def staleness_high(stored_hash: str | None, current_hash: str) -> bool:
    """DAG-03 — boolean staleness derivation.

    Args:
        stored_hash: inputs_hash persisted on the prior projection row
            (may be None for legacy rows pre-Phase-95 migration).
        current_hash: inputs_hash computed NOW from the current profile.

    Returns:
        True if stale (must recompute / flag UI badge), False if fresh.
    """
    return stored_hash is None or stored_hash != current_hash


__all__ = ["staleness_high"]
