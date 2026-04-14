"""Pydantic schemas for granular consent receipts (ISO/IEC 29184:2020).

v2.7 Phase 29 / PRIV-01.
"""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class ConsentPurpose(str, Enum):
    """The 4 granular purposes enforced per nLPD art. 6 al. 6."""

    VISION_EXTRACTION = "vision_extraction"
    PERSISTENCE_365D = "persistence_365d"
    TRANSFER_US_ANTHROPIC = "transfer_us_anthropic"
    COUPLE_PROJECTION = "couple_projection"
    # v2.7 Phase 29 / PRIV-02: nominative declaration per uploaded doc_hash.
    # Unlike the 4 global purposes above, this one is granted *per-upload* and
    # carries extra fields (subjectName, subjectRole, declaredDocHash,
    # declaredFromIp) inside receipt_json.
    THIRD_PARTY_ATTESTATION = "third_party_attestation"


class _Base(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        from_attributes=True,
    )


class ConsentGrantRequest(_Base):
    purpose: ConsentPurpose
    policy_version: str = Field(..., description="Privacy policy version, e.g. v2.3.0")


class ConsentGrantNominativeRequest(_Base):
    """PRIV-02: opposable declaration for a detected third party on an upload."""

    subject_name: str = Field(..., min_length=1, max_length=200)
    doc_hash: str = Field(..., min_length=16, max_length=128)
    subject_role: str = Field(
        default="declared_other",
        pattern=r"^(declared_partner|declared_other)$",
    )
    policy_version: str = Field(default="v2.3.0")


class ConsentReceiptOut(_Base):
    receipt_id: str
    purpose: ConsentPurpose
    policy_version: str
    policy_hash: str
    consent_timestamp: datetime
    revoked_at: Optional[datetime] = None
    prev_hash: Optional[str] = None
    signature: str
    receipt_json: Dict[str, Any]


class ConsentListResponse(_Base):
    consents: List[ConsentReceiptOut]
    chain_valid: bool
    chain_break_receipt_id: Optional[str] = None


class ConsentRevokeResponse(_Base):
    receipt_id: str
    purpose: ConsentPurpose
    revoked_at: datetime
    cascade_scheduled: bool = False
    cascade_eta_days: int = 0
    message: str
