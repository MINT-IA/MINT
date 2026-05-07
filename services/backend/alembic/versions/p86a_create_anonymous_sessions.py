"""Create anonymous_sessions table (Phase 13 schema drift fix).

The `AnonymousSession` SQLAlchemy model (introduced Phase 13 for
anonymous chat rate limiting) was never paired with an alembic
migration. Existing staging / production environments have the table
because `Base.metadata.create_all()` ran at app boot before alembic was
the source of truth — so they never noticed.

CI fresh-database runs (Phase 95-03 TEST-03/04: `alembic upgrade head
&& alembic downgrade base && alembic upgrade head`) hit
`sqlalchemy.exc.NoSuchTableError: anonymous_sessions` because:
- the chain reaches `p86_eclairage_delivered` which calls
  `inspector.get_columns("anonymous_sessions")`
- the table was never created via alembic, so it does not exist on a
  fresh DB

This migration ships the table creation idempotently. It is inserted
BEFORE `p86_eclairage_delivered` in the chain. For prod / staging
already at `p86_eclairage_delivered`, the upgrade direction is a no-op
(alembic only walks forward when current != head). For the downgrade
direction the chain becomes:

    p86_eclairage_delivered → p86a_create_anonymous_sessions → 29_04_drop_auto_confirmed → ...

Both directions are idempotent so the same code runs cleanly on:
- fresh test_migration.db (creates table)
- staging / prod (table already exists from create_all → no-op)
- downgrade then upgrade (drop then re-create)

Revision ID: p86a_create_anonymous_sessions
Revises: 29_04_drop_auto_confirmed
Create Date: 2026-05-07 08:10:00 UTC
"""

from alembic import op
import sqlalchemy as sa


revision = "p86a_create_anonymous_sessions"
down_revision = "29_04_drop_auto_confirmed"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create anonymous_sessions table if it does not already exist."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "anonymous_sessions" in inspector.get_table_names():
        return  # already exists (prod / staging via create_all)

    op.create_table(
        "anonymous_sessions",
        sa.Column("session_id", sa.String(length=36), primary_key=True),
        sa.Column(
            "message_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
        ),
    )


def downgrade() -> None:
    """Drop anonymous_sessions table if it exists."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "anonymous_sessions" not in inspector.get_table_names():
        return  # already gone

    op.drop_table("anonymous_sessions")
