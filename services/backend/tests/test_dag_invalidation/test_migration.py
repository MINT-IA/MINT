"""Phase 95 — DAG-04 alembic upgrade/downgrade roundtrip on SQLite test DB."""
from __future__ import annotations

import os

import sqlalchemy as sa
from alembic import command
from alembic.config import Config


def _make_config(tmp_path, monkeypatch) -> Config:
    # WARN-2 fix : resolve absolute path from __file__ so the test
    # passes regardless of pytest invocation cwd. The `<verify><automated>`
    # block runs from `cd services/backend`, so relative paths like
    # "services/backend/alembic.ini" would fail.
    # Additionally : env.py overrides sqlalchemy.url from
    # settings.DATABASE_URL, so we MUST patch the env var BEFORE the
    # Config is constructed (and clear the cached settings if any).
    from pathlib import Path
    db_url = f"sqlite:///{tmp_path}/test.db"
    monkeypatch.setenv("DATABASE_URL", db_url)
    # Invalidate the cached Settings if app.core.config has been imported
    import importlib
    from app.core import config as _cfg_mod
    importlib.reload(_cfg_mod)
    # Also patch alembic.env's imported settings handle so the in-memory
    # alembic.env (re-importable each command) picks up the new URL.
    backend_root = Path(__file__).parent.parent.parent  # services/backend
    cfg = Config(str(backend_root / "alembic.ini"))
    cfg.set_main_option("script_location", str(backend_root / "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    return cfg


def test_upgrade_adds_columns(tmp_path, monkeypatch):
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    cols = {c["name"] for c in insp.get_columns("scenarios")}
    assert "inputs_hash" in cols
    assert "superseded_by" in cols


def test_downgrade_removes_columns(tmp_path, monkeypatch):
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "-1")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    cols = {c["name"] for c in insp.get_columns("scenarios")}
    assert "inputs_hash" not in cols
    assert "superseded_by" not in cols


def test_roundtrip_idempotent(tmp_path, monkeypatch):
    cfg = _make_config(tmp_path, monkeypatch)
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "-1")
    command.upgrade(cfg, "head")
    engine = sa.create_engine(f"sqlite:///{tmp_path}/test.db")
    insp = sa.inspect(engine)
    cols = {c["name"] for c in insp.get_columns("scenarios")}
    assert "inputs_hash" in cols
    assert "superseded_by" in cols


def test_orm_exposes_new_fields():
    from app.models.scenario import ScenarioModel
    assert hasattr(ScenarioModel, "inputs_hash")
    assert hasattr(ScenarioModel, "superseded_by")
