"""Migration p118 — _phase02_parity_audit table — Plan 02-03 iter-2 B14.

Asserts the additive migration creates the audit-evidence table and that
ORM round-trip insert/select works.
"""
from __future__ import annotations

import os
import tempfile
import uuid

import pytest
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import sessionmaker

from app.models.phase02_parity_audit import Phase02ParityAudit


@pytest.fixture
def fresh_sqlite_alembic_db(monkeypatch):
    """Build a fresh SQLite DB with alembic migrated to head ; teardown removes file.

    NB : alembic env.py overrides the URL with `settings.DATABASE_URL`, so
    we must set the env var (and reload settings) for alembic to target the
    tempfile DB. Cleared on teardown so subsequent tests aren't poisoned.
    """
    from alembic.config import Config
    from alembic import command

    tf = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tf.close()
    db_url = f"sqlite:///{tf.name}"

    # Override the URL that env.py picks up via settings.DATABASE_URL.
    monkeypatch.setenv("DATABASE_URL", db_url)
    # Reload the settings module so the cached DATABASE_URL resolves to
    # the new env var.
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
    # Restore the original settings for the next test
    importlib.reload(cfg_module)


def test_p118_creates_table_and_expected_columns(fresh_sqlite_alembic_db):
    engine, _ = fresh_sqlite_alembic_db
    inspector = inspect(engine)
    assert "_phase02_parity_audit" in inspector.get_table_names()
    cols = {c["name"] for c in inspector.get_columns("_phase02_parity_audit")}
    expected = {
        "id",
        "audited_at",
        "user_id_hash",
        "diff_detected",
        "diff_details",
        "audit_run_id",
    }
    assert cols == expected, f"unexpected cols: {cols ^ expected}"


def test_p118_indexes_present(fresh_sqlite_alembic_db):
    engine, _ = fresh_sqlite_alembic_db
    inspector = inspect(engine)
    idx_names = {i["name"] for i in inspector.get_indexes("_phase02_parity_audit")}
    assert "ix_phase02_parity_audit_run" in idx_names
    assert "ix_phase02_parity_audit_audited_at" in idx_names


def test_p118_orm_insert_and_select(fresh_sqlite_alembic_db):
    _, Session = fresh_sqlite_alembic_db
    session = Session()
    try:
        run_id = str(uuid.uuid4())
        row = Phase02ParityAudit(
            user_id_hash="a" * 64,
            diff_detected=False,
            diff_details={},
            audit_run_id=run_id,
        )
        session.add(row)
        session.commit()

        # Re-read
        fetched = session.query(Phase02ParityAudit).filter_by(audit_run_id=run_id).one()
        assert fetched.user_id_hash == "a" * 64
        assert fetched.diff_detected is False
        assert fetched.diff_details == {}
        assert fetched.audit_run_id == run_id
        assert fetched.id is not None
        assert fetched.audited_at is not None
    finally:
        session.close()


def test_p118_orm_insert_diff_detected_with_details(fresh_sqlite_alembic_db):
    _, Session = fresh_sqlite_alembic_db
    session = Session()
    try:
        run_id = str(uuid.uuid4())
        details = {"reasons": ["pillar_3a_balance: numeric diff (left=1.0, right=2.0)"]}
        row = Phase02ParityAudit(
            user_id_hash="b" * 64,
            diff_detected=True,
            diff_details=details,
            audit_run_id=run_id,
        )
        session.add(row)
        session.commit()

        fetched = session.query(Phase02ParityAudit).filter_by(audit_run_id=run_id).one()
        assert fetched.diff_detected is True
        assert fetched.diff_details == details
    finally:
        session.close()


def test_p118_downgrade_removes_table(fresh_sqlite_alembic_db):
    engine, _ = fresh_sqlite_alembic_db
    from alembic.config import Config
    from alembic import command

    # DATABASE_URL is already set on env from the fixture, so env.py picks
    # up the tempfile URL automatically.
    cfg = Config("alembic.ini")

    # Downgrade by one revision
    command.downgrade(cfg, "p113_extend_proj_audit_mob")
    inspector = inspect(create_engine(str(engine.url)))
    assert "_phase02_parity_audit" not in inspector.get_table_names()
