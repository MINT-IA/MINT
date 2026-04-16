"""Create profile_facts table with purpose + ttl_expires_at columns.

PRIV-06 — Phase 29-03.

Idempotent + safe on prod data:
    - Creates profile_facts if not exists (8-key allowlist storage).
    - On legacy DBs that already had a different profile_facts shape,
      the migration adds missing columns (purpose / ttl_expires_at) and
      backfills via the in-process allowlist module. Unknown legacy keys
      are tagged purpose='legacy' + ttl_expires_at=NOW()+30d so the
      nightly purge cleans them gradually.

Revision ID: 29_03_fact_key_ttl_purpose
Revises:    29_02_consents_granular
"""
from __future__ import annotations

revision = "29_03_fact_key_ttl_purpose"
down_revision = "29_02_consents_granular"

from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector


def _has_table(inspector: Inspector, table: str) -> bool:
    return table in inspector.get_table_names()


def _has_column(inspector: Inspector, table: str, column: str) -> bool:
    return any(c["name"] == column for c in inspector.get_columns(table))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _has_table(inspector, "profile_facts"):
        op.create_table(
            "profile_facts",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "user_id",
                sa.String(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            sa.Column("fact_key", sa.String(length=64), nullable=False),
            sa.Column("value", sa.Text(), nullable=True),
            sa.Column(
                "purpose",
                sa.String(length=32),
                nullable=False,
                server_default="projection",
            ),
            sa.Column("ttl_expires_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text("CURRENT_TIMESTAMP"),
            ),
            sa.UniqueConstraint(
                "user_id", "fact_key", name="uq_profile_facts_user_key"
            ),
        )
        op.create_index(
            "ix_profile_facts_ttl_expires",
            "profile_facts",
            ["ttl_expires_at"],
        )
        return

    # Legacy table existed (some env). Add missing columns idempotently.
    if not _has_column(inspector, "profile_facts", "purpose"):
        op.add_column(
            "profile_facts",
            sa.Column(
                "purpose",
                sa.String(length=32),
                nullable=False,
                server_default="legacy",
            ),
        )
    if not _has_column(inspector, "profile_facts", "ttl_expires_at"):
        op.add_column(
            "profile_facts",
            sa.Column("ttl_expires_at", sa.DateTime(timezone=True), nullable=True),
        )

    # Backfill legacy rows: known keys → real purpose, unknown → 'legacy'
    # with TTL = NOW() + 30 days so the purge job cleans them gradually.
    try:
        from app.services.privacy.fact_key_allowlist import ALLOWED_FACT_KEYS

        for key, meta in ALLOWED_FACT_KEYS.items():
            op.execute(
                sa.text(
                    "UPDATE profile_facts SET purpose = :p, ttl_expires_at = NULL "
                    "WHERE fact_key = :k AND (purpose IS NULL OR purpose = 'legacy')"
                ).bindparams(p=meta["purpose"].value, k=key)
            )
        # Tag remaining (unknown) rows as legacy with 30d TTL.
        op.execute(
            sa.text(
                "UPDATE profile_facts SET purpose = 'legacy', "
                "ttl_expires_at = (CURRENT_TIMESTAMP + INTERVAL '30 days') "
                "WHERE purpose IS NULL OR (purpose = 'legacy' AND ttl_expires_at IS NULL)"
            )
        )
    except Exception:
        # Backfill is best-effort. If the in-process import fails (e.g.
        # alembic offline mode), leave rows as-is — the application-level
        # allowlist still gates new writes.
        pass


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if _has_table(inspector, "profile_facts"):
        try:
            op.drop_index("ix_profile_facts_ttl_expires", table_name="profile_facts")
        except Exception:
            pass
        # Down-migration drops the table because there is no pre-29-03
        # canonical schema to revert to. Data loss is intentional and
        # documented; downgrade is for dev/test only.
        op.drop_table("profile_facts")
