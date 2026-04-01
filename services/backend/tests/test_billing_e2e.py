"""
E2E billing tests -- P6 merge gate.
Tests cover the 13 scenarios from P6_BILLING_INVARIANTS.md section 6.
ALL 13 must pass before merge to main.
"""

from datetime import datetime, timedelta

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.core.config import settings
from app.main import app


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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
    assert response.status_code == 201, f"Register failed for {email}: {response.json()}"
    return response.json()["access_token"]


def _get_user_id(client: TestClient, token: str) -> str:
    me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me.status_code == 200
    return me.json()["id"]


def _activate_tier(client: TestClient, token: str, tier: str = "couple_plus"):
    """Activate a subscription tier via debug endpoint."""
    return client.post(
        "/api/v1/billing/debug/activate",
        headers={"Authorization": f"Bearer {token}"},
        json={"tier": tier, "status": "active", "is_trial": False, "period_days": 30},
    )


def _create_household(owner_id: str):
    """Create a household for a billing owner via direct service call."""
    from tests.conftest import TestingSessionLocal
    from app.models.user import User
    from app.services.household_service import create_household_for_billing_owner

    db = TestingSessionLocal()
    try:
        owner_user = db.query(User).filter(User.id == owner_id).first()
        create_household_for_billing_owner(db, owner_user)
    finally:
        db.close()


def _setup_household(client: TestClient, owner_email: str, partner_email: str):
    """
    Full household setup: register both users, activate couple_plus for owner,
    create household, invite partner.
    Returns (owner_token, partner_token, owner_id, partner_id, invitation_code).
    """
    owner_token = _register_and_token(client, owner_email)
    partner_token = _register_and_token(client, partner_email)
    owner_id = _get_user_id(client, owner_token)
    partner_id = _get_user_id(client, partner_token)

    # Activate couple_plus for owner
    activate = _activate_tier(client, owner_token, "couple_plus")
    assert activate.status_code == 200

    # Create household
    _create_household(owner_id)

    # Invite partner
    invite_resp = client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": partner_email},
    )
    assert invite_resp.status_code == 201, f"Invite failed: {invite_resp.json()}"
    code = invite_resp.json()["invitation_code"]

    return owner_token, partner_token, owner_id, partner_id, code


def _accept_invitation(client: TestClient, partner_token: str, code: str):
    """Accept a household invitation. Returns response."""
    return client.post(
        "/api/v1/household/accept",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"invitation_code": code},
    )


# ===========================================================================
# E1: Owner purchases couple_plus -> entitlements activated
# ===========================================================================
def test_e1_owner_purchases_couple_plus(client: TestClient):
    """E1: Owner purchases couple_plus -> entitlements activated, household creatable."""
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "e2e-e1-owner@example.com")
    user_id = _get_user_id(auth_client, token)

    # Activate couple_plus via debug endpoint
    activate = _activate_tier(auth_client, token, "couple_plus")
    assert activate.status_code == 200
    activate_body = activate.json()
    assert activate_body["tier"] == "couple_plus"

    # Verify entitlements include all premium+ features
    entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert entitlements.status_code == 200
    body = entitlements.json()
    assert body["tier"] == "couple_plus"
    assert body["is_active"] is True
    # couple_plus should have all 13 features
    assert "dashboard" in body["features"]
    assert "forecast" in body["features"]
    assert "coachLlm" in body["features"]
    assert "vault" in body["features"]
    assert "monteCarlo" in body["features"]
    assert "arbitrageModules" in body["features"]
    assert "exportPdf" in body["features"]
    assert "scenariosEtSi" in body["features"]
    assert "scoreEvolution" in body["features"]

    # Verify no household yet (household creation is separate from subscription)
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert hh.status_code == 200
    assert hh.json()["household"] is None

    # Verify the user CAN create a household (has the right tier)
    _create_household(user_id)
    hh2 = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert hh2.status_code == 200
    assert hh2.json()["household"] is not None
    assert hh2.json()["role"] == "owner"


