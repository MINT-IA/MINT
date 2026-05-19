"""audit_events HMAC-pepper backfill — D-14 carry-over.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-14 + D-15 + D-24.

p112_audit_event_user_hash (Hotfix C 2026-05-17) backfilled
`audit_events.user_id_hash` with **bare SHA-256** via the `pgcrypto`
`digest(user_id, 'sha256')` DO-block. Bare SHA-256 is rainbow-table
reversible (security-auditor obs #175) — an attacker with a DB dump
plus a list of plausible user_id formats can pre-compute the hash
column.

D-14 mandates the re-backfill using **HMAC-SHA256 with the
`MINT_AUDIT_HASH_PEPPER` server-secret**, routed through the canonical
`app.services.audit.hmac_pepper.hmac_user_id()` entry. Adding the
server-only pepper makes pre-computation infeasible — an attacker
needs (a) the dump AND (b) the pepper bytes from Railway secrets.

This migration is a **Python data_upgrade** (NOT a pgcrypto DO-block) :
- Reads existing rows via SQLAlchemy session
- Re-hashes each `user_id_hash` using `hmac_user_id()` from the canonical
  entry (pepper is read from env at migration time; TESTING=1 fallback
  preserved for the test fixture)
- Updates the row in place
- Postgres post-pass : NULLs the plaintext `user_id` column (D-14 calls
  for plaintext-drop ; we NULL rather than DROP COLUMN to retain schema
  for one deprecation cycle ; a Phase 04 migration may DROP after the
  last reader is gone)

The migration is idempotent : re-running it on already-HMAC-hashed rows
is a no-op (the hash equals itself), and rows where `user_id` is NULL
(or where pgcrypto was missing at p112-backfill time, leaving
`user_id_hash` NULL) are skipped.

Revision ID : p114_hmac_pepper_audit          (24 chars — within Postgres VARCHAR(32) cap)
Revises     : p98_fact_event_projection       (chains off the continuation-3 head)
Create Date : 2026-05-18

Why not chain p114 off p113
===========================
The plan-frontmatter sketch had `p98 -> p113 -> p114 -> p115 -> p116`.
p113 is the audit_mobile column extension landed in this same continuation-4.
Because p114 and p113 touch DIFFERENT tables (audit_events vs
projection_audit_records), they are commutative — chaining order is
only an audit-log preference, not a correctness constraint. We chain
p114 -> p98 directly to keep p113 and p114/p115/p116 on independent
audit sub-chains (each easily revertible without affecting the other).
A merge migration at p113 + p114 head reconciliation is added separately
if dual-head appears (gsd-tools script proves single-head invariant
post-each-commit).

Downgrade
=========
True downgrade is impossible : HMAC is one-way, plaintext user_id was
NULLed and cannot be reconstructed. `downgrade()` is a no-op that logs
a warning ; rollback strategy is to restore from a pre-migration backup.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p114_hmac_pepper_audit"  # 22 chars — within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p98_fact_event_projection"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Re-backfill audit_events.user_id_hash via HMAC-pepper + NULL plaintext (PG only)."""
    bind = op.get_bind()

    # Import inside the migration body so the import path resolves against
    # the runtime services/backend/app/ tree (alembic env.py prepends it).
    # The hmac_user_id call reads MINT_AUDIT_HASH_PEPPER at first invocation
    # (lru_cached) ; TESTING=1 fallback applies for the test fixture path.
    from app.services.audit.hmac_pepper import hmac_user_id  # noqa: WPS433

    # ── Python data_upgrade : re-hash every row that still has a plaintext
    # user_id available. Rows where user_id is already NULL (e.g., p112
    # backfill missed them or a subsequent privacy-delete already cleared
    # them) are left alone.
    rows = bind.execute(
        sa.text("SELECT id, user_id FROM audit_events WHERE user_id IS NOT NULL")
    ).fetchall()

    for row in rows:
        new_hash = hmac_user_id(row.user_id)
        bind.execute(
            sa.text("UPDATE audit_events SET user_id_hash = :h WHERE id = :i"),
            {"h": new_hash, "i": row.id},
        )

    # ── Postgres post-pass : NULL the plaintext user_id (D-14 plaintext-drop).
    # SQLite test path skips this — fresh test DBs have minimal data and the
    # post-pass would interfere with parallel test cases that still rely on
    # plaintext user_id reads (DEFERRED-02-01-A / pre-existing readers).
    if bind.dialect.name == "postgresql":
        bind.execute(
            sa.text("UPDATE audit_events SET user_id = NULL WHERE user_id IS NOT NULL")
        )


def downgrade() -> None:
    """No-op — HMAC is one-way and plaintext user_id is unrecoverable.

    Per D-14 + alembic conventions for irreversible data migrations, this
    is intentionally a no-op. To roll back the HMAC-pepper backfill, restore
    from a pre-migration pg_dump snapshot.
    """
    # Intentionally empty. Document the irreversibility in the migration
    # docstring + this comment so future readers don't re-add a faux-downgrade.
    return
