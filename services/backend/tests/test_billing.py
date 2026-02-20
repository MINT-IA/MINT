"""
Tests for billing endpoints.
"""

import jwt
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.core.config import settings
from app.main import app


def _auth_client(client: TestClient):
    """Client without auth override — for testing real JWT flow."""
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


def test_billing_entitlements_default_free(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "billing-free@example.com")

    response = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["tier"] == "free"
    assert body["is_active"] is False
    assert body["features"] == []


def test_billing_debug_activate_grants_coach_features(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "billing-coach@example.com")

    activate = auth_client.post(
        "/api/v1/billing/debug/activate",
        headers={"Authorization": f"Bearer {token}"},
        json={"tier": "coach", "status": "active", "is_trial": False, "period_days": 30},
    )
    assert activate.status_code == 200
    assert len(activate.json()["features"]) >= 5

    entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert entitlements.status_code == 200
    body = entitlements.json()
    assert body["tier"] == "coach"
    assert body["is_active"] is True
    assert "dashboard" in body["features"]
    assert "vault" in body["features"]


def test_stripe_checkout_requires_configuration(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "billing-stripe@example.com")

    prev_secret = settings.STRIPE_SECRET_KEY
    prev_price = settings.STRIPE_PRICE_COACH_MONTHLY
    settings.STRIPE_SECRET_KEY = ""
    settings.STRIPE_PRICE_COACH_MONTHLY = ""
    try:
        response = auth_client.post(
            "/api/v1/billing/checkout/stripe",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "success_url": "https://mint.ch/success",
                "cancel_url": "https://mint.ch/cancel",
            },
        )
        assert response.status_code == 503
    finally:
        settings.STRIPE_SECRET_KEY = prev_secret
        settings.STRIPE_PRICE_COACH_MONTHLY = prev_price


def test_stripe_webhook_rejects_bad_signature(client: TestClient):
    prev = settings.STRIPE_WEBHOOK_SECRET
    settings.STRIPE_WEBHOOK_SECRET = "whsec_test"
    try:
        response = client.post(
            "/api/v1/billing/webhooks/stripe",
            headers={"Stripe-Signature": "t=123,v1=deadbeef"},
            content=b'{"id":"evt_1","type":"checkout.session.completed","data":{"object":{}}}',
        )
        assert response.status_code == 400
    finally:
        settings.STRIPE_WEBHOOK_SECRET = prev


def test_apple_verify_purchase_activates_entitlements(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "billing-apple@example.com")
    user_id = auth_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    ).json()["id"]

    response = auth_client.post(
        "/api/v1/billing/apple/verify",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "product_id": settings.APPLE_IAP_PRODUCT_COACH_MONTHLY,
            "transaction_id": "1000001234567890",
            "original_transaction_id": "1000001234567890",
            "is_trial": True,
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "verified"
    assert body["tier"] == "coach"
    assert body["source"] == "apple"
    assert "dashboard" in body["features"]


def test_apple_webhook_activates_subscription_and_is_idempotent(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "billing-apple-webhook@example.com")

    me = auth_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    user_id = me.json()["id"]

    payload = {
        "notificationUUID": "apple-notif-123",
        "notificationType": "DID_RENEW",
        "data": {
            "user_id": user_id,
            "product_id": settings.APPLE_IAP_PRODUCT_COACH_MONTHLY,
            "transaction_id": "tx-apple-001",
            "original_transaction_id": "orig-tx-apple-001",
            "is_trial": False,
        },
    }

    first = client.post("/api/v1/billing/webhooks/apple", json=payload)
    assert first.status_code == 200
    assert first.json()["received"] is True

    second = client.post("/api/v1/billing/webhooks/apple", json=payload)
    assert second.status_code == 200

    entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert entitlements.status_code == 200
    body = entitlements.json()
    assert body["tier"] == "coach"
    assert body["is_active"] is True
    assert "dashboard" in body["features"]


def test_apple_webhook_expired_disables_entitlements(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "billing-apple-expired@example.com")
    user_id = auth_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    ).json()["id"]

    activate_payload = {
        "notificationUUID": "apple-notif-activate-1",
        "notificationType": "SUBSCRIBED",
        "data": {
            "user_id": user_id,
            "product_id": settings.APPLE_IAP_PRODUCT_COACH_MONTHLY,
            "transaction_id": "tx-apple-activate-001",
            "original_transaction_id": "orig-tx-apple-expired-001",
            "is_trial": False,
        },
    }
    client.post("/api/v1/billing/webhooks/apple", json=activate_payload)

    expire_payload = {
        "notificationUUID": "apple-notif-expire-2",
        "notificationType": "EXPIRED",
        "data": {
            "user_id": user_id,
            "product_id": settings.APPLE_IAP_PRODUCT_COACH_MONTHLY,
            "transaction_id": "tx-apple-expire-001",
            "original_transaction_id": "orig-tx-apple-expired-001",
            "is_trial": False,
        },
    }
    expired = client.post("/api/v1/billing/webhooks/apple", json=expire_payload)
    assert expired.status_code == 200

    entitlements = auth_client.get(
        "/api/v1/billing/entitlements",
        headers={"Authorization": f"Bearer {token}"},
    )
    body = entitlements.json()
    assert body["tier"] == "free"
    assert body["is_active"] is False
    assert body["features"] == []


def test_apple_verify_rejects_payload_mismatch(client: TestClient):
    auth_client = _auth_client(client)
    token = _register_and_token(auth_client, "billing-apple-mismatch@example.com")
    bad_payload = jwt.encode(
        {"productId": "wrong.product", "transactionId": "wrong-tx"},
        key="",
        algorithm="none",
    )

    response = auth_client.post(
        "/api/v1/billing/apple/verify",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "product_id": settings.APPLE_IAP_PRODUCT_COACH_MONTHLY,
            "transaction_id": "right-tx",
            "signed_payload": bad_payload,
        },
    )
    assert response.status_code == 400