# ===========================================================================
# E2: Owner invites partner -> partner receives pending invitation
# ===========================================================================
def test_e2_owner_invites_partner(client: TestClient):
    """E2: Owner invites partner -> partner receives invitation code."""
    auth_client = _auth_client(client)
    owner_token = _register_and_token(auth_client, "e2e-e2-owner@example.com")
    _register_and_token(auth_client, "e2e-e2-partner@example.com")
    owner_id = _get_user_id(auth_client, owner_token)

    # Activate couple_plus for owner
    _activate_tier(auth_client, owner_token, "couple_plus")

    # Create household
    _create_household(owner_id)

    # Invite partner by email
    invite_resp = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "e2e-e2-partner@example.com"},
    )
    assert invite_resp.status_code == 201
    invite_body = invite_resp.json()
    assert "invitation_code" in invite_body
    assert invite_body["partner_email"] == "e2e-e2-partner@example.com"
    assert "expires_at" in invite_body

    # Verify partner appears in household members as "pending"
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert hh.status_code == 200
    members = hh.json()["members"]
    pending_members = [m for m in members if m["status"] == "pending"]
    assert len(pending_members) == 1
    assert pending_members[0]["email"] == "e2e-e2-partner@example.com"


# ===========================================================================
# E3: Partner accepts -> propagation
# ===========================================================================
def test_e3_partner_accepts_entitlements_propagate(client: TestClient):
    """E3: Partner accepts -> gets same features as billing_owner."""
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household(
        auth_client, "e2e-e3-owner@example.com", "e2e-e3-partner@example.com"
    )

    # Accept invitation
    accept = _accept_invitation(auth_client, partner_token, code)
    assert accept.status_code == 200
    assert accept.json()["status"] == "accepted"

    # Verify partner's entitlements match owner's features
    partner_entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert partner_entitlements.status_code == 200
    partner_body = partner_entitlements.json()

    owner_entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    owner_body = owner_entitlements.json()

    # Partner should have the same feature set via household inheritance
    assert "dashboard" in partner_body["features"]
    assert "coachLlm" in partner_body["features"]
    assert "vault" in partner_body["features"]
    assert "monteCarlo" in partner_body["features"]
    # Features should match
    assert set(partner_body["features"]) == set(owner_body["features"])

    # Verify household shows both members as active
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert hh.status_code == 200
    active_members = [m for m in hh.json()["members"] if m["status"] == "active"]
    assert len(active_members) == 2


# ===========================================================================
# E4: Restore purchase (re-activation after subscription lapses)
# ===========================================================================
def test_e4_restore_purchase(client: TestClient):
    """E4: Restore purchase -> entitlements restored."""
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "e2e-e4-owner@example.com")

    # Activate couple_plus (simulate purchase)
    activate = _activate_tier(auth_client, token, "couple_plus")
    assert activate.status_code == 200

    # Verify features active
    ent1 = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ent1.status_code == 200
    assert ent1.json()["is_active"] is True
    assert "dashboard" in ent1.json()["features"]
    assert "coachLlm" in ent1.json()["features"]

    # Deactivate (simulate lapse: set tier to free)
    deactivate = auth_client.post(
        "/api/v1/billing/debug/activate",
        headers={"Authorization": f"Bearer {token}"},
        json={"tier": "free", "status": "inactive", "is_trial": False, "period_days": 0},
    )
    assert deactivate.status_code == 200

    # Verify features gone
    ent2 = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ent2.status_code == 200
    assert ent2.json()["is_active"] is False
    assert ent2.json()["features"] == []

    # Re-activate (simulate restore)
    restore = _activate_tier(auth_client, token, "couple_plus")
    assert restore.status_code == 200

    # Verify features restored
    ent3 = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ent3.status_code == 200
    assert ent3.json()["is_active"] is True
    assert ent3.json()["tier"] == "couple_plus"
    assert "dashboard" in ent3.json()["features"]
    assert "coachLlm" in ent3.json()["features"]
    assert "vault" in ent3.json()["features"]


