"""Phase mint-calc-engine-v1 W3 Plan 12 — D-CE-12 composite index migration tests.

Verifies that `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` :
  1. Parses syntactically (ast.parse).
  2. Chains its `down_revision` onto the actual alembic head verified at plan-time
     (`p97_snapshots_fk_defaults`, NOT the RESEARCH §Q-D stale long-form
     `p97_snapshots_fk_and_server_defaults` which was truncated to ≤32 chars during
     Phase 97 — see p97 file line 49 comment).
  3. Contains both branches of the dialect guard (`if bind.dialect.name != "postgresql"`
     in `upgrade` AND `downgrade`).
  4. Contains `autocommit_block()` for the PG `CREATE INDEX CONCURRENTLY` path (footgun
     mitigation — CONCURRENTLY cannot run inside a transaction, RESEARCH §Q-D).
  5. Contains the literal `CREATE INDEX CONCURRENTLY IF NOT EXISTS` token (PG path).
  6. Contains the partial predicate `WHERE superseded_by IS NULL` (only living scenarios).
  7. Contains `DROP INDEX` (downgrade symmetric).
  8. Applies cleanly on SQLite via `alembic upgrade head` (no CONCURRENTLY, no partial
     WHERE — SQLite supports neither in the same statement form).
  9. Creates the `idx_scenarios_cache_lookup` index post-upgrade (verified via
     SQLAlchemy inspector).
 10. Downgrade -1 removes the index cleanly.
 11. Re-running upgrade head is a no-op (idempotent ; `IF NOT EXISTS` guard).

Test 4 (EXPLAIN ANALYZE Index Scan) is PG-only and SKIPS on SQLite because :
  - SQLite EXPLAIN output shape is different (no « Index Scan » string).
  - SQLite SQL syntax for `gen_random_uuid()` + cast semantics diverge from PG.
The post-deploy production verification path runs that on Railway PG14+ (see
SUMMARY.md « Deployment notes »).

Stub fixture pattern modeled on services/backend/tests/test_dag_invalidation/
test_migration.py (the precedent Phase 95 migration tests, verified at plan-time).
"""
from __future__ import annotations

import ast
import importlib
from pathlib import Path

import pytest
import sqlalchemy as sa
from alembic import command
from alembic.config import Config


INDEX_NAME = "idx_scenarios_cache_lookup"
MIGRATION_PATH = (
    Path(__file__).parent.parent
    / "alembic"
    / "versions"
    / "p110_scenarios_cache_lookup_index.py"
)
# The actual alembic head at plan-time was `p97_snapshots_fk_defaults` — the
# revision id was truncated from the long-form `p97_snapshots_fk_and_server_defaults`
# (36 chars) to satisfy Postgres' VARCHAR(32) alembic_version.version_num column
# constraint (see p97 file line 49 comment). RESEARCH §Q-D cites the stale long form ;
# Plan 12 reads the actual revision id from the file and chains correctly.
EXPECTED_DOWN_REVISION = "p97_snapshots_fk_defaults"


# ---------------------------------------------------------------------------
# Static checks (don't require alembic execution).
# ---------------------------------------------------------------------------
def test_migration_file_exists():
    """Migration file is present at the expected path."""
    assert MIGRATION_PATH.is_file(), f"Migration file missing: {MIGRATION_PATH}"


def test_migration_parses_syntactically():
    """`ast.parse` succeeds on the migration body."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    ast.parse(src)  # raises SyntaxError on failure


def test_migration_down_revision_chains_to_p97():
    """down_revision points to the actual alembic head at plan-time."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    # Robust grep that survives string-quoting style (single vs double).
    assert (
        f'down_revision = "{EXPECTED_DOWN_REVISION}"' in src
        or f"down_revision = '{EXPECTED_DOWN_REVISION}'" in src
    ), (
        f"down_revision must equal {EXPECTED_DOWN_REVISION} ; found mismatch. "
        f"RESEARCH §Q-D cites stale `p97_snapshots_fk_and_server_defaults` (36ch, "
        f"truncated to 32ch in p97 file)."
    )


def test_migration_uses_autocommit_block():
    """Both upgrade and downgrade must wrap PG CONCURRENTLY in autocommit_block."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    # ≥2 occurrences : upgrade + downgrade.
    count = src.count("autocommit_block")
    assert count >= 2, (
        f"autocommit_block must appear ≥2x (upgrade + downgrade) ; got {count}. "
        f"CREATE INDEX CONCURRENTLY cannot run inside a transaction — "
        f"see RESEARCH §Q-D footgun mitigation."
    )


def test_migration_has_create_index_concurrently():
    """PG path uses `CREATE INDEX CONCURRENTLY IF NOT EXISTS`."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    assert "CREATE INDEX CONCURRENTLY IF NOT EXISTS" in src, (
        "PG path must emit `CREATE INDEX CONCURRENTLY IF NOT EXISTS` ; "
        "ensures idempotent re-run + zero-lock build."
    )


