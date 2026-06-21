"""Add stable Apple subject to users.

Revision ID: p124_user_apple_sub
Revises: p120_fact_event_idempotency
Create Date: 2026-06-21 09:05:00 UTC
"""

from alembic import op
import sqlalchemy as sa


revision = "p124_user_apple_sub"
down_revision = "p120_fact_event_idempotency"
branch_labels = None
depends_on = None


def _has_column(table_name: str, column_name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return column_name in {column["name"] for column in inspector.get_columns(table_name)}


def _has_index(table_name: str, index_name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return index_name in {index["name"] for index in inspector.get_indexes(table_name)}


def _backfill_synthetic_apple_subs() -> None:
    """Recover stable subs from legacy synthetic Apple relay emails."""
    bind = op.get_bind()
    prefix = "apple_"
    suffix = "@privaterelay.appleid.com"
    rows = bind.execute(
        sa.text(
            "SELECT id, email FROM users "
            "WHERE apple_sub IS NULL AND email LIKE :pattern"
        ),
        {"pattern": f"{prefix}%{suffix}"},
    )
    for row in rows:
        email = row.email
        if not email.startswith(prefix) or not email.endswith(suffix):
            continue
        apple_sub = email[len(prefix) : -len(suffix)]
        if not apple_sub:
            continue
        bind.execute(
            sa.text(
                "UPDATE users SET apple_sub = :apple_sub "
                "WHERE id = :user_id AND apple_sub IS NULL"
            ),
            {"apple_sub": apple_sub, "user_id": row.id},
        )


def upgrade() -> None:
    """Add nullable unique Apple sub for stable Sign in with Apple binding."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "users" not in inspector.get_table_names():
        return

    if not _has_column("users", "apple_sub"):
        with op.batch_alter_table("users", schema=None) as batch_op:
            batch_op.add_column(sa.Column("apple_sub", sa.String(), nullable=True))

    _backfill_synthetic_apple_subs()

    if not _has_index("users", "ix_users_apple_sub"):
        op.create_index(
            "ix_users_apple_sub",
            "users",
            ["apple_sub"],
            unique=True,
        )


def downgrade() -> None:
    """Remove stable Apple sub column and index if present."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "users" not in inspector.get_table_names():
        return

    if _has_index("users", "ix_users_apple_sub"):
        op.drop_index("ix_users_apple_sub", table_name="users")

    if _has_column("users", "apple_sub"):
        with op.batch_alter_table("users", schema=None) as batch_op:
            batch_op.drop_column("apple_sub")
