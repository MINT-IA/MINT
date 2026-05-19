"""D-17 snapshot cache invalidation contract (Plan 02-02 P1 Task 2 step 9-10).

Snapshot reads MUST return a fresh computation when the active regulatory
`constants_version_hash` differs from the hash stamped on the most recent
SnapshotModel row for the user.

The current snapshot_service writes `constants_version_hash` to every
SnapshotModel row at compute time (services/backend/app/services/snapshots/
snapshot_service.py:115-123 — Hotfix B 2026-05-17). This module is the
read-side counterpart : `is_snapshot_stale(snapshot_row)` returns True if
the active registry has rotated forward, signaling « recompute ».

Per CONTEXT.md D-04 « point-in-time historical row immutability » : we do
NOT mutate the stored snapshot's constants_version_hash on regulatory
rotation. Old snapshots stay stamped with the hash that was active when
they were computed (audit-trail anchor). The cache « invalidation » is a
recompute trigger on read, NOT a row mutation.

Pairs with p116 alembic tombstone (deferred to continuation) which records
the deprecation in alembic_version history.

References :
- CONTEXT.md D-17 « SnapshotModel.constants_version_hash invalidates the
  snapshot cache when active regulatory version changes »
- services/backend/app/services/snapshots/snapshot_service.py (writer side)
- services/backend/app/services/regulatory/registry.py (registry singleton)
"""
from __future__ import annotations

from datetime import date
from typing import Any


def is_snapshot_stale(
    snapshot_row: Any,
    *,
    on_date: date | None = None,
) -> bool:
    """Return True if `snapshot_row.constants_version_hash` no longer matches
    the active regulatory version on `on_date` (defaults to today).

    Returns False (« fresh ») if :
    - The snapshot row has no `constants_version_hash` (legacy pre-Hotfix-B row)
    - The active hash matches the stamped hash

    Returns True (« stale, recompute ») if :
    - The active hash differs from the stamped hash

    Callers (snapshot read path) interpret True as « invalidate cache, run
    a fresh compute_snapshot() ». The stale row itself remains in the DB
    (D-04 point-in-time immutability).
    """
    stamped = getattr(snapshot_row, "constants_version_hash", None)
    if not stamped:
        # Legacy snapshot (pre-Hotfix-B 2026-05-17). Treated as fresh by
        # convention — the absence of a stamp means « registry was not yet
        # versioned », so we cannot prove staleness.
        return False

    from app.services.regulatory.registry import RegulatoryRegistry

    active = RegulatoryRegistry.instance().version_hash(on_date=on_date or date.today())
    return active != stamped


def cache_key_for_snapshot(user_id: str, inputs_hash: str, constants_version_hash: str) -> str:
    """Compose the D-17 cache key for a snapshot lookup.

    Includes `constants_version_hash` so that a regulatory rotation
    naturally evicts old keys (different key = cache miss). Pair with
    in-memory or Redis-backed cache layer (Plan 02-04 deferred).

    Format : ``snapshot:{user_id}:{inputs_hash}:{constants_version_hash}``
    """
    return f"snapshot:{user_id}:{inputs_hash}:{constants_version_hash}"
