"""Hotfix C 2026-05-17 — audit_events.user_id_hash + Postgres backfill.

Closes the PII-residency gap on the audit log surfaced by the data-
architecture panel: `audit_events.user_id` was stored in plaintext with
no FK CASCADE and no DEK protection, so audit rows for an erased user
remained fully re-identifiable.

This migration adds `audit_events.user_id_hash` (sha256, indexed) and
backfills existing rows on Postgres. The plaintext `user_id` column
is intentionally NOT dropped here — it stays one deprecation cycle so
read paths can migrate. A follow-up migration (PR body tracks the gap)
will NULL it after writers have shipped.

Revision ID : p112_audit_event_user_hash     (26 chars — within Postgres
              alembic_version.version_num VARCHAR(32) cap).
Revises     : p111_projection_audit
Create Date : 2026-05-17

Dialect branch
==============
Postgres : backfill via `encode(digest(user_id, 'sha256'), 'hex')`
(requires the `pgcrypto` extension — see fallback below). Defense in
depth: a DO block tries pgcrypto first, falls back to a no-op if the
extension is not installed. New writes (audit_service.log_audit_event)
populate the column going forward regardless.

SQLite : skip backfill. Test fixtures use fresh DBs; existing rows are
created within the test session and write through the updated helper.

Downgrade
=========
Drop the column + drop the index.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p112_audit_event_user_hash"  # 26 chars — within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p111_projection_audit"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Step 1 : add user_id_hash column (nullable for backfill compat) ──
    with op.batch_alter_table("audit_events", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("user_id_hash", sa.String(length=64), nullable=True),
        )
        batch_op.create_index(
            "ix_audit_events_user_id_hash",
            ["user_id_hash"],
        )

    # ── Step 2 : Postgres backfill (best-effort, no-op if pgcrypto absent) ──
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute(
            """
            DO $$
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'
                ) THEN
                    UPDATE audit_events
                       SET user_id_hash = encode(digest(user_id, 'sha256'), 'hex')
                     WHERE user_id IS NOT NULL
                       AND user_id_hash IS NULL;
                END IF;
            END
            $$;
            """
        )
        # Note: rows where pgcrypto is missing OR user_id IS NULL stay
        # with user_id_hash IS NULL. New writes populate via
        # audit_service.hash_user_id() in Python; backfill of missing
        # rows can be re-attempted as a one-off if pgcrypto is later
        # installed.


def downgrade() -> None:
    with op.batch_alter_table("audit_events", schema=None) as batch_op:
        batch_op.drop_index("ix_audit_events_user_id_hash")
        batch_op.drop_column("user_id_hash")
