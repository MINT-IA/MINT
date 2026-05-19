"""Unit tests for KeyVaultService logical key-id + iter-2 A4 fail-closed + A5 TTL cache.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-02 + D-35 PROPOSED (A4) + A5.
"""
from __future__ import annotations

import os
import time

import pytest

os.environ["TESTING"] = "1"

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.dek_vault import DEKVault  # noqa: F401
from app.models.user import User  # noqa: F401
from app.services.encryption.key_vault import (
    KMSBackendUnavailable,
    KeyVaultService,
    key_vault,
)


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    key_vault.reset()
    s = Session()
    try:
        yield s
    finally:
        s.close()
        key_vault.reset()


# ---------------------------------------------------------------------------
# D-02 — logical key-id baked into kms_key_ref on new DEK rows
# ---------------------------------------------------------------------------


def test_get_or_create_dek_uses_kms_key_id_env(db_session, monkeypatch):
    """D-02: when MINT_KMS_KEY_ID='mint-master-v1' is set, kms_key_ref on the
    new dek_vault row equals that logical id (audit anchor)."""
    monkeypatch.setenv("MINT_KMS_KEY_ID", "mint-master-v1")
    monkeypatch.setenv("MINT_KMS_BACKEND", "fernet")  # dev opt-in
    monkeypatch.delenv("MINT_MASTER_KEY", raising=False)
    key_vault.reset()
    dek = key_vault.get_or_create_dek(db_session, "user-d02-test")
    assert len(dek) == 32
    row = db_session.query(DEKVault).filter_by(user_id="user-d02-test").one()
    assert row.kms_key_ref == "mint-master-v1"


# ---------------------------------------------------------------------------
# iter-2 A4 + D-35 PROPOSED — fail-closed when MINT_KMS_KEY_ID unset (prod)
# ---------------------------------------------------------------------------


def test_no_silent_fernet_fallback_when_both_unset(monkeypatch):
    """D-35: when neither MINT_KMS_KEY_ID nor MINT_KMS_BACKEND is set AND
    TESTING is unset, _select_backend MUST raise KMSBackendUnavailable.

    The Plan 02-01 silent Fernet fallback was a security HIGH (split-brain
    key wrapping). Production deploys must explicitly set MINT_KMS_KEY_ID
    OR opt in to dev-Fernet via MINT_KMS_BACKEND=fernet.
    """
    monkeypatch.delenv("MINT_KMS_KEY_ID", raising=False)
    monkeypatch.delenv("MINT_KMS_BACKEND", raising=False)
    monkeypatch.delenv("TESTING", raising=False)
    svc = KeyVaultService()
    with pytest.raises(KMSBackendUnavailable):
        svc._get_backend()


def test_explicit_fernet_opt_in_works(monkeypatch):
    """Dev opt-in: MINT_KMS_BACKEND=fernet bypasses the fail-closed gate."""
    monkeypatch.setenv("MINT_KMS_BACKEND", "fernet")
    monkeypatch.delenv("MINT_KMS_KEY_ID", raising=False)
    monkeypatch.setenv("TESTING", "1")  # let _fernet_from_env generate volatile MK
    svc = KeyVaultService()
    backend = svc._get_backend()
    assert backend is not None  # no exception


def test_testing_alone_allows_fernet_fallback(monkeypatch):
    """TESTING=1 alone allows fernet fallback (pre-existing test contract)."""
    monkeypatch.delenv("MINT_KMS_KEY_ID", raising=False)
    monkeypatch.delenv("MINT_KMS_BACKEND", raising=False)
    monkeypatch.setenv("TESTING", "1")
    svc = KeyVaultService()
    backend = svc._get_backend()
    assert backend is not None


# ---------------------------------------------------------------------------
# iter-2 A5 — TTL DEK cache (bounded + expiring)
# ---------------------------------------------------------------------------


def test_dek_cache_is_ttl_bounded():
    """A5: _dek_cache is a TTLCache (not unbounded dict) — maxsize + ttl set."""
    from cachetools import TTLCache
    svc = KeyVaultService()
    assert isinstance(svc._dek_cache, TTLCache)
    assert svc._dek_cache.maxsize == KeyVaultService._DEK_CACHE_MAXSIZE
    assert svc._dek_cache.ttl == KeyVaultService._DEK_CACHE_TTL_SECONDS


def test_dek_cache_evicts_after_ttl(db_session, monkeypatch):
    """A5: cache entry evicted after TTL — re-fetch hits DB again.

    Uses a 1-second TTL override so the test doesn't sleep 5 minutes.
    """
    from cachetools import TTLCache
    monkeypatch.setenv("MINT_KMS_BACKEND", "fernet")
    monkeypatch.setenv("MINT_KMS_KEY_ID", "mint-master-v1")
    key_vault.reset()
    # Override TTL to 1 second for test
    key_vault._dek_cache = TTLCache(maxsize=10, ttl=1)
    dek1 = key_vault.get_or_create_dek(db_session, "user-ttl-test")
    assert "user-ttl-test" in key_vault._dek_cache
    time.sleep(1.2)
    # Cache should have evicted
    assert "user-ttl-test" not in key_vault._dek_cache
    # Re-fetch should still work (reads from DB) — same DEK bytes
    dek2 = key_vault.get_or_create_dek(db_session, "user-ttl-test")
    assert dek1 == dek2
