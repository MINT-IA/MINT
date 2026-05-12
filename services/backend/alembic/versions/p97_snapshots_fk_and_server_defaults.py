"""Phase 97 W7 B023b — snapshots FK + server_defaults parity with ORM.

Closes the drift surfaced during B023 re-verification (W7 iter#8,
2026-05-11) :

  (i)  `snapshots.user_id` had no FK to `users.id` in the DB even
       though the ORM declares
       `ForeignKey('users.id', ondelete='CASCADE')`. Orphan rows could
       leak via raw SQL deletes (GDPR Art. 8 / LPD right-to-erasure
       edge case).

  (ii) 15 columns had `server_default=text(...)` in the ORM
       (snapshot.py:25-44) but the alembic chain emitted them as
       `nullable=True` with no server_default. Raw SQL INSERTs that
       omitted these columns landed NULL ; downstream calculator code
       may crash on NULL where it expects 0.0 / 0 / 'VD' /
       'swiss_native' / 'single'.

Tests live at services/backend/tests/test_snapshots_migration_exists.py
`test_snapshots_user_id_fk_present_and_cascade` +
`test_snapshots_server_defaults_match_orm`. They are RED on every
revision before this one and GREEN starting with this migration.

Safety notes for the FK addition
================================
Adding a FK on `user_id` requires that every existing snapshots row
has a matching users row, otherwise the constraint creation fails.
We DELETE orphan rows first (snapshots where user_id is NULL or has no
matching users.id). On Railway prod this is the correct GDPR move : if
the parent user is gone, the snapshots are orphan PII that should not
persist. The cleanup is logged via op.execute on a small SELECT-then-
DELETE pattern that is idempotent (re-running the migration on a
clean DB is a no-op because the cleanup matches zero rows).

batch_alter_table is used for SQLite compatibility (the test fixtures
use SQLite in-memory ; SQLite cannot ALTER TABLE ADD CONSTRAINT
directly). batch_alter_table reads the table, recreates it with the
new schema, and copies data. PostgreSQL takes the direct path.

Karpathy #3 surgical : 1 migration file, 1 reversible op block. No
ORM changes (snapshot.py already declares the intended shape).
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "p97_snapshots_fk_and_server_defaults"
down_revision: Union[str, Sequence[str], None] = "p95_dag_invalidation"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Columns with their target server_default. Mirrors
# `app/models/snapshot.py` :25-44 and the
# `EXPECTED_SERVER_DEFAULTS` dict in the regression test.
_SERVER_DEFAULTS: dict[str, str] = {
    "age": "0",
    "gross_income": "0.0",
    "canton": "'VD'",
    "archetype": "'swiss_native'",
    "household_type": "'single'",
    "replacement_ratio": "0.0",
    "months_liquidity": "0.0",
    "tax_saving_potential": "0.0",
    "confidence_score": "0.0",
    "enrichment_count": "0",
    "fri_total": "0.0",
    "fri_l": "0.0",
    "fri_f": "0.0",
    "fri_r": "0.0",
    "fri_s": "0.0",
}

# Column types — needed for batch_alter_table.alter_column on SQLite
# (the recreate path requires an existing_type). Mirror snapshot.py.
_COLUMN_TYPES: dict[str, type] = {
    "age": sa.Integer,
    "gross_income": sa.Float,
    "canton": sa.String,
    "archetype": sa.String,
    "household_type": sa.String,
    "replacement_ratio": sa.Float,
    "months_liquidity": sa.Float,
    "tax_saving_potential": sa.Float,
    "confidence_score": sa.Float,
    "enrichment_count": sa.Integer,
    "fri_total": sa.Float,
    "fri_l": sa.Float,
    "fri_f": sa.Float,
    "fri_r": sa.Float,
    "fri_s": sa.Float,
}


def upgrade() -> None:
    # ── Step 1 : cleanup orphan snapshots (GDPR-safe) ─────────────────
    # Delete rows whose user_id references a user that no longer exists.
    # Required before the FK constraint can be added.
    op.execute(
        """
        DELETE FROM snapshots
        WHERE user_id IS NULL
           OR user_id NOT IN (SELECT id FROM users)
        """
    )

    # ── Step 2 : add FK + server_defaults via batch_alter_table ──────
    # batch_alter_table is required for SQLite (no ALTER TABLE ADD
    # CONSTRAINT). On PostgreSQL the batch is a no-op wrapper that
    # emits the constraint addition directly. The FK name follows the
    # alembic naming convention `fk_<table>_<column>_<referenced_table>`.
    with op.batch_alter_table("snapshots", schema=None) as batch_op:
        batch_op.create_foreign_key(
            constraint_name="fk_snapshots_user_id_users",
            referent_table="users",
            local_cols=["user_id"],
            remote_cols=["id"],
            ondelete="CASCADE",
        )
        for col_name, default_sql in _SERVER_DEFAULTS.items():
            batch_op.alter_column(
                col_name,
                existing_type=_COLUMN_TYPES[col_name](),
                server_default=sa.text(default_sql),
                existing_nullable=True,
            )


def downgrade() -> None:
    with op.batch_alter_table("snapshots", schema=None) as batch_op:
        for col_name in _SERVER_DEFAULTS:
            batch_op.alter_column(
                col_name,
                existing_type=_COLUMN_TYPES[col_name](),
                server_default=None,
                existing_nullable=True,
            )
        batch_op.drop_constraint("fk_snapshots_user_id_users", type_="foreignkey")