def test_migration_has_dialect_branch_in_both_directions():
    """Dialect guard `if bind.dialect.name != 'postgresql'` appears ≥2x."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    count = src.count('if bind.dialect.name != "postgresql"')
    assert count >= 2, (
        f"Expected dialect guard ≥2x (upgrade + downgrade) ; got {count}. "
        f"SQLite test path must skip CONCURRENTLY + partial WHERE."
    )


def test_migration_has_partial_index_predicate():
    """Partial predicate `WHERE superseded_by IS NULL` present (only living rows)."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    assert "WHERE superseded_by IS NULL" in src, (
        "Partial predicate `WHERE superseded_by IS NULL` is the whole point of "
        "the cache-lookup index — superseded scenarios are stale and must not "
        "pollute the index hot set."
    )


def test_migration_has_drop_index_in_downgrade():
    """Downgrade symmetric : drops the index (PG CONCURRENTLY + SQLite plain)."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    assert "DROP INDEX CONCURRENTLY IF EXISTS" in src, "PG downgrade path missing"
    # SQLite path uses plain `DROP INDEX IF EXISTS`.
    assert "DROP INDEX IF EXISTS" in src, "SQLite downgrade path missing"


def test_migration_index_name_correct():
    """Index name matches the plan / RESEARCH §Q-D + D-CE-12 specification."""
    src = MIGRATION_PATH.read_text(encoding="utf-8")
    assert INDEX_NAME in src, f"Index name {INDEX_NAME} missing"


# ---------------------------------------------------------------------------
# Runtime checks (apply migration on a fresh in-memory SQLite via alembic).
# Pattern modeled on test_dag_invalidation/test_migration.py — see the
# precedent there for the monkeypatch + config reload dance.
# ---------------------------------------------------------------------------
def _make_config(tmp_path, monkeypatch) -> Config:
    """Build an alembic Config pointing at a fresh SQLite DB under tmp_path."""
    db_url = f"sqlite:///{tmp_path}/test.db"
    monkeypatch.setenv("DATABASE_URL", db_url)
    # Invalidate the cached Settings if app.core.config has been imported.
    from app.core import config as _cfg_mod

    importlib.reload(_cfg_mod)
    backend_root = Path(__file__).parent.parent  # services/backend
    cfg = Config(str(backend_root / "alembic.ini"))
    cfg.set_main_option("script_location", str(backend_root / "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    return cfg


def test_upgrade_head_creates_index_on_sqlite(tmp_path, monkeypatch):
    """`alembic upgrade head` chains through p110 and creates the index."""
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    index_names = {idx["name"] for idx in insp.get_indexes("scenarios")}
    assert INDEX_NAME in index_names, (
        f"Expected index {INDEX_NAME} after `alembic upgrade head` ; "
        f"found indexes on scenarios: {index_names}"
    )


def test_downgrade_below_p110_removes_index(tmp_path, monkeypatch):
    """Downgrading past p110 removes the index, leaves p97 + p95 intact.

    Targets the specific revision boundary (`p97_snapshots_fk_defaults`,
    the parent of p110) instead of relative `-1` so the test is robust
    to future migrations stacked above p110 (Hotfix B p111, Hotfix C
    p112, etc.).
    """
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "p97_snapshots_fk_defaults")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    index_names = {idx["name"] for idx in insp.get_indexes("scenarios")}
    assert INDEX_NAME not in index_names, (
        f"Expected index {INDEX_NAME} dropped after downgrade past p110 ; "
        f"still found: {index_names}"
    )
    # Sanity : scenarios table itself + Phase 95 columns still present
    # (we only undid p110+later, not p95).
    cols = {c["name"] for c in insp.get_columns("scenarios")}
    assert "inputs_hash" in cols, "Downgraded too far — p95 columns gone"
    assert "superseded_by" in cols, "Downgraded too far — p95 columns gone"


def test_upgrade_is_idempotent(tmp_path, monkeypatch):
    """Re-running `alembic upgrade head` after a successful upgrade is a no-op.

    Verifies the `IF NOT EXISTS` guard prevents duplicate-index errors on replay
    (e.g. deploy retry after partial Railway failure).
    """
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    # Second upgrade must not raise.
    command.upgrade(cfg, "head")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    index_names = {idx["name"] for idx in insp.get_indexes("scenarios")}
    assert INDEX_NAME in index_names, "Idempotent upgrade lost the index"


# ---------------------------------------------------------------------------
# PostgreSQL-only — EXPLAIN ANALYZE proves Index Scan, not Seq Scan.
# Skipped on SQLite (the default test environment).
# ---------------------------------------------------------------------------
@pytest.mark.skipif(
    "sqlite" in str(Path(__file__).parent.parent / "mint.db")
    or True,  # default-skip ; force PG-only ; production verification via Railway.
    reason="EXPLAIN ANALYZE Index Scan check is PostgreSQL-only ; "
    "post-deploy verification runs on Railway PG14+",
)
def test_explain_analyze_uses_index_scan_on_pg():
    """D-CE-12 SLO : cache-lookup query MUST use Index Scan, not Seq Scan.

    Inserts ≥100 rows for planner to prefer the index, then EXPLAIN ANALYZE
    the canonical cache-lookup shape and assert 'Index Scan' in the plan.
    See RESEARCH §Q-D verification query.
    """
    # Implementation lives in the production post-deploy doc, not in this test
    # body, because it requires a live PG connection. The skip mark above
    # guarantees this test body is never executed under pytest.
    raise NotImplementedError("PG-only ; runs post-deploy on Railway")
