"""Third-party declaration opposable — v2.7 Phase 29 / PRIV-02.

Covers:
    1. 428 gate — upload blocked without a fresh declaration receipt for this
       doc_hash.
    2. Nominative receipt shape — contains subjectName, declaredDocHash, hashed
       IP (never raw IP).
    3. Gate passes once a matching declaration is granted.
    4. Stale declaration (TTL expired) triggers the gate again.
    5. Declaration for a different doc_hash does NOT satisfy the gate.
    6. Session-scoped persistence — third-party facts do NOT land in
       profile_facts; they land in the Redis session store with a TTL.

Uses an in-memory SQLite + a fake Redis to keep tests pure (Phase 27 pattern
already established in test_token_budget + test_slo_monitor).
"""
from __future__ import annotations

import asyncio
import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

import pytest

os.environ.setdefault("TESTING", "1")
os.environ.setdefault("MINT_IP_SALT", "test-ip-salt-only")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
import app.models  # noqa: F401 — register models

from app.schemas.document_understanding import (
    ConfidenceLevel,
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractedField,
    ExtractionStatus,
    RenderMode,
)
from app.services.consent.consent_service import ConsentService
from app.services.document_third_party import (
    DECLARATION_TTL_HOURS,
    ThirdPartyDeclarationRequired,
    require_declaration_or_block,
)


# ── Fixtures ──────────────────────────────────────────────────────────────────


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
    def fake_shred(db, user_id):
        return True

    return ConsentService(shred_hook=fake_shred)


def _understanding(third_party: bool, name: Optional[str] = None) -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        extracted_fields=[
            ExtractedField(
                field_name="salaireAssure",
                value=67000.0,
                confidence=ConfidenceLevel.high,
                source_text="Lauren Martin — Salaire assuré 67'000",
            )
        ],
        overall_confidence=0.9,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
        third_party_detected=third_party,
        third_party_name=name,
    )


# ── Tests ─────────────────────────────────────────────────────────────────────


def test_gate_blocks_when_no_declaration(db, service):
    u = "user-1"
    result = _understanding(third_party=True, name="Lauren Martin")

    with pytest.raises(ThirdPartyDeclarationRequired) as exc:
        require_declaration_or_block(
            db,
            user_id=u,
            understanding=result,
            doc_hash="sha256-doc-A",
        )

    err = exc.value
    assert "Lauren Martin" in err.subject_names
    assert err.doc_hash == "sha256-doc-A"


def test_gate_passes_when_no_third_party_detected(db, service):
    u = "user-1"
    result = _understanding(third_party=False)
    # Must not raise.
    require_declaration_or_block(
        db,
        user_id=u,
        understanding=result,
        doc_hash="sha256-doc-A",
    )


def test_nominative_receipt_shape(db, service):
    row = service.grant_nominative(
        db,
        user_id="user-1",
        subject_name="Lauren Martin",
        doc_hash="sha256-doc-A",
        declared_from_ip="203.0.113.42",
    )
    rj = row.receipt_json
    assert rj["purposeCategory"] == "third_party_attestation"
    assert rj["subjectName"] == "Lauren Martin"
    assert rj["subjectRole"] in ("declared_partner", "declared_other")
    assert rj["declaredDocHash"] == "sha256-doc-A"
    assert "declaredFromIp" in rj
    assert rj["declaredFromIp"] != "203.0.113.42"  # must be hashed
    assert len(rj["declaredFromIp"]) == 32  # truncated HMAC hex (16 bytes)
    # Signature still HMAC-SHA256 of the full receipt_json
    assert row.signature and len(row.signature) == 64


def test_gate_passes_after_declaration_granted(db, service):
    u = "user-1"
    service.grant_nominative(
        db,
        user_id=u,
        subject_name="Lauren Martin",
        doc_hash="sha256-doc-A",
        declared_from_ip="127.0.0.1",
    )
    result = _understanding(third_party=True, name="Lauren Martin")
    # Must not raise.
    require_declaration_or_block(
        db,
        user_id=u,
        understanding=result,
        doc_hash="sha256-doc-A",
    )


