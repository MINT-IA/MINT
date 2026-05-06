"""anonymous_sessions.eclairage_delivered (Phase 71b carry-over hotfix v2.12.0)

Phase 71b added `eclairage_delivered` Boolean column to the
AnonymousSession SQLAlchemy model but never created the corresponding
Alembic migration. Result : staging Railway PostgreSQL ran without the
column, every `/api/v1/anonymous/chat` POST hit
`column anonymous_sessions.eclairage_delivered does not exist`
(Sentry alert 2026-05-06 11:01 UTC, post v2.12.0 TestFlight build).

This hotfix migration ships the column with `server_default='0'` so
existing rows on staging/production back-fill cleanly without
manual SQL.

Revision ID: p86_eclairage_delivered
Revises: 29_04_drop_auto_confirmed
Create Date: 2026-05-06 11:30:00 UTC
"""

from alembic import op
import sqlalchemy as sa


revision = "p86_eclairage_delivered"
down_revision = "29_04_drop_auto_confirmed"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Add `eclairage_delivered` Boolean to anonymous_sessions.

    Idempotency: guarded with a column-exists check via a raw SQL
    inspection, so re-running on a DB that already has the column
    (e.g. local dev SQLite where the model auto-created it) does not
    fail.
    """
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("anonymous_sessions")}
    if "eclairage_delivered" in cols:
        return  # already present (local SQLite auto-create case)

    op.add_column(
        "anonymous_sessions",
        sa.Column(
            "eclairage_delivered",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("anonymous_sessions", "eclairage_delivered")
