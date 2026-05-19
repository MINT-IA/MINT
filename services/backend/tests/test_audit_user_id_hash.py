"""Tests for audit_service.hash_user_id + log_audit_event hash wiring
(Hotfix C 2026-05-17, updated 2026-05-18 for Plan 02-02 D-14 HMAC-pepper migration).

Verifies the PII-clean audit contract:
    - hash_user_id returns 64-char HMAC-SHA256-pepper hex (or None on None input)
    - hash_user_id is deterministic across calls
    - log_audit_event populates both user_id (legacy) and user_id_hash
    - The hash matches `hash_user_id(user_id)` exactly (no drift)
    - Plan 02-02 D-14: hash NO LONGER equals bare hashlib.sha256(user_id) —
      the HMAC-pepper migration is the rainbow-table mitigation.
"""

import hashlib
import os
import re
from typing import Iterator

import pytest

os.environ["TESTING"] = "1"  # let hmac_pepper fall back to test-pepper

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.database import Base
from app.models.audit_event import AuditEventModel
from app.services.audit_service import hash_user_id, log_audit_event


@pytest.fixture
def db() -> Iterator[Session]:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_hash_user_id_returns_64char_hex() -> None:
    h = hash_user_id("user-abc")
    assert h is not None
    assert re.fullmatch(r"[0-9a-f]{64}", h)


def test_hash_user_id_is_deterministic() -> None:
    assert hash_user_id("alice") == hash_user_id("alice")


def test_hash_user_id_returns_none_for_none() -> None:
    assert hash_user_id(None) is None


def test_hash_user_id_does_NOT_match_stdlib_sha256_post_hmac_pepper() -> None:
    """Plan 02-02 D-14: hash_user_id now uses HMAC-SHA256 with a server-only
    pepper (security-auditor obs #175 — rainbow-table mitigation). The output
    MUST differ from bare hashlib.sha256(user_id) — otherwise the pepper is
    not being applied.

    Replaces the pre-Plan-02-02 contract that hash_user_id == bare sha256.
    """
    user_id = "user-12345"
    bare = hashlib.sha256(user_id.encode("utf-8")).hexdigest()
    actual = hash_user_id(user_id)
    assert actual != bare, (
        "hash_user_id must differ from bare sha256 (HMAC-pepper mitigation, D-14)"
    )
    # Shape is still 64-char lowercase hex
    assert re.fullmatch(r"[0-9a-f]{64}", actual)


def test_log_audit_event_writes_user_id_hash(db: Session) -> None:
    log_audit_event(
        db,
        event_type="login",
        user_id="alice-id",
    )
    db.commit()
    row = db.query(AuditEventModel).first()
    assert row is not None
    assert row.user_id == "alice-id"  # legacy plaintext kept one cycle
    assert row.user_id_hash == hash_user_id("alice-id")


def test_log_audit_event_handles_none_user_id(db: Session) -> None:
    log_audit_event(
        db,
        event_type="system_boot",
        user_id=None,
    )
    db.commit()
    row = db.query(AuditEventModel).first()
    assert row is not None
    assert row.user_id is None
    assert row.user_id_hash is None