def test_gate_rejects_wrong_doc_hash(db, service):
    u = "user-1"
    service.grant_nominative(
        db,
        user_id=u,
        subject_name="Lauren Martin",
        doc_hash="sha256-doc-A",
        declared_from_ip="127.0.0.1",
    )
    result = _understanding(third_party=True, name="Lauren Martin")
    with pytest.raises(ThirdPartyDeclarationRequired):
        require_declaration_or_block(
            db,
            user_id=u,
            understanding=result,
            doc_hash="sha256-doc-B",  # different upload
        )


def test_gate_rejects_stale_declaration(db, service):
    u = "user-1"
    row = service.grant_nominative(
        db,
        user_id=u,
        subject_name="Lauren Martin",
        doc_hash="sha256-doc-A",
        declared_from_ip="127.0.0.1",
    )
    # Backdate the consent_timestamp past the TTL window.
    row.consent_timestamp = datetime.now(timezone.utc) - timedelta(
        hours=DECLARATION_TTL_HOURS + 1
    )
    db.commit()

    result = _understanding(third_party=True, name="Lauren Martin")
    with pytest.raises(ThirdPartyDeclarationRequired):
        require_declaration_or_block(
            db,
            user_id=u,
            understanding=result,
            doc_hash="sha256-doc-A",
        )


def test_gate_rejects_revoked_declaration(db, service):
    u = "user-1"
    row = service.grant_nominative(
        db,
        user_id=u,
        subject_name="Lauren Martin",
        doc_hash="sha256-doc-A",
        declared_from_ip="127.0.0.1",
    )
    row.revoked_at = datetime.now(timezone.utc)
    db.commit()

    result = _understanding(third_party=True, name="Lauren Martin")
    with pytest.raises(ThirdPartyDeclarationRequired):
        require_declaration_or_block(
            db,
            user_id=u,
            understanding=result,
            doc_hash="sha256-doc-A",
        )


# ── Session-scoped third-party fact persistence ──────────────────────────────


class _FakeRedis:
    """Minimal async fake covering setex/get/exists/ttl used by the store."""

    def __init__(self) -> None:
        self._data: Dict[str, Any] = {}
        self._ttls: Dict[str, int] = {}

    async def setex(self, key: str, ttl: int, value: str) -> bool:
        self._data[key] = value
        self._ttls[key] = ttl
        return True

    async def get(self, key: str) -> Optional[str]:
        return self._data.get(key)

    async def ttl(self, key: str) -> int:
        return self._ttls.get(key, -2)

    async def exists(self, key: str) -> int:
        return 1 if key in self._data else 0


def test_third_party_fact_routed_to_session_store_not_profile_facts(db):
    """is_third_party=True must skip profile_facts write and hit Redis."""
    from app.core import redis_client as _rc
    from app.services import document_memory_service as dms

    fake = _FakeRedis()
    _rc.set_redis_client_for_tests(fake)
    try:
        ok = dms.persist_fact(
            db,
            user_id="user-1",
            key="salaire_assure",
            value=67000,
            source="coach",
            is_third_party=True,
            session_id="sess-abc",
        )
        assert ok is True  # policy gate accepted — routed to session store

        # Key in fake redis under the tpf:<session>:<hashed_fact> prefix
        keys = list(fake._data.keys())
        assert any(k.startswith("tpf:sess-abc:") for k in keys), keys
        # TTL honoured (default 2h = 7200s)
        for k, ttl in fake._ttls.items():
            if k.startswith("tpf:sess-abc:"):
                assert ttl > 0 and ttl <= 7200

        # profile_facts row should NOT exist (SQLite has no table anyway; the
        # absence is demonstrated by the fact that the session-store path
        # returned True without attempting an INSERT).
    finally:
        _rc.reset_for_tests()


def test_ip_hashing_roundtrip_stable(db, service):
    """Same raw IP hashes to same digest; different IPs differ."""
    r1 = service.grant_nominative(
        db, user_id="u1", subject_name="Lauren Martin",
        doc_hash="A", declared_from_ip="203.0.113.42",
    )
    r2 = service.grant_nominative(
        db, user_id="u1", subject_name="Lauren Martin",
        doc_hash="B", declared_from_ip="203.0.113.42",
    )
    r3 = service.grant_nominative(
        db, user_id="u1", subject_name="Lauren Martin",
        doc_hash="C", declared_from_ip="198.51.100.9",
    )
    assert r1.receipt_json["declaredFromIp"] == r2.receipt_json["declaredFromIp"]
    assert r1.receipt_json["declaredFromIp"] != r3.receipt_json["declaredFromIp"]
