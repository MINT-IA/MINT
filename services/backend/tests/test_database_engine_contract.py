"""Executable contracts for production database engine options."""

from app.core.database import engine_options_for_url


def test_postgresql_engine_explicitly_requests_read_committed():
    options = engine_options_for_url("postgresql://mint:secret@db/mint")

    assert options["isolation_level"] == "READ COMMITTED"


def test_sqlite_engine_keeps_its_threading_contract_without_pg_isolation():
    options = engine_options_for_url("sqlite:///./mint.db")

    assert options == {"connect_args": {"check_same_thread": False}}