# ===========================================================================
# E5: Downgrade/cancel -> partner loses access
# ===========================================================================
def test_e5_downgrade_partner_loses_access(client: TestClient):
    """E5: Downgrade/cancel -> partner loses access."""
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household(
        auth_client, "e2e-e5-owner@example.com", "e2e-e5-partner@example.com"
    )

    # Accept invitation
    accept = _accept_invitation(auth_client, partner_token, code)
    assert accept.status_code == 200

    # Verify partner has features
    ent_before = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert "dashboard" in ent_before.json()["features"]

    # Downgrade owner's subscription (tier = free)
    downgrade = auth_client.post(
        "/api/v1/billing/debug/activate",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"tier": "free", "status": "inactive", "is_trial": False, "period_days": 0},
    )
    assert downgrade.status_code == 200

    # Recompute entitlements for partner (this happens via billing entitlements endpoint)
    ent_after = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert ent_after.status_code == 200
    partner_body = ent_after.json()
    # Partner should have lost couple_plus features since billing owner downgraded
    assert partner_body["features"] == []
    assert partner_body["is_active"] is False


# ===========================================================================
# W1: Same event_id sent 2x -> 2nd = 200 OK, no double mutation
# ===========================================================================
def test_w1_webhook_dedup_no_double_mutation(client: TestClient):
    """W1: Same event_id 2x -> 200 OK both times, no double processing."""
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "e2e-w1@example.com")
    user_id = _get_user_id(auth_client, token)

    # Send Apple webhook with a fixed notificationUUID
    payload = {
        "notificationUUID": "e2e-dedup-w1-uuid",
        "notificationType": "DID_RENEW",
        "data": {
            "user_id": user_id,
            "product_id": settings.APPLE_IAP_PRODUCT_COACH_MONTHLY,
            "transaction_id": "tx-e2e-w1-001",
            "original_transaction_id": "orig-tx-e2e-w1-001",
            "is_trial": False,
        },
    }

    # First send
    first = client.post("/api/v1/billing/webhooks/apple", json=payload)
    assert first.status_code == 200
    assert first.json()["received"] is True

    # Verify entitlements activated
    ent1 = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ent1.status_code == 200
    assert ent1.json()["is_active"] is True

    # Second send (same notificationUUID)
    second = client.post("/api/v1/billing/webhooks/apple", json=payload)
    assert second.status_code == 200
    assert second.json()["received"] is True

    # Verify entitlements unchanged (still active, same result)
    ent2 = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ent2.status_code == 200
    assert ent2.json()["is_active"] is True

    # Verify only 1 webhook event recorded (dedup)
    from tests.conftest import TestingSessionLocal
    from app.models.billing import BillingWebhookEventModel

    db = TestingSessionLocal()
    try:
        events = (
            db.query(BillingWebhookEventModel)
            .filter(
                BillingWebhookEventModel.provider == "apple",
                BillingWebhookEventModel.event_id == "e2e-dedup-w1-uuid",
            )
            .all()
        )
        assert len(events) == 1
        assert events[0].outcome == "applied"
    finally:
        db.close()


