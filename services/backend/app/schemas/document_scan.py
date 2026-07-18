"""Schema for document scan confirmation — syncs extracted data to backend profile.

Used by POST /api/v1/profiles/{profile_id}/scan-confirmation.
Mobile sends confirmed extraction fields after user reviews OCR/Vision output.

See: MINT_FINAL_EXECUTION_SYSTEM.md §13.11 (Chantier 4)
"""

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StrictBool,
    field_validator,
    model_validator,
)
from pydantic.alias_generators import to_camel
from typing import Annotated, List, Literal, Optional, Union
from datetime import date, datetime, timezone
from enum import Enum
from uuid import UUID


class DocumentType(str, Enum):
    """Supported document types for scanning."""
    lpp_certificate = "lpp_certificate"
    avs_extract = "avs_extract"
    avs_official_pension = "avs_official_pension"
    tax_declaration = "tax_declaration"
    salary_certificate = "salary_certificate"
    payslip = "payslip"
    lease_contract = "lease_contract"
    lpp_plan = "lpp_plan"
    insurance_contract = "insurance_contract"
    # Mobile-originated types (unified contract)
    pillar_3a_attestation = "pillar_3a_attestation"
    pillar_3a_beneficiary_clause = "pillar_3a_beneficiary_clause"
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
        description="Base64-encoded document (JPEG, PNG, or PDF)",
    )
    canton: Optional[str] = Field(
        None,
        description="User's canton (helps contextualize fiscal documents)",
    )
    language_hint: Optional[str] = Field(
        None,
        description="Expected language: fr, de, it",
    )
    subject_kind: Optional[Literal["self", "manualPartner"]] = Field(
        None,
        description="Owner boundary for LPP extraction; legacy callers default to self",
    )
    receipt_id: Optional[UUID] = Field(
        None,
        description="Active manual-partner accountability receipt",
    )


class Pillar3aBeneficiaryExactDatesV1(BaseModel):
    """Institution-attested exact chronology for one 3a contract."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        extra="forbid",
    )

    kind: Literal["exactDates"]
    designation_effective_date: Optional[date]
    last_assignment_modification_date: Optional[date]

    @field_validator(
        "designation_effective_date",
        "last_assignment_modification_date",
        mode="before",
    )
    @classmethod
    def require_canonical_civil_date(cls, value):
        if value is None:
            return value
        if not isinstance(value, str) or len(value) != 10:
            raise ValueError("civil date must be canonical YYYY-MM-DD")
        try:
            parsed = date.fromisoformat(value)
        except ValueError as exc:
            raise ValueError("civil date must be canonical YYYY-MM-DD") from exc
        if parsed.isoformat() != value:
            raise ValueError("civil date must be canonical YYYY-MM-DD")
        return parsed

    @model_validator(mode="after")
    def require_at_least_one_attested_date(self):
        if (
            self.designation_effective_date is None
            and self.last_assignment_modification_date is None
        ):
            raise ValueError("at least one institution-attested date is required")
        return self


class Pillar3aBeneficiaryAttestedRegimeV1(BaseModel):
    """Institution-attested chronology regime when exact dates are unavailable."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        extra="forbid",
    )

    kind: Literal["attestedRegime"]
    regime: Literal["pre20270601", "post20270601"]


Pillar3aBeneficiaryTemporalBasisV1 = Annotated[
    Union[
        Pillar3aBeneficiaryExactDatesV1,
        Pillar3aBeneficiaryAttestedRegimeV1,
    ],
    Field(discriminator="kind"),
]


