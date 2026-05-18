"""snapshot constants invalidation tombstone — D-17 carry-over.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-17.

This is a **tombstone migration** : it makes NO schema change. Its sole
purpose is to record in `alembic_version` history that the D-17 cache-key
contract was extended in the application layer at this revision.

The actual D-17 wiring lives in :
- `app/services/cache/snapshot_cache.py` :
    * `is_snapshot_stale(snapshot_row, *, on_date=None) -> bool` —
      compares `snapshot_row.constants_version_hash` against the active
      `RegulatoryRegistry.version_hash()` ; returns True (« stale,
      recompute ») when mismatched.
    * `cache_key_for_snapshot(user_id, inputs_hash, constants_version_hash)
      -> str` — composes the cache key with constants_version_hash so
      regulatory rotation naturally evicts old entries via key mismatch.
- `app/services/snapshots/snapshot_service.py` :
    * (continuation-4 P1 read-path wiring) — `read_monthly_gross_income`
      and other snapshot reads consult `is_snapshot_stale()` to trigger a
      fresh recompute when the active hash has rotated.

Per CONTEXT.md D-04 « point-in-time historical row immutability », we do
NOT mutate the stored snapshot's `constants_version_hash` on regulatory
rotation. Old snapshots stay stamped with the hash that was active when
they were computed (audit-trail anchor). The « invalidation » is a
recompute trigger on read, NOT a row mutation. This migration is
declarative : it pins the alembic chain to the moment the D-17 contract
landed in the application layer.

Why a tombstone migration (vs no migration)
===========================================
Alembic's `alembic_version` row is the deterministic anchor for
« which code-side contracts must be live ». If a future deploy rolls
back to a revision earlier than p116, the cache-key contract reverts
implicitly (the application code is the source of truth). The tombstone
ensures that any « D-17 wiring active ? » question can be answered by
checking `alembic_version` rather than grepping the application tree.

Idempotent : `upgrade()` is empty + `downgrade()` is empty. Re-running
either is a no-op.

Revision ID : p116_snapshot_invalidation      (21 chars — within Postgres VARCHAR(32) cap)
Revises     : p115_hmac_pepper_pii            (chains off p115 for audit-log linearity)
Create Date : 2026-05-18
"""
from typing import Sequence, Union


revision: str = "p116_snapshot_invalidation"  # 26 chars — within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p115_hmac_pepper_pii"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """D-17 tombstone — no schema change ; see snapshot_cache.py for the contract."""
    # Intentionally empty. The D-17 cache-key extension is enforced by
    # `app/services/cache/snapshot_cache.py` ; this revision records the
    # « contract is live » fact in alembic_version history.
    return


def downgrade() -> None:
    """D-17 tombstone — no schema change ; downgrade is also a no-op."""
    return
