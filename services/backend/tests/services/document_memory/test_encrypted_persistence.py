"""document_memory_service encrypt/decrypt persistence tests (PRIV-04).

Flag ON  → writes go to *_enc columns, plaintext stays NULL.
Flag OFF → writes go to plaintext columns, *_enc stays NULL.
Mixed    → reads prefer *_enc; fall back to plaintext when *_enc IS NULL.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from unittest.mock import patch

import pytest

os.environ.setdefault("TESTING", "1")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.user import User  # noqa: F401
from app.models.dek_vault import DEKVault  # noqa: F401
from app.models.document_memory import DocumentMemory

from app.services import document_memory_service as dms
from app.services.encryption.key_vault import key_vault


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


def _mk_row(db, user_id: str, fp: str = "fp1") -> DocumentMemory:
    row = DocumentMemory(
        user_id=user_id,
        fingerprint=fp,
        doc_type="lpp_certificate",
        issuer="CPE",
        last_seen_at=datetime.now(timezone.utc),
        field_history=[],
    )
    db.add(row)
    db.commit()
    return row


def test_flag_on_writes_go_to_encrypted_columns(db):
    uid = _mk_user(db, "flag_on")
    row = _mk_row(db, uid)
    with patch.object(dms, "_flag_privacy_v2", return_value=True):
        dms.persist_evidence_text(
            db, uid, row,
            evidence_text="Avoir LPP: 70'377",
            vision_raw="{\"avoir\": 70377}",
        )
        db.commit()

    db.refresh(row)
    assert row.evidence_text is None
    assert row.vision_raw is None
    assert row.evidence_text_enc is not None
    assert row.vision_raw_enc is not None
    # Not equal to plaintext-utf8 (would mean no encryption happened).
    assert bytes(row.evidence_text_enc) != "Avoir LPP: 70'377".encode("utf-8")


def test_flag_off_writes_go_to_plaintext_columns(db):
    uid = _mk_user(db, "flag_off")
    row = _mk_row(db, uid)
    with patch.object(dms, "_flag_privacy_v2", return_value=False):
        dms.persist_evidence_text(
            db, uid, row,
            evidence_text="legacy text",
            vision_raw="legacy raw",
        )
        db.commit()

    db.refresh(row)
    assert row.evidence_text == "legacy text"
    assert row.vision_raw == "legacy raw"
    assert row.evidence_text_enc is None
    assert row.vision_raw_enc is None


def test_read_prefers_encrypted_when_present(db):
    uid = _mk_user(db, "mixed")
    row = _mk_row(db, uid)
    with patch.object(dms, "_flag_privacy_v2", return_value=True):
        dms.persist_evidence_text(db, uid, row, "enc-content", "enc-raw")
        db.commit()

    out = dms.read_evidence_text(db, uid, row)
    assert out == {"evidence_text": "enc-content", "vision_raw": "enc-raw"}


def test_read_falls_back_to_plaintext_when_enc_absent(db):
    uid = _mk_user(db, "legacy_row")
    row = _mk_row(db, uid)
    # Simulate pre-migration state: plaintext columns populated directly.
    row.evidence_text = "pre-migration evidence"
    row.vision_raw = "pre-migration raw"
    db.commit()

    out = dms.read_evidence_text(db, uid, row)
    assert out == {
        "evidence_text": "pre-migration evidence",
        "vision_raw": "pre-migration raw",
    }


def test_read_handles_mixed_fields(db):
    """evidence_text encrypted, vision_raw plaintext (realistic mid-migration)."""
    uid = _mk_user(db, "partial")
    row = _mk_row(db, uid)
    # Encrypt evidence only.
    with patch.object(dms, "_flag_privacy_v2", return_value=True):
        dms.persist_evidence_text(db, uid, row, "enc-ev", None)
        db.commit()
    # Now add legacy plaintext for vision_raw (simulating partial migration).
    row.vision_raw = "plain-raw"
    db.commit()

    out = dms.read_evidence_text(db, uid, row)
    assert out["evidence_text"] == "enc-ev"
    assert out["vision_raw"] == "plain-raw"


def test_read_after_shred_raises_dek_revoked(db):
    uid = _mk_user(db, "shred_read")
    row = _mk_row(db, uid)
    with patch.object(dms, "_flag_privacy_v2", return_value=True):
        dms.persist_evidence_text(db, uid, row, "secret", None)
        db.commit()

    key_vault.crypto_shred_user(db, uid)

    db.refresh(row)
    with pytest.raises(dms.DEKRevokedError):
        dms.read_evidence_text(db, uid, row)


def test_migration_script_dry_run_does_not_mutate(db, monkeypatch):
    uid = _mk_user(db, "mig_user")
    row = _mk_row(db, uid)
    row.evidence_text = "to-encrypt"
    row.vision_raw = "to-encrypt-raw"
    db.commit()

    # Monkeypatch SessionLocal so the script uses our in-memory DB.
    from scripts import migrate_evidence_text_encrypt as mig

    def _fake_session_local():
        return db

    # Prevent the script from closing the shared fixture session.
    original_close = db.close
    db.close = lambda: None  # type: ignore[method-assign]
    monkeypatch.setattr(mig, "SessionLocal", _fake_session_local)
    try:
        users, migrated, failed = mig.migrate(dry_run=True, batch_size=100)
    finally:
        db.close = original_close  # type: ignore[method-assign]

    assert users == 1
    assert migrated == 1
    assert failed == 0
    # Plaintext still there, encrypted still empty.
    db.refresh(row)
    assert row.evidence_text == "to-encrypt"
    assert row.evidence_text_enc is None


def test_migration_script_live_run_encrypts_and_nulls_plaintext(db, monkeypatch):
    uid = _mk_user(db, "mig_live")
    row = _mk_row(db, uid)
    row.evidence_text = "enc-me"
    row.vision_raw = "enc-me-raw"
    db.commit()

    from scripts import migrate_evidence_text_encrypt as mig

    def _fake_session_local():
        return db

    original_close = db.close
    db.close = lambda: None  # type: ignore[method-assign]
    monkeypatch.setattr(mig, "SessionLocal", _fake_session_local)
    try:
        users, migrated, failed = mig.migrate(dry_run=False, batch_size=100)
    finally:
        db.close = original_close  # type: ignore[method-assign]

    assert users == 1
    assert migrated == 1
    assert failed == 0

    db.refresh(row)
    assert row.evidence_text is None
    assert row.vision_raw is None
    assert row.evidence_text_enc is not None
    assert row.vision_raw_enc is not None

    # Verify round-trip via service.
    out = dms.read_evidence_text(db, uid, row)
    assert out == {"evidence_text": "enc-me", "vision_raw": "enc-me-raw"}
