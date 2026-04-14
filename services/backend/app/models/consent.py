"""
Consent model — granular ISO/IEC 29184:2020 consent receipts per user.

v2.7 Phase 29 / PRIV-01 — replaces legacy single-row "enabled" checkbox with one
row per (user, purpose) grant. Each row carries a signed receipt JSON that is
hash-chained (Merkle) to the previous row across all purposes for the user —
tampering with any historical row breaks the chain.

Four purposes (nLPD art. 6 al. 6 requires granular per-purpose consent):
    - vision_extraction   : LLM Vision reads user-uploaded documents.
    - persistence_365d    : Encrypted evidence_text retained 365 days.
    - transfer_us_anthropic : Document content sent to Anthropic US API
                              (deprecated once Phase 29-06 Bedrock EU flips).
    - couple_projection   : Third-party (partner) data used for couple
                            projections — triggers D-PRIV-02 declaration.

Legacy columns (`consent_type`, `enabled`) are preserved for audit; new
granular flow uses `purpose_category` + `receipt_json` + `signature`.

Sources:
    - nLPD art. 6 al. 6 (granular consent per purpose)
    - nLPD art. 7 (Privacy by Design)
    - LSFin art. 3
    - ISO/IEC 29184:2020 (Online privacy notices and consent)
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    String,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.types import JSON

from app.core.database import Base


# Portable JSONB (JSONB on Postgres, JSON on SQLite).
JSONType = JSON().with_variant(JSONB(), "postgresql")


class ConsentModel(Base):
    """Consent state — one row per (user_id, purpose_category) grant.

    v2.7 PRIV-01: granular receipts + Merkle chain.

    Legacy Phase 23 columns `consent_type` / `enabled` remain for backward-compat
    but new code MUST use `purpose_category` / `revoked_at`. Granted rows have
    `revoked_at IS NULL`; revoked rows have a timestamp.
    """
    __tablename__ = "consents"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, nullable=False, index=True)

    # --- Legacy (Phase 23) — deprecated but kept for audit trail --------------
    consent_type = Column(String, nullable=True)
    enabled = Column(Boolean, default=False, nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # --- v2.7 PRIV-01 granular receipt fields --------------------------------
    # `receipt_id` is the stable external identifier returned to clients so
    # user_id never appears in receipt URLs or audit logs.
    receipt_id = Column(String(36), unique=True, nullable=True, index=True)
    purpose_category = Column(String(64), nullable=True, index=True)
    policy_version = Column(String(32), nullable=True)
    policy_hash = Column(String(64), nullable=True)  # sha256 hex
    consent_timestamp = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)
    receipt_json = Column(JSONType, nullable=True)
    prev_hash = Column(String(64), nullable=True)  # sha256 hex of prev signature, null on genesis
    signature = Column(String(64), nullable=True)  # HMAC-SHA256 hex

    __table_args__ = (
        # Legacy index preserved (now non-unique because we may have many rows
        # per (user, purpose) over time — one per grant/revoke cycle).
        Index("ix_consents_user_type", "user_id", "consent_type"),
        Index("ix_consents_user_purpose", "user_id", "purpose_category", "revoked_at"),
    )
