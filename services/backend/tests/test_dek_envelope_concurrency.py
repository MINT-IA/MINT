"""Concurrency contract for KeyVaultService.get_or_create_dek (Pitfall 2).

Phase mint-data-architecture-v1-02 Plan 02-02 W1 Task 2 — DEK race-safety.

The PK UNIQUE constraint on dek_vault.user_id blocks a second concurrent
INSERT for the same never-seen user_id. The existing get_or_create_dek
raises IntegrityError on race-loss; the documented mitigation (Pitfall 2)
is retry-once + re-read from DB. Until the retry-shim ships, the race-loser
raising is an acceptable failure mode.

Test pattern note
=================
This test exercises the race via a sequential simulation rather than real
threads. macOS system-Python (3.9.6) + sqlite3 + ThreadingMode SERIALIZED
+ StaticPool exhibits a known segfault when two threads INSERT concurrently
into the same in-memory DB (issue reported upstream — sqlite3 module under
darwin19+ requires SQLITE_THREADSAFE=2 which the stock build does NOT have).
Real Postgres race coverage lives in tests/integration/test_dek_envelope_
concurrency_pg.py (pg_fixture-based) — out of scope for this Task 2 commit.
"""
from __future__ import annotations

import os

import pytest

os.environ["TESTING"] = "1"

from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.dek_vault import DEKVault
from app.models.user import User  # noqa: F401
from app.services.encryption.key_vault import key_vault


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    key_vault.reset()
    s = sessionmaker(bind=engine)()
    try:
        yield s
    finally:
        s.close()
        key_vault.reset()


def test_idempotent_get_or_create_same_user_one_row(db_session):
    """Sequential get_or_create x N -> exactly 1 dek_vault row (idempotent)."""
    user_id = "user-idempotent"
    for _ in range(5):
        key_vault.get_or_create_dek(db_session, user_id)
    rows = db_session.query(DEKVault).filter(DEKVault.user_id == user_id).all()
    assert len(rows) == 1


def test_race_loser_raises_integrity_error_on_duplicate_insert(db_session):
    """Simulate the race: a second writer inserting under bypassed cache
    receives IntegrityError on the PK conflict.

    The race is simulated rather than threaded — get_or_create_dek's cache
    layer makes real concurrent inserts hard to reproduce, but the underlying
    PK constraint behaviour is the actual contract under test.
    """
    user_id = "user-race-loser"
    # First writer creates the row through the normal path
    key_vault.get_or_create_dek(db_session, user_id)
    # Simulate a racer that bypassed the cache + attempts INSERT directly
    key_vault.reset()  # blow away cache to force re-create path
    # Manually add a duplicate row — emulates two writers committing concurrently
    from datetime import datetime, timezone
    dup = DEKVault(
        user_id=user_id,
        wrapped_dek=b"x" * 80,
        kms_key_ref="mint-master-v1",
        algo="AES-256-GCM",
        created_at=datetime.now(timezone.utc),
    )
    db_session.add(dup)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()
    # Invariant holds: still exactly one row
    rows = db_session.query(DEKVault).filter(DEKVault.user_id == user_id).all()
    assert len(rows) == 1


def test_get_or_create_returns_same_bytes_on_repeat(db_session):
    """Re-calling get_or_create_dek for the same user yields the same DEK bytes.

    Note: cannot exercise the cache-cleared path without setting MINT_MASTER_KEY
    explicitly (volatile MK gets regenerated on reset()). The repeat-call path
    via cache is sufficient for the unit contract; cross-process DEK stability
    is exercised by tests/services/encryption/test_envelope.py.
    """
    user_id = "user-stable-dek"
    dek1 = key_vault.get_or_create_dek(db_session, user_id)
    dek2 = key_vault.get_or_create_dek(db_session, user_id)
    assert dek1 == dek2
    assert isinstance(dek1, bytes)
    assert len(dek1) == 32  # AES-256 DEK
