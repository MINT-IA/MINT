"""Add latest_event_id to fact_current for D-27 replay idempotency.

Revision ID: p120_fact_event_idempotency
Revises: p123_waitlist_entry
Create Date: 2026-06-02

The migration name keeps the Phase 02 plan vocabulary, but it chains after the
current repository head (`p123_waitlist_entry`) to avoid creating a second
Alembic head.
"""

from alembic import op
import sqlalchemy as sa


revision = "p120_fact_event_idempotency"
down_revision = "p123_waitlist_entry"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("fact_current")}
    if "latest_event_id" not in columns:
        op.add_column(
            "fact_current",
            sa.Column("latest_event_id", sa.String(length=36), nullable=True),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("fact_current")}
    if "latest_event_id" in columns:
        op.drop_column("fact_current", "latest_event_id")