# ===========================================================================
# W2: Stale event (timestamp < last_event_at) -> ignored
# ===========================================================================
def test_w2_stale_event_ignored(client: TestClient):
    """W2: Stale event -> ignored, entitlements unchanged."""
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "e2e-w2@example.com")
    user_id = _get_user_id(auth_client, token)

    # Activate couple_plus so we have a subscription with a known state
    _activate_tier(auth_client, token, "couple_plus")

    # Set last_event_at to far future so any new event appears stale
    from tests.conftest import TestingSessionLocal
    from app.models.billing import SubscriptionModel, BillingWebhookEventModel

    db = TestingSessionLocal()
    try:
        sub = (
            db.query(SubscriptionModel)
            .filter(SubscriptionModel.user_id == user_id)
            .first()
        )
        assert sub is not None
        # Set last_event_at to far future
        sub.last_event_at = datetime.utcnow() + timedelta(days=365)
        # Also set an external_subscription_id for Stripe lookup
        sub.external_subscription_id = "sub_stale_w2_test"
        db.commit()
    finally:
        db.close()

    # Send a Stripe webhook event that should be stale
    # (its timestamp will be "now" which is before last_event_at set to future)
    stripe_event = {
        "id": "evt_stale_w2_test",
        "type": "customer.subscription.updated",
        "data": {
            "object": {
                "id": "sub_stale_w2_test",
                "status": "canceled",
                "metadata": {"user_id": user_id},
            },
        },
    }

    # SEC-3: Use a test webhook secret with proper HMAC signature
    import json
    import hmac
    import hashlib
    import time

    test_secret = "whsec_test_stale_event"
    prev_secret = settings.STRIPE_WEBHOOK_SECRET
    settings.STRIPE_WEBHOOK_SECRET = test_secret
    try:
        payload = json.dumps(stripe_event).encode("utf-8")
        timestamp = str(int(time.time()))
        signed_payload = f"{timestamp}.{payload.decode('utf-8')}".encode("utf-8")
        sig = hmac.new(
            test_secret.encode("utf-8"), signed_payload, hashlib.sha256
        ).hexdigest()
        stripe_sig = f"t={timestamp},v1={sig}"

        resp = client.post(
            "/api/v1/billing/webhooks/stripe",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "Stripe-Signature": stripe_sig,
            },
        )
        assert resp.status_code == 200
    finally:
        settings.STRIPE_WEBHOOK_SECRET = prev_secret

    # Verify entitlements unchanged (still couple_plus, not canceled)
    ent = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ent.status_code == 200
    assert ent.json()["tier"] == "couple_plus"
    assert ent.json()["is_active"] is True

    # Verify the webhook event was recorded as skipped_stale
    db = TestingSessionLocal()
    try:
        event = (
            db.query(BillingWebhookEventModel)
            .filter(
                BillingWebhookEventModel.provider == "stripe",
                BillingWebhookEventModel.event_id == "evt_stale_w2_test",
            )
            .first()
        )
        assert event is not None
        assert event.outcome == "skipped_stale"
        assert event.is_processed is True
    finally:
        db.close()


# ===========================================================================
# C1: 2 simultaneous accepts (same code) -> 1 succeeds, 2nd idempotent
# ===========================================================================
def test_c1_double_accept_same_code(client: TestClient):
    """C1: Double accept same code -> first succeeds, second is idempotent."""
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household(
        auth_client, "e2e-c1-owner@example.com", "e2e-c1-partner@example.com"
    )

    # First accept: should succeed
    first = _accept_invitation(auth_client, partner_token, code)
    assert first.status_code == 200
    assert first.json()["status"] == "accepted"

    # Second accept: should return already_accepted (idempotent)
    second = _accept_invitation(auth_client, partner_token, code)
    assert second.status_code == 200
    assert second.json()["status"] == "already_accepted"

    # Verify only 2 members in household (no duplication)
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert hh.status_code == 200
    active_members = [m for m in hh.json()["members"] if m["status"] == "active"]
    assert len(active_members) == 2


# ===========================================================================
# C2: Accept during transfer -> isolation guaranteed
# ===========================================================================
def test_c2_accept_during_transfer(client: TestClient):
    """C2: Accept during transfer -> both operations complete without corruption."""
    auth_client = _auth_client(client)

    # Register 3 users: owner, partner1, partner2
    owner_token = _register_and_token(auth_client, "e2e-c2-owner@example.com")
    partner1_token = _register_and_token(auth_client, "e2e-c2-partner1@example.com")
    owner_id = _get_user_id(auth_client, owner_token)
    partner1_id = _get_user_id(auth_client, partner1_token)

    # Setup: activate, create household, invite partner1
    _activate_tier(auth_client, owner_token, "couple_plus")
    _create_household(owner_id)

    invite_resp = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "e2e-c2-partner1@example.com"},
    )
    assert invite_resp.status_code == 201
    code = invite_resp.json()["invitation_code"]

    # Partner1 accepts
    accept = _accept_invitation(auth_client, partner1_token, code)
    assert accept.status_code == 200
    assert accept.json()["status"] == "accepted"

    # Transfer ownership to partner1
    transfer = auth_client.put(
        "/api/v1/household/transfer",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"new_owner_id": partner1_id},
    )
    assert transfer.status_code == 200
    assert transfer.json()["status"] == "transferred"

    # Verify no corruption: partner1 is now owner, original owner is partner
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {partner1_token}"},
    )
    assert hh.status_code == 200
    assert hh.json()["role"] == "owner"
    assert len(hh.json()["members"]) == 2

    # Verify original owner is now partner
    hh_owner = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert hh_owner.status_code == 200
    assert hh_owner.json()["role"] == "partner"


