"""Schema for document scan confirmation — syncs extracted data to backend profile.

Used by POST /api/v1/profiles/{profile_id}/scan-confirmation.
Mobile sends confirmed extraction fields after user reviews OCR/Vision output.

See: MINT_FINAL_EXECUTION_SYSTEM.md §13.11 (Chantier 4)
"""

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel
from typing import List, Optional, Union
from datetime import datetime, timezone
from enum import Enum


class DocumentType(str, Enum):
    """Supported document types for scanning."""
    lpp_certificate = "lpp_certificate"
    avs_extract = "avs_extract"
    tax_declaration = "tax_declaration"
    salary_certificate = "salary_certificate"
    payslip = "payslip"
    lease_contract = "lease_contract"
    lpp_plan = "lpp_plan"
    insurance_contract = "insurance_contract"
    # Mobile-originated types (unified contract)
    pillar_3a_attestation = "pillar_3a_attestation"
    mortgage_attestation = "mortgage_attestation"
    insurance_policy = "insurance_policy"
    lease = "lease"
    lamal_statement = "lamal_statement"
    other = "other"


class ConfidenceLevel(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"


class LppPlanType(str, Enum):
    """LPP plan type classification (DOC-04).

    - legal: minimum LPP (taux conversion 6.8%)
    - surobligatoire: enveloping plan (higher contributions, may have lower conversion)
    - plan_1e: individual investment plan (NO guaranteed conversion rate)
    """
    legal = "legal"
    surobligatoire = "surobligatoire"
    plan_1e = "1e"


class ExtractedFieldConfirmation(BaseModel):
    """A single confirmed extracted field."""
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    field_name: str = Field(..., description="Profile field name (e.g., avoirLppTotal)")
    value: Union[float, str, int, bool] = Field(..., description="Confirmed value")
    confidence: ConfidenceLevel = ConfidenceLevel.medium
    source_text: Optional[str] = Field(
        None,
        description="Original text from document (for audit, not stored long-term)",
    )


class DocumentScanConfirmation(BaseModel):
    """Payload from mobile after user confirms a document scan extraction."""
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    document_type: DocumentType
    confirmed_fields: List[ExtractedFieldConfirmation]
    overall_confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Overall extraction confidence (0-1)",
    )
    extraction_method: str = Field(
        "ocr_mlkit",
        description="How the data was extracted: ocr_mlkit, claude_vision, manual",
    )
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class DocumentScanResponse(BaseModel):
    """Response after scan confirmation is processed."""
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    status: str = "confirmed"
    fields_updated: int = 0
    confidence_delta: float = 0.0
    message: str = "Scan data synced to profile"


class DocumentClassificationResult(BaseModel):
    """Result of pre-extraction document classification (DOC-10).

    Determines whether an uploaded image is a Swiss financial document
    before running full extraction.
    """
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    is_financial: bool = Field(..., description="Whether document is a Swiss financial document")
    detected_type: Optional[str] = Field(None, description="Detected document type if financial")
    confidence: ConfidenceLevel = ConfidenceLevel.medium
    rejection_reason: Optional[str] = Field(
        None,
        description="Reason for rejection (set when is_financial=False)",
    )


class VisionExtractionRequest(BaseModel):
    """Request to extract data from a document image using Claude Vision."""
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    document_type: DocumentType
    image_base64: str = Field(
        ...,
        max_length=5_000_000,  # ~3.75 MB raw image (base64 overhead ~33%)
        description="Base64-encoded document image (JPEG/PNG)",
    )
    canton: Optional[str] = Field(
        None,
        description="User's canton (helps contextualize fiscal documents)",
    )
    language_hint: Optional[str] = Field(
        None,
        description="Expected language: fr, de, it",
    )


class VisionExtractionResponse(BaseModel):
    """Response from Claude Vision document extraction."""
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    document_type: DocumentType
    extracted_fields: List[ExtractedFieldConfirmation]
    overall_confidence: float
    extraction_method: str = "claude_vision"
    raw_analysis: Optional[str] = Field(
        None,
        description="Claude's natural language analysis of the document",
    )
    plan_type: Optional[str] = Field(
        None,
        description="LPP plan type: legal, surobligatoire, 1e (DOC-04)",
    )
    plan_type_warning: Optional[str] = Field(
        None,
        description="Warning message for 1e plans (no guaranteed conversion rate)",
    )
    coherence_warnings: List[str] = Field(
        default_factory=list,
        description="Cross-field coherence warnings (DOC-05)",
    )
