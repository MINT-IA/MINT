"""Canonical Pydantic v2 contract: DocumentUnderstandingResult.

v2.7 Phase 28 / DOC-01.

Single source of truth for "what MINT understood about this document".
Shared by coach + document scanner + extraction review screen. The
backend computes `render_mode` (confirm/ask/narrative/reject) — the
internal `processing_mode` never leaks to the client.

This is an INTERNAL contract surfaced via the existing `/extract-vision`
endpoint when the `DOCUMENTS_V2_ENABLED` feature flag is on. There is
NO public `/documents/understand` endpoint (architecture astronaute
rejected after 4-expert challenge of external audit).
"""
from __future__ import annotations

from enum import Enum
from typing import Any, Dict, List, Literal, Optional, Union

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

# Re-export ConfidenceLevel from the existing scan schema so callers have
# a single import. New code should import from here; legacy code keeps
# importing from app.schemas.document_scan.
from app.schemas.document_scan import ConfidenceLevel  # noqa: F401


class DocumentClass(str, Enum):
    """Canonical document classes recognised by the fused Vision call."""

    lpp_certificate = "lpp_certificate"
    salary_certificate = "salary_certificate"
    avs_extract = "avs_extract"
    pillar_3a_attestation = "pillar_3a_attestation"
    tax_declaration = "tax_declaration"
    payslip = "payslip"
    lease = "lease"
    mortgage_attestation = "mortgage_attestation"
    insurance_policy = "insurance_policy"
    lamal_statement = "lamal_statement"
    bank_statement = "bank_statement"
    non_financial = "non_financial"
    unknown = "unknown"


class RenderMode(str, Enum):
    """One of 4 opaque render modes the client switches its UI on."""

    confirm = "confirm"      # high confidence, ask user to confirm extracted fields
    ask = "ask"              # mostly confident, need 1-2 confirmations
    narrative = "narrative"  # cannot structure, narrate what it implies
    reject = "reject"        # not a financial document or unparseable


class ExtractionStatus(str, Enum):
    """Exhaustive outcomes from the understand pipeline."""

    success = "success"
    partial = "partial"
    no_fields_found = "no_fields_found"
    parse_error = "parse_error"
    encrypted_needs_password = "encrypted_needs_password"
    non_financial = "non_financial"
    rejected_local = "rejected_local"


class FieldStatus(str, Enum):
    """Validation status of an extracted field.

    v2.7 Phase 29-04 / PRIV-08: the legacy ``confirmed`` auto-status was
    removed. Per LSFin art. 7-10, an auto-validated numeric output equates
    to implicit financial advice — the user MUST promote a field to
    ``user_validated`` via an explicit action (tap or swipe on the
    BatchValidationBubble). Every Vision extraction now persists as
    ``needs_review`` regardless of model confidence (including 0.99).

    ``human_review`` is a NumericSanity flag — the value passed the bound
    but needs an extra eyes-on step (e.g. avoir_lpp > 5M CHF). The field
    still persists, still starts at ``needs_review``, and surfaces a
    secondary ``humanReviewBadge`` in the UI.
    """

    needs_review = "needs_review"
    user_validated = "user_validated"  # user tapped "correct" or swipe-confirmed
    corrected_by_user = "corrected_by_user"  # user edited the value
    rejected = "rejected"  # user marked the field wrong
    human_review = "human_review"  # NumericSanity flag, distinct from reject


class ExtractedField(BaseModel):
    """A single extracted field with provenance."""

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    field_name: str
    value: Union[float, int, str, bool, None] = None
    confidence: ConfidenceLevel = ConfidenceLevel.medium
    source_text: str = ""
    # v2.7 Phase 29-04 / PRIV-08: every field starts as needs_review.
    # Writes with status=confirmed are rejected at the runtime guard
    # (see ``_enforce_no_auto_confirm`` in document_vision_service).
    status: FieldStatus = FieldStatus.needs_review
    human_review_flag: bool = False  # set by NumericSanity when disposition=human_review


class CoherenceWarning(BaseModel):
    """Cross-field validation warning."""

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    code: str
    message: str
    fields: List[str] = Field(default_factory=list)


class CommitmentSuggestion(BaseModel):
    """Implementation intention proposed by the narrative path."""

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    when: Optional[str] = None
    where: Optional[str] = None
    if_then: Optional[str] = None
    action_label: Optional[str] = None


class FieldDiff(BaseModel):
    """A single field's change between current upload and previous one."""

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    old: Union[float, int, str, bool, None] = None
    new: Union[float, int, str, bool, None] = None
    delta_pct: Optional[float] = None


class DocumentUnderstandingResult(BaseModel):
    """Canonical contract for what MINT understood about a document.

    Discriminated by `document_class`; the per-class field shapes are
    enforced in `extracted_fields` (open-ended list) rather than via a
    Union to keep the schema serialisable to JSON for tool_use.
    """

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    schema_version: Literal["1.0"] = "1.0"

    # Classification
    document_class: DocumentClass
    subtype: Optional[str] = None
    issuer_guess: Optional[str] = None
    classification_confidence: float = Field(default=0.0, ge=0.0, le=1.0)

    # Extraction
    extracted_fields: List[ExtractedField] = Field(default_factory=list)
    overall_confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    extraction_status: ExtractionStatus

    # LPP-specific (kept for backward compat with VisionExtractionResponse)
    plan_type: Optional[str] = None
    plan_type_warning: Optional[str] = None
    coherence_warnings: List[CoherenceWarning] = Field(default_factory=list)

    # Render decision (computed by backend, opaque to caller)
    render_mode: RenderMode

    # Free text — MUST pass through ComplianceGuard before return
    summary: Optional[str] = None
    questions_for_user: List[str] = Field(default_factory=list, max_length=3)
    narrative: Optional[str] = None
    commitment_suggestion: Optional[CommitmentSuggestion] = None

    # Third-party detection (silent flag, nLPD gate is phase 29)
    third_party_detected: bool = False
    third_party_name: Optional[str] = None

    # Document Memory differential
    fingerprint: Optional[str] = None
    diff_from_previous: Optional[Dict[str, FieldDiff]] = None

    # PDF preflight transparency
    pages_processed: Optional[int] = None
    pages_total: Optional[int] = None
    pdf_warning: Optional[str] = None

    # Cost accounting
    cost_tokens_in: int = 0
    cost_tokens_out: int = 0

    # v2.7 Phase 29-04 — VisionGuard + NumericSanity telemetry.
    guard_blocked: bool = False
    guard_flagged_categories: List[str] = Field(default_factory=list)
    guard_reason: Optional[str] = None
    guard_cost_usd: float = 0.0
    sanity_rejected_fields: List[str] = Field(default_factory=list)
    sanity_human_review_fields: List[str] = Field(default_factory=list)


__all__ = [
    "ConfidenceLevel",
    "DocumentClass",
    "RenderMode",
    "ExtractionStatus",
    "FieldStatus",
    "ExtractedField",
    "CoherenceWarning",
    "CommitmentSuggestion",
    "FieldDiff",
    "DocumentUnderstandingResult",
]