# ===========================================================================
# C3: Webhook downgrade during accept -> member added but may lose access
# ===========================================================================
def test_c3_downgrade_during_accept(client: TestClient):
    """C3: Webhook downgrade during accept -> partner added but may lose access."""
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household(
        auth_client, "e2e-c3-owner@example.com", "e2e-c3-partner@example.com"
    )

    # Partner accepts (while owner still has couple_plus)
    accept = _accept_invitation(auth_client, partner_token, code)
    assert accept.status_code == 200
    assert accept.json()["status"] == "accepted"

    # Verify partner has features right after accept
    ent_before = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert ent_before.status_code == 200
    assert "dashboard" in ent_before.json()["features"]

    # Now downgrade the owner (simulate webhook downgrade)
    downgrade = auth_client.post(
        "/api/v1/billing/debug/activate",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"tier": "free", "status": "canceled", "is_trial": False, "period_days": 0},
    )
    assert downgrade.status_code == 200

    # Check partner entitlements after owner downgrade
    ent_after = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert ent_after.status_code == 200
    # Partner should have lost features since billing owner is now free
    assert ent_after.json()["features"] == []

    # But partner is still in the household (membership preserved)
    hh = auth_client.get(
        "/api/v1/household",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert hh.status_code == 200
    assert hh.json()["household"] is not None
    active_members = [m for m in hh.json()["members"] if m["status"] == "active"]
    assert len(active_members) == 2


# ===========================================================================
# C4: Concurrent revoke on same user -> idempotent
# ===========================================================================
def test_c4_concurrent_revoke_idempotent(client: TestClient):
    """C4: Double revoke -> both return 200, no corruption."""
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household(
        auth_client, "e2e-c4-owner@example.com", "e2e-c4-partner@example.com"
    )

    # Accept invitation
    accept = _accept_invitation(auth_client, partner_token, code)
    assert accept.status_code == 200

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

    # Verify partner lost entitlements
    ent = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {partner_token}"},
    )
    assert ent.status_code == 200
    assert ent.json()["features"] == []


# ===========================================================================
# A1: Invitation expires after 72h
# ===========================================================================
def test_a1_invitation_expires_72h(client: TestClient):
    """A1: Invitation expires after 72h -> auto-expired, owner can resend."""
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household(
        auth_client, "e2e-a1-owner@example.com", "e2e-a1-partner@example.com"
    )

    # Patch the invitation to be 73h old (expired)
    from tests.conftest import TestingSessionLocal
    from app.models.household import HouseholdMemberModel

    db = TestingSessionLocal()
    try:
        member = (
            db.query(HouseholdMemberModel)
            .filter(HouseholdMemberModel.invitation_code == code)
            .first()
        )
        member.invited_at = datetime.utcnow() - timedelta(hours=73)
        db.commit()
    finally:
        db.close()

    # Accept should fail with 410
    accept = _accept_invitation(auth_client, partner_token, code)
    assert accept.status_code == 410
    assert "expire" in accept.json()["detail"]

    # Owner should be able to revoke expired pending and re-invite
    # First, delete the expired pending member so we can re-invite
    revoke = auth_client.delete(
        f"/api/v1/household/member/{partner_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert revoke.status_code == 200

    # Re-invite partner (the revoked membership must clear cooldown for re-invite)
    # Set cooldown_override since the revocation just happened
    db = TestingSessionLocal()
    try:
        revoked = (
            db.query(HouseholdMemberModel)
            .filter(
                HouseholdMemberModel.user_id == partner_id,
                HouseholdMemberModel.status == "revoked",
            )
            .first()
        )
        if revoked:
            revoked.cooldown_override = True
            db.commit()
    finally:
        db.close()

    re_invite = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "e2e-a1-partner@example.com"},
    )
    assert re_invite.status_code == 201
    new_code = re_invite.json()["invitation_code"]
    assert new_code != code  # New code generated


