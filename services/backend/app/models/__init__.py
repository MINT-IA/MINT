"""
Database models for MINT backend.
"""

from app.models.user import User
from app.models.profile_model import ProfileModel
from app.models.session_model import SessionModel
from app.models.analytics_event import AnalyticsEvent
from app.models.audit_event import AuditEventModel
from app.models.auth_security import (
    LoginSecurityStateModel,
    PasswordResetTokenModel,
    EmailVerificationTokenModel,
)
from app.models.billing import (
    SubscriptionModel,
    EntitlementModel,
    BillingTransactionModel,
    BillingWebhookEventModel,
)
from app.models.household import (
    HouseholdModel,
    HouseholdMemberModel,
    AdminAuditEventModel,
)
from app.models.snapshot import SnapshotModel
from app.models.consent import ConsentModel
from app.models.token_blacklist import TokenBlacklist
from app.models.document import DocumentModel
from app.models.scenario import ScenarioModel
from app.models.banking_consent import BankingConsentModel
from app.models.external_data_source import ExternalDataSourceModel
from app.models.magic_link_token import MagicLinkTokenModel

__all__ = [
    "User",
    "ProfileModel",
    "SessionModel",
    "AnalyticsEvent",
    "AuditEventModel",
    "LoginSecurityStateModel",
    "PasswordResetTokenModel",
    "EmailVerificationTokenModel",
    "SubscriptionModel",
    "EntitlementModel",
    "BillingTransactionModel",
    "BillingWebhookEventModel",
    "HouseholdModel",
    "HouseholdMemberModel",
    "AdminAuditEventModel",
    "SnapshotModel",
    "ConsentModel",
    "TokenBlacklist",
    "DocumentModel",
    "ScenarioModel",
    "BankingConsentModel",
    "ExternalDataSourceModel",
    "MagicLinkTokenModel",
]
