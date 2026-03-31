"""Add password_changed_at column to users table.

Token invalidation on password change (FIX-049).
Tokens issued before this timestamp are rejected by auth middleware.

Revision ID: p13_password_changed_at
Revises: p12_add_birth_date
"""

revision = "p13_password_changed_at"
down_revision = "p12_add_birth_date"

from alembic import op
import sqlalchemy as sa


def upgrade():
    op.add_column(
        "users",
        sa.Column("password_changed_at", sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_column("users", "password_changed_at")
