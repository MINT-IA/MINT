"""Create document_memory table for v2.7 phase 28 differential update.

Revision ID: p28_document_memory
Revises: 5f7922bff82b
"""

revision = "p28_document_memory"
down_revision = "5f7922bff82b"

from alembic import op
import sqlalchemy as sa


def upgrade():
    op.create_table(
        "document_memory",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("fingerprint", sa.String(length=128), nullable=False),
        sa.Column("doc_type", sa.String(), nullable=False),
        sa.Column("issuer", sa.String(), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.Column("field_history", sa.JSON(), nullable=False),
        sa.UniqueConstraint(
            "user_id", "fingerprint", name="uq_document_memory_user_fp"
        ),
    )
    op.create_index(
        "ix_document_memory_user_id", "document_memory", ["user_id"]
    )
    op.create_index(
        "ix_document_memory_fingerprint", "document_memory", ["fingerprint"]
    )
    op.create_index(
        "ix_document_memory_user_fp", "document_memory", ["user_id", "fingerprint"]
    )


def downgrade():
    op.drop_index("ix_document_memory_user_fp", table_name="document_memory")
    op.drop_index("ix_document_memory_fingerprint", table_name="document_memory")
    op.drop_index("ix_document_memory_user_id", table_name="document_memory")
    op.drop_table("document_memory")
