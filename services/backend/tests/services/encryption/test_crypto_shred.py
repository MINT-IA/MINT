"""Crypto-shredding contract tests.

v2.7 Phase 29 / PRIV-04.

Verifies that crypto_shred_user renders previously-encrypted evidence
unreadable while leaving the ciphertext bytes on disk — the exact
guarantee PFPDT validated in the 2024 Infomaniak opinion.
"""
from __future__ import annotations

import math
import os
import secrets
from collections import Counter
from datetime import datetime, timezone

import pytest

os.environ.setdefault("TESTING", "1")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.user import User  # noqa: F401
from app.models.dek_vault import DEKVault  # noqa: F401
from app.models.document_memory import DocumentMemory

from app.services.encryption.envelope import encrypt_text, decrypt_text
from app.services.encryption.key_vault import (
    key_vault,
    DEKRevokedError,
)


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
        key_vault.reset()


def _mk_user(db, user_id: str) -> str:
    u = User(
        id=user_id,
        email=f"{user_id}@test.local",
        hashed_password="x",
        created_at=datetime.now(timezone.utc),
    )
    db.add(u)
    db.commit()
    return user_id


def _entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = Counter(data)
    n = len(data)
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


def test_shred_makes_evidence_unreadable_but_preserves_bytes(db):
    uid = _mk_user(db, "target")
    pt_ev = "Lauren LPP 70'377 CHF · evidence" * 50
    pt_vr = "raw vision json: {\"avoir\":70377}" * 30
    enc_ev = encrypt_text(db, uid, pt_ev)
    enc_vr = encrypt_text(db, uid, pt_vr)
    assert enc_ev is not None and enc_vr is not None

    row = DocumentMemory(
        user_id=uid,
        fingerprint="fp_shred_1",
        doc_type="lpp_certificate",
        issuer="CPE",
        last_seen_at=datetime.now(timezone.utc),
        field_history=[],
        evidence_text_enc=enc_ev,
        vision_raw_enc=enc_vr,
    )
    db.add(row)
    db.commit()

    # Sanity: decrypts before shred.
    assert decrypt_text(db, uid, bytes(enc_ev)) == pt_ev
    assert decrypt_text(db, uid, bytes(enc_vr)) == pt_vr

    # Shred.
    assert key_vault.crypto_shred_user(db, uid) is True

    # Refetch the stored row — bytes must still be present (backup safety
    # illusion preserved) but unreadable.
    fresh = db.query(DocumentMemory).filter(DocumentMemory.user_id == uid).one()
    assert fresh.evidence_text_enc is not None
    assert fresh.vision_raw_enc is not None

    # Entropy check — bytes look random, not recoverable without DEK.
    assert _entropy(bytes(fresh.evidence_text_enc)[12:]) >= 7.5
    assert _entropy(bytes(fresh.vision_raw_enc)[12:]) >= 7.5

    # Decryption now refused.
    with pytest.raises(DEKRevokedError):
        decrypt_text(db, uid, bytes(fresh.evidence_text_enc))
    with pytest.raises(DEKRevokedError):
        decrypt_text(db, uid, bytes(fresh.vision_raw_enc))


def test_shred_is_cross_row_global_for_that_user(db):
    uid = _mk_user(db, "multi_rows")
    blobs = [encrypt_text(db, uid, f"row-{i}-evidence") for i in range(5)]
    for i, b in enumerate(blobs):
        db.add(DocumentMemory(
            user_id=uid,
            fingerprint=f"fp{i}",
            doc_type="misc",
            last_seen_at=datetime.now(timezone.utc),
            field_history=[],
            evidence_text_enc=b,
        ))
    db.commit()

    key_vault.crypto_shred_user(db, uid)

    # Every row unreadable.
    for i, b in enumerate(blobs):
        with pytest.raises(DEKRevokedError):
            decrypt_text(db, uid, bytes(b))


def test_shred_does_not_affect_other_users(db):
    a = _mk_user(db, "userA")
    b = _mk_user(db, "userB")
    blob_a = encrypt_text(db, a, "alice stuff")
    blob_b = encrypt_text(db, b, "bob stuff")

    key_vault.crypto_shred_user(db, a)

    with pytest.raises(DEKRevokedError):
        decrypt_text(db, a, bytes(blob_a))
    # Bob still readable.
    assert decrypt_text(db, b, bytes(blob_b)) == "bob stuff"


def test_shred_clears_cache(db):
    """Even if the process had a cached DEK, shredding invalidates it."""
    uid = _mk_user(db, "cache_shred")
    blob = encrypt_text(db, uid, "cached")
    # Prime cache.
    _ = key_vault.get_dek(db, uid)
    assert uid in key_vault._dek_cache

    key_vault.crypto_shred_user(db, uid)
    assert uid not in key_vault._dek_cache

    with pytest.raises(DEKRevokedError):
        decrypt_text(db, uid, bytes(blob))
