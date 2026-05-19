"""_phase02_parity_audit table — full-population audit persistence.

Phase mint-data-architecture-v1-02 Plan 02-03 — iter-2 B14.

Creates a staging-only audit table that persists the 100%% staging-user
canonical-JSON parity-audit results. Populated by the Task 2a checkpoint
preamble (Claude steps 5-8) running `tools/parity/projection_diff.py
--audit-all-users --persist-to _phase02_parity_audit` against Railway
staging Postgres BEFORE Julien gates PR-3a merge.

The « 100%% audit » signal replaces the original Plan 02-03 « 20 random
users » sample (database-architect MED-6, postgres-pro MED-5,
qa-expert HIGH-1 4-way convergence). The structured persistence enables
Julien to read the row count + diff_detected filter via plain SQL :

    SELECT count(*), count(*) FILTER (WHERE diff_detected) FROM _phase02_parity_audit ;

The table prefix `_phase02_` mirrors the `_` underscore prefix convention
established by Plan 02-02 for staging-only audit substrates. The table
WILL NOT be referenced by application code at runtime ; it exists purely
as a checkpoint-evidence anchor.

Why a real migration (vs ad-hoc CREATE TABLE)
=============================================
1. Alembic head linearity : Plan 02-03's PR-5 drops SnapshotModel at
   alembic head p117 (planned in Task 5). p118 chains off p116 (current
   head) ; PR-5 will rebase p117 to chain off p118 if shipping
   together, OR p118 may merge alone and p117 chains off p118.
2. Schema reproducibility : a fresh ephemeral test DB can recreate the
   audit substrate without an out-of-band SQL script.
3. CI surface : the migration is exercised by the standard alembic-
   upgrade test in pytest.

Revision ID : p118_phase02_parity_audit  (25 chars — within VARCHAR(32) cap)
Revises     : p113_extend_proj_audit_mob (actual head after Plan 02-02
              continuation-4 — p113 chains off p116, see p113 docstring
              for the chain-order rationale ; p118 chains off p113 to
              keep audit-log linearity)
Create Date : 2026-05-18
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB


revision: str = "p118_phase02_parity_audit"
down_revision: Union[str, Sequence[str], None] = "p113_extend_proj_audit_mob"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create _phase02_parity_audit table (Postgres + SQLite portable)."""
    bind = op.get_bind()
    dialect = bind.dialect.name

    # Portable JSONB column : JSONB on Postgres, JSON on SQLite test path.
    if dialect == "postgresql":
        diff_details_type = JSONB()
    else:
        diff_details_type = sa.JSON()

    # Portable autoincrement PK : SQLite only auto-allocates on INTEGER PRIMARY KEY,
    # so we use BigInteger().with_variant(Integer(), "sqlite") so prod Postgres
    # gets BIGSERIAL while the SQLite test fallback gets a working ROWID-backed
    # INTEGER PRIMARY KEY autoincrement.
    pk_type = sa.BigInteger().with_variant(sa.Integer(), "sqlite")

    op.create_table(
        "_phase02_parity_audit",
        sa.Column("id", pk_type, primary_key=True, autoincrement=True),
        sa.Column(
            "audited_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "user_id_hash",
            sa.String(length=64),
            nullable=False,
            doc=(
                "HMAC-SHA256 of user_id (via app.services.audit.hmac_pepper). "
                "The plain user_id never lands in audit storage (D-24)."
            ),
        ),
        sa.Column(
            "diff_detected",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
            doc="True if projection_diff.diff_payloads returned DIFF.",
        ),
        sa.Column(
            "diff_details",
            diff_details_type,
            nullable=False,
            server_default=sa.text("'{}'") if dialect != "postgresql" else sa.text("'{}'::jsonb"),
            doc=(
                "Structured ParityDiffResult.reasons when diff_detected=true ; "
                "{} when EQUAL. Bounded by canonical-JSON length, enabling "
                "Julien spot-check via SELECT ... WHERE diff_detected=true."
            ),
        ),
        sa.Column(
            "audit_run_id",
            sa.String(length=36),
            nullable=False,
            doc=(
                "UUID v4 — one value per --audit-all-users invocation. Enables "
                "filtering to the latest audit pass : "
                "WHERE audit_run_id = (SELECT audit_run_id FROM ... ORDER BY audited_at DESC LIMIT 1)."
            ),
        ),
    )

    # Index for the « how many users in latest audit pass had diff » query.
    op.create_index(
        "ix_phase02_parity_audit_run",
        "_phase02_parity_audit",
        ["audit_run_id", "diff_detected"],
    )
    op.create_index(
        "ix_phase02_parity_audit_audited_at",
        "_phase02_parity_audit",
        ["audited_at"],
        postgresql_using=None,
    )


def downgrade() -> None:
    op.drop_index("ix_phase02_parity_audit_audited_at", table_name="_phase02_parity_audit")
    op.drop_index("ix_phase02_parity_audit_run", table_name="_phase02_parity_audit")
    op.drop_table("_phase02_parity_audit")
