"""Add birth_date column to snapshots table.

Revision ID: p12_add_birth_date
Revises: p11_profile_userid_idx
"""

revision = "p12_add_birth_date"
down_revision = "p11_profile_userid_idx"

from alembic import op
import sqlalchemy as sa


def upgrade():
    op.add_column("snapshots", sa.Column("birth_date", sa.String(), nullable=True))


def downgrade():
    op.drop_column("snapshots", "birth_date")
