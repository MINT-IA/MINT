"""audit_events PII HMAC-pepper hash columns — D-15 carry-over.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-15 + D-24.

p114 closed the `user_id_hash` rainbow-table gap. p115 extends the same
HMAC-pepper protection to the remaining audit PII columns :
- `actor_email` → `actor_email_hash` (VARCHAR(64))
- `ip_address`  → `ip_address_hash`  (VARCHAR(64))
- `user_agent`  → `user_agent_hash`  (VARCHAR(64))

Each new column is nullable + indexed on the *_hash column so cross-table
audit joins remain efficient (e.g., « all actions by actor X » via the
hash-based identifier).

This migration is an ALTER + Python data_upgrade :
1. Add 3 *_hash columns via batch_alter_table (portable to SQLite via
   the standard alembic recipe).
2. For each existing row, compute the HMAC-pepper hash via
   `hmac_pii()` (canonical entry — same pepper as `hmac_user_id`,
   different input domain ; hash-uniform per the hmac_pepper docstring).
3. Plaintext `actor_email` / `ip_address` / `user_agent` columns are
   **RETAINED** for one deprecation cycle (D-15 explicit) so existing
   audit-export readers don't break ; a Phase 04 migration can NULL
   them after writers stop reading.

Idempotent : re-running the migration on already-hashed columns produces
the same hash bytes for the same input ; UPDATE is a no-op.

Revision ID : p115_hmac_pepper_pii            (22 chars — within Postgres VARCHAR(32) cap)
Revises     : p114_hmac_pepper_audit          (chains off p114 for audit-log linearity)
Create Date : 2026-05-18

Downgrade
=========
Drop the 3 new columns + their indexes. The original plaintext columns
are unaffected — they were retained intentionally — so downgrade is
schema-only and lossless for the plaintext side.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p115_hmac_pepper_pii"  # 20 chars — within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p114_hmac_pepper_audit"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Columns added by this migration : (plaintext_source, new_hash_column)
_HASH_COLUMNS = (
    ("actor_email", "actor_email_hash"),
    ("ip_address", "ip_address_hash"),
    ("user_agent", "user_agent_hash"),
)


def upgrade() -> None:
    """Add 3 *_hash columns + backfill via hmac_pii()."""
    bind = op.get_bind()

    # ── Step 1 : add the 3 *_hash columns + their indexes ────────────────
    with op.batch_alter_table("audit_events", schema=None) as batch_op:
        for _plaintext, hash_col in _HASH_COLUMNS:
            batch_op.add_column(
                sa.Column(hash_col, sa.String(length=64), nullable=True),
            )
            batch_op.create_index(
                f"ix_audit_events_{hash_col}",
                [hash_col],
            )

    # ── Step 2 : Python data_upgrade — backfill via hmac_pii() ───────────
    # Import inside the body so the import path resolves through env.py.
    from app.services.audit.hmac_pepper import hmac_pii  # noqa: WPS433

    # Single SELECT pulls all needed columns ; per-row UPDATE writes the
    # 3 hashes in one statement. For a pre-launch DB the row count is
    # bounded by the testing-cohort size ; production scale will be
    # bounded by Phase-04-pre-launch audit volume (≤ 10k rows expected).
    rows = bind.execute(
        sa.text(
            """
            SELECT id, actor_email, ip_address, user_agent
              FROM audit_events
             WHERE actor_email IS NOT NULL
                OR ip_address IS NOT NULL
                OR user_agent IS NOT NULL
            """
        )
    ).fetchall()

    for row in rows:
        bind.execute(
            sa.text(
                """
                UPDATE audit_events
                   SET actor_email_hash = :ae,
                       ip_address_hash  = :ip,
                       user_agent_hash  = :ua
                 WHERE id = :i
                """
            ),
            {
                "ae": hmac_pii(row.actor_email),
                "ip": hmac_pii(row.ip_address),
                "ua": hmac_pii(row.user_agent),
                "i": row.id,
            },
        )


def downgrade() -> None:
    """Drop the 3 *_hash columns + indexes. Plaintext columns are untouched."""
    with op.batch_alter_table("audit_events", schema=None) as batch_op:
        for _plaintext, hash_col in _HASH_COLUMNS:
            batch_op.drop_index(f"ix_audit_events_{hash_col}")
            batch_op.drop_column(hash_col)
