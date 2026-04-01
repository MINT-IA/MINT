"""
Billing endpoints (Stripe-first foundation).
"""

import json
from fastapi import APIRouter, Depends, Header, Request, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional

from app.core.auth import require_current_user
from app.core.database import get_db
from app.core.config import settings
from app.core.rate_limit import limiter
from app.models.user import User
from app.schemas.billing import (
    BillingEntitlementsResponse,
    StripeCheckoutRequest,
    StripeCheckoutResponse,
    StripeWebhookAck,
    StripePortalResponse,
    BillingDebugActivateRequest,
    BillingDebugActivateResponse,
    AppleVerifyPurchaseRequest,
    AppleVerifyPurchaseResponse,
    AppleWebhookRequest,
    AppleWebhookAck,
)
from app.services.billing_service import (
    get_entitlement_snapshot,
    create_stripe_checkout_session,
    verify_stripe_webhook_signature,
    process_stripe_event,
    create_stripe_billing_portal_session,
    get_or_create_subscription,
    recompute_entitlements,
    activate_apple_purchase,
    process_apple_notification,
    tier_from_product_id,
)
from app.services.audit_service import log_audit_event

router = APIRouter()


def _request_ip(request: Request) -> Optional[str]:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        # Use RIGHTMOST IP — closest to the server, hardest to spoof
        return forwarded.split(",")[-1].strip()
    return request.client.host if request.client else None


@router.get("/entitlements", response_model=BillingEntitlementsResponse)
@limiter.limit("30/minute")
def get_entitlements(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> BillingEntitlementsResponse:
    snapshot = get_entitlement_snapshot(db, current_user)
    return BillingEntitlementsResponse(**snapshot)


@router.post("/checkout/stripe", response_model=StripeCheckoutResponse)
@limiter.limit("10/minute")
def create_checkout(
    request: Request,
    body: StripeCheckoutRequest,
    current_user: User = Depends(require_current_user),
) -> StripeCheckoutResponse:
    session = create_stripe_checkout_session(
        user=current_user,
        success_url=body.success_url,
        cancel_url=body.cancel_url,
        price_id=body.price_id,
    )
    return StripeCheckoutResponse(
        checkout_url=session["url"],
        session_id=session["id"],
    )


@router.post("/portal/stripe", response_model=StripePortalResponse)
@limiter.limit("10/minute")
def create_portal(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> StripePortalResponse:
    sub = get_or_create_subscription(db, current_user)
    if not sub.external_customer_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No Stripe customer found for current user",
        )
    portal = create_stripe_billing_portal_session(sub.external_customer_id)
    return StripePortalResponse(portal_url=portal["url"])


@router.post("/webhooks/stripe", response_model=StripeWebhookAck)
@limiter.limit("60/minute")
async def stripe_webhook(
    request: Request,
    db: Session = Depends(get_db),
    stripe_signature: Optional[str] = Header(default=None, alias="Stripe-Signature"),
) -> StripeWebhookAck:
    payload = await request.body()
    verify_stripe_webhook_signature(payload, stripe_signature)
    event = json.loads(payload.decode("utf-8"))
    process_stripe_event(db, event)
    return StripeWebhookAck(received=True, event_type=event.get("type", "unknown"))


@router.post("/debug/activate", response_model=BillingDebugActivateResponse, include_in_schema=False)
@limiter.limit("5/minute")
def debug_activate_subscription(
    request: Request,
    body: BillingDebugActivateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> BillingDebugActivateResponse:
    """
    Internal/dev helper to activate subscription without store checkout.
    SECURITY: Only available in development. Hidden from OpenAPI schema.
    """
    if settings.ENVIRONMENT != "development":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Not found",
        )

    sub = get_or_create_subscription(db, current_user)
    sub.tier = body.tier
    sub.status = body.status
    sub.is_trial = body.is_trial
    from datetime import datetime, timedelta, timezone

    sub.current_period_end = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=body.period_days)
    db.commit()
    db.refresh(sub)
    _, features = recompute_entitlements(db, current_user.id)
    return BillingDebugActivateResponse(
        user_id=current_user.id,
        tier=sub.tier,
        status=sub.status,
        features=features,
        created_subscription_id=sub.id,
    )


@router.post("/apple/verify", response_model=AppleVerifyPurchaseResponse)
@limiter.limit("10/minute")
def verify_apple_purchase(
    request: Request,
    body: AppleVerifyPurchaseRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AppleVerifyPurchaseResponse:
    if (
        settings.ENVIRONMENT in {"production", "staging"}
        and not settings.BILLING_ALLOW_CLIENT_APPLE_VERIFY
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Direct Apple verification is disabled in this environment",
        )

    if not body.signed_payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="signed_payload is required",
        )

    features = activate_apple_purchase(
        db,
        current_user,
        product_id=body.product_id,
        transaction_id=body.transaction_id,
        original_transaction_id=body.original_transaction_id,
        purchased_at=body.purchased_at,
        expires_at=body.expires_at,
        is_trial=body.is_trial,
        raw_payload=body.signed_payload,
    )
    log_audit_event(
        db,
        event_type="billing.apple_verify",
        status="success",
        source="api",
        user_id=current_user.id,
        actor_email=current_user.email,
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
        details={
            "product_id": body.product_id,
            "transaction_id": body.transaction_id,
            "is_trial": body.is_trial,
        },
    )
    resolved_tier = tier_from_product_id(body.product_id)
    db.commit()
    return AppleVerifyPurchaseResponse(
        status="verified",
        tier=resolved_tier,
        source="apple",
        features=features,
    )


@router.post("/webhooks/apple", response_model=AppleWebhookAck)
@limiter.limit("60/minute")
def apple_webhook(
    request: Request,
    body: AppleWebhookRequest,
    db: Session = Depends(get_db),
) -> AppleWebhookAck:
    if settings.APPLE_WEBHOOK_SHARED_SECRET:
        provided = request.headers.get("x-apple-webhook-secret", "")
        if provided != settings.APPLE_WEBHOOK_SHARED_SECRET:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Apple webhook secret",
            )

    process_apple_notification(db, body.model_dump())
    data = body.data if isinstance(body.data, dict) else {}
    log_audit_event(
        db,
        event_type="billing.apple_webhook",
        status="success",
        source="webhook",
        user_id=data.get("user_id"),
        ip_address=_request_ip(request),
        user_agent=request.headers.get("user-agent"),
        details={
            "notification_type": body.notificationType,
            "notification_uuid": body.notificationUUID,
            "product_id": data.get("product_id"),
            "transaction_id": data.get("transaction_id"),
        },
    )
    db.commit()
    return AppleWebhookAck(
        received=True,
        notification_type=body.notificationType,
    )
