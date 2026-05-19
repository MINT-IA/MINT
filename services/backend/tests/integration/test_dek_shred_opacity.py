"""DEK crypto-shred opacity (D-03 + T-02-02).

Phase mint-data-architecture-v1-02 Plan 02-02 W1 Task 2.

After crypto_shred_user(db, user_id), decrypting any encrypted_value
for that user MUST raise DEKRevokedError (NOT silently return stale bytes
NOR plaintext). This is the PFPDT-validated RTBF guarantee.

This test uses in-memory SQLite (no pg_fixture needed — the contract is
behavioural, not DDL-specific).
"""
from __future__ import annotations

import os

import pytest

os.environ["TESTING"] = "1"

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.dek_vault import DEKVault  # noqa: F401
from app.models.user import User  # noqa: F401
from app.services.encryption.encrypted_value_helper import (
    decrypt_value,
    encrypt_value,
)
from app.services.encryption.key_vault import DEKRevokedError, key_vault


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


def test_decrypt_after_shred_raises_dek_revoked(db_session):
    """Encrypt -> shred -> decrypt MUST raise DEKRevokedError (not return data)."""
    user_id = "user-shred-test"
    envelope = encrypt_value(db_session, user_id, {"secret": "value"})
    # Shred the DEK (sets wrapped_dek=NULL + revoked_at=now)
    key_vault.crypto_shred_user(db_session, user_id)
    db_session.commit()
    with pytest.raises(DEKRevokedError):
        decrypt_value(db_session, user_id, envelope)


def test_shred_is_idempotent(db_session):
    """Multiple crypto_shred_user calls for the same user are no-ops."""
    user_id = "user-shred-idem"
    encrypt_value(db_session, user_id, "hello")
    assert key_vault.crypto_shred_user(db_session, user_id) is True
    # Second call still returns True (row exists) but is a no-op
    assert key_vault.crypto_shred_user(db_session, user_id) is True


def test_shred_does_not_remove_envelope_rows(db_session):
    """Shred sets wrapped_dek=NULL but does NOT delete the envelope JSONB rows.

    The envelope bytes remain present on backups (already-written WAL); they
    are simply cryptographically irrecoverable. This is the explicit
    crypto-shred contract per the panel ADR.
    """
    user_id = "user-shred-row-test"
    envelope = encrypt_value(db_session, user_id, "secret")
    # Envelope dict is what would be stored in fact_event.value_enc JSONB
    assert envelope["ct"]  # still present
    key_vault.crypto_shred_user(db_session, user_id)
    # Envelope dict structure is unchanged (we never mutated it)
    assert envelope["ct"]  # still present, but can no longer be decrypted
    with pytest.raises(DEKRevokedError):
        decrypt_value(db_session, user_id, envelope)


def test_shred_user_a_does_not_affect_user_b(db_session):
    """RTBF for user A must not impact user B's data accessibility."""
    env_a = encrypt_value(db_session, "user-A", "data-A")
    env_b = encrypt_value(db_session, "user-B", "data-B")
    key_vault.crypto_shred_user(db_session, "user-A")
    db_session.commit()
    # User B can still decrypt
    assert decrypt_value(db_session, "user-B", env_b) == "data-B"
    # User A cannot
    with pytest.raises(DEKRevokedError):
        decrypt_value(db_session, "user-A", env_a)
