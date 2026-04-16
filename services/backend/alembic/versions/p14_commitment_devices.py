"""Create commitment_devices and pre_mortem_entries tables.

Commitment devices (CMIT-01/06): WHEN/WHERE/IF-THEN implementation intentions.
Pre-mortem entries (CMIT-05/06): risk scenarios before irrevocable decisions.

Revision ID: p14_commitment_devices
Revises: p13_password_changed_at
"""

revision = "p14_commitment_devices"
down_revision = "p13_password_changed_at"

from alembic import op
import sqlalchemy as sa


def upgrade():
    op.create_table(
        "commitment_devices",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "type",
            sa.String(),
            nullable=False,
            server_default="implementation_intention",
        ),
        sa.Column("when_text", sa.Text(), nullable=False),
        sa.Column("where_text", sa.Text(), nullable=False),
        sa.Column("if_then_text", sa.Text(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("reminder_at", sa.DateTime(), nullable=True),
    )
    op.create_index(
        "ix_commitment_devices_user_id", "commitment_devices", ["user_id"]
    )
    op.create_index(
        "ix_commitment_devices_user_status",
        "commitment_devices",
        ["user_id", "status"],
    )

    op.create_table(
        "pre_mortem_entries",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("decision_type", sa.String(), nullable=False),
        sa.Column("decision_context", sa.Text(), nullable=True),
        sa.Column("user_response", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index(
        "ix_pre_mortem_entries_user_id", "pre_mortem_entries", ["user_id"]
    )
    op.create_index(
        "ix_pre_mortem_entries_user_type",
        "pre_mortem_entries",
        ["user_id", "decision_type"],
    )


def downgrade():
    op.drop_index("ix_pre_mortem_entries_user_type", table_name="pre_mortem_entries")
    op.drop_index("ix_pre_mortem_entries_user_id", table_name="pre_mortem_entries")
    op.drop_table("pre_mortem_entries")
    op.drop_index(
        "ix_commitment_devices_user_status", table_name="commitment_devices"
    )
    op.drop_index("ix_commitment_devices_user_id", table_name="commitment_devices")
    op.drop_table("commitment_devices")
