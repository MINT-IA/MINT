"""Phase 95 DAG-INVALIDATION — inputs_hash + superseded_by additive.

Revision ID: p95_dag_invalidation
Revises: 29_05_magic_link_tokens
Create Date: 2026-05-10 UTC

Adds two nullable columns to the `scenarios` table :
- inputs_hash    TEXT(64) NULL — SHA256 hex of RFC 8785 canonical inputs
- superseded_by  TEXT(36) NULL — UUID7 of the scenario that replaces this one

Both default NULL. Existing rows remain NULL until the next projection
touch invokes the new emitter (Wave 2). Per CONTEXT D-06 + RESEARCH §D-06
+ ROADMAP Phase 95 Success Criteria #3 — additive only, zero backfill.

Idempotency : inspector.get_columns guard makes re-running the upgrade
a no-op (precedent : p86_anonymous_session_eclairage_delivered.py).

Downgrade uses batch_alter_table for SQLite < 3.35 compat (SQLite cannot
drop columns directly). On PostgreSQL the batch wrapper degrades to raw
DROP COLUMN.
"""
from alembic import op
import sqlalchemy as sa


revision = "p95_dag_invalidation"
down_revision = "29_05_magic_link_tokens"
branch_labels = None
depends_on = None

TARGET_TABLE = "scenarios"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns(TARGET_TABLE)}
    if "inputs_hash" not in cols:
        op.add_column(
            TARGET_TABLE,
            sa.Column("inputs_hash", sa.String(64), nullable=True),
        )
    if "superseded_by" not in cols:
        op.add_column(
            TARGET_TABLE,
            sa.Column("superseded_by", sa.String(36), nullable=True),
        )


def downgrade() -> None:
    # SQLite < 3.35 cannot drop columns directly — batch_alter_table is
    # the cross-DB safe path. On PostgreSQL the batch wrapper still
    # produces a clean DROP COLUMN per column.
    with op.batch_alter_table(TARGET_TABLE) as batch:
        batch.drop_column("superseded_by")
        batch.drop_column("inputs_hash")
