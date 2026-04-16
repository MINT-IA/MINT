"""Merkle chain tamper-detection tests — v2.7 Phase 29 / PRIV-01."""
from __future__ import annotations

import os
import pytest

os.environ.setdefault("TESTING", "1")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
import app.models  # noqa: F401
from app.models.consent import ConsentModel
from app.services.consent.consent_service import ConsentService
from app.services.consent.merkle_chain import verify_chain


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def service():
    return ConsentService(shred_hook=lambda db, uid: True)


def test_empty_chain_is_valid(db):
    valid, break_at = verify_chain(db, "u1")
    assert valid is True
    assert break_at is None


def test_clean_chain_validates(db, service):
    service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    service.grant(db, user_id="u1", purpose="couple_projection", policy_version="v2.3.0")
    valid, break_at = verify_chain(db, "u1")
    assert valid is True
    assert break_at is None


def test_tampered_receipt_json_breaks_chain(db, service):
    r1 = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    # Tamper: mutate the stored JSON so signature no longer verifies
    r1.receipt_json = {**r1.receipt_json, "policyHash": "0" * 64}
    db.add(r1)
    db.commit()

    valid, break_at = verify_chain(db, "u1")
    assert valid is False
    assert break_at == r1.receipt_id


def test_tampered_prev_hash_breaks_chain(db, service):
    r1 = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    r2 = service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    r2.prev_hash = "f" * 64
    db.add(r2)
    db.commit()
    valid, break_at = verify_chain(db, "u1")
    assert valid is False
    assert break_at == r2.receipt_id


def test_deleted_middle_row_breaks_chain(db, service):
    r1 = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    r2 = service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    r3 = service.grant(db, user_id="u1", purpose="couple_projection", policy_version="v2.3.0")

    db.delete(r2)
    db.commit()

    valid, break_at = verify_chain(db, "u1")
    assert valid is False
    # r3's prev_hash was linked to r2.signature — with r2 gone, r3 breaks
    assert break_at == r3.receipt_id
