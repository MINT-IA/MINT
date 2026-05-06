"""Phase 93 — coach_message_audits table (COMP-01).

Stand up the OAR-G art. 24 + FINMA Guidance 8/2024 SS VI compliant audit
log for every coach response (authenticated /coach/chat + anonymous
/anonymous/chat).

A FINMA inspector running

    SELECT * FROM coach_message_audits WHERE created_at > '2026-05-06'

must see one row per LLM response, with hashed prompt + response
(nLPD-safe), archetype, banned-term-hit flag, eclairage kind, and
retained_until = +10y.

Idempotent forward + rollback so the migration is safe to re-run on a
local SQLite that already auto-created the table via Base.metadata.

Revision ID: p93_coach_message_audit
Revises: p86_eclairage_delivered
Create Date: 2026-05-07 00:00:00 UTC
"""

from alembic import op
import sqlalchemy as sa


revision = "p93_coach_message_audit"
down_revision = "p86_eclairage_delivered"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create the coach_message_audits table + indexes (idempotent)."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "coach_message_audits" in inspector.get_table_names():
        # Already present (local SQLite auto-create or re-run on a DB
        # that already migrated). Per the p86 idempotency pattern.
        return

    op.create_table(
        "coach_message_audits",
        sa.Column("id", sa.String(), primary_key=True, nullable=False),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("archetype", sa.String(), nullable=True),
        sa.Column("prompt_hash", sa.String(), nullable=False),
        sa.Column("response_hash", sa.String(), nullable=False),
        sa.Column(
            "banned_term_hit",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("eclairage_kind", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("retained_until", sa.DateTime(), nullable=True),
    )

    # Indexes mirror the SQLAlchemy model (`index=True` on session_id +
    # created_at). Named explicitly so the rollback drops them cleanly.
    op.create_index(
        "ix_coach_message_audits_session_id",
        "coach_message_audits",
        ["session_id"],
    )
    op.create_index(
        "ix_coach_message_audits_created_at",
        "coach_message_audits",
        ["created_at"],
    )


def downgrade() -> None:
    """Drop the coach_message_audits table + indexes (idempotent)."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "coach_message_audits" not in inspector.get_table_names():
        return

    # Drop indexes first to keep rollback symmetric with upgrade.
    existing_indexes = {ix["name"] for ix in inspector.get_indexes("coach_message_audits")}
    if "ix_coach_message_audits_created_at" in existing_indexes:
        op.drop_index(
            "ix_coach_message_audits_created_at",
            table_name="coach_message_audits",
        )
    if "ix_coach_message_audits_session_id" in existing_indexes:
        op.drop_index(
            "ix_coach_message_audits_session_id",
            table_name="coach_message_audits",
        )
    op.drop_table("coach_message_audits")
