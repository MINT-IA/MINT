"""
Consent Manager — nLPD-compliant banking consent management.

Rules (nLPD / Nouvelle Loi sur la Protection des Donnees):
    - Consentement explicite (jamais pre-coche)
    - Granulaire : choix des scopes (comptes, soldes, transactions)
    - Duree maximale : 90 jours (renouvelable)
    - Revocable a tout moment
    - Journal d'audit pour tracer toutes les operations

Sprint S14 — Open Banking infrastructure.
Updated P7 — Migrated from in-memory to DB persistence (BankingConsentModel).
"""

import json
import logging
from dataclasses import dataclass
from typing import Dict, List, Optional
from datetime import datetime, timedelta, timezone
import uuid

from sqlalchemy.orm import Session

from app.models.audit_event import AuditEventModel
from app.models.banking_consent import BankingConsentModel

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAX_CONSENT_DURATION_DAYS = 90
VALID_SCOPES = ["accounts", "balances", "transactions"]


# ---------------------------------------------------------------------------
# Data classes (public API — unchanged for backward compatibility)
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
# Helpers
# ---------------------------------------------------------------------------

def _model_to_consent(model: BankingConsentModel) -> BankingConsent:
    """Convert a DB model to a BankingConsent dataclass."""
    return BankingConsent(
        consent_id=model.id,
        user_id=model.user_id,
        bank_id=model.bank_id,
        bank_name=model.bank_name,
        scopes=json.loads(model.scopes),
        granted_at=model.granted_at.isoformat() + "Z",
        expires_at=model.expires_at.isoformat() + "Z",
        revoked=model.status == "revoked",
        revoked_at=model.revoked_at.isoformat() + "Z" if model.revoked_at else None,
    )


# ---------------------------------------------------------------------------
# Manager (DB-backed, with in-memory fallback for tests)
# ---------------------------------------------------------------------------

