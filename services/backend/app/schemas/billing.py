"""
Billing schemas.
"""

from datetime import datetime
from typing import Any, Optional
from pydantic import BaseModel, Field


class BillingEntitlementsResponse(BaseModel):
    tier: str
    status: str
    is_active: bool
    is_trial: bool
    current_period_end: Optional[datetime] = None
    features: list[str] = Field(default_factory=list)
    source: str = "stripe"


class StripeCheckoutRequest(BaseModel):
    success_url: str
    cancel_url: str
    price_id: Optional[str] = None


class StripeCheckoutResponse(BaseModel):
    checkout_url: str
    session_id: str


class StripeWebhookAck(BaseModel):
    received: bool
    event_type: str


class StripePortalResponse(BaseModel):
    portal_url: str


class BillingDebugActivateRequest(BaseModel):
    tier: str = "coach"
    status: str = "active"
    is_trial: bool = False
    period_days: int = 30


class BillingDebugActivateResponse(BaseModel):
    user_id: str
    tier: str
    status: str
    features: list[str]
    created_subscription_id: str


class StripeEventEnvelope(BaseModel):
    id: str
    type: str
    data: dict[str, Any]


class AppleVerifyPurchaseRequest(BaseModel):
    product_id: str
    transaction_id: str
    original_transaction_id: Optional[str] = None
    purchased_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    is_trial: bool = False
    signed_payload: Optional[str] = None


class AppleVerifyPurchaseResponse(BaseModel):
    status: str
    tier: str
    source: str
    features: list[str]


class AppleWebhookRequest(BaseModel):
    notificationUUID: str
    notificationType: str
    subtype: Optional[str] = None
    data: dict[str, Any] = Field(default_factory=dict)


class AppleWebhookAck(BaseModel):
    received: bool
    notification_type: str
