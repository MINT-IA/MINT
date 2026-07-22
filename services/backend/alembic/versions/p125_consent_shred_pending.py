"""Add durable shred_pending flag to consents.

Audit T02-F49 (beads MINT_nosync-tqj): revoke() ignored the _shred() return
value and reported cascade_scheduled=True even when the crypto-shred failed,
with no durable retry — the nLPD erasure guarantee was fail-open. This flag
records a failed shred durably so it can be retried on the next consent
interaction (or swept by a job).

Revision ID: p125_consent_shred_pending
Revises: p124_user_apple_sub
Create Date: 2026-07-22 14:20:00 UTC
"""

from alembic import op
import sqlalchemy as sa


revision = "p125_consent_shred_pending"
down_revision = "p124_user_apple_sub"
branch_labels = None
depends_on = None


def _has_column(table_name: str, column_name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return column_name in {column["name"] for column in inspector.get_columns(table_name)}


def upgrade() -> None:
    if not _has_column("consents", "shred_pending"):
        op.add_column(
            "consents",
            sa.Column(
                "shred_pending",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
        )


def downgrade() -> None:
    if _has_column("consents", "shred_pending"):
        op.drop_column("consents", "shred_pending")
