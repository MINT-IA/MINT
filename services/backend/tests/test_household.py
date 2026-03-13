"""
Tests for household management endpoints (Couple+ billing, P6.4 + P6.5).
"""

from datetime import datetime, timedelta

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.core.config import settings
from app.main import app


def _auth_client(client: TestClient):
    """Client without auth override -- for testing real JWT flow."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    return client


def _register_and_token(client: TestClient, email: str) -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "billingpass123"},
    )
    assert response.status_code == 201
    return response.json()["access_token"]


def _get_user_id(client: TestClient, token: str) -> str:
    me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me.status_code == 200
    return me.json()["id"]


def _activate_couple_plus(client: TestClient, token: str):
    """Activate couple_plus subscription for testing."""
    return client.post(
        "/api/v1/billing/debug/activate",
        headers={"Authorization": f"Bearer {token}"},
        json={"tier": "couple_plus", "status": "active", "is_trial": False, "period_days": 30},
    )


def _setup_household_with_invite(client: TestClient):
    """
    Helper: register owner + partner, activate couple_plus, create household, invite partner.
    Returns (owner_token, partner_token, owner_id, partner_id, invitation_code).
    """
    owner_token = _register_and_token(client, "hh-owner@example.com")
    partner_token = _register_and_token(client, "hh-partner@example.com")
    owner_id = _get_user_id(client, owner_token)
    partner_id = _get_user_id(client, partner_token)

    # Activate couple_plus for owner
    activate = _activate_couple_plus(client, owner_token)
    assert activate.status_code == 200

    # Create household (via billing service -- households are auto-created)
    from tests.conftest import TestingSessionLocal
    from app.models.user import User
    from app.services.household_service import create_household_for_billing_owner

    db = TestingSessionLocal()
    try:
        owner_user = db.query(User).filter(User.id == owner_id).first()
        create_household_for_billing_owner(db, owner_user)
    finally:
        db.close()

    # Invite partner
    invite_resp = client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "hh-partner@example.com"},
    )
    assert invite_resp.status_code == 201
    code = invite_resp.json()["invitation_code"]

    return owner_token, partner_token, owner_id, partner_id, code


# ---------------------------------------------------------------------------
# E1: Get household (empty for new user)
# ---------------------------------------------------------------------------
def test_e1_get_household_empty(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "hh-empty@example.com")

    resp = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["household"] is None
    assert body["members"] == []
    assert body["role"] is None


# ---------------------------------------------------------------------------
# E2: Create household + invite partner (owner must have couple_plus)
# ---------------------------------------------------------------------------
def test_e2_create_household_and_invite(client: TestClient):
    auth_client = _auth_client(client)
    owner_token = _register_and_token(auth_client, "hh-e2-owner@example.com")
    _register_and_token(auth_client, "hh-e2-partner@example.com")
    owner_id = _get_user_id(auth_client, owner_token)

    # Activate couple_plus
    _activate_couple_plus(auth_client, owner_token)

    # Create household
    from tests.conftest import TestingSessionLocal
    from app.models.user import User
    from app.services.household_service import create_household_for_billing_owner

    db = TestingSessionLocal()
    try:
        owner_user = db.query(User).filter(User.id == owner_id).first()
        create_household_for_billing_owner(db, owner_user)
    finally:
        db.close()

    # Verify household exists
    get_resp = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert get_resp.status_code == 200
    body = get_resp.json()
    assert body["household"] is not None
    assert body["role"] == "owner"
    assert len(body["members"]) == 1

    # Invite partner
    invite_resp = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "hh-e2-partner@example.com"},
    )
    assert invite_resp.status_code == 201
    invite_body = invite_resp.json()
    assert "invitation_code" in invite_body
    assert invite_body["partner_email"] == "hh-e2-partner@example.com"
    assert "expires_at" in invite_body


# ---------------------------------------------------------------------------
# E3: Accept invitation -> entitlements propagated
# ---------------------------------------------------------------------------
def test_e3_accept_invitation_propagates_entitlements(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Accept invitation
    accept_resp = auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )
    assert accept_resp.status_code == 200
    assert accept_resp.json()["status"] == "accepted"

    # Verify partner has entitlements from household
    entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert entitlements.status_code == 200
    body = entitlements.json()
    # Partner should inherit couple_plus features via household
    assert "dashboard" in body["features"]

    # Verify household shows both members
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert hh.status_code == 200
    members = hh.json()["members"]
    active_members = [m for m in members if m["status"] == "active"]
    assert len(active_members) == 2


# ---------------------------------------------------------------------------
# E4: Invite without couple_plus -> 403
# ---------------------------------------------------------------------------
def test_e4_invite_without_couple_plus(client: TestClient):
    auth_client = _auth_client(client)
    owner_token = _register_and_token(auth_client, "hh-e4-owner@example.com")
    _register_and_token(auth_client, "hh-e4-partner@example.com")
    owner_id = _get_user_id(auth_client, owner_token)

    # Create household but with premium (not couple_plus)
    auth_client.post(
        "/api/v1/billing/debug/activate",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"tier": "premium", "status": "active", "is_trial": False, "period_days": 30},
    )

    from tests.conftest import TestingSessionLocal
    from app.models.user import User
    from app.services.household_service import create_household_for_billing_owner

    db = TestingSessionLocal()
    try:
        owner_user = db.query(User).filter(User.id == owner_id).first()
        create_household_for_billing_owner(db, owner_user)
    finally:
        db.close()

    invite_resp = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "hh-e4-partner@example.com"},
    )
    assert invite_resp.status_code == 403


# ---------------------------------------------------------------------------
# E5: Self-invite -> 400
# ---------------------------------------------------------------------------
def test_e5_self_invite(client: TestClient):
    auth_client = _auth_client(client)
    owner_token = _register_and_token(auth_client, "hh-e5-owner@example.com")
    owner_id = _get_user_id(auth_client, owner_token)

    _activate_couple_plus(auth_client, owner_token)

    from tests.conftest import TestingSessionLocal
    from app.models.user import User
    from app.services.household_service import create_household_for_billing_owner

    db = TestingSessionLocal()
    try:
        owner_user = db.query(User).filter(User.id == owner_id).first()
        create_household_for_billing_owner(db, owner_user)
    finally:
        db.close()

    invite_resp = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "hh-e5-owner@example.com"},
    )
    assert invite_resp.status_code == 400
    assert "toi-meme" in invite_resp.json()["detail"]


# ---------------------------------------------------------------------------
# E6: Revoke partner -> partner loses entitlements
# ---------------------------------------------------------------------------
def test_e6_revoke_partner_loses_entitlements(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Accept invitation first
    auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )

    # Revoke partner
    revoke_resp = auth_client.delete(
        f"/api/v1/household/member/{partner_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert revoke_resp.status_code == 200
    assert revoke_resp.json()["status"] == "revoked"

    # Partner should lose features
    entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert entitlements.status_code == 200
    body = entitlements.json()
    assert body["tier"] == "free"
    assert body["features"] == []


# ---------------------------------------------------------------------------
# E7: Transfer ownership
# ---------------------------------------------------------------------------
def test_e7_transfer_ownership(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Accept invitation first
    auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )

    # Transfer ownership
    transfer_resp = auth_client.put(
        "/api/v1/household/transfer",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"new_owner_id": partner_id},
    )
    assert transfer_resp.status_code == 200
    body = transfer_resp.json()
    assert body["status"] == "transferred"
    assert body["new_owner_id"] == partner_id

    # Verify the partner is now the owner
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert hh.status_code == 200
    assert hh.json()["role"] == "owner"


# ---------------------------------------------------------------------------
# E8: Accept expired invitation -> 410
# ---------------------------------------------------------------------------
def test_e8_accept_expired_invitation(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Patch the invitation timestamp to be old
    from tests.conftest import TestingSessionLocal
    from app.models.household import HouseholdMemberModel

    db = TestingSessionLocal()
    try:
        member = db.query(HouseholdMemberModel).filter(
            HouseholdMemberModel.invitation_code == code
        ).first()
        member.invited_at = datetime.utcnow() - timedelta(hours=73)
        db.commit()
    finally:
        db.close()

    accept_resp = auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )
    assert accept_resp.status_code == 410
    assert "expire" in accept_resp.json()["detail"]


# ---------------------------------------------------------------------------
# E9: Accept on full household -> 409
# ---------------------------------------------------------------------------
def test_e9_accept_on_full_household(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Accept the invitation (household now full: owner + partner = 2)
    auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )

    # Create a third user
    _register_and_token(auth_client, "hh-third@example.com")

    # Try to invite third user (should fail: household at max)
    invite_resp = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "hh-third@example.com"},
    )
    assert invite_resp.status_code == 409


# ---------------------------------------------------------------------------
# A1: Invitation expiry check (72h)
# ---------------------------------------------------------------------------
def test_a1_invitation_expiry_72h(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Patch the invitation to be exactly at 72h boundary
    from tests.conftest import TestingSessionLocal
    from app.models.household import HouseholdMemberModel

    db = TestingSessionLocal()
    try:
        member = db.query(HouseholdMemberModel).filter(
            HouseholdMemberModel.invitation_code == code
        ).first()
        # Set to just under 72h -- should still work
        member.invited_at = datetime.utcnow() - timedelta(hours=71, minutes=59)
        db.commit()
    finally:
        db.close()

    accept_resp = auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )
    assert accept_resp.status_code == 200
    assert accept_resp.json()["status"] == "accepted"


# ---------------------------------------------------------------------------
# A2: Accept expired code -> 410
# ---------------------------------------------------------------------------
def test_a2_accept_expired_code(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    from tests.conftest import TestingSessionLocal
    from app.models.household import HouseholdMemberModel

    db = TestingSessionLocal()
    try:
        member = db.query(HouseholdMemberModel).filter(
            HouseholdMemberModel.invitation_code == code
        ).first()
        member.invited_at = datetime.utcnow() - timedelta(hours=100)
        db.commit()
    finally:
        db.close()

    accept_resp = auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )
    assert accept_resp.status_code == 410


# ---------------------------------------------------------------------------
# A3: Accept on full household -> 409
# (Same scenario as E9, with an active code for a second partner)
# ---------------------------------------------------------------------------
def test_a3_accept_on_full_household_direct(client: TestClient):
    auth_client = _auth_client(client)
    owner_token = _register_and_token(auth_client, "hh-a3-owner@example.com")
    partner1_token = _register_and_token(auth_client, "hh-a3-p1@example.com")
    partner2_token = _register_and_token(auth_client, "hh-a3-p2@example.com")
    owner_id = _get_user_id(auth_client, owner_token)
    partner2_id = _get_user_id(auth_client, partner2_token)

    _activate_couple_plus(auth_client, owner_token)

    from tests.conftest import TestingSessionLocal
    from app.models.user import User
    from app.services.household_service import create_household_for_billing_owner

    db = TestingSessionLocal()
    try:
        owner_user = db.query(User).filter(User.id == owner_id).first()
        create_household_for_billing_owner(db, owner_user)
    finally:
        db.close()

    # Invite and accept partner1
    inv1 = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "hh-a3-p1@example.com"},
    )
    assert inv1.status_code == 201
    auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner1_token}"},
        json={"invitation_code": inv1.json()["invitation_code"]},
    )

    # Household is full (owner + partner1 = 2 active)
    # Manually create a pending membership for partner2 (bypassing invite checks)
    from app.models.household import HouseholdMemberModel, HouseholdModel
    import secrets

    db = TestingSessionLocal()
    try:
        hh = db.query(HouseholdModel).filter(
            HouseholdModel.household_owner_user_id == owner_id
        ).first()
        code2 = secrets.token_urlsafe(32)
        m2 = HouseholdMemberModel(
            household_id=hh.id,
            user_id=partner2_id,
            role="partner",
            status="pending",
            invitation_code=code2,
        )
        db.add(m2)
        db.commit()
    finally:
        db.close()

    # Try to accept -- should fail with 409
    accept_resp = auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner2_token}"},
        json={"invitation_code": code2},
    )
    assert accept_resp.status_code == 409


# ---------------------------------------------------------------------------
# Admin override cooldown
# ---------------------------------------------------------------------------
def test_admin_override_cooldown(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Accept invitation
    auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )

    # Revoke partner
    auth_client.delete(
        f"/api/v1/household/member/{partner_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )

    # Register an admin user
    admin_token = _register_and_token(auth_client, "admin@mint.ch")

    # Set admin allowlist
    prev = settings.AUTH_ADMIN_EMAIL_ALLOWLIST
    settings.AUTH_ADMIN_EMAIL_ALLOWLIST = "admin@mint.ch"
    try:
        override_resp = auth_client.post(
            "/api/v1/household/admin/override-cooldown",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "user_id": partner_id,
                "reason": "Erreur operationnelle lors de la revocation du partenaire",
            },
        )
        assert override_resp.status_code == 200
        body = override_resp.json()
        assert body["status"] == "override_applied"
        assert body["target_user_id"] == partner_id
        assert body["overridden_count"] >= 1
    finally:
        settings.AUTH_ADMIN_EMAIL_ALLOWLIST = prev


# ---------------------------------------------------------------------------
# Admin override without admin role -> 403
# ---------------------------------------------------------------------------
def test_admin_override_without_admin_role(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "hh-nonadmin@example.com")

    prev = settings.AUTH_ADMIN_EMAIL_ALLOWLIST
    settings.AUTH_ADMIN_EMAIL_ALLOWLIST = "admin@mint.ch"
    try:
        resp = auth_client.post(
            "/api/v1/household/admin/override-cooldown",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "user_id": "some-user-id",
                "reason": "Raison tres longue pour le test d'override",
            },
        )
        assert resp.status_code == 403
        assert "support_admin" in resp.json()["detail"]
    finally:
        settings.AUTH_ADMIN_EMAIL_ALLOWLIST = prev


# ---------------------------------------------------------------------------
# Feature flags endpoint
# ---------------------------------------------------------------------------
def test_feature_flags_endpoint(client: TestClient):
    resp = client.get("/api/v1/config/feature-flags")
    assert resp.status_code == 200
    body = resp.json()
    assert "enableCouplePlusTier" in body
    assert "enableSlmNarratives" in body
    assert "enableDecisionScaffold" in body
    assert "valeurLocative2028Reform" in body
    assert "safeModeDegraded" in body


# ---------------------------------------------------------------------------
# Accept invalid code -> 404
# ---------------------------------------------------------------------------
def test_accept_invalid_code(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "hh-badcode@example.com")

    resp = auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {token}"},
        json={"invitation_code": "nonexistent-code-12345"},
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# Invite nonexistent user -> 404
# ---------------------------------------------------------------------------
def test_invite_nonexistent_user(client: TestClient):
    auth_client = _auth_client(client)
    owner_token = _register_and_token(auth_client, "hh-inv-ne-owner@example.com")
    owner_id = _get_user_id(auth_client, owner_token)

    _activate_couple_plus(auth_client, owner_token)

    from tests.conftest import TestingSessionLocal
    from app.models.user import User
    from app.services.household_service import create_household_for_billing_owner

    db = TestingSessionLocal()
    try:
        owner_user = db.query(User).filter(User.id == owner_id).first()
        create_household_for_billing_owner(db, owner_user)
    finally:
        db.close()

    resp = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "does-not-exist@example.com"},
    )
    assert resp.status_code == 404
    assert "Aucun compte" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# Revoke idempotent (already revoked -> returns already_revoked)
# ---------------------------------------------------------------------------
def test_revoke_idempotent(client: TestClient):
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household_with_invite(auth_client)

    # Accept
    auth_client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )

    # First revoke
    first = auth_client.delete(
        f"/api/v1/household/member/{partner_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert first.status_code == 200
    assert first.json()["status"] == "revoked"

    # Second revoke (idempotent)
    second = auth_client.delete(
        f"/api/v1/household/member/{partner_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert second.status_code == 200
    assert second.json()["status"] == "already_revoked"


# ---------------------------------------------------------------------------
# Admin override cooldown with short reason -> 400
# ---------------------------------------------------------------------------
def test_admin_override_short_reason(client: TestClient):
    auth_client = _auth_client(client)
    admin_token = _register_and_token(auth_client, "admin-short@mint.ch")

    prev = settings.AUTH_ADMIN_EMAIL_ALLOWLIST
    settings.AUTH_ADMIN_EMAIL_ALLOWLIST = "admin-short@mint.ch"
    try:
        resp = auth_client.post(
            "/api/v1/household/admin/override-cooldown",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "user_id": "some-user",
                "reason": "short",
            },
        )
        assert resp.status_code == 400
        assert "10 caracteres" in resp.json()["detail"]
    finally:
        settings.AUTH_ADMIN_EMAIL_ALLOWLIST = prev
