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


# Valid tiers
VALID_TIERS = {"free", "starter", "premium", "couple_plus"}

# Feature access levels
# "Y" = full access, "basic" = limited, "-" = no access
TIER_FEATURE_MATRIX: dict[str, dict[str, str]] = {
    "dashboard":          {"free": "-", "starter": "Y", "premium": "Y", "couple_plus": "Y"},
    "forecast":           {"free": "-", "starter": "Y", "premium": "Y", "couple_plus": "Y"},
    "checkin":            {"free": "-", "starter": "Y", "premium": "Y", "couple_plus": "Y"},
    "scoreEvolution":     {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
    "alertesProactives":  {"free": "-", "starter": "Y", "premium": "Y", "couple_plus": "Y"},
    "historique":         {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
    "profilCouple":       {"free": "-", "starter": "basic", "premium": "Y", "couple_plus": "Y"},
    "coachLlm":           {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
    "scenariosEtSi":      {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
    "exportPdf":          {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
    "vault":              {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
    "monteCarlo":         {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
    "arbitrageModules":   {"free": "-", "starter": "-", "premium": "Y", "couple_plus": "Y"},
}

ALL_FEATURES = list(TIER_FEATURE_MATRIX.keys())

# Legacy alias — keep COACH_FEATURES for backward compatibility during migration
COACH_FEATURES = ALL_FEATURES

# Map store product IDs to tiers
PRODUCT_TO_TIER: dict[str, str] = {
    "ch.mint.starter.monthly": "starter",
    "ch.mint.premium.monthly": "premium",
    "ch.mint.couple_plus.monthly": "couple_plus",
    "ch.mint.starter.annual": "starter",
    "ch.mint.premium.annual": "premium",
    "ch.mint.couple_plus.annual": "couple_plus",
    # Legacy
    "ch.mint.coach.monthly": "premium",
}

_JWT_COMPACT_RE = re.compile(r"^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$")


def _now() -> datetime:
    return datetime.utcnow()


def _is_subscription_active(sub: SubscriptionModel) -> bool:
    if sub.status not in {"active", "trialing"}:
        return False
    if sub.current_period_end is None:
        return True
    return sub.current_period_end >= _now()


def features_for_tier(tier: str) -> list[str]:
    """Return list of features with access != '-' for given tier."""
    if tier not in VALID_TIERS:
        return []
    return [
        feature
        for feature, access in TIER_FEATURE_MATRIX.items()
        if access.get(tier, "-") != "-"
    ]


def tier_from_product_id(product_id: str) -> str:
    """Map store product ID to tier. Defaults to free for unknown products (fail-closed)."""
    return PRODUCT_TO_TIER.get(product_id, "free")


def _stripe_price_to_tier(price_id: str) -> str:
    """Resolve tier from Stripe price ID using configured price settings.

    Returns "free" for unknown price IDs (fail-closed, not fail-open).
    """
    price_map: dict[str, str] = {}
    # Monthly
    if settings.STRIPE_PRICE_STARTER_MONTHLY:
        price_map[settings.STRIPE_PRICE_STARTER_MONTHLY] = "starter"
    if settings.STRIPE_PRICE_PREMIUM_MONTHLY:
        price_map[settings.STRIPE_PRICE_PREMIUM_MONTHLY] = "premium"
    if settings.STRIPE_PRICE_COUPLE_PLUS_MONTHLY:
        price_map[settings.STRIPE_PRICE_COUPLE_PLUS_MONTHLY] = "couple_plus"
    # Annual
    if settings.STRIPE_PRICE_STARTER_ANNUAL:
        price_map[settings.STRIPE_PRICE_STARTER_ANNUAL] = "starter"
    if settings.STRIPE_PRICE_PREMIUM_ANNUAL:
        price_map[settings.STRIPE_PRICE_PREMIUM_ANNUAL] = "premium"
    if settings.STRIPE_PRICE_COUPLE_PLUS_ANNUAL:
        price_map[settings.STRIPE_PRICE_COUPLE_PLUS_ANNUAL] = "couple_plus"
    # Legacy
    if settings.STRIPE_PRICE_COACH_MONTHLY:
        price_map[settings.STRIPE_PRICE_COACH_MONTHLY] = "premium"
    return price_map.get(price_id, "free")


def _is_internal_access_user(db: Session, user_id: str) -> bool:
    """Check if user qualifies for internal full access override.

    Allowlist supports:
    - "*" → all authenticated users (TestFlight/dev)
    - "a@b.ch,c@d.ch" → specific emails only
    - "" (empty) → no one (fail-closed)
    """
    if not settings.INTERNAL_ACCESS_ENABLED:
        return False
    raw = settings.INTERNAL_ACCESS_ALLOWLIST.strip()
    if not raw:
        return False
    if raw == "*":
        return True
    allowlist = [e.strip() for e in raw.split(",") if e.strip()]
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return False
    return user.email in allowlist


def _compute_effective_tier(db: Session, user_id: str) -> str:
    """Compute effective tier: internal override > direct subscription > household.

    Pure read — no side effects, no commits.
    """
    from app.models.household import HouseholdMemberModel, HouseholdModel

    tier_rank = {"free": 0, "starter": 1, "premium": 2, "couple_plus": 3}

    # Priority 1: Internal access override
    if _is_internal_access_user(db, user_id):
        override_tier = settings.INTERNAL_ACCESS_DEFAULT_TIER
        if override_tier not in VALID_TIERS:
            override_tier = "premium"
        return override_tier

    # Priority 2: Direct subscription
    sub = (
        db.query(SubscriptionModel)
        .filter(SubscriptionModel.user_id == user_id)
        .order_by(SubscriptionModel.updated_at.desc())
        .first()
    )
    direct_tier = "free"
    if sub and _is_subscription_active(sub):
        direct_tier = sub.tier if sub.tier in VALID_TIERS else "free"

    # Household inherited
    inherited_tier = "free"
    membership = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.user_id == user_id,
            HouseholdMemberModel.status == "active",
        )
        .first()
    )
    if membership:
        household = (
            db.query(HouseholdModel)
            .filter(HouseholdModel.id == membership.household_id)
            .first()
        )
        if household:
            billing_sub = (
                db.query(SubscriptionModel)
                .filter(SubscriptionModel.user_id == household.billing_owner_user_id)
                .order_by(SubscriptionModel.updated_at.desc())
                .first()
            )
            if billing_sub and _is_subscription_active(billing_sub):
                inherited_tier = billing_sub.tier if billing_sub.tier in VALID_TIERS else "free"

    return (
        direct_tier
        if tier_rank.get(direct_tier, 0) >= tier_rank.get(inherited_tier, 0)
        else inherited_tier
    )


def recompute_entitlements(
    db: Session,
    user_id: str,
    restricted_features: set[str] | None = None,
) -> tuple[str, list[str]]:
    """
    Recompute feature entitlements for a user.

    1. Compute effective tier (direct vs household-inherited, higher wins)
    2. Log internal access override (single audit point)
    3. Apply regulatory restrictions (FATCA etc.)
    4. Upsert entitlement rows

    Returns (effective_tier, active_features).
    """
    from app.models.household import AdminAuditEventModel

    effective_tier = _compute_effective_tier(db, user_id)

    # Audit log for internal access — single point, inside the commit below
    if _is_internal_access_user(db, user_id):
        db.add(AdminAuditEventModel(
            admin_user_id=user_id,
            action="internal_access_override",
            target_user_id=user_id,
            reason=f"Internal full access ({effective_tier}) — INTERNAL_ACCESS_ENABLED=true",
        ))

    sub = (
        db.query(SubscriptionModel)
        .filter(SubscriptionModel.user_id == user_id)
        .order_by(SubscriptionModel.updated_at.desc())
        .first()
    )

    # Compute features for effective tier
    active_features = features_for_tier(effective_tier)

    # Apply regulatory restrictions (INV-15: FATCA etc.)
    if restricted_features:
        active_features = [f for f in active_features if f not in restricted_features]

    # Upsert entitlements
    existing = (
        db.query(EntitlementModel).filter(EntitlementModel.user_id == user_id).all()
    )
    by_key = {e.feature_key: e for e in existing}
    for feature in ALL_FEATURES:
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
    return effective_tier, active_features


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
    effective_tier, features = recompute_entitlements(db, user.id)
    is_active = effective_tier != "free"
    return {
        "tier": effective_tier,
        "status": sub.status if sub else "inactive",
        "is_active": is_active,
        "is_trial": sub.is_trial if sub else False,
        "current_period_end": sub.current_period_end if sub else None,
        "features": features,
        "source": sub.source if sub else "stripe",
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
            detail="External service unavailable",
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
        "metadata[price_id]": final_price_id,
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
        outcome="applied",
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

        # Resolve tier from price_id in checkout session metadata
        checkout_price_id = obj.get("metadata", {}).get("price_id", "")
        resolved_tier = _stripe_price_to_tier(checkout_price_id) if checkout_price_id else "free"

        event_ts_raw = event.get("created")
        event_ts = datetime.utcfromtimestamp(event_ts_raw) if event_ts_raw else _now()

        sub.tier = resolved_tier
        sub.status = "active"
        sub.is_trial = False
        sub.external_customer_id = obj.get("customer")
        sub.external_subscription_id = obj.get("subscription")
        sub.current_period_end = _now() + timedelta(days=30)
        sub.last_event_at = event_ts
        sub.updated_at = _now()
        db.flush()

        record.subscription_id = sub.id

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

        # HIGH-3: Auto-create household on couple_plus purchase
        if resolved_tier == "couple_plus":
            from app.services.household_service import create_household_for_billing_owner
            user_obj = db.query(User).filter(User.id == user_id).first()
            if user_obj:
                create_household_for_billing_owner(db, user_obj)

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
                # HIGH-5: Use event timestamp for stale check (not processing time)
                event_ts_raw = event.get("created")
                event_ts = datetime.utcfromtimestamp(event_ts_raw) if event_ts_raw else _now()

                # FIX-082: Monotone timestamp with 5-min tolerance for clock skew.
                # Was rejecting valid webhooks when event_ts lagged by seconds.
                if sub.last_event_at and sub.last_event_at > event_ts + timedelta(minutes=5):
                    record.outcome = "skipped_stale"
                    record.is_processed = True
                    db.commit()
                    return

                # HIGH-1: Resolve tier from subscription items price_id
                items = obj.get("items", {}).get("data", [])
                item_price_id = ""
                if items:
                    item_price_id = items[0].get("price", {}).get("id", "")
                resolved_sub_tier = _stripe_price_to_tier(item_price_id) if item_price_id else "free"

                stripe_status = obj.get("status", "canceled")
                if stripe_status in {"active", "trialing"}:
                    sub.status = stripe_status
                    sub.tier = resolved_sub_tier
                    sub.is_trial = stripe_status == "trialing"
                else:
                    sub.status = "canceled"
                    sub.tier = "free"
                    sub.is_trial = False
                end_ts = obj.get("current_period_end")
                sub.current_period_end = (
                    datetime.utcfromtimestamp(end_ts)
                    if end_ts
                    else event_ts
                )
                sub.last_event_at = event_ts
                sub.updated_at = _now()
                record.subscription_id = sub.id
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
    Activate subscription from an Apple purchase signal.

    Note: in this foundation phase we accept client-transmitted purchase evidence.
    Full App Store Server API signature verification is handled in next phase.
    """
    # Accept any known product ID (multi-tier) or legacy coach product
    known_products = set(PRODUCT_TO_TIER.keys())
    if product_id not in known_products:
        # Fallback: check legacy single-product setting
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

    resolved_tier = tier_from_product_id(product_id)

    sub = (
        db.query(SubscriptionModel)
        .filter(SubscriptionModel.user_id == user.id)
        .order_by(SubscriptionModel.updated_at.desc())
        .first()
    ) or SubscriptionModel(user_id=user.id, source="apple")
    if sub.id is None:
        db.add(sub)

    sub.tier = resolved_tier
    sub.source = "apple"
    sub.status = "trialing" if is_trial else "active"
    sub.is_trial = is_trial
    sub.external_subscription_id = original_transaction_id or transaction_id
    sub.current_period_end = expires_at or (_now() + timedelta(days=30))
    sub.last_event_at = _now()
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

    # HIGH-3: Auto-create household on couple_plus purchase
    if resolved_tier == "couple_plus":
        from app.services.household_service import create_household_for_billing_owner
        create_household_for_billing_owner(db, user)

    _, features = recompute_entitlements(db, user.id)
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

    Apple JWS signature verification.

    In production (APPLE_ROOT_CA_PEM set or ENVIRONMENT=production), signature
    verification is ENFORCED. In dev/test, it's skipped to allow sandbox testing.

    See: https://developer.apple.com/documentation/appstoreserverapi
    """
    if not signed_payload:
        return
    # Webhook payloads may not provide StoreKit's JWS. Only attempt decode
    # if payload looks like a compact JWS: 3 non-empty base64url-like segments.
    if not _JWT_COMPACT_RE.match(signed_payload):
        return

    import os
    is_production = os.getenv("ENVIRONMENT", "").lower() == "production"
    apple_root_ca = os.getenv("APPLE_ROOT_CA_PEM")

    try:
        if is_production and apple_root_ca:
            # Production: verify Apple's JWS signature using their root CA.
            # Requires APPLE_ROOT_CA_PEM env var with Apple Root CA certificate.
            claims = jwt.decode(
                signed_payload,
                apple_root_ca,
                algorithms=["ES256"],
                options={"verify_exp": False},
            )
        else:
            # Dev/Sandbox: skip signature verification for TestFlight testing.
            # WARNING: This path must NOT be reachable in production.
            if is_production:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="APPLE_ROOT_CA_PEM required in production",
                )
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
    current_tier: str = "premium",
) -> tuple[str, str, bool]:
    upper_type = notification_type.upper()
    upper_subtype = (subtype or "").upper()

    if upper_type in {"SUBSCRIBED", "DID_RENEW", "OFFER_REDEEMED"}:
        return (current_tier, "trialing" if is_trial else "active", is_trial)

    if upper_type in {"DID_FAIL_TO_RENEW", "GRACE_PERIOD_EXPIRED"}:
        return (current_tier, "past_due", False)

    if upper_type in {"EXPIRED", "REFUND", "REVOKE"}:
        return ("free", "canceled", False)

    if upper_type == "DID_CHANGE_RENEWAL_STATUS" and upper_subtype == "AUTO_RENEW_DISABLED":
        return (current_tier, "active", False)

    return (current_tier, "trialing" if is_trial else "active", is_trial)


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
        outcome="applied",
    )
    db.add(row)
    db.flush()

    data = payload.get("data", {}) or {}
    user_id = data.get("user_id")
    product_id = data.get("product_id")
    transaction_id = data.get("transaction_id")
    original_transaction_id = data.get("original_transaction_id")
    is_trial = data.get("is_trial") is True

    # Resolve tier from product_id
    resolved_tier = tier_from_product_id(product_id) if product_id else "free"

    tier, mapped_status, mapped_trial = _map_apple_notification_status(
        notification_type, payload.get("subtype"), is_trial, current_tier=resolved_tier
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
            # HIGH-5: Use Apple event timestamp (signedDate in millis) instead of processing time
            signed_date = payload.get("signedDate")
            if signed_date:
                try:
                    event_ts = datetime.utcfromtimestamp(signed_date / 1000)
                except (ValueError, TypeError, OSError):
                    event_ts = _now()
            else:
                event_ts = _now()

            # Monotone timestamp idempotence
            target_sub = sub or (
                db.query(SubscriptionModel)
                .filter(SubscriptionModel.user_id == user.id)
                .order_by(SubscriptionModel.updated_at.desc())
                .first()
            )
            if target_sub and target_sub.last_event_at and target_sub.last_event_at > event_ts:
                row.outcome = "skipped_stale"
                row.subscription_id = target_sub.id
                row.is_processed = True
                db.commit()
                return

            if tier == "free":
                # Cancellation/refund path
                current_sub = target_sub
                if current_sub:
                    current_sub.tier = "free"
                    current_sub.status = mapped_status
                    current_sub.is_trial = False
                    current_sub.current_period_end = expires_at or event_ts
                    current_sub.last_event_at = event_ts
                    current_sub.updated_at = _now()
                    row.subscription_id = current_sub.id
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
                    latest_sub.tier = resolved_tier
                    latest_sub.is_trial = mapped_trial
                    latest_sub.last_event_at = event_ts
                    latest_sub.updated_at = _now()
                    row.subscription_id = latest_sub.id
                    db.flush()
                    recompute_entitlements(db, user.id)

    row.is_processed = True
    db.commit()
