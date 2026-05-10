"""Create magic_link_tokens table for passwordless login.

Backfills a table that has lived in the ORM since 2025 but never had its
own alembic revision. Previous boots relied on
``Base.metadata.create_all()`` at lifespan startup to create it in dev;
production got the table the same way on first deploy and has carried
it since — undocumented in alembic's head.

The latent debt surfaced 2026-04-21 when
``Base.metadata.create_all()`` raised
``psycopg2.errors.UniqueViolation`` on ``pg_type_typname_nsp_index``
for ``magic_link_tokens`` (orphan row-type surviving schema churn),
keeping Railway healthcheck from ever passing. The lifespan boot
now gates ``create_all()`` to non-production environments — so prod
must rely on alembic alone, which means this migration MUST own the
table shape going forward.

Idempotent: checks ``inspector.has_table`` before emitting CREATE,
so running it on prod DBs that already carry the table is a no-op.
New prod DBs (and dev DBs once we delete ``create_all()``) get it
natively from this revision.

Revision ID: 29_05_magic_link_tokens
Revises:    29_04_drop_auto_confirmed
"""
from __future__ import annotations

revision = "29_05_magic_link_tokens"
down_revision = "29_04_drop_auto_confirmed"

from alembic import op
import sqlalchemy as sa


_TABLE = "magic_link_tokens"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if _TABLE in inspector.get_table_names():
        # Already present (most prod + dev DBs today). Skip quietly.
        return

    op.create_table(
        _TABLE,
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("token_hash", sa.String(), nullable=False, unique=True),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("used", sa.Boolean(), nullable=False),
        sa.Column("used_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index(
        op.f("ix_magic_link_tokens_email"),
        _TABLE,
        ["email"],
        unique=False,
    )
    op.create_index(
        op.f("ix_magic_link_tokens_token_hash"),
        _TABLE,
        ["token_hash"],
        unique=True,
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if _TABLE not in inspector.get_table_names():
        return
    op.drop_index(
        op.f("ix_magic_link_tokens_token_hash"),
        table_name=_TABLE,
    )
    op.drop_index(
        op.f("ix_magic_link_tokens_email"),
        table_name=_TABLE,
    )
    op.drop_table(_TABLE)
