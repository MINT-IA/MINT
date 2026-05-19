"""fact_event + fact_current — append-only event log + denormalised read-side.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-01 + D-19 + D-26 + D-27 + D-28.

Creates the two-table event-log + projection substrate that backs the W1 → W2
canary parity gate (D-25). The write side is `fact_event` (append-only); the
read side is `fact_current` (denormalised, UPSERT-keyed by (user_id, field_key)).

DDL summary
===========

  ┌─ fact_event ────────────────────────────────────────────────────────────────┐
  │ Append-only event log. Postgres: PARTITION BY HASH (user_id) PARTITIONS 8   │
  │ for scale (D-28). REVOKE UPDATE, DELETE FROM PUBLIC enforces structural     │
  │ append-only at the DB level (matches p111_projection_audit pattern).        │
  │ FK fact_event.user_id → users.id is ADDED NOT VALID then VALIDATEd in a     │
  │ second statement so the FK creation is an online migration (iter-2 A2).     │
  └────────────────────────────────────────────────────────────────────────────┘

  ┌─ fact_current ──────────────────────────────────────────────────────────────┐
  │ Denormalised read-side. PRIMARY KEY (user_id, field_key). Postgres:         │
  │ covering index INCLUDE (value_enc, valid_from) for index-only-scan reads ;  │
  │ fillfactor=80 for in-place HOT updates (UPSERT churn pattern).              │
  │ SQLite test fallback: plain composite-PK + non-covering index.              │
  └────────────────────────────────────────────────────────────────────────────┘

`dek_vault` is NOT touched here — the existing table (per-user PK, no dek_id /
dek_scope / tombstone) already supports the canary write+decrypt path via
KeyVaultService.get_or_create_dek. Adding dek_id / dek_scope / tombstone_at
is Task 3A "DEK tombstone backend" (continuation-4, out of scope this turn).

D-26 envelope shape (`value_enc` JSONB) and D-29 confidence shape are validated
at the application layer by Pydantic v2 (`app/models/encryption/encrypted_value.py`).
The JSONB column on Postgres + JSON on SQLite is portable via the conventional
`JSON().with_variant(JSONB(), "postgresql")` pattern used across the codebase.

Revision ID : p98_fact_event_projection   (24 chars — within Postgres VARCHAR(32) cap)
Revises     : p98_merge_p86_eclairage      (the merge head from continuation-2)
Create Date : 2026-05-18

Dialect branch
==============
Postgres : PARTITION BY HASH (user_id) PARTITIONS 8 on fact_event ; covering
INCLUDE index on fact_current ; REVOKE UPDATE, DELETE on fact_event ;
FK ADD NOT VALID + VALIDATE in two statements for online-migration safety.
SQLite : non-partitioned table ; non-covering composite index ; FK declared
inline at CREATE TABLE time (SQLite has no online FK addition path).

Downgrade
=========
DROP TABLE cascades partitions on Postgres. SQLite drops both tables outright.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB


# revision identifiers, used by Alembic.
revision: str = "p98_fact_event_projection"  # 24 chars — within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p98_merge_p86_eclairage"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Portable JSONB shim — matches the convention in app/models/consent.py and
# elsewhere. JSON on SQLite, JSONB on Postgres.
JSONType = sa.JSON().with_variant(JSONB(), "postgresql")


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        _upgrade_postgres()
    else:
        _upgrade_sqlite()


def _upgrade_postgres() -> None:
    """Postgres path : partitioned fact_event + covering-index fact_current + REVOKE."""
    # ── fact_event (PARTITION BY HASH, 8 partitions, append-only) ──────────
    # We can't use op.create_table directly because alembic doesn't emit
    # `PARTITION BY HASH (...) PARTITIONS N`. Use raw DDL.
    # Postgres v14+ enforces : any UNIQUE / PRIMARY KEY constraint on a
    # partitioned table MUST include the partition-key columns. We partition
    # by HASH (user_id), so the PRIMARY KEY must include user_id. We use a
    # composite PK (event_id, user_id) instead of just event_id. event_id is
    # a UUID7 (uuid_utils.uuid7) so collisions across users are practically
    # impossible — the composite PK is functionally equivalent to a unique
    # constraint on event_id alone, while satisfying the partition rule.
    op.execute(
        """
        CREATE TABLE fact_event (
            event_id        UUID NOT NULL,
            user_id         VARCHAR NOT NULL,
            field_key       VARCHAR(128) NOT NULL,
            value_enc       JSONB NOT NULL,
            confidence      JSONB NULL,
            valid_from      TIMESTAMPTZ NOT NULL,
            recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
            source          VARCHAR(64) NOT NULL,
            event_version   INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (event_id, user_id)
        ) PARTITION BY HASH (user_id)
        """
    )
    # Declare the 8 partitions explicitly so they exist post-migration.
    for i in range(8):
        op.execute(
            f"""
            CREATE TABLE fact_event_p{i}
                PARTITION OF fact_event
                FOR VALUES WITH (MODULUS 8, REMAINDER {i})
            """
        )

    # Append-only enforcement at DB level (matches p111_projection_audit pattern).
    # We REVOKE UPDATE and DELETE only — INSERT must remain allowed for the
    # projector. The append-only invariant is "no row mutation post-INSERT",
    # not "no INSERT".
    op.execute("REVOKE UPDATE, DELETE ON fact_event FROM PUBLIC")
    # Also revoke from each declared partition (Postgres routes INSERT through
    # the parent, but UPDATE/DELETE can be issued directly against a partition).
    for i in range(8):
        op.execute(f"REVOKE UPDATE, DELETE ON fact_event_p{i} FROM PUBLIC")

    # Defense in depth: if the app_role exists (Railway prod), revoke there too.
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_role') THEN
                REVOKE UPDATE, DELETE ON fact_event FROM app_role;
            END IF;
        END
        $$;
        """
    )

    # Per-user-and-field event lookup index (event-log replay path).
    op.execute(
        """
        CREATE INDEX ix_fact_event_user_field_valid
            ON fact_event (user_id, field_key, valid_from)
        """
    )

    # iter-2 A2 : FK added NOT VALID for online-migration semantics, then
    # VALIDATEd in a separate statement. NOT VALID skips the existing-row
    # check at ADD time (no AccessExclusiveLock); VALIDATE then walks the
    # rows with a ShareUpdateExclusiveLock that does NOT block writes.
    op.execute(
        """
        ALTER TABLE fact_event
            ADD CONSTRAINT fact_event_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES users (id)
            ON DELETE CASCADE
            NOT VALID
        """
    )
    op.execute(
        "ALTER TABLE fact_event VALIDATE CONSTRAINT fact_event_user_id_fkey"
    )

    # ── fact_current (denormalised read-side, UPSERT-friendly) ─────────────
    op.execute(
        """
        CREATE TABLE fact_current (
            user_id     VARCHAR NOT NULL,
            field_key   VARCHAR(128) NOT NULL,
            value_enc   JSONB NOT NULL,
            confidence  JSONB NULL,
            valid_from  TIMESTAMPTZ NOT NULL,
            updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (user_id, field_key)
        ) WITH (fillfactor = 80)
        """
    )

    # Covering index for index-only scans on the dominant read pattern
    # (look up one field for one user — used by the snapshot read path
    # post-feature-flag flip in Plan 02-03 PR-2).
    op.execute(
        """
        CREATE INDEX ix_fact_current_user_field_covering
            ON fact_current (user_id, field_key)
            INCLUDE (value_enc, valid_from)
        """
    )

    # FK to users — same online-migration treatment as fact_event.
    op.execute(
        """
        ALTER TABLE fact_current
            ADD CONSTRAINT fact_current_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES users (id)
            ON DELETE CASCADE
            NOT VALID
        """
    )
    op.execute(
        "ALTER TABLE fact_current VALIDATE CONSTRAINT fact_current_user_id_fkey"
    )


