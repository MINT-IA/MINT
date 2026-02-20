"""
Billing orchestration service.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Optional
import hmac
import hashlib
import json
import re
import urllib.parse
import urllib.request
import jwt

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.billing import (
    SubscriptionModel,
    EntitlementModel,
    BillingWebhookEventModel,
    BillingTransactionModel,
)
from app.models.user import User


COACH_FEATURES = [
    "dashboard",
    "forecast",
    "checkin",
    "scoreEvolution",
    "alertesProactives",
    "historique",
    "profilCouple",
    "coachLlm",
    "scenariosEtSi",
    "exportPdf",
    "vault",
]
_JWT_COMPACT_RE = re.compile(r"^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$")


def _now() -> datetime:
    return datetime.utcnow()


def _is_subscription_active(sub: SubscriptionModel) -> bool:
    if sub.status not in {"active", "trialing"}:
        return False
    if sub.current_period_end is None:
        return True
    return sub.current_period_end >= _now()


def recompute_entitlements(db: Session, user_id: str) -> list[str]:
    sub = (
        db.query(SubscriptionModel)
        .filter(SubscriptionModel.user_id == user_id)
        .order_by(SubscriptionModel.updated_at.desc())
        .first()
    )
    active = bool(sub and sub.tier == "coach" and _is_subscription_active(sub))
    active_features = COACH_FEATURES if active else []

    existing = (
        db.query(EntitlementModel).filter(EntitlementModel.user_id == user_id).all()
    )
    by_key = {e.feature_key: e for e in existing}
    for feature in COACH_FEATURES:
        row = by_key.get(feature)
        if row is None:
            db.add(
                EntitlementModel(
                    user_id=user_id,
                    subscription_id=sub.id if sub else None,
                    feature_key=feature,
                    is_active=feature in active_features,
                )
            )
        else:
            row.subscription_id = sub.id if sub else None
            row.is_active = feature in active_features
            row.updated_at = _now()
    db.commit()
    return active_features


def get_or_create_subscription(db: Session, user: User) -> SubscriptionModel:
    sub = (
        db.query(SubscriptionModel)
        .filter(SubscriptionModel.user_id == user.id)
        .order_by(SubscriptionModel.updated_at.desc())
        .first()
    )
    if sub:
        return sub
    sub = SubscriptionModel(
        user_id=user.id,
        tier="free",
        status="inactive",
        source="stripe",
        is_trial=False,
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return sub


def get_entitlement_snapshot(db: Session, user: User) -> dict[str, Any]:
    sub = get_or_create_subscription(db, user)
    features = recompute_entitlements(db, user.id)
    sub = db.query(SubscriptionModel).filter(SubscriptionModel.id == sub.id).first()
    return {
        "tier": sub.tier,
        "status": sub.status,
        "is_active": _is_subscription_active(sub) and sub.tier == "coach",
        "is_trial": sub.is_trial,
        "current_period_end": sub.current_period_end,
        "features": features,
        "source": sub.source,
    }


def _stripe_post(path: str, data: dict[str, Any]) -> dict[str, Any]:
    if not settings.STRIPE_SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Billing provider not configured",
        )
    body = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(
        f"https://api.stripe.com/v1/{path}",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {settings.STRIPE_SECRET_KEY}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Billing provider request failed: {exc}",
        ) from exc


def create_stripe_checkout_session(
    user: User,
    success_url: str,
    cancel_url: str,
    price_id: Optional[str],
) -> dict[str, Any]:
    final_price_id = price_id or settings.STRIPE_PRICE_COACH_MONTHLY
    if not final_price_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Stripe price not configured",
        )

    payload = {
        "mode": "subscription",
        "line_items[0][price]": final_price_id,
        "line_items[0][quantity]": "1",
        "success_url": success_url,
        "cancel_url": cancel_url,
        "client_reference_id": user.id,
        "metadata[user_id]": user.id,
    }
    return _stripe_post("checkout/sessions", payload)


def create_stripe_billing_portal_session(
    customer_id: str,
    return_url: Optional[str] = None,
) -> dict[str, Any]:
    payload = {
        "customer": customer_id,
        "return_url": return_url or settings.BILLING_PORTAL_RETURN_URL,
    }
    return _stripe_post("billing_portal/sessions", payload)


def verify_stripe_webhook_signature(payload: bytes, sig_header: Optional[str]) -> None:
    secret = settings.STRIPE_WEBHOOK_SECRET
    if not secret:
        return
    if not sig_header:
        raise HTTPException(status_code=400, detail="Missing Stripe signature header")
    elements = dict(
        item.split("=", 1) for item in sig_header.split(",") if "=" in item
    )
    timestamp = elements.get("t")
    signature = elements.get("v1")
    if not timestamp or not signature:
        raise HTTPException(status_code=400, detail="Invalid Stripe signature header")

    signed_payload = f"{timestamp}.{payload.decode('utf-8')}".encode("utf-8")
    expected = hmac.new(
        secret.encode("utf-8"), signed_payload, hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise HTTPException(status_code=400, detail="Invalid Stripe signature")


def process_stripe_event(db: Session, event: dict[str, Any]) -> None:
    event_id = event.get("id", "")
    event_type = event.get("type", "")
    if not event_id or not event_type:
        raise HTTPException(status_code=400, detail="Malformed Stripe event")

    existing = (
        db.query(BillingWebhookEventModel)
        .filter(
            BillingWebhookEventModel.provider == "stripe",
            BillingWebhookEventModel.event_id == event_id,
        )
        .first()
    )
    if existing:
        return

    record = BillingWebhookEventModel(
        provider="stripe",
        event_id=event_id,
        event_type=event_type,
        payload=json.dumps(event),
        is_processed=False,
    )
    db.add(record)
    db.flush()

    obj = event.get("data", {}).get("object", {})
    user_id = (
        obj.get("metadata", {}).get("user_id")
        or obj.get("client_reference_id")
        or None
    )

    if event_type == "checkout.session.completed" and user_id:
        sub = (
            db.query(SubscriptionModel)
            .filter(SubscriptionModel.user_id == user_id)
            .order_by(SubscriptionModel.updated_at.desc())
            .first()
        ) or SubscriptionModel(user_id=user_id, source="stripe")
        if sub.id is None:
            db.add(sub)

        sub.tier = "coach"
        sub.status = "active"
        sub.is_trial = False
        sub.external_customer_id = obj.get("customer")
        sub.external_subscription_id = obj.get("subscription")
        sub.current_period_end = _now() + timedelta(days=30)
        sub.updated_at = _now()
        db.flush()

        db.add(
            BillingTransactionModel(
                subscription_id=sub.id,
                provider_transaction_id=obj.get("id"),
                amount_cents=(obj.get("amount_total") or 0),
                currency=(obj.get("currency") or "chf"),
                status="succeeded",
                raw_payload=json.dumps(obj),
            )
        )
        recompute_entitlements(db, user_id)

    if event_type in {"customer.subscription.deleted", "customer.subscription.updated"}:
        sub_id = obj.get("id")
        if sub_id:
            sub = (
                db.query(SubscriptionModel)
                .filter(SubscriptionModel.external_subscription_id == sub_id)
                .first()
            )
            if sub:
                stripe_status = obj.get("status", "canceled")
                if stripe_status in {"active", "trialing"}:
                    sub.status = stripe_status
                    sub.tier = "coach"
                    sub.is_trial = stripe_status == "trialing"
                else:
                    sub.status = "canceled"
                    sub.tier = "free"
                    sub.is_trial = False
                end_ts = obj.get("current_period_end")
                sub.current_period_end = (
                    datetime.utcfromtimestamp(end_ts)
                    if end_ts
                    else _now()
                )
                sub.updated_at = _now()
                recompute_entitlements(db, sub.user_id)

    record.is_processed = True
    db.commit()


def activate_apple_purchase(
    db: Session,
    user: User,
    *,
    product_id: str,
    transaction_id: str,
    original_transaction_id: Optional[str],
    purchased_at: Optional[datetime],
    expires_at: Optional[datetime],
    is_trial: bool,
    raw_payload: Optional[str],
) -> list[str]:
    """
    Activate coach subscription from an Apple purchase signal.

    Note: in this foundation phase we accept client-transmitted purchase evidence.
    Full App Store Server API signature verification is handled in next phase.
    """
    expected_product = settings.APPLE_IAP_PRODUCT_COACH_MONTHLY
    if expected_product and product_id != expected_product:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unknown Apple product_id",
        )
    _validate_apple_signed_payload(
        signed_payload=raw_payload,
        expected_product_id=product_id,
        expected_transaction_id=transaction_id,
    )

    sub = (
        db.query(SubscriptionModel)
        .filter(SubscriptionModel.user_id == user.id)
        .order_by(SubscriptionModel.updated_at.desc())
        .first()
    ) or SubscriptionModel(user_id=user.id, source="apple")
    if sub.id is None:
        db.add(sub)

    sub.tier = "coach"
    sub.source = "apple"
    sub.status = "trialing" if is_trial else "active"
    sub.is_trial = is_trial
    sub.external_subscription_id = original_transaction_id or transaction_id
    sub.current_period_end = expires_at or (_now() + timedelta(days=30))
    sub.updated_at = _now()
    db.flush()

    db.add(
        BillingTransactionModel(
            subscription_id=sub.id,
            provider_transaction_id=transaction_id,
            amount_cents=0,
            currency="chf",
            status="succeeded",
            raw_payload=raw_payload,
        )
    )

    features = recompute_entitlements(db, user.id)
    return features


def _validate_apple_signed_payload(
    *,
    signed_payload: Optional[str],
    expected_product_id: str,
    expected_transaction_id: str,
) -> None:
    """
    Lightweight consistency checks on Apple signed payload.
    Full cryptographic validation is done in the dedicated App Store Server
    integration phase. Here we at least ensure payload claims match request fields.
    """
    if not signed_payload:
        return
    # Webhook payloads may not provide StoreKit's JWS. Only attempt decode
    # if payload looks like a compact JWS: 3 non-empty base64url-like segments.
    if not _JWT_COMPACT_RE.match(signed_payload):
        return
    try:
        claims = jwt.decode(
            signed_payload,
            options={"verify_signature": False, "verify_exp": False},
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Malformed Apple signed payload",
        ) from exc

    payload_product = claims.get("productId")
    payload_tx = claims.get("transactionId")
    if payload_product and payload_product != expected_product_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Apple payload product mismatch",
        )
    if payload_tx and payload_tx != expected_transaction_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Apple payload transaction mismatch",
        )


def _map_apple_notification_status(
    notification_type: str,
    subtype: Optional[str],
    is_trial: bool,
) -> tuple[str, str, bool]:
    upper_type = notification_type.upper()
    upper_subtype = (subtype or "").upper()

    if upper_type in {"SUBSCRIBED", "DID_RENEW", "OFFER_REDEEMED"}:
        return ("coach", "trialing" if is_trial else "active", is_trial)

    if upper_type in {"DID_FAIL_TO_RENEW", "GRACE_PERIOD_EXPIRED"}:
        return ("coach", "past_due", False)

    if upper_type in {"EXPIRED", "REFUND", "REVOKE"}:
        return ("free", "canceled", False)

    if upper_type == "DID_CHANGE_RENEWAL_STATUS" and upper_subtype == "AUTO_RENEW_DISABLED":
        return ("coach", "active", False)

    return ("coach", "trialing" if is_trial else "active", is_trial)


def process_apple_notification(db: Session, payload: dict[str, Any]) -> None:
    """
    Process Apple server notification payload (foundation parser).

    Expected minimal fields:
    - notificationUUID
    - notificationType
    - data.user_id (our linkage)
    - data.product_id
    - data.transaction_id
    """
    notification_uuid = payload.get("notificationUUID")
    notification_type = payload.get("notificationType", "")
    if not notification_uuid or not notification_type:
        raise HTTPException(status_code=400, detail="Malformed Apple notification")

    existing = (
        db.query(BillingWebhookEventModel)
        .filter(
            BillingWebhookEventModel.provider == "apple",
            BillingWebhookEventModel.event_id == notification_uuid,
        )
        .first()
    )
    if existing:
        return

    row = BillingWebhookEventModel(
        provider="apple",
        event_id=notification_uuid,
        event_type=notification_type,
        payload=json.dumps(payload),
        is_processed=False,
    )
    db.add(row)
    db.flush()

    data = payload.get("data", {}) or {}
    user_id = data.get("user_id")
    product_id = data.get("product_id")
    transaction_id = data.get("transaction_id")
    original_transaction_id = data.get("original_transaction_id")
    is_trial = data.get("is_trial") is True
    tier, mapped_status, mapped_trial = _map_apple_notification_status(
        notification_type, payload.get("subtype"), is_trial
    )
    expires_at_raw = data.get("expires_at")
    expires_at = None
    if isinstance(expires_at_raw, str):
        try:
            expires_at = datetime.fromisoformat(expires_at_raw.replace("Z", "+00:00"))
            if expires_at.tzinfo is not None:
                expires_at = expires_at.replace(tzinfo=None)
        except ValueError:
            expires_at = None

    sub: Optional[SubscriptionModel] = None
    if original_transaction_id:
        sub = (
            db.query(SubscriptionModel)
            .filter(SubscriptionModel.external_subscription_id == original_transaction_id)
            .order_by(SubscriptionModel.updated_at.desc())
            .first()
        )
    if sub and not user_id:
        user_id = sub.user_id

    if user_id and product_id and transaction_id:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            if tier == "free":
                # Cancellation/refund path
                current_sub = sub or (
                    db.query(SubscriptionModel)
                    .filter(SubscriptionModel.user_id == user.id)
                    .order_by(SubscriptionModel.updated_at.desc())
                    .first()
                )
                if current_sub:
                    current_sub.tier = "free"
                    current_sub.status = mapped_status
                    current_sub.is_trial = False
                    current_sub.current_period_end = expires_at or _now()
                    current_sub.updated_at = _now()
                    db.flush()
                    recompute_entitlements(db, user.id)
            else:
                activate_apple_purchase(
                    db,
                    user,
                    product_id=product_id,
                    transaction_id=transaction_id,
                    original_transaction_id=original_transaction_id,
                    purchased_at=None,
                    expires_at=expires_at,
                    is_trial=mapped_trial,
                    raw_payload=data.get("signed_payload")
                    if isinstance(data.get("signed_payload"), str)
                    else None,
                )
                # Force mapped status (active/trialing/past_due)
                latest_sub = (
                    db.query(SubscriptionModel)
                    .filter(SubscriptionModel.user_id == user.id)
                    .order_by(SubscriptionModel.updated_at.desc())
                    .first()
                )
                if latest_sub:
                    latest_sub.status = mapped_status
                    latest_sub.tier = "coach"
                    latest_sub.is_trial = mapped_trial
                    latest_sub.updated_at = _now()
                    db.flush()
                    recompute_entitlements(db, user.id)

    row.is_processed = True
    db.commit()