class ConsentManager:
    """Manage banking consents per nLPD requirements.

    Rules:
        - Consentement explicite (jamais pre-coche)
        - Granulaire : choix des scopes par la personne utilisatrice
        - Duree maximale : 90 jours (renouvelable)
        - Revocable a tout moment
        - Journal d'audit via admin_audit_events table

    Storage: DB-backed via BankingConsentModel.
    Falls back to in-memory dict when db=None (tests).
    """

    def __init__(self):
        self._fallback_consents: Dict[str, BankingConsent] = {}
        self._audit_log: List[AuditLogEntry] = []

    @staticmethod
    def _log_audit(
        db: Session,
        user_id: str,
        event_type: str,
        details: dict,
    ) -> None:
        """Persist an audit entry to the audit_events table."""
        db.add(AuditEventModel(
            user_id=user_id,
            event_type=event_type,
            status="success",
            source="open_banking",
            details_json=json.dumps(details),
        ))
        # Committed by the caller's transaction (no extra commit).

    def create_consent(
        self,
        user_id: str,
        bank_id: str,
        bank_name: str,
        scopes: List[str],
        db: Optional[Session] = None,
    ) -> BankingConsent:
        """Create a new banking consent.

        Args:
            user_id: Identifier of the consenting person.
            bank_id: Bank identifier (e.g. "ubs").
            bank_name: Human-readable bank name.
            scopes: List of requested scopes (must be subset of VALID_SCOPES).
            db: SQLAlchemy session (None = in-memory fallback for tests).

        Returns:
            BankingConsent object.

        Raises:
            ValueError: If scopes are invalid or empty.
        """
        if not scopes:
            raise ValueError("Au moins un scope est requis pour creer un consentement.")
        invalid = [s for s in scopes if s not in VALID_SCOPES]
        if invalid:
            raise ValueError(
                f"Scopes invalides : {invalid}. Scopes acceptes : {VALID_SCOPES}"
            )

        now = datetime.now(timezone.utc)
        consent_id = str(uuid.uuid4())
        expires_at = now + timedelta(days=MAX_CONSENT_DURATION_DAYS)

        if db is not None:
            model = BankingConsentModel(
                id=consent_id,
                user_id=user_id,
                bank_id=bank_id,
                bank_name=bank_name,
                scopes=json.dumps(scopes),
                status="active",
                granted_at=now,
                expires_at=expires_at,
            )
            db.add(model)
            self._log_audit(db, user_id, "consent_created", {
                "consent_id": consent_id,
                "bank_id": bank_id,
                "bank_name": bank_name,
                "scopes": scopes,
            })
            try:
                db.commit()
                db.refresh(model)
            except Exception:
                db.rollback()
                raise
            logger.info("Banking consent created: %s for %s", consent_id, bank_name)
            return _model_to_consent(model)

        # In-memory fallback (tests)
        consent = BankingConsent(
            consent_id=consent_id,
            user_id=user_id,
            bank_id=bank_id,
            bank_name=bank_name,
            scopes=scopes,
            granted_at=now.isoformat() + "Z",
            expires_at=expires_at.isoformat() + "Z",
        )
        self._fallback_consents[consent_id] = consent
        self._audit_log.append(AuditLogEntry(
            timestamp=now.isoformat() + "Z",
            user_id=user_id,
            consent_id=consent_id,
            action="created",
            details=f"Consentement cree pour {bank_name} — scopes: {scopes}",
        ))
        return consent

    def revoke_consent(
        self, consent_id: str, db: Optional[Session] = None
    ) -> bool:
        """Revoke an existing consent.

        Returns:
            True if revoked successfully, False if consent not found.
        """
        now = datetime.now(timezone.utc)

        if db is not None:
            model = db.query(BankingConsentModel).filter_by(id=consent_id).first()
            if not model:
                return False
            model.status = "revoked"
            model.revoked_at = now
            self._log_audit(db, model.user_id, "consent_revoked", {
                "consent_id": consent_id,
                "bank_name": model.bank_name,
            })
            try:
                db.commit()
            except Exception:
                db.rollback()
                raise
            logger.info("Banking consent revoked: %s", consent_id)
            return True

        # In-memory fallback
        consent = self._fallback_consents.get(consent_id)
        if not consent:
            return False
        consent.revoked = True
        consent.revoked_at = now.isoformat() + "Z"
        self._audit_log.append(AuditLogEntry(
            timestamp=now.isoformat() + "Z",
            user_id=consent.user_id,
            consent_id=consent_id,
            action="revoked",
            details=f"Consentement revoque pour {consent.bank_name}",
        ))
        return True

    def get_active_consents(
        self, user_id: str, db: Optional[Session] = None
    ) -> List[BankingConsent]:
        """Get all active (non-revoked, non-expired) consents for a person."""
        now = datetime.now(timezone.utc)

        if db is not None:
            models = (
                db.query(BankingConsentModel)
                .filter_by(user_id=user_id, status="active")
                .filter(BankingConsentModel.expires_at > now)
                .all()
            )
            return [_model_to_consent(m) for m in models]

        # In-memory fallback
        now_str = now.isoformat() + "Z"
        return [
            c
            for c in self._fallback_consents.values()
            if c.user_id == user_id
            and not c.revoked
            and c.expires_at > now_str
        ]

    def is_consent_valid(
        self, consent_id: str, db: Optional[Session] = None
    ) -> bool:
        """Check if a consent is currently valid (not revoked, not expired)."""
        now = datetime.now(timezone.utc)

        if db is not None:
            model = db.query(BankingConsentModel).filter_by(id=consent_id).first()
            if not model:
                return False
            expires = model.expires_at.replace(tzinfo=timezone.utc) if model.expires_at.tzinfo is None else model.expires_at
            return model.status == "active" and expires > now

        # In-memory fallback
        consent = self._fallback_consents.get(consent_id)
        if not consent or consent.revoked:
            return False
        return consent.expires_at > now.isoformat() + "Z"

    def get_consent(
        self, consent_id: str, db: Optional[Session] = None
    ) -> Optional[BankingConsent]:
        """Retrieve a consent by its identifier."""
        if db is not None:
            model = db.query(BankingConsentModel).filter_by(id=consent_id).first()
            return _model_to_consent(model) if model else None

        return self._fallback_consents.get(consent_id)

    def get_consent_audit_log(
        self, user_id: str, db: Optional[Session] = None
    ) -> List[dict]:
        """Get the audit trail for a person's consents.

        Returns:
            List of audit log entries as dicts.
        """
        if db is not None:
            rows = (
                db.query(AuditEventModel)
                .filter_by(user_id=user_id, source="open_banking")
                .order_by(AuditEventModel.created_at)
                .all()
            )
            return [
                {
                    "timestamp": row.created_at.isoformat() + "Z",
                    "action": row.event_type,
                    "details": row.details_json,
                }
                for row in rows
            ]

        # In-memory fallback
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