def _upgrade_sqlite() -> None:
    """SQLite path : non-partitioned tables for test fixtures. No PARTITION,
    no INCLUDE, no REVOKE, FK declared inline.

    The behavioural contract (append-only, UPSERT-keyed read-side) is
    preserved at the application layer by FactProjector. The DB-level
    enforcement only kicks in on Postgres (Railway prod / pg_fixture tests).
    """
    # Composite PK (event_id, user_id) to match the Postgres path (where the
    # partition rule requires user_id in the PK). SQLite doesn't enforce
    # partitioning, but using the same PK shape here keeps the ORM model
    # consistent across dialects.
    op.create_table(
        "fact_event",
        sa.Column("event_id", sa.String(length=36), nullable=False),
        sa.Column(
            "user_id",
            sa.String,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("field_key", sa.String(length=128), nullable=False),
        sa.Column("value_enc", JSONType, nullable=False),
        sa.Column("confidence", JSONType, nullable=True),
        sa.Column("valid_from", sa.DateTime(), nullable=False),
        sa.Column(
            "recorded_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.current_timestamp(),
        ),
        sa.Column("source", sa.String(length=64), nullable=False),
        sa.Column("event_version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.PrimaryKeyConstraint("event_id", "user_id"),
    )
    op.create_index(
        "ix_fact_event_user_field_valid",
        "fact_event",
        ["user_id", "field_key", "valid_from"],
    )

    op.create_table(
        "fact_current",
        sa.Column(
            "user_id",
            sa.String,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("field_key", sa.String(length=128), nullable=False),
        sa.Column("value_enc", JSONType, nullable=False),
        sa.Column("confidence", JSONType, nullable=True),
        sa.Column("valid_from", sa.DateTime(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.current_timestamp(),
        ),
        sa.PrimaryKeyConstraint("user_id", "field_key"),
    )
    op.create_index(
        "ix_fact_current_user_field_covering",
        "fact_current",
        ["user_id", "field_key"],
    )


def downgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        # DROP TABLE on the parent cascades to all 8 partitions.
        op.execute("DROP INDEX IF EXISTS ix_fact_current_user_field_covering")
        op.execute("DROP TABLE IF EXISTS fact_current")
        op.execute("DROP INDEX IF EXISTS ix_fact_event_user_field_valid")
        op.execute("DROP TABLE IF EXISTS fact_event")  # cascades to partitions
    else:
        op.drop_index("ix_fact_current_user_field_covering", table_name="fact_current")
        op.drop_table("fact_current")
        op.drop_index("ix_fact_event_user_field_valid", table_name="fact_event")
        op.drop_table("fact_event")
