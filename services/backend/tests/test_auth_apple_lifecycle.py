"""P0 — Apple account lifecycle: complete deletion + clean reconnection.

Covers the device dead-end (2026-08-03): after deleting an Apple account, a
same-e-mail account (magic link / password) permanently locked the user out —
login short-circuited on the delete tombstone (`recreate_required`) and
register always refused to link (`apple_email_already_linked`). Because
`users.email` is UNIQUE, a "fresh" account with that e-mail is impossible, so
reclaiming the existing account via a verified Apple e-mail is the only clean
recovery.

Also covers nLPD completeness: account deletion must purge every user-scoped
PII table and must not retain plaintext PII in the audit tombstone.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.api.v1.endpoints import auth as auth_endpoint
from app.core.auth import get_current_user, require_current_user
from app.main import app
from app.models.audit_event import AuditEventModel
from app.models.user import User
from app.services.audit.hmac_pepper import hmac_user_id
from tests.conftest import TestingSessionLocal


def _clear_overrides() -> None:
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)


def _patch_apple(monkeypatch, payloads):
    def fake_verify(identity_token, nonce):
        return payloads[identity_token]

    monkeypatch.setattr(auth_endpoint, "_verify_apple_identity_token", fake_verify)


# ---------------------------------------------------------------------------
# AUTH — reconnection after delete must not dead-end
# ---------------------------------------------------------------------------


def test_apple_register_relinks_verified_same_email_account_after_delete(
    client: TestClient, monkeypatch
):
    """THE fix. Apple account deleted, a same-e-mail account then exists
    (magic link). The register/recreate path with a VERIFIED Apple e-mail must
    reclaim that account instead of dead-ending on apple_email_already_linked."""
    _clear_overrides()
    email = "julien.reclaim@example.ch"
    sub = "001999.reclaim-apple-sub"
    _patch_apple(
        monkeypatch,
        {"apple": {"sub": sub, "email": email, "email_verified": True}},
    )

    # 1. Apple register + 2. delete
    r = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "apple", "nonce": "n", "allowRecreateAfterDelete": True},
    )
    assert r.status_code == 200
    token = r.json()["accessToken"]
    assert client.delete(
        "/api/v1/auth/account", headers={"Authorization": f"Bearer {token}"}
    ).status_code == 200

    # 3. Same-e-mail account is created (magic link — frictionless auto-create)
    from app.services.magic_link_service import MagicLinkService

    db = TestingSessionLocal()
    try:
        ml_token = MagicLinkService(db).generate_token(email)
    finally:
        db.close()
    assert client.post(
        "/api/v1/auth/magic-link/verify", json={"token": ml_token}
    ).status_code == 200

    # 4. Apple REGISTER path now RECLAIMS the verified-owned account (200).
    reclaimed = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "apple", "nonce": "n", "allowRecreateAfterDelete": True},
    )
    assert reclaimed.status_code == 200, reclaimed.json()
    assert reclaimed.json()["email"] == email

    # The account is now Apple-linked, and a subsequent LOGIN works cleanly.
    db = TestingSessionLocal()
    try:
        owner = db.query(User).filter(User.email == email).one()
        assert owner.apple_sub == sub
        assert reclaimed.json()["userId"] == owner.id
    finally:
        db.close()

    login = client.post(
        "/api/v1/auth/apple/verify", json={"identity_token": "apple", "nonce": "n"}
    )
    assert login.status_code == 200
    assert login.json()["userId"] == reclaimed.json()["userId"]


def test_apple_register_still_blocks_unverified_same_email_after_delete(
    client: TestClient, monkeypatch
):
    """Takeover hardening (T11-F01) preserved: an UNVERIFIED Apple e-mail must
    still never attach to a pre-existing account, even on the recreate path."""
    _clear_overrides()
    email = "unverified-reclaim@example.ch"
    sub = "001999.unverified-reclaim-sub"
    # No email_verified claim -> Apple does not attest the e-mail.
    _patch_apple(monkeypatch, {"apple": {"sub": sub, "email": email}})

    r = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "apple", "nonce": "n", "allowRecreateAfterDelete": True},
    )
    assert r.status_code == 200
    token = r.json()["accessToken"]
    client.delete("/api/v1/auth/account", headers={"Authorization": f"Bearer {token}"})

    # Same-e-mail password account exists.
    assert client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "correct horse battery staple"},
    ).status_code == 201

    blocked = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "apple", "nonce": "n", "allowRecreateAfterDelete": True},
    )
    assert blocked.status_code == 409
    assert blocked.json()["detail"]["code"] == "apple_email_already_linked"

    db = TestingSessionLocal()
    try:
        victim = db.query(User).filter(User.email == email).one()
        assert victim.apple_sub is None
    finally:
        db.close()


def test_full_cycle_register_delete_reregister_delete_reregister(
    client: TestClient, monkeypatch
):
    """Task's explicit cycle: register->delete->re-register->delete->re-register
    must stay green for a single Apple identity with no colliding account."""
    _clear_overrides()
    _patch_apple(
        monkeypatch,
        {"t": {"sub": "001999.cycle-sub", "email": "cycle@example.ch", "email_verified": True}},
    )
    last_user_ids = set()
    for _ in range(3):
        r = client.post(
            "/api/v1/auth/apple/verify",
            json={"identity_token": "t", "nonce": "n", "allowRecreateAfterDelete": True},
        )
        assert r.status_code == 200, r.json()
        last_user_ids.add(r.json()["userId"])
        token = r.json()["accessToken"]
        assert client.delete(
            "/api/v1/auth/account", headers={"Authorization": f"Bearer {token}"}
        ).status_code == 200
    # Each recreate is a genuinely fresh account row.
    assert len(last_user_ids) == 3


# ---------------------------------------------------------------------------
# nLPD — deletion must purge every user-scoped PII table
# ---------------------------------------------------------------------------


def _count_mutable_pii(user_id: str, email: str) -> dict[str, int]:
    from app.models.coach_insight import CoachInsightRecord
    from app.models.magic_link_token import MagicLinkTokenModel

    db = TestingSessionLocal()
    try:
        return {
            "coach_insights": db.query(CoachInsightRecord)
            .filter(CoachInsightRecord.user_id == user_id)
            .count(),
            "magic_link_tokens": db.query(MagicLinkTokenModel)
            .filter(MagicLinkTokenModel.email == email.lower())
            .count(),
        }
    finally:
        db.close()


def test_delete_physically_purges_mutable_pii(client: TestClient, monkeypatch):
    """nLPD art. 6/32: deletion must physically purge mutable user-scoped PII
    (coach memory, resurrection tokens), not just profiles/documents."""
    _clear_overrides()
    email = "purge-me@example.ch"
    _patch_apple(
        monkeypatch,
        {"t": {"sub": "001999.purge-sub", "email": email, "email_verified": True}},
    )
    r = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "t", "nonce": "n", "allowRecreateAfterDelete": True},
    )
    user_id = r.json()["userId"]
    token = r.json()["accessToken"]

    from app.models.coach_insight import CoachInsightRecord
    from app.models.magic_link_token import MagicLinkTokenModel

    db = TestingSessionLocal()
    try:
        db.add(CoachInsightRecord(user_id=user_id, topic="revenu", summary="~120k CHF/an"))
        db.add(
            MagicLinkTokenModel(
                id="mlt-" + user_id[:8],
                email=email.lower(),
                token_hash="h" * 64,
                expires_at=datetime.now(timezone.utc),
                used=False,
            )
        )
        db.commit()
    finally:
        db.close()

    assert all(v >= 1 for v in _count_mutable_pii(user_id, email).values())

    assert client.delete(
        "/api/v1/auth/account", headers={"Authorization": f"Bearer {token}"}
    ).status_code == 200

    after = _count_mutable_pii(user_id, email)
    assert after == {"coach_insights": 0, "magic_link_tokens": 0}, after


def test_delete_crypto_shreds_dek_for_append_only_data(client: TestClient, monkeypatch):
    """Append-only tables (fact_event, money_truth_receipts) REVOKE DELETE, so a
    literal purge would fail in production and leave data behind. Erasure is by
    crypto-shredding: destroying the user's DEK makes every DEK-encrypted value
    (incl. fact_event.value_enc) irrecoverable. This test proves the DEK is
    destroyed on deletion, and that the append-only receipt row is NOT falsely
    reported as row-deleted."""
    _clear_overrides()
    email = "shred-me@example.ch"
    _patch_apple(
        monkeypatch,
        {"t": {"sub": "001999.shred-sub", "email": email, "email_verified": True}},
    )
    r = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "t", "nonce": "n", "allowRecreateAfterDelete": True},
    )
    user_id = r.json()["userId"]
    token = r.json()["accessToken"]

    from app.services.encryption.key_vault import key_vault, DEKRevokedError
    from app.services.encryption.encrypted_value_helper import encrypt_value
    from app.models.fact_event import FactEvent
    from app.models.money_truth_receipt_record import MoneyTruthReceiptRecord

    # Seed a DEK + a DEK-encrypted append-only fact event + a receipt.
    db = TestingSessionLocal()
    try:
        key_vault.reset()
        key_vault.get_or_create_dek(db, user_id)
        enc = encrypt_value(db, user_id, {"amount": 120000})
        db.add(
            FactEvent(
                event_id="evt-" + user_id[:8],
                user_id=user_id,
                field_key="incomeNetYearly",
                value_enc=enc,
                valid_from=datetime.now(timezone.utc),
                source="test",
            )
        )
        db.add(
            MoneyTruthReceiptRecord(
                owner_scope_hash=hmac_user_id(user_id),
                owner_kind="user",
                receipt_id="r" * 8,
                inputs_hash="i" * 8,
                claim_id="c" * 8,
                receipt_body='{"income": 120000}',
                output_hash="o" * 8,
            )
        )
        db.commit()
    finally:
        db.close()

    # DEK resolvable before deletion.
    db = TestingSessionLocal()
    try:
        assert key_vault.get_dek(db, user_id)
    finally:
        db.close()

    assert client.delete(
        "/api/v1/auth/account", headers={"Authorization": f"Bearer {token}"}
    ).status_code == 200

    key_vault.reset()  # drop the in-process cache to force a DB read
    db = TestingSessionLocal()
    try:
        # Crypto-shred proven: the DEK is gone -> encrypted values irrecoverable.
        import pytest as _pytest

        with _pytest.raises(DEKRevokedError):
            key_vault.get_dek(db, user_id)

        # Append-only receipt is NOT row-deleted (REVOKE DELETE) — retained,
        # pseudonymised by HMAC(user_id). We do not pretend to have deleted it.
        assert (
            db.query(MoneyTruthReceiptRecord)
            .filter(MoneyTruthReceiptRecord.owner_scope_hash == hmac_user_id(user_id))
            .count()
            == 1
        )
    finally:
        db.close()


def test_delete_redacts_audit_pii_but_keeps_tombstone(client: TestClient, monkeypatch):
    """nLPD: after deletion no plaintext PII (actor_email / user_id) may remain
    in the audit trail, yet the hashed anti-resurrection tombstone must survive
    so a deleted Apple sub still cannot silently re-create a session."""
    _clear_overrides()
    email = "audit-redact@example.ch"
    sub = "001999.audit-redact-sub"
    _patch_apple(monkeypatch, {"t": {"sub": sub, "email": email, "email_verified": True}})
    r = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "t", "nonce": "n", "allowRecreateAfterDelete": True},
    )
    user_id = r.json()["userId"]
    token = r.json()["accessToken"]
    assert client.delete(
        "/api/v1/auth/account", headers={"Authorization": f"Bearer {token}"}
    ).status_code == 200

    db = TestingSessionLocal()
    try:
        rows = db.query(AuditEventModel).filter(
            (AuditEventModel.user_id == user_id)
            | (AuditEventModel.actor_email == email)
        ).all()
        assert rows == [], "plaintext PII leaked in audit_events after deletion"

        tombstone = (
            db.query(AuditEventModel)
            .filter(
                AuditEventModel.event_type == "auth.account_delete",
                AuditEventModel.status == "success",
            )
            .one()
        )
        # Hashed linkage retained (forensics) but no plaintext.
        assert tombstone.user_id is None
        assert tombstone.actor_email is None
        assert tombstone.user_id_hash  # pepper-hash kept
        details = json.loads(tombstone.details_json or "{}")
        assert "apple" in details["deleted_provider_subject_hashes"]
    finally:
        db.close()

    # Anti-resurrection still enforced: login for the deleted sub -> recreate_required.
    login = client.post("/api/v1/auth/apple/verify", json={"identity_token": "t", "nonce": "n"})
    assert login.status_code == 409
    assert login.json()["detail"]["code"] == "recreate_required"
