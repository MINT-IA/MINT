"""p113_extend_projection_audit_mobile — D-12 + D-MOB-03 schema validation.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P2.

Asserts that p113 :
1. Adds 8 Mobile L1 columns to projection_audit_records (source +
   app_version + observed_at + anonymous_session_id + local_event_id +
   app_lifecycle_state + client_ts + server_received_ts).
2. Creates the uq_proj_audit_anon_observed UNIQUE index (handshake
   replay safety per iter-2 A6).
3. Preserves the existing schema (Hotfix B columns untouched).
4. server-default 'projection' on `source` keeps existing writers
   semantically unchanged.

Same alembic env.py override pattern as test_migration_p11{4,5,6}.py.
"""
from __future__ import annotations

import importlib
from pathlib import Path

import sqlalchemy as sa
from alembic import command
from alembic.config import Config


def _make_config(tmp_path, monkeypatch):
    db_url = f"sqlite:///{tmp_path}/test.db"
    monkeypatch.setenv("DATABASE_URL", db_url)
    monkeypatch.setenv("TESTING", "1")
    from app.core import config as _cfg_mod
    importlib.reload(_cfg_mod)
    backend_root = Path(__file__).parent.parent.parent
    cfg = Config(str(backend_root / "alembic.ini"))
    cfg.set_main_option("script_location", str(backend_root / "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    return cfg, db_url


_EXPECTED_NEW_COLS = {
    "source",
    "app_version",
    "observed_at",
    "anonymous_session_id",
    "local_event_id",
    "app_lifecycle_state",
    "client_ts",
    "server_received_ts",
}

_EXPECTED_PRE_EXISTING_COLS = {
    "id",
    "user_id_hash",
    "computed_at",
    "projection_type",
    "projection_id",
    "constants_version_hash",
    "scenario_inputs_hash",
    "output_hash",
    "lsfin_disclaimer_shown",
}


def test_p113_adds_mobile_l1_columns_sqlite(tmp_path, monkeypatch):
    """SQLite : verify the 8 new columns + the UNIQUE index."""
    cfg, db_url = _make_config(tmp_path, monkeypatch)

    # Upgrade through p116 (pre-p113 state ; projection_audit_records
    # carries only the Hotfix B columns).
    command.upgrade(cfg, "p116_snapshot_invalidation")

    engine = sa.create_engine(db_url)
    inspector_pre = sa.inspect(engine)
    cols_pre = {c["name"] for c in inspector_pre.get_columns("projection_audit_records")}
    # Pre-p113 : only Hotfix B columns.
    assert _EXPECTED_PRE_EXISTING_COLS.issubset(cols_pre), (
        f"missing Hotfix B columns pre-p113: "
        f"{_EXPECTED_PRE_EXISTING_COLS - cols_pre}"
    )
    assert _EXPECTED_NEW_COLS.isdisjoint(cols_pre), (
        f"Mobile L1 columns present BEFORE p113 ; got {cols_pre & _EXPECTED_NEW_COLS}"
    )

    # Run p113.
    command.upgrade(cfg, "p113_extend_proj_audit_mob")

    inspector_post = sa.inspect(engine)
    cols_post = {c["name"] for c in inspector_post.get_columns("projection_audit_records")}
    assert _EXPECTED_NEW_COLS.issubset(cols_post), (
        f"missing Mobile L1 columns post-p113: {_EXPECTED_NEW_COLS - cols_post}"
    )
    assert _EXPECTED_PRE_EXISTING_COLS.issubset(cols_post), (
        f"p113 dropped Hotfix B columns: {_EXPECTED_PRE_EXISTING_COLS - cols_post}"
    )

    # UNIQUE index present.
    indexes = inspector_post.get_indexes("projection_audit_records")
    unique_names = {idx["name"] for idx in indexes if idx.get("unique")}
    assert "uq_proj_audit_anon_observed" in unique_names, (
        f"UNIQUE index uq_proj_audit_anon_observed missing ; got {unique_names}"
    )


def test_p113_source_default_is_projection_sqlite(tmp_path, monkeypatch):
    """A row inserted without specifying `source` defaults to 'projection'."""
    cfg, db_url = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "p113_extend_proj_audit_mob")

    engine = sa.create_engine(db_url)
    with engine.connect() as conn:
        conn.execute(
            sa.text(
                """
                INSERT INTO projection_audit_records
                    (id, user_id_hash, computed_at, projection_type, projection_id,
                     constants_version_hash, scenario_inputs_hash, output_hash,
                     lsfin_disclaimer_shown)
                VALUES
                    ('test-default-src', 'hash-x', CURRENT_TIMESTAMP, 'snapshot',
                     'snap-1', 'cvh-1', 'in-1', 'out-1', 0)
                """
            )
        )
        conn.commit()
        row = conn.execute(
            sa.text(
                "SELECT source FROM projection_audit_records WHERE id = 'test-default-src'"
            )
        ).fetchone()
    assert row.source == "projection", (
        f"server-default 'projection' broken ; got source={row.source!r}"
    )


def test_p113_downgrade_drops_mobile_l1_columns_sqlite(tmp_path, monkeypatch):
    """Downgrade from p113 → p116 removes the 8 Mobile L1 columns."""
    cfg, db_url = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "p113_extend_proj_audit_mob")

    engine = sa.create_engine(db_url)
    cols_pre_down = {
        c["name"] for c in sa.inspect(engine).get_columns("projection_audit_records")
    }
    assert _EXPECTED_NEW_COLS.issubset(cols_pre_down)

    command.downgrade(cfg, "p116_snapshot_invalidation")
    cols_post_down = {
        c["name"] for c in sa.inspect(engine).get_columns("projection_audit_records")
    }
    assert _EXPECTED_NEW_COLS.isdisjoint(cols_post_down), (
        f"downgrade did not remove all Mobile L1 columns ; still present : "
        f"{cols_post_down & _EXPECTED_NEW_COLS}"
    )
    assert _EXPECTED_PRE_EXISTING_COLS.issubset(cols_post_down), (
        f"downgrade dropped Hotfix B columns: "
        f"{_EXPECTED_PRE_EXISTING_COLS - cols_post_down}"
    )
