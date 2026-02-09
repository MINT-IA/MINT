"""
Consent Manager — nLPD-compliant banking consent management.

Rules (nLPD / Nouvelle Loi sur la Protection des Donnees):
    - Consentement explicite (jamais pre-coche)
    - Granulaire : choix des scopes (comptes, soldes, transactions)
    - Duree maximale : 90 jours (renouvelable)
    - Revocable a tout moment
    - Journal d'audit pour tracer toutes les operations

Sprint S14 — Open Banking infrastructure.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import uuid


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAX_CONSENT_DURATION_DAYS = 90
VALID_SCOPES = ["accounts", "balances", "transactions"]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class BankingConsent:
    """Represents a banking data access consent."""

    consent_id: str
    user_id: str
    bank_id: str  # e.g. "ubs", "postfinance", "raiffeisen"
    bank_name: str
    scopes: List[str]  # ["accounts", "balances", "transactions"]
    granted_at: str  # ISO datetime
    expires_at: str  # ISO datetime (max 90 days per PSD2/bLink)
    revoked: bool = False
    revoked_at: Optional[str] = None


@dataclass
class AuditLogEntry:
    """An entry in the consent audit trail."""

    timestamp: str  # ISO datetime
    user_id: str
    consent_id: str
    action: str  # "created", "revoked", "accessed", "expired"
    details: str


# ---------------------------------------------------------------------------
# Manager
# ---------------------------------------------------------------------------

class ConsentManager:
    """Manage banking consents per nLPD requirements.

    Rules:
        - Consentement explicite (jamais pre-coche)
        - Granulaire : choix des scopes par la personne utilisatrice
        - Duree maximale : 90 jours (renouvelable)
        - Revocable a tout moment
        - Journal d'audit pour tracer toutes les operations

    Storage: In-memory (dict) for MVP. Production will use database.
    """

    def __init__(self):
        self._consents: Dict[str, BankingConsent] = {}
        self._audit_log: List[AuditLogEntry] = []

    def create_consent(
        self,
        user_id: str,
        bank_id: str,
        bank_name: str,
        scopes: List[str],
    ) -> BankingConsent:
        """Create a new banking consent.

        Args:
            user_id: Identifier of the consenting person.
            bank_id: Bank identifier (e.g. "ubs").
            bank_name: Human-readable bank name.
            scopes: List of requested scopes (must be subset of VALID_SCOPES).

        Returns:
            BankingConsent object.

        Raises:
            ValueError: If scopes are invalid or empty.
        """
        # Validate scopes
        if not scopes:
            raise ValueError("Au moins un scope est requis pour creer un consentement.")
        invalid = [s for s in scopes if s not in VALID_SCOPES]
        if invalid:
            raise ValueError(
                f"Scopes invalides : {invalid}. Scopes acceptes : {VALID_SCOPES}"
            )

        now = datetime.utcnow()
        consent = BankingConsent(
            consent_id=str(uuid.uuid4()),
            user_id=user_id,
            bank_id=bank_id,
            bank_name=bank_name,
            scopes=scopes,
            granted_at=now.isoformat() + "Z",
            expires_at=(now + timedelta(days=MAX_CONSENT_DURATION_DAYS)).isoformat() + "Z",
        )

        self._consents[consent.consent_id] = consent

        self._audit_log.append(
            AuditLogEntry(
                timestamp=now.isoformat() + "Z",
                user_id=user_id,
                consent_id=consent.consent_id,
                action="created",
                details=f"Consentement cree pour {bank_name} — scopes: {scopes}",
            )
        )

        return consent

    def revoke_consent(self, consent_id: str) -> bool:
        """Revoke an existing consent.

        Args:
            consent_id: Consent identifier to revoke.

        Returns:
            True if revoked successfully, False if consent not found.
        """
        consent = self._consents.get(consent_id)
        if not consent:
            return False

        now = datetime.utcnow()
        consent.revoked = True
        consent.revoked_at = now.isoformat() + "Z"

        self._audit_log.append(
            AuditLogEntry(
                timestamp=now.isoformat() + "Z",
                user_id=consent.user_id,
                consent_id=consent_id,
                action="revoked",
                details=f"Consentement revoque pour {consent.bank_name}",
            )
        )

        return True

    def get_active_consents(self, user_id: str) -> List[BankingConsent]:
        """Get all active (non-revoked, non-expired) consents for a person.

        Args:
            user_id: Person's identifier.

        Returns:
            List of active BankingConsent objects.
        """
        now = datetime.utcnow().isoformat() + "Z"
        return [
            c
            for c in self._consents.values()
            if c.user_id == user_id
            and not c.revoked
            and c.expires_at > now
        ]

    def is_consent_valid(self, consent_id: str) -> bool:
        """Check if a consent is currently valid (not revoked, not expired).

        Args:
            consent_id: Consent identifier.

        Returns:
            True if valid, False otherwise.
        """
        consent = self._consents.get(consent_id)
        if not consent:
            return False

        if consent.revoked:
            return False

        now = datetime.utcnow().isoformat() + "Z"
        if consent.expires_at <= now:
            return False

        return True

    def get_consent(self, consent_id: str) -> Optional[BankingConsent]:
        """Retrieve a consent by its identifier.

        Args:
            consent_id: Consent identifier.

        Returns:
            BankingConsent or None.
        """
        return self._consents.get(consent_id)

    def get_consent_audit_log(self, user_id: str) -> List[dict]:
        """Get the audit trail for a person's consents.

        Args:
            user_id: Person's identifier.

        Returns:
            List of audit log entries as dicts.
        """
        return [
            {
                "timestamp": entry.timestamp,
                "consentId": entry.consent_id,
                "action": entry.action,
                "details": entry.details,
            }
            for entry in self._audit_log
            if entry.user_id == user_id
        ]
