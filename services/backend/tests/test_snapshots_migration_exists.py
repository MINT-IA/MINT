"""Phase 97 W7 iter#8 — snapshots-table schema parity regression guard.

Origin : authored as the RED repro test for B023 (audit-backend-api.md
row B023). During REPRO step, deterministic re-verification proved B023
was a FALSE FLAG : the `snapshots` table IS created by the existing
alembic chain. Specifically, `d73dcc3968c9_baseline_14_models.py` lines
109-135 emit `op.create_table('snapshots', ...)` with 20 columns + 3
indexes, and `p12_add_birth_date.py` adds the 21st column `birth_date`.
The audit row checked `ls alembic/versions/ | grep snapshot` — a
filename-only grep — and missed the baseline migration which contains
the create_table call in its CONTENT.

B023 → REJECTED 2026-05-11T21:15Z. See 97-BUGS-REGISTRY.md for the full
re-verification log. The drift that DID surface during re-verification
(missing FK + missing server_defaults) is filed as a separate, smaller
row B023b for the next cycle.

This test file is now repurposed as the permanent schema-parity
regression guard for the snapshots table. Future PRs that drop the
table from the alembic chain, omit a column, or break the head linkage
will fail this test = PR blocked.

Coverage :

1. The `snapshots` table is created by `alembic upgrade head` on a
   fresh SQLite DB (canonical alembic path, not the Base.metadata
   side-channel).

2. All 21 columns of `app/models/snapshot.py::SnapshotModel` are
   present after upgrade (schema parity ORM-vs-DB).

3. The 3 expected indexes are present : `ix_snapshots_created_at`,
   `ix_snapshots_user_created` (composite), `ix_snapshots_user_id`.

4. Alembic head linearity : `alembic heads` returns a single revision
   (no dangling unmerged branches).

Pattern parity : `tests/test_dag_invalidation/test_migration.py` (Phase
95 W1 precedent — same tmp_path + monkeypatch Config setup).
"""
from __future__ import annotations

from pathlib import Path

import sqlalchemy as sa
from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory


# Expected columns on the snapshots table (mirrors app/models/snapshot.py).
EXPECTED_COLUMNS = {
    "id",
    "user_id",
    "created_at",
    "trigger",
    "model_version",
    "age",
    "birth_date",
    "gross_income",
    "canton",
    "archetype",
    "household_type",
    "replacement_ratio",
    "months_liquidity",
    "tax_saving_potential",
    "confidence_score",
    "enrichment_count",
    "fri_total",
    "fri_l",
    "fri_f",
    "fri_r",
    "fri_s",
}

# Expected indexes (per d73dcc3968c9_baseline_14_models.py:132-135).
EXPECTED_INDEX_NAMES = {
    "ix_snapshots_created_at",
    "ix_snapshots_user_created",
    "ix_snapshots_user_id",
}


def _make_config(tmp_path, monkeypatch) -> Config:
    """Build an alembic Config pointed at a fresh tmp SQLite DB.

    Same pattern as `test_dag_invalidation/test_migration.py` :
    - absolute paths from __file__ so the test is cwd-independent
    - DATABASE_URL env var patched BEFORE config.set_main_option so env.py
      picks up the new URL even if app.core.config was already imported
    - app.core.config reloaded to invalidate the cached Settings()
    """
    db_url = f"sqlite:///{tmp_path}/test.db"
    monkeypatch.setenv("DATABASE_URL", db_url)
    import importlib
    from app.core import config as _cfg_mod
    importlib.reload(_cfg_mod)
    backend_root = Path(__file__).parent.parent  # services/backend
    cfg = Config(str(backend_root / "alembic.ini"))
    cfg.set_main_option("script_location", str(backend_root / "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    return cfg


def test_alembic_upgrade_creates_snapshots_table(tmp_path, monkeypatch):
    """Test 1 : `alembic upgrade head` creates the snapshots table.

    Canonical alembic path — NOT `Base.metadata.create_all()` side-
    channel. Future migration that drops the table without a matching
    re-create will fail this test.
    """
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    table_names = set(insp.get_table_names())
    assert "snapshots" in table_names, (
        f"snapshots table NOT created by `alembic upgrade head`. "
        f"Tables present: {sorted(table_names)}. "
        f"This regressed from the d73dcc3968c9 baseline + p12_add_birth_date "
        f"chain — check that those migrations are still reachable from head."
    )


def test_snapshots_columns_match_orm(tmp_path, monkeypatch):
    """Test 2 : the 21 columns of SnapshotModel are present after upgrade.

    Schema parity between `app/models/snapshot.py::SnapshotModel` and
    the DB shape produced by `alembic upgrade head`. A new ORM column
    added without a matching alembic migration fails this test ;
    similarly an ORM column dropped without a migration.
    """
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    cols = {c["name"] for c in insp.get_columns("snapshots")}
    missing = EXPECTED_COLUMNS - cols
    extra = cols - EXPECTED_COLUMNS
    assert not missing, (
        f"snapshots table missing columns: {sorted(missing)}. "
        f"app/models/snapshot.py declares them but the alembic chain "
        f"does not create them."
    )
    assert not extra, (
        f"snapshots table has unexpected extra columns: {sorted(extra)}. "
        f"alembic creates columns that are NOT in app/models/snapshot.py. "
        f"Schema drift — either add to the model or drop in a new migration."
    )

    # Also assert the live ORM table matches the DB exactly.
    from app.models.snapshot import SnapshotModel
    orm_cols = {c.name for c in SnapshotModel.__table__.columns}
    assert orm_cols == cols, (
        f"Live ORM ↔ DB drift. ORM-only: {sorted(orm_cols - cols)} ; "
        f"DB-only: {sorted(cols - orm_cols)}."
    )


def test_snapshots_indexes_present(tmp_path, monkeypatch):
    """Test 3 : the 3 expected indexes are present.

    Per d73dcc3968c9_baseline_14_models.py:132-135 :
    - ix_snapshots_created_at
    - ix_snapshots_user_created (composite on user_id + created_at — hot path)
    - ix_snapshots_user_id

    The composite ix_snapshots_user_created is the perf-critical index
    for the reverse-chronological per-user query at
    `app/services/snapshots/snapshot_service.py:177-181`.
    """
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    index_names = {idx["name"] for idx in insp.get_indexes("snapshots")}
    missing = EXPECTED_INDEX_NAMES - index_names
    assert not missing, (
        f"snapshots table missing indexes: {sorted(missing)}. "
        f"Hot-path query at snapshot_service.py:177-181 depends on "
        f"ix_snapshots_user_created specifically."
    )


def test_alembic_chain_has_single_head(tmp_path, monkeypatch):
    """Test 4 : the alembic chain has a single head (no dangling branches).

    Multiple heads = unmerged branches = ambiguous `alembic upgrade head`
    behaviour. The Phase 95 `5f7922bff82b_merge_p11_and_p15.py` precedent
    shows how merges are handled when they DO happen ; this test asserts
    we are NOT currently in a multi-head state that would block any
    new migration from chaining cleanly.
    """
    cfg = _make_config(tmp_path, monkeypatch)
    script = ScriptDirectory.from_config(cfg)
    heads = script.get_heads()
    assert len(heads) == 1, (
        f"Alembic chain has {len(heads)} heads: {heads}. "
        f"Expected a single head. Multiple heads block any new migration "
        f"from chaining cleanly without an explicit merge revision."
    )
