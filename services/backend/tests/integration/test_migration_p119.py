"""Migration p119 — _phase02_parity_audit_continuous — Plan 02-03 iter-2 B18."""
from __future__ import annotations

import os
import tempfile
import uuid

import pytest
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker

from app.models.phase02_parity_audit_continuous import Phase02ParityAuditContinuous


@pytest.fixture
def fresh_sqlite_alembic_db(monkeypatch):
    from alembic.config import Config
    from alembic import command

    tf = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tf.close()
    db_url = f"sqlite:///{tf.name}"

    monkeypatch.setenv("DATABASE_URL", db_url)
    import importlib
    import app.core.config as cfg_module
    importlib.reload(cfg_module)

    cfg = Config("alembic.ini")
    command.upgrade(cfg, "head")

    engine = create_engine(db_url)
    Session = sessionmaker(bind=engine)
    yield engine, Session
    engine.dispose()
    os.unlink(tf.name)
    importlib.reload(cfg_module)


def test_p119_creates_table(fresh_sqlite_alembic_db):
    engine, _ = fresh_sqlite_alembic_db
    assert "_phase02_parity_audit_continuous" in inspect(engine).get_table_names()


def test_p119_columns(fresh_sqlite_alembic_db):
    engine, _ = fresh_sqlite_alembic_db
    cols = {c["name"] for c in inspect(engine).get_columns("_phase02_parity_audit_continuous")}
    expected = {"id", "sampled_at", "user_id_hash", "diff_count", "diff_details", "sampler_run_id"}
    assert cols == expected


def test_p119_indexes(fresh_sqlite_alembic_db):
    engine, _ = fresh_sqlite_alembic_db
    idx_names = {i["name"] for i in inspect(engine).get_indexes("_phase02_parity_audit_continuous")}
    assert "ix_phase02_parity_audit_continuous_sampled" in idx_names
    assert "ix_phase02_parity_audit_continuous_dirty" in idx_names


def test_p119_orm_round_trip(fresh_sqlite_alembic_db):
    _, Session = fresh_sqlite_alembic_db
    s = Session()
    try:
        run_id = str(uuid.uuid4())
        row = Phase02ParityAuditContinuous(
            user_id_hash="c" * 64,
            diff_count=0,
            diff_details={},
            sampler_run_id=run_id,
        )
        s.add(row)
        s.commit()
        fetched = s.query(Phase02ParityAuditContinuous).filter_by(sampler_run_id=run_id).one()
        assert fetched.diff_count == 0
        assert fetched.diff_details == {}
    finally:
        s.close()


def test_p119_orm_dirty_row_with_reasons(fresh_sqlite_alembic_db):
    _, Session = fresh_sqlite_alembic_db
    s = Session()
    try:
        run_id = str(uuid.uuid4())
        reasons = {"reasons": ["a.b: numeric diff (left=1, right=2, tol=1e-9)"]}
        row = Phase02ParityAuditContinuous(
            user_id_hash="d" * 64,
            diff_count=1,
            diff_details=reasons,
            sampler_run_id=run_id,
        )
        s.add(row)
        s.commit()
        fetched = s.query(Phase02ParityAuditContinuous).filter_by(sampler_run_id=run_id).one()
        assert fetched.diff_count == 1
        assert fetched.diff_details == reasons
    finally:
        s.close()
