"""_phase02_parity_audit_continuous — continuous drift sampler persistence.

Phase mint-data-architecture-v1-02 Plan 02-03 — iter-2 B18.

Sibling of `_phase02_parity_audit` (p118). Whereas p118 stores the
ONE-SHOT 100%% staging-user audit captured immediately before PR-3a
merge, this table stores the CONTINUOUS 30-min sampled drift checks
running through the 7-day soak window between PR-3a merge and PR-3b
merge.

The Task 2b checkpoint preamble (« 7-day continuous-drift sampler clean
window prerequisite ») queries this table :

    SELECT date_trunc('hour', sampled_at) AS h,
           count(*) FILTER (WHERE diff_count > 0) AS dirty
    FROM _phase02_parity_audit_continuous
    WHERE sampled_at > now() - interval '7 days'
    GROUP BY 1 ORDER BY 1 DESC;

Expected : zero rows with dirty > 0 across the 7-day window OR at
least 24 consecutive hours adjacent to NOW are clean.

The table is staging-only at runtime ; production never queries it.
Cron job `services/backend/app/cron/continuous_drift_sampler.py`
samples 100 random staging users every 30 min, runs `projection_diff`
on each pair, writes one row per user per cron tick (so 100 rows × 48
ticks/day × 7 days = ~33,600 rows for the full soak window).

Revision ID : p119_phase02_parity_cont   (24 chars — within VARCHAR(32) cap)
Revises     : p118_phase02_parity_audit
Create Date : 2026-05-18
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB


revision: str = "p119_phase02_parity_cont"
down_revision: Union[str, Sequence[str], None] = "p118_phase02_parity_audit"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create _phase02_parity_audit_continuous (staging-only)."""
    bind = op.get_bind()
    dialect = bind.dialect.name

    diff_details_type = JSONB() if dialect == "postgresql" else sa.JSON()
    pk_type = sa.BigInteger().with_variant(sa.Integer(), "sqlite")

    op.create_table(
        "_phase02_parity_audit_continuous",
        sa.Column("id", pk_type, primary_key=True, autoincrement=True),
        sa.Column(
            "sampled_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("user_id_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "diff_count",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
            doc=(
                "Number of ParityDiffResult.reasons entries for this sample. "
                "0 = EQUAL ; >0 = DIFF count (drift). The 7-day clean window "
                "test is `SUM(diff_count) FILTER (WHERE sampled_at > now() - "
                "interval '24 hours') = 0`."
            ),
        ),
        sa.Column(
            "diff_details",
            diff_details_type,
            nullable=False,
            server_default=sa.text("'{}'") if dialect != "postgresql" else sa.text("'{}'::jsonb"),
        ),
        sa.Column("sampler_run_id", sa.String(length=36), nullable=False),
    )

    op.create_index(
        "ix_phase02_parity_audit_continuous_sampled",
        "_phase02_parity_audit_continuous",
        ["sampled_at"],
    )
    # Partial-index optimisation for the « how many dirty in last 24h » query.
    # SQLite supports partial indexes ; Postgres does too. The condition
    # is identical across dialects.
    op.create_index(
        "ix_phase02_parity_audit_continuous_dirty",
        "_phase02_parity_audit_continuous",
        ["diff_count"],
        postgresql_where=sa.text("diff_count > 0"),
        sqlite_where=sa.text("diff_count > 0"),
    )


def downgrade() -> None:
    op.drop_index(
        "ix_phase02_parity_audit_continuous_dirty",
        table_name="_phase02_parity_audit_continuous",
    )
    op.drop_index(
        "ix_phase02_parity_audit_continuous_sampled",
        table_name="_phase02_parity_audit_continuous",
    )
    op.drop_table("_phase02_parity_audit_continuous")
