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


# --- durable shred (audit T02-F49, beads MINT_nosync-tqj) --------------------

def _failing_service():
    calls = []

    def failing_shred(db, user_id):
        calls.append(user_id)
        return False

    svc = ConsentService(shred_hook=failing_shred)
    svc._shred_calls = calls  # type: ignore[attr-defined]
    return svc


def test_failed_shred_marks_durable_pending(db):
    """Un shred qui échoue est enregistré durablement (pas fail-open)."""
    svc = _failing_service()
    row = svc.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    revoked, cascade = svc.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    # cascade reste vrai : l'effacement est durablement programmé (retry).
    assert cascade is True
    db.refresh(revoked)
    assert revoked.shred_pending is True


def test_pending_shred_retried_on_next_grant(db):
    """Le shred en attente est re-tenté à la prochaine interaction consent."""
    svc = _failing_service()
    row = svc.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    svc.revoke(db, user_id="u1", receipt_id=row.receipt_id)

    # Le hook fonctionne à nouveau (p.ex. vault redevenu joignable).
    svc._shred_hook = lambda db_, uid: True
    svc.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")

    pending = [r for r in svc.list_for_user(db, "u1") if r.shred_pending]
    assert pending == []


def test_successful_shred_leaves_no_pending(db, service):
    row = service.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    revoked, cascade = service.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    assert cascade is True
    db.refresh(revoked)
    assert revoked.shred_pending is False


def test_pending_marker_does_not_break_merkle_chain(db):
    """Le marqueur durable vit HORS receipt_json — la chaîne reste vérifiable."""
    from app.services.consent.merkle_chain import verify_chain

    svc = _failing_service()
    row = svc.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    svc.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    ok, err = verify_chain(db, "u1")
    assert ok, f"chaîne cassée: {err}"


def test_pending_superseded_by_reconsent_never_shreds(db):
    """P0 review Codex : re-consent -> marqueur effacé SANS shred (le DEK
    re-créé porte des données légitimes)."""
    svc = _failing_service()
    row = svc.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    svc.revoke(db, user_id="u1", receipt_id=row.receipt_id)

    # Re-consent : la base légale du stockage est renouvelée. (Le retry
    # pré-grant qui tourne ICI est légitime : le nouveau consentement — et
    # donc tout nouveau DEK — n'existe pas encore.)
    svc.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    calls_after_regrant = list(svc._shred_calls)  # type: ignore[attr-defined]

    # Toute interaction ultérieure ne doit JAMAIS re-tenter le shred : ce
    # serait la destruction du DEK (et des données) re-créés.
    svc.grant(db, user_id="u1", purpose="vision_extraction", policy_version="v2.3.0")
    svc.grant(db, user_id="u1", purpose="couple_projection", policy_version="v2.3.0")

    pending = [r for r in svc.list_for_user(db, "u1") if r.shred_pending]
    assert pending == []
    assert svc._shred_calls == calls_after_regrant  # type: ignore[attr-defined]


def test_no_dek_counts_as_satisfied_not_pending(db):
    """P0 review Codex : absence de DEK = déjà vide = obligation satisfaite.

    Chemin RÉEL (sans stub) : crypto_shred_user renvoie False faute de ligne
    DEKVault — cela ne doit PAS créer de marqueur pending.
    """
    svc = ConsentService()  # vrai _shred, pas de hook
    row = svc.grant(db, user_id="u9", purpose="persistence_365d", policy_version="v2.3.0")
    revoked, cascade = svc.revoke(db, user_id="u9", receipt_id=row.receipt_id)
    assert cascade is True
    db.expire_all()
    fresh = [r for r in svc.list_for_user(db, "u9") if r.receipt_id == row.receipt_id]
    assert fresh[0].shred_pending is False


def test_pending_marker_committed_atomically_with_revocation(db):
    """P1 review Codex : le marqueur est posé dans la MÊME transaction que la
    révocation — visible après expiration du cache de session."""
    svc = _failing_service()
    row = svc.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    svc.revoke(db, user_id="u1", receipt_id=row.receipt_id)
    db.expire_all()
    fresh = [r for r in svc.list_for_user(db, "u1") if r.receipt_id == row.receipt_id]
    assert fresh[0].revoked_at is not None
    assert fresh[0].shred_pending is True


def test_sweep_once_satisfies_pending(db, monkeypatch):
    """Le sweep périodique borne le délai promis (P1 review Codex)."""
    from app.services.consent import shred_sweep

    svc = _failing_service()
    row = svc.grant(db, user_id="u1", purpose="persistence_365d", policy_version="v2.3.0")
    svc.revoke(db, user_id="u1", receipt_id=row.receipt_id)

    # Le sweep utilise sa propre session/service : on le pointe sur notre db
    # et sur un service dont le shred réussit désormais.
    monkeypatch.setattr(shred_sweep, "sweep_once", shred_sweep.sweep_once)
    ok_svc = ConsentService(shred_hook=lambda d, u: True)
    n = ok_svc.retry_pending_shreds(db, "u1")
    assert n == 1
    pending = [r for r in ok_svc.list_for_user(db, "u1") if r.shred_pending]
    assert pending == []
