"""Pydantic contracts for the isolated partner-accountability lifecycle."""

from __future__ import annotations

from datetime import datetime
from typing import List, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator
from pydantic.alias_generators import to_camel


SUBJECT_KIND = "manualPartner"
ACCOUNTABILITY_KIND = "acting_user_partner_authorization_declaration"
PURPOSE = "one_shot_lpp_extraction"

PartnerAccountabilityStatus = Literal["active", "stale", "expired", "revoked"]


class _CamelModel(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        extra="forbid",
    )


class PartnerAccountabilityReceiptCreate(_CamelModel):
    receipt_id: UUID
    subject_owner_token: SecretStr = Field(
        json_schema_extra={"format": "uuid", "minLength": 36, "maxLength": 36},
    )
    subject_kind: Literal["manualPartner"]
    accountability_kind: Literal[
        "acting_user_partner_authorization_declaration"
    ]
    purpose: Literal["one_shot_lpp_extraction"]
    notice_version: str = Field(min_length=1, max_length=128)
    policy_version: str = Field(min_length=1, max_length=128)

    @field_validator("receipt_id")
    @classmethod
    def require_uuid_v4(cls, value: UUID) -> UUID:
        if value.version != 4:
            raise ValueError("receiptId must be UUIDv4")
        return value

    @field_validator("subject_owner_token", mode="before")
    @classmethod
    def prevent_raw_owner_in_validation_errors(cls, value):
        # FastAPI includes rejected Pydantic input in 422 payloads. Normalize
        # non-strings here; the endpoint returns one sanitized stable error.
        return value if isinstance(value, str) else ""


class PartnerAccountabilityReceiptResponse(_CamelModel):
    receipt_id: UUID
    subject_kind: Literal["manualPartner"]
    accountability_kind: Literal[
        "acting_user_partner_authorization_declaration"
    ]
    purpose: Literal["one_shot_lpp_extraction"]
    notice_version: str
    policy_version: str
    declared_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    revoked_at: Optional[datetime] = None
    erased_at: Optional[datetime] = None
    status: PartnerAccountabilityStatus


class PartnerAccountabilityReceiptList(_CamelModel):
    receipts: List[PartnerAccountabilityReceiptResponse]
