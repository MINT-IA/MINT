"""Create waitlist_entries table — sub-phase 01.5 archetype HARD GATE.

Persists email + consent metadata captured by the mobile WaitlistScreen
when a user's archetype is NOT in the calibrated set
(`swiss_native` / `swiss_native_couple`-equivalent). Schema mirrors
`app/models/waitlist_entry.py`.

Per memory `project_orm_orphan_pattern` — model + migration ship in
the same PR. The ORM-orphan CI lint (p122_orm_orphan_safety_net) would
fail at merge if this migration were missing.

Idempotent : checks `inspector.get_table_names()` before CREATE/DROP so
the migration is safe on a DB that already has the table (e.g. if a
local dev ran `Base.metadata.create_all()` before alembic walked here).

Revision ID: p123_waitlist_entry
Revises: p122_orm_orphan_safety_net
Create Date: 2026-05-21 21:00:00 UTC
"""

from alembic import op
import sqlalchemy as sa


revision = "p123_waitlist_entry"
down_revision = "p122_orm_orphan_safety_net"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create waitlist_entries table + indexes if absent."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "waitlist_entries" in inspector.get_table_names():
        return

    op.create_table(
        "waitlist_entries",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("email", sa.String(length=254), nullable=False),
        sa.Column("archetype", sa.String(length=32), nullable=False),
        sa.Column("locale", sa.String(length=8), nullable=False),
        sa.Column(
            "source",
            sa.String(length=32),
            nullable=False,
            server_default="other",
        ),
        sa.Column(
            "anonymous_session_id",
            sa.String(length=36),
            nullable=False,
        ),
        sa.Column("consent_given", sa.Boolean(), nullable=False),
        sa.Column(
            "legal_entity",
            sa.String(length=64),
            nullable=False,
            server_default="MINT SA",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("notified_at", sa.DateTime(), nullable=True),
        sa.Column(
            "retention_purge_after",
            sa.DateTime(),
            nullable=False,
        ),
    )

    op.create_index(
        "ix_waitlist_entries_email",
        "waitlist_entries",
        ["email"],
    )
    op.create_index(
        "ix_waitlist_entries_archetype",
        "waitlist_entries",
        ["archetype"],
    )
    op.create_index(
        "ix_waitlist_entries_anonymous_session_id",
        "waitlist_entries",
        ["anonymous_session_id"],
    )


def downgrade() -> None:
    """Drop waitlist_entries table + indexes if present."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "waitlist_entries" not in inspector.get_table_names():
        return

    op.drop_index(
        "ix_waitlist_entries_anonymous_session_id",
        table_name="waitlist_entries",
    )
    op.drop_index(
        "ix_waitlist_entries_archetype",
        table_name="waitlist_entries",
    )
    op.drop_index(
        "ix_waitlist_entries_email",
        table_name="waitlist_entries",
    )
    op.drop_table("waitlist_entries")
