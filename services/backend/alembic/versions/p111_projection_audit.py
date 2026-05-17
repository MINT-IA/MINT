"""Hotfix B 2026-05-17 — projection_audit_records + snapshots.constants_version_hash.

Closes two gaps surfaced by the data-architecture panel (ADR
.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md):

  (i)  Snapshots had no record of the regulatory snapshot that produced
       them. Adds `snapshots.constants_version_hash` (nullable for
       backfill compat; populated on new rows by the writer in
       app/services/snapshots/snapshot_service.py).

  (ii) No append-only LSFin advice audit trail existed. Creates the
       `projection_audit_records` table and, on Postgres, runs
       `REVOKE UPDATE, DELETE` so the table is structurally append-only
       at the DB level — `DROP TABLE` remains the only way to clear
       rows (which itself is auditable in Postgres).

Revision ID : p111_projection_audit       (21 chars — within Postgres
              alembic_version.version_num VARCHAR(32) cap that bit
              the p97 deploy on 2026-05-12).
Revises     : p110_scenarios_cache_idx
Create Date : 2026-05-17

Dialect branch
==============
Postgres : REVOKE UPDATE, DELETE on the audit table from PUBLIC and (if
the role exists) from `app_role`. SQLite test path keeps INSERT-only by
convention — SQLite has no role-level GRANT, so the test fixtures rely
on the application never issuing UPDATE / DELETE on this table. The
behavioural contract is identical; only the enforcement mechanism
differs.

Downgrade
=========
DROP TABLE removes all privileges automatically, so no symmetric GRANT
is needed on downgrade. The `constants_version_hash` column is dropped
via `batch_alter_table` for SQLite compatibility.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p111_projection_audit"  # 21 chars — within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p110_scenarios_cache_idx"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Step 1 : add constants_version_hash to snapshots ────────────────
    # Nullable so existing rows backfill cleanly (they predate the writer
    # change). New rows get a non-null value from
    # snapshot_service.create_snapshot.
    with op.batch_alter_table("snapshots", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("constants_version_hash", sa.String(length=64), nullable=True),
        )

    # ── Step 2 : create projection_audit_records (append-only) ──────────
    op.create_table(
        "projection_audit_records",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id_hash", sa.String(length=64), nullable=False),
        sa.Column("computed_at", sa.DateTime(), nullable=False),
        sa.Column("projection_type", sa.String(length=32), nullable=False),
        sa.Column("projection_id", sa.String(), nullable=False),
        sa.Column("constants_version_hash", sa.String(length=64), nullable=False),
        sa.Column("scenario_inputs_hash", sa.String(length=64), nullable=False),
        sa.Column("output_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "lsfin_disclaimer_shown",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("0"),  # SQLite-safe; Postgres coerces to false
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_projection_audit_user_computed",
        "projection_audit_records",
        ["user_id_hash", "computed_at"],
    )

    # ── Step 3 : Postgres append-only enforcement ───────────────────────
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute(
            "REVOKE UPDATE, DELETE ON projection_audit_records FROM PUBLIC"
        )
        # Defense in depth: revoke from the named app role if it exists.
        # The DO block makes this safe in environments where app_role is
        # not provisioned (CI, dev). Failure to revoke is non-blocking.
        op.execute(
            """
            DO $$
            BEGIN
                IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_role') THEN
                    REVOKE UPDATE, DELETE ON projection_audit_records FROM app_role;
                END IF;
            END
            $$;
            """
        )


def downgrade() -> None:
    op.drop_index(
        "ix_projection_audit_user_computed",
        table_name="projection_audit_records",
    )
    op.drop_table("projection_audit_records")
    with op.batch_alter_table("snapshots", schema=None) as batch_op:
        batch_op.drop_column("constants_version_hash")
