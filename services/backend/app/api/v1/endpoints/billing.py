"""
Billing endpoints (Stripe-first foundation).
"""

import json
from fastapi import APIRouter, Depends, Header, Request, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.billing import (
    BillingEntitlementsResponse,
    StripeCheckoutRequest,
    StripeCheckoutResponse,
    StripeWebhookAck,
    StripePortalResponse,
    BillingDebugActivateRequest,
    BillingDebugActivateResponse,
)
from app.services.billing_service import (
    get_entitlement_snapshot,
    create_stripe_checkout_session,
    verify_stripe_webhook_signature,
    process_stripe_event,
    create_stripe_billing_portal_session,
    get_or_create_subscription,
    recompute_entitlements,
)

router = APIRouter()


@router.get("/entitlements", response_model=BillingEntitlementsResponse)
def get_entitlements(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> BillingEntitlementsResponse:
    snapshot = get_entitlement_snapshot(db, current_user)
    return BillingEntitlementsResponse(**snapshot)


@router.post("/checkout/stripe", response_model=StripeCheckoutResponse)
def create_checkout(
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
def create_portal(
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


@router.post("/debug/activate", response_model=BillingDebugActivateResponse)
def debug_activate_subscription(
    body: BillingDebugActivateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> BillingDebugActivateResponse:
    """
    Internal/dev helper to activate subscription without store checkout.
    """
    sub = get_or_create_subscription(db, current_user)
    sub.tier = body.tier
    sub.status = body.status
    sub.is_trial = body.is_trial
    from datetime import datetime, timedelta

    sub.current_period_end = datetime.utcnow() + timedelta(days=body.period_days)
    db.commit()
    db.refresh(sub)
    features = recompute_entitlements(db, current_user.id)
    return BillingDebugActivateResponse(
        user_id=current_user.id,
        tier=sub.tier,
        status=sub.status,
        features=features,
        created_subscription_id=sub.id,
    )
