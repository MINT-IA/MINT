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
