"""projection_audit_records — Mobile L1 columns + handshake UNIQUE.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-12 + D-MOB-03 + iter-2 A6.

Extends `projection_audit_records` (per the original Hotfix B 2026-05-17
schema) with five Mobile L1 audit columns + a UNIQUE constraint that
makes the `/v1/audit/mobile-session-link` endpoint replay-safe :

  source                   VARCHAR(32)  NOT NULL DEFAULT 'projection'
  app_version              VARCHAR(32)  NULL
  observed_at              TIMESTAMPTZ  NULL
  anonymous_session_id     VARCHAR(36)  NULL  -- UUID v7 from Mobile L1
  local_event_id           VARCHAR(64)  NULL  -- mobile-side dedup key
  app_lifecycle_state      VARCHAR(32)  NULL  -- 'paused' | 'resumed' | 'inactive' | 'detached'
  client_ts                TIMESTAMPTZ  NULL  -- mobile-side timestamp
  server_received_ts       TIMESTAMPTZ  NULL  -- backend-side ingest timestamp

`source` defaults to `'projection'` so existing rows (pre-D-12) keep the
audit log semantics they had before. New mobile audit rows write
`source='mobile_session_start'` or `'mobile_session_warm_resume'` and
populate the other Mobile L1 columns.

UNIQUE constraint
=================
`uq_proj_audit_anon_observed` on `(anonymous_session_id, observed_at)`
WHERE `anonymous_session_id IS NOT NULL` (partial unique on Postgres ;
plain unique on SQLite). This is the iter-2 A6 replay-safety contract :
a duplicate batch POST returns 200 + skipped-count, NOT 409, so the
mobile offline replay can be retried indefinitely without server-side
state divergence.

Why p113 chains off p116 (not p98 as plan-frontmatter sketched)
================================================================
The plan-frontmatter sketch had `p98 -> p113 -> p114 -> p115 -> p116`.
Continuation-4 ships p114/p115/p116 BEFORE p113 (P1 landed first
because the pepper carry-overs were higher-risk + the audit_events
table is cross-cutting). p113 chains off p116 to keep the audit-log
linear and avoid a new dual-head condition. The migrations on the
two tables (audit_events vs projection_audit_records) are commutative
— chain order is an audit-log preference, not a correctness constraint.

Revision ID : p113_extend_proj_audit_mob      (28 chars — within Postgres VARCHAR(32) cap)
Revises     : p116_snapshot_invalidation      (chains off the P1 head)
Create Date : 2026-05-18

Downgrade
=========
Drop the UNIQUE index + drop the 8 columns. Schema-side reversible ;
existing rows that wrote mobile-L1 columns lose those values (data
loss on downgrade — same trade-off as any column-add migration).
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p113_extend_proj_audit_mob"  # 26 chars — within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p116_snapshot_invalidation"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add 8 Mobile L1 columns + a partial UNIQUE index."""
    bind = op.get_bind()
    is_pg = bind.dialect.name == "postgresql"

    with op.batch_alter_table("projection_audit_records", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "source",
                sa.String(length=32),
                nullable=False,
                server_default=sa.text("'projection'"),
            ),
        )
        batch_op.add_column(
            sa.Column("app_version", sa.String(length=32), nullable=True),
        )
        batch_op.add_column(
            sa.Column("observed_at", sa.DateTime(timezone=True), nullable=True),
        )
        batch_op.add_column(
            sa.Column("anonymous_session_id", sa.String(length=36), nullable=True),
        )
        batch_op.add_column(
            sa.Column("local_event_id", sa.String(length=64), nullable=True),
        )
        batch_op.add_column(
            sa.Column("app_lifecycle_state", sa.String(length=32), nullable=True),
        )
        batch_op.add_column(
            sa.Column("client_ts", sa.DateTime(timezone=True), nullable=True),
        )
        batch_op.add_column(
            sa.Column(
                "server_received_ts",
                sa.DateTime(timezone=True),
                nullable=True,
            ),
        )

    # ── UNIQUE on (anonymous_session_id, observed_at) — partial on PG,
    # plain on SQLite. The Mobile L1 handshake replay-safety contract.
    if is_pg:
        # Partial unique : only enforced when anonymous_session_id IS NOT NULL,
        # so existing rows (pre-D-12, source='projection') with NULL
        # anonymous_session_id remain unaffected.
        op.execute(
            """
            CREATE UNIQUE INDEX uq_proj_audit_anon_observed
                ON projection_audit_records (anonymous_session_id, observed_at)
                WHERE anonymous_session_id IS NOT NULL
            """
        )
    else:
        # SQLite path : plain unique (SQLite supports partial via
        # sqlite_where but the test fixture path uses fresh DBs where
        # the partial-vs-plain distinction is observable only at INSERT
        # time on NULL rows — and we have none).
        op.create_index(
            "uq_proj_audit_anon_observed",
            "projection_audit_records",
            ["anonymous_session_id", "observed_at"],
            unique=True,
        )


def downgrade() -> None:
    """Drop the UNIQUE index + the 8 Mobile L1 columns."""
    bind = op.get_bind()
    is_pg = bind.dialect.name == "postgresql"

    if is_pg:
        op.execute("DROP INDEX IF EXISTS uq_proj_audit_anon_observed")
    else:
        op.drop_index(
            "uq_proj_audit_anon_observed",
            table_name="projection_audit_records",
        )

    with op.batch_alter_table("projection_audit_records", schema=None) as batch_op:
        batch_op.drop_column("server_received_ts")
        batch_op.drop_column("client_ts")
        batch_op.drop_column("app_lifecycle_state")
        batch_op.drop_column("local_event_id")
        batch_op.drop_column("anonymous_session_id")
        batch_op.drop_column("observed_at")
        batch_op.drop_column("app_version")
        batch_op.drop_column("source")
