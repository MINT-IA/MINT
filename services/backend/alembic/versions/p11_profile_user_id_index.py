"""Add index on profiles.user_id for query performance.

Revision ID: p11_profile_userid_idx
Revises: p10_scenarios_table
"""

revision = "p11_profile_userid_idx"
down_revision = "p10_scenarios_table"

from alembic import op


def upgrade():
    op.create_index("ix_profiles_user_id", "profiles", ["user_id"])


def downgrade():
    op.drop_index("ix_profiles_user_id", "profiles")
