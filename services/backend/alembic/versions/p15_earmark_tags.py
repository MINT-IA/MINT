"""Create provenance_records and earmark_tags tables.

Provenance records (INTL-01/02): who recommended a financial product.
Earmark tags (INTL-03/04): relational/emotional money tagging.

Revision ID: p15_earmark_tags
Revises: p14_commitment_devices
"""

revision = "p15_earmark_tags"
down_revision = "p14_commitment_devices"

from alembic import op
import sqlalchemy as sa


def upgrade():
    op.create_table(
        "provenance_records",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("product_type", sa.String(), nullable=False),
        sa.Column("recommended_by", sa.String(), nullable=False),
        sa.Column("institution", sa.String(), nullable=True),
        sa.Column("context_note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index(
        "ix_provenance_records_user_id", "provenance_records", ["user_id"]
    )
    op.create_index(
        "ix_provenance_records_user_product",
        "provenance_records",
        ["user_id", "product_type"],
    )

    op.create_table(
        "earmark_tags",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("label", sa.String(), nullable=False),
        sa.Column("source_description", sa.Text(), nullable=True),
        sa.Column("amount_hint", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index(
        "ix_earmark_tags_user_id", "earmark_tags", ["user_id"]
    )
    op.create_index(
        "ix_earmark_tags_user_label",
        "earmark_tags",
        ["user_id", "label"],
    )


def downgrade():
    op.drop_index("ix_earmark_tags_user_label", table_name="earmark_tags")
    op.drop_index("ix_earmark_tags_user_id", table_name="earmark_tags")
    op.drop_table("earmark_tags")
    op.drop_index(
        "ix_provenance_records_user_product", table_name="provenance_records"
    )
    op.drop_index("ix_provenance_records_user_id", table_name="provenance_records")
    op.drop_table("provenance_records")
