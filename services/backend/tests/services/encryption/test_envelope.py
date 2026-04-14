"""Envelope encryption contract tests — AES-256-GCM round-trip + crypto-shred.

v2.7 Phase 29 / PRIV-04.

Covers:
    - round-trip 1 KB + 1 MB payloads
    - nonce uniqueness across 10_000 encrypts for one user
    - distinct users get distinct DEKs (cross-user isolation)
    - post-revoke decryption raises DEKRevokedError
    - ciphertext entropy (bytes/8) ≥ 7.5 bits/byte
    - AAD binding: swapping user_id fails GCM authentication
"""
from __future__ import annotations

import math
import os
import secrets
from collections import Counter

import pytest

# Enable volatile MK path for tests.
os.environ.setdefault("TESTING", "1")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.user import User  # noqa: F401
from app.models.dek_vault import DEKVault  # noqa: F401

from app.services.encryption.envelope import (
    encrypt_bytes,
    decrypt_bytes,
    EncryptionError,
)
from app.services.encryption.key_vault import key_vault, DEKRevokedError


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    try:
        yield s
    finally:
        s.close()
        # Reset cache so different tests don't leak DEKs.
        key_vault.reset()


def _mk_user(db, user_id: str = "u1") -> str:
    """Create a users row (DEKVault has FK → users.id)."""
    from datetime import datetime, timezone
    u = User(
        id=user_id,
        email=f"{user_id}@test.local",
        hashed_password="x",
        created_at=datetime.now(timezone.utc),
    )
    db.add(u)
    db.commit()
    return user_id


def _shannon_entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = Counter(data)
    n = len(data)
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


# ---------------------------------------------------------------------------
# Round-trip
# ---------------------------------------------------------------------------

def test_roundtrip_1kb(db):
    uid = _mk_user(db, "u_small")
    pt = secrets.token_bytes(1024)
    blob = encrypt_bytes(db, uid, pt)
    assert blob != pt  # ciphertext differs from plaintext
    assert decrypt_bytes(db, uid, blob) == pt


def test_roundtrip_1mb(db):
    uid = _mk_user(db, "u_big")
    pt = secrets.token_bytes(1024 * 1024)
    blob = encrypt_bytes(db, uid, pt)
    assert decrypt_bytes(db, uid, blob) == pt


def test_roundtrip_empty(db):
    uid = _mk_user(db, "u_empty")
    blob = encrypt_bytes(db, uid, b"")
    assert decrypt_bytes(db, uid, blob) == b""


def test_roundtrip_text_utf8(db):
    uid = _mk_user(db, "u_txt")
    pt = "Lauren Martin — salaire 122'207 CHF · évidence".encode("utf-8")
    blob = encrypt_bytes(db, uid, pt)
    assert decrypt_bytes(db, uid, blob) == pt


# ---------------------------------------------------------------------------
# Nonce uniqueness — 10k writes, every (nonce) distinct
# ---------------------------------------------------------------------------

def test_nonce_uniqueness_10k_writes(db):
    uid = _mk_user(db, "u_nonces")
    pt = b"stable-plaintext"
    N = 10_000
    nonces = set()
    for _ in range(N):
        blob = encrypt_bytes(db, uid, pt)
        nonces.add(bytes(blob[:12]))
    # Perfect uniqueness (or at most one collision) — 2^96 space, birthday
    # collision prob at 10k is ~6e-20. Any collision here = critical bug.
    assert len(nonces) == N


# ---------------------------------------------------------------------------
# Cross-user isolation
# ---------------------------------------------------------------------------

def test_distinct_users_have_distinct_deks(db):
    a = _mk_user(db, "alice")
    b = _mk_user(db, "bob")
    dek_a = key_vault.get_or_create_dek(db, a)
    dek_b = key_vault.get_or_create_dek(db, b)
    assert dek_a != dek_b
    assert len(dek_a) == 32
    assert len(dek_b) == 32


def test_cross_user_decrypt_fails_aad_mismatch(db):
    a = _mk_user(db, "alice2")
    b = _mk_user(db, "bob2")
    pt = b"alice private evidence"
    blob = encrypt_bytes(db, a, pt)
    # Provision bob's DEK before trying cross-decrypt (otherwise raises
    # DEKRevokedError before AAD check). Then attempting decrypt should
    # fail GCM auth — either wrong key or wrong AAD.
    key_vault.get_or_create_dek(db, b)
    with pytest.raises(EncryptionError):
        decrypt_bytes(db, b, blob)


# ---------------------------------------------------------------------------
# DEK idempotency
# ---------------------------------------------------------------------------

def test_get_or_create_dek_is_idempotent(db):
    uid = _mk_user(db, "idem")
    dek1 = key_vault.get_or_create_dek(db, uid)
    # Clear the in-process cache so the second call hits the DB row.
    key_vault._dek_cache.clear()
    dek2 = key_vault.get_or_create_dek(db, uid)
    assert dek1 == dek2
    rows = db.query(DEKVault).filter(DEKVault.user_id == uid).all()
    assert len(rows) == 1


# ---------------------------------------------------------------------------
# Crypto-shredding
# ---------------------------------------------------------------------------

def test_revoke_blocks_decrypt_and_keeps_ciphertext_entropy(db):
    uid = _mk_user(db, "shredme")
    pt = secrets.token_bytes(4096)
    blob = encrypt_bytes(db, uid, pt)
    assert decrypt_bytes(db, uid, blob) == pt

    assert key_vault.revoke_dek(db, uid) is True

    # Ciphertext is still in our hands (simulating backup); entropy high.
    entropy = _shannon_entropy(blob[12:])  # skip nonce bytes
    assert entropy >= 7.5, f"ciphertext entropy too low: {entropy}"

    # Decryption impossible now.
    with pytest.raises(DEKRevokedError):
        decrypt_bytes(db, uid, blob)


def test_revoke_is_idempotent(db):
    uid = _mk_user(db, "idem_revoke")
    key_vault.get_or_create_dek(db, uid)
    assert key_vault.revoke_dek(db, uid) is True
    # Second call still returns True (row exists, already revoked).
    assert key_vault.revoke_dek(db, uid) is True


def test_revoke_unknown_user_returns_false(db):
    assert key_vault.revoke_dek(db, "ghost-user") is False


def test_crypto_shred_user_alias(db):
    uid = _mk_user(db, "alias_shred")
    key_vault.get_or_create_dek(db, uid)
    assert key_vault.crypto_shred_user(db, uid) is True
    with pytest.raises(DEKRevokedError):
        key_vault.get_dek(db, uid)


# ---------------------------------------------------------------------------
# Tamper detection
# ---------------------------------------------------------------------------

def test_tampered_ciphertext_raises_encryption_error(db):
    uid = _mk_user(db, "tampered")
    pt = b"original"
    blob = bytearray(encrypt_bytes(db, uid, pt))
    # Flip one byte in the ciphertext portion (past the 12-byte nonce).
    blob[20] ^= 0x01
    with pytest.raises(EncryptionError):
        decrypt_bytes(db, uid, bytes(blob))


def test_truncated_blob_rejected(db):
    uid = _mk_user(db, "trunc")
    with pytest.raises(EncryptionError):
        decrypt_bytes(db, uid, b"too-short")
