"""Persist scenarios in PostgreSQL.

Revision ID: p10_scenarios_table
Revises: p9_documents_table
"""
revision = "p10_scenarios_table"
down_revision = "p9_documents_table"

from alembic import op
import sqlalchemy as sa


def upgrade():
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    if "scenarios" in inspector.get_table_names():
        return

    op.create_table(
        "scenarios",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("profile_id", sa.String(), nullable=False, index=True),
        sa.Column("kind", sa.String(), nullable=False),
        sa.Column("inputs", sa.JSON(), nullable=True),
        sa.Column("outputs", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime()),
    )


def downgrade():
    op.drop_table("scenarios")