class Pillar3aBeneficiaryAuthorityVisionPayloadV1(BaseModel):
    """Strict private contract accepted from Vision before local review."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        extra="forbid",
    )

    document_kind: Literal[
        "confirmationInstitutionnelle",
        "avenantAccuse",
        "formulaireDesignationAccuse",
    ]
    source_date: date
    legal_year: int = Field(strict=True, ge=1900, le=9999)
    institution_attested: StrictBool
    contract_scoped: StrictBool
    temporal_basis: Pillar3aBeneficiaryTemporalBasisV1
    confidence: Literal["high"]

    @field_validator("source_date", mode="before")
    @classmethod
    def require_canonical_source_date(cls, value):
        if not isinstance(value, str) or len(value) != 10:
            raise ValueError("source date must be canonical YYYY-MM-DD")
        try:
            parsed = date.fromisoformat(value)
        except ValueError as exc:
            raise ValueError("source date must be canonical YYYY-MM-DD") from exc
        if parsed.isoformat() != value:
            raise ValueError("source date must be canonical YYYY-MM-DD")
        return parsed

    @model_validator(mode="after")
    def require_positive_authority_attestations(self):
        if not self.institution_attested or not self.contract_scoped:
            raise ValueError("exact institutional contract authority is required")
        if isinstance(self.temporal_basis, Pillar3aBeneficiaryExactDatesV1):
            attested_dates = (
                self.temporal_basis.designation_effective_date,
                self.temporal_basis.last_assignment_modification_date,
            )
            if any(
                value is not None and value > self.source_date
                for value in attested_dates
            ):
                raise ValueError("attested date cannot follow the source date")
        elif (
            self.temporal_basis.regime == "post20270601"
            and self.source_date < date(2027, 6, 1)
        ):
            raise ValueError("post-reform authority predates the reform")
        return self


class Pillar3aBeneficiaryAuthorityCandidateV1(BaseModel):
    """Review-only metadata for one exact institutional 3a authority document."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        extra="forbid",
    )

    schema_version: Literal[1]
    document_authority_id: UUID
    document_kind: Literal[
        "confirmationInstitutionnelle",
        "avenantAccuse",
        "formulaireDesignationAccuse",
    ]
    source_date: date
    legal_year: int = Field(strict=True, ge=1900, le=9999)
    institution_attested: Literal[True]
    contract_scoped: Literal[True]
    temporal_basis: Pillar3aBeneficiaryTemporalBasisV1
    needs_review: Literal[True]


class PremierEclairageRequest(BaseModel):
    """Request for document-specific premier éclairage generation (DOC-07).

    After document extraction, sends extracted fields to generate a
    personalized 4-layer insight using the MINT insight engine.
    """
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    document_type: DocumentType
    extracted_fields: List[ExtractedFieldConfirmation]
    overall_confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Overall extraction confidence (0-1)",
    )
    plan_type: Optional[str] = Field(
        None,
        description="LPP plan type: legal, surobligatoire, 1e",
    )
    plan_type_warning: Optional[str] = Field(
        None,
        description="Warning for 1e plans",
    )
    canton: Optional[str] = Field(
        None,
        description="User's canton for regional context",
    )


class PremierEclairageResponse(BaseModel):
    """Response with 4-layer premier éclairage from document data (DOC-07).

    Structure follows the MINT 4-layer insight engine:
    1. Factual extraction (what the document says)
    2. Human translation (what it means in plain language)
    3. Personal perspective (what it implies for YOU)
    4. Questions to ask (before signing/acting)
    """
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    factual_extraction: str = Field(
        ...,
        description="Layer 1: key facts extracted from the document",
    )
    human_translation: str = Field(
        ...,
        description="Layer 2: plain language explanation, no jargon",
    )
    personal_perspective: str = Field(
        ...,
        description="Layer 3: what this implies for the user personally",
    )
    questions_to_ask: List[str] = Field(
        ...,
        description="Layer 4: questions to ask before signing/acting",
    )
    disclaimer: str = Field(
        ...,
        description="Mandatory LSFin disclaimer",
    )
    sources: List[str] = Field(
        ...,
        description="Legal references (LPP art. X, LIFD art. Y, etc.)",
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
    extraction_status: str = Field(
        "success",
        description=(
            "Extraction outcome: 'success' (fields extracted and validated), "
            "'partial' (some fields extracted, some rejected by validation), "
            "'no_fields_found' (Claude parsed OK but returned zero fields — "
            "document unreadable or empty), or 'parse_error' (Claude returned "
            "non-JSON). Flutter surfaces a targeted error for each status."
        ),
    )
