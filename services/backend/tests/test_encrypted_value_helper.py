"""Unit tests for app.services.encryption.encrypted_value_helper.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-26 + iter-2 B6.

encrypt_value/decrypt_value wrap existing envelope.encrypt_bytes/decrypt_bytes
with JSON canonical serialization + EncryptedValue Pydantic v2 shape.
iter-2 B6: scan plaintext for LSFin banned terms when source_type in
{'coach_inference', 'user_input'} before encryption (fail-closed).
"""
from __future__ import annotations

import os

import pytest

# Set TESTING=1 before any imports that read env
os.environ["TESTING"] = "1"

from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.core.database import Base  # noqa: E402
from app.models.dek_vault import DEKVault  # noqa: E402,F401
from app.models.encryption.encrypted_value import EncryptedValue  # noqa: E402
from app.models.user import User  # noqa: E402,F401
from app.services.encryption.encrypted_value_helper import (  # noqa: E402
    BannedTermsViolation,
    decrypt_value,
    encrypt_value,
)
from app.services.encryption.key_vault import key_vault  # noqa: E402


@pytest.fixture
def db_session():
    """In-memory SQLite session with dek_vault + users tables (self-contained).

    Mirrors `services/backend/tests/services/encryption/test_envelope.py:43-50`
    pattern — per-test engine + create_all so the dek_vault row writes succeed.
    Clears the key_vault singleton between tests to prevent DEK-cache bleed.
    """
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    key_vault.reset()  # clear cross-test DEK cache
    s = Session()
    try:
        yield s
    finally:
        s.close()
        key_vault.reset()


# ---------------------------------------------------------------------------
# Roundtrip across plaintext types
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "value",
    [
        "hello world",
        12345,
        12345.67,
        True,
        None,
        {"nested": {"key": "value", "n": 42}},
        ["a", "b", "c"],
        {"list": [1, 2, 3], "mixed": {"x": "y"}},
    ],
)
def test_encrypt_value_roundtrip(db_session, value):
    """Encrypt then decrypt yields the same value (JSON-roundtrippable)."""
    user_id = "user-roundtrip-test"
    envelope = encrypt_value(db_session, user_id, value)
    assert isinstance(envelope, dict)
    # The envelope must validate against the D-26 shape
    EncryptedValue.model_validate(envelope)
    decrypted = decrypt_value(db_session, user_id, envelope)
    assert decrypted == value


def test_envelope_dek_id_is_logical_key_id(db_session):
    """D-02: envelope carries the logical key-id 'mint-master-v1' (audit anchor)."""
    envelope = encrypt_value(db_session, "user-dek-id-test", "hello")
    EncryptedValue.model_validate(envelope)
    assert envelope["dek_id"] == "mint-master-v1"


def test_envelope_alg_is_aes_256_gcm(db_session):
    """D-26: envelope alg is always AES-256-GCM."""
    envelope = encrypt_value(db_session, "user-alg-test", "hello")
    assert envelope["alg"] == "AES-256-GCM"


def test_envelope_enc_v_default_one(db_session):
    """enc_v defaults to 1 (envelope-format version)."""
    envelope = encrypt_value(db_session, "user-encv-test", "hello")
    assert envelope["enc_v"] == 1


# ---------------------------------------------------------------------------
# AAD cross-user binding (D-26 security invariant)
# ---------------------------------------------------------------------------


def test_aad_cross_user_decrypt_fails(db_session):
    """AAD binds ciphertext to user_id: decrypting with a different user_id MUST fail.

    Existing envelope.py invariant preserved by the helper. This is the
    core security property the audit / event-log architecture relies on.
    """
    envelope = encrypt_value(db_session, "user-A", "secret data")
    with pytest.raises(Exception):  # EncryptionError on tag mismatch
        decrypt_value(db_session, "user-B", envelope)


# ---------------------------------------------------------------------------
# Canonical JSON serialization (deterministic across runs)
# ---------------------------------------------------------------------------


def test_canonical_json_deterministic(db_session):
    """Encrypting the same dict twice produces ciphertexts that decrypt to the
    same value — even when key order differs in the input dict.

    NOTE: nonces are random, so the BYTE-level envelope differs each call.
    But the recovered plaintext, post-decrypt, must be deterministic.
    """
    user_id = "user-canonical-json"
    e1 = encrypt_value(db_session, user_id, {"b": 2, "a": 1})
    e2 = encrypt_value(db_session, user_id, {"a": 1, "b": 2})  # different key order
    d1 = decrypt_value(db_session, user_id, e1)
    d2 = decrypt_value(db_session, user_id, e2)
    assert d1 == d2 == {"a": 1, "b": 2}


# ---------------------------------------------------------------------------
# iter-2 B6 — banned-terms scan on coach_inference / user_input source_type
# ---------------------------------------------------------------------------


def test_banned_terms_scan_on_coach_inference_rejects_garanti(db_session):
    """iter-2 B6: encrypt_value(... source_type='coach_inference') scans the
    plaintext for LSFin banned terms and raises BannedTermsViolation BEFORE
    encryption (fail-closed at write time)."""
    with pytest.raises(BannedTermsViolation):
        encrypt_value(
            db_session,
            "user-banned",
            {"narrative": "votre rendement est garanti à 4%"},
            source_type="coach_inference",
        )


def test_banned_terms_scan_on_user_input_rejects_optimal(db_session):
    """iter-2 B6: source_type='user_input' also triggers the scan.

    Note: word-boundary regex respects French inflection — `optimale` is NOT
    caught (suffix `e`), only the masculine root `optimal`. The vocabulary
    lint flags only the canonical roots; LSFin paraphrase scanning catches
    semantic variants via BANNED_PARAPHRASE_VERBS.
    """
    with pytest.raises(BannedTermsViolation):
        encrypt_value(
            db_session,
            "user-banned-2",
            {"hint": "choisir l'optimal serait préférable"},
            source_type="user_input",
        )


def test_banned_terms_scan_skipped_when_source_type_absent(db_session):
    """When source_type is not in the scan set, plaintext is NOT scanned —
    raw financial values (numbers, codes, hashes) bypass the LSFin scan."""
    # Should NOT raise — no source_type provided
    envelope = encrypt_value(
        db_session,
        "user-no-scan",
        {"narrative": "votre rendement est garanti à 4%"},  # would be banned if scanned
    )
    EncryptedValue.model_validate(envelope)


def test_banned_terms_scan_passes_clean_text(db_session):
    """Clean text in coach_inference source_type encrypts normally."""
    envelope = encrypt_value(
        db_session,
        "user-clean",
        {"narrative": "votre situation pourrait évoluer ; envisager une revue"},
        source_type="coach_inference",
    )
    EncryptedValue.model_validate(envelope)
