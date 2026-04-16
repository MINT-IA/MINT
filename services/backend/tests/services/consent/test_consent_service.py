"""Tests for granular consent service — v2.7 Phase 29 / PRIV-01."""
from __future__ import annotations

import os
import pytest

os.environ.setdefault("TESTING", "1")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
# Ensure all models registered
import app.models  # noqa: F401
from app.models.consent import ConsentModel
from app.services.consent.consent_service import (
    ConsentNotFoundError,
    ConsentService,
)


# Fresh in-memory DB per test — avoids state leak between chain tests.
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
    # Stub the shred hook so we do not depend on a real DEKVault row.
    calls = []

    def fake_shred(db, user_id):
        calls.append(user_id)
        return True

    svc = ConsentService(shred_hook=fake_shred)
    svc._shred_calls = calls  # type: ignore[attr-defined]
    return svc


# --- grant ------------------------------------------------------------------

def test_grant_creates_receipt_row(db, service):
    row = service.grant(
        db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0"
    )
    assert row.receipt_id
    assert row.purpose_category == "vision_extraction"
    assert row.policy_version == "v2.3.0"
    assert row.signature and len(row.signature) == 64  # hex sha256
    assert row.prev_hash is None  # genesis of chain
    assert row.receipt_json["piiPrincipalId"] != "u1"  # hashed, not raw
    assert row.receipt_json["lawfulBasis"] == "consent_nLPD_art_6_al_6"
    assert row.receipt_json["jurisdiction"] == "CH"


def test_grant_chains_prev_hash(db, service):
    r1 = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    r2 = service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    assert r2.prev_hash is not None
    # prev_hash of r2 = sha256(r1.signature)
    import hashlib
    assert r2.prev_hash == hashlib.sha256(r1.signature.encode("utf-8")).hexdigest()


def test_grant_separate_chains_per_user(db, service):
    r1 = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    r2 = service.grant(db, user_id="u2", purpose="vision_extraction", policy_version="v2.3.0")
    assert r1.prev_hash is None and r2.prev_hash is None


def test_four_purposes_all_accepted(db, service):
    purposes = [
        "vision_extraction",
        "persistence_365d",
        "transfer_us_anthropic",
        "couple_projection",
    ]
    for p in purposes:
        row = service.grant(db, user_id="u1", purpose=p, policy_version="v2.3.0")
        assert row.purpose_category == p
    rows = service.list_for_user(db, "u1")
    assert {r.purpose_category for r in rows} == set(purposes)


# --- revoke -----------------------------------------------------------------

def test_revoke_sets_timestamp(db, service):
    row = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    revoked, cascade = service.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    assert revoked.revoked_at is not None
    assert cascade is False  # vision_extraction does not cascade-shred


def test_revoke_persistence_cascades_shred(db, service):
    row = service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    _, cascade = service.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    assert cascade is True
    assert service._shred_calls == ["u1"]  # type: ignore[attr-defined]


def test_revoke_persistence_no_cascade_if_another_active(db, service):
    r1 = service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.1")
    _, cascade = service.revoke(db, user_id="u1", receipt_id=r1.receipt_id)
    # r2 still active → no cascade
    assert cascade is False
    assert service._shred_calls == []  # type: ignore[attr-defined]


def test_revoke_unknown_raises(db, service):
    with pytest.raises(ConsentNotFoundError):
        service.revoke(db, user_id="u1", receipt_id="missing-id")


def test_revoke_idempotent(db, service):
    row = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    service.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    # Second revoke returns same row, no error
    again, cascade = service.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    assert again.revoked_at is not None
    assert cascade is False


# --- receipt shape ----------------------------------------------------------

def test_receipt_conforms_iso_29184_shape(db, service):
    row = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    r = row.receipt_json
    required = {
        "receiptId",
        "piiPrincipalId",
        "piiController",
        "purposeCategory",
        "policyUrl",
        "policyVersion",
        "policyHash",
        "consentTimestamp",
        "jurisdiction",
        "lawfulBasis",
        "revocationEndpoint",
        "prevHash",
    }
    assert required.issubset(r.keys())
    assert r["piiController"] == "MINT Finance SA"


def test_signature_over_receipt_json_is_deterministic_verifiable(db, service):
    from app.services.consent.receipt_builder import verify_signature
    row = service.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    assert verify_signature(row.receipt_json, row.signature)