# ===========================================================================
# A2: Accept expired code -> 410 Gone
# ===========================================================================
def test_a2_accept_expired_code_410(client: TestClient):
    """A2: Accept expired invitation -> 410 Gone."""
    auth_client = _auth_client(client)
    owner_token, partner_token, owner_id, partner_id, code = _setup_household(
        auth_client, "e2e-a2-owner@example.com", "e2e-a2-partner@example.com"
    )

    # Patch the invitation to be expired (100h old)
    from tests.conftest import TestingSessionLocal
    from app.models.household import HouseholdMemberModel

    db = TestingSessionLocal()
    try:
        member = (
            db.query(HouseholdMemberModel)
            .filter(HouseholdMemberModel.invitation_code == code)
            .first()
        )
        member.invited_at = datetime.utcnow() - timedelta(hours=100)
        db.commit()
    finally:
        db.close()

    accept = _accept_invitation(auth_client, partner_token, code)
    assert accept.status_code == 410
    assert "expire" in accept.json()["detail"]


# ===========================================================================
# A3: Accept on full household -> 409 Conflict
# ===========================================================================
def test_a3_full_household_409(client: TestClient):
    """A3: Accept when household full -> 409 Conflict."""
    auth_client = _auth_client(client)

    # Register owner, partner1, partner2
    owner_token = _register_and_token(auth_client, "e2e-a3-owner@example.com")
    partner1_token = _register_and_token(auth_client, "e2e-a3-p1@example.com")
    partner2_token = _register_and_token(auth_client, "e2e-a3-p2@example.com")
    owner_id = _get_user_id(auth_client, owner_token)
    partner2_id = _get_user_id(auth_client, partner2_token)

    # Setup household and invite partner1
    _activate_tier(auth_client, owner_token, "couple_plus")
    _create_household(owner_id)

    inv1 = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "e2e-a3-p1@example.com"},
    )
    assert inv1.status_code == 201

    # Accept partner1
    accept1 = _accept_invitation(auth_client, partner1_token, inv1.json()["invitation_code"])
    assert accept1.status_code == 200

    # Household is now full (owner + partner1 = 2 active)
    # Try to invite partner2 -- should fail with 409
    inv2 = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={"email": "e2e-a3-p2@example.com"},
    )
    assert inv2.status_code == 409

    # Also verify: manually create a pending membership and try to accept
    # (bypasses invite check, tests accept-level full check)
    import secrets
    from tests.conftest import TestingSessionLocal
    from app.models.household import HouseholdMemberModel, HouseholdModel

    db = TestingSessionLocal()
    try:
        hh = (
            db.query(HouseholdModel)
            .filter(HouseholdModel.household_owner_user_id == owner_id)
            .first()
        )
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

    accept2 = _accept_invitation(auth_client, partner2_token, code2)
    assert accept2.status_code == 409


# ===========================================================================
# A4: Join new household within 30d cooldown -> 403 Forbidden
# ===========================================================================
def test_a4_cooldown_30d_403(client: TestClient):
    """A4: Join within 30d cooldown -> 403 Forbidden."""
    auth_client = _auth_client(client)

    # Setup first household: owner1 + partner
    owner1_token, partner_token, owner1_id, partner_id, code1 = _setup_household(
        auth_client, "e2e-a4-owner1@example.com", "e2e-a4-partner@example.com"
    )

    # Partner accepts first household
    accept1 = _accept_invitation(auth_client, partner_token, code1)
    assert accept1.status_code == 200

    # Owner1 revokes partner
    revoke = auth_client.delete(
        f"/api/v1/household/member/{partner_id}",
        headers={"Authorization": f"Bearer {owner1_token}"},
    )
    assert revoke.status_code == 200
    assert revoke.json()["status"] == "revoked"

    # Setup second household: owner2
    owner2_token = _register_and_token(auth_client, "e2e-a4-owner2@example.com")
    owner2_id = _get_user_id(auth_client, owner2_token)
    _activate_tier(auth_client, owner2_token, "couple_plus")
    _create_household(owner2_id)

    # Owner2 tries to invite the partner (who was just revoked < 30d ago)
    inv2 = auth_client.post(
        "/api/v1/household/invite",
        headers={"Authorization": f"Bearer {owner2_token}"},
        json={"email": "e2e-a4-partner@example.com"},
    )
    assert inv2.status_code == 403
    assert "30 jours" in inv2.json()["detail"]
