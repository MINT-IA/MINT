"""Fail-closed Vision extraction for exact pillar-3a beneficiary authority."""

from __future__ import annotations

import json
from typing import Literal
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, StrictBool, model_validator

from app.core.config import settings
from app.schemas.document_scan import (
    Pillar3aBeneficiaryAuthorityCandidateV1,
    Pillar3aBeneficiaryAuthorityVisionPayloadV1,
)


class Pillar3aBeneficiaryAuthorityUnavailable(Exception):
    """The document did not establish the exact, reviewable authority contract."""


class _AuthorityClassification(BaseModel):
    model_config = ConfigDict(extra="forbid")

    is_financial: StrictBool
    detected_type: Literal["pillar_3a_beneficiary_clause"]
    confidence: Literal["high"]

    @model_validator(mode="after")
    def require_financial_document(self):
        if not self.is_financial:
            raise ValueError("exact financial authority is required")
        return self


_AUTHORITY_CLASSIFICATION_PROMPT = """Classify this Swiss pillar-3a document.

Return detected_type "pillar_3a_beneficiary_clause" only when the document is
issued or acknowledged by the 3a institution, is tied to one exact contract,
and attests the current beneficiary designation/order or a registered change.
A generic balance/contribution attestation, blank form, testament, user
declaration, legal text, or raw OCR is not authority for this type.

Return only strict JSON with exactly these keys:
{"is_financial": true, "detected_type": "pillar_3a_beneficiary_clause", "confidence": "high"}
"""

_AUTHORITY_EXTRACTION_PROMPT = """Extract only review metadata from this exact
institution-issued or institution-acknowledged pillar-3a beneficiary authority.

Allowed documentKind values:
- confirmationInstitutionnelle
- avenantAccuse
- formulaireDesignationAccuse

Return sourceDate as an explicit YYYY-MM-DD document date and legalYear as an
explicit integer from the document. Never infer a temporal regime from either.
temporalBasis must be exactly one of:
- {"kind":"exactDates","designationEffectiveDate":"YYYY-MM-DD or null","lastAssignmentModificationDate":"YYYY-MM-DD or null"}, with at least one date;
- {"kind":"attestedRegime","regime":"pre20270601 or post20270601"}, only when the institution explicitly attests that regime.

Do not return beneficiary identity, order, rank, share, source text, OCR,
analysis, contract number, ledger ids, or document ids. Return only strict JSON
with exactly these keys:
{"documentKind":"confirmationInstitutionnelle","sourceDate":"2026-01-15","legalYear":2026,"institutionAttested":true,"contractScoped":true,"temporalBasis":{"kind":"exactDates","designationEffectiveDate":"2026-01-15","lastAssignmentModificationDate":null},"confidence":"high"}
"""


def _call_json(image_base64: str, prompt: str, *, max_tokens: int) -> object:
    # Import the module, rather than the function, so the checked-in transport
    # seam remains patchable by deterministic golden tests.
    from app.services import document_vision_service

    response = document_vision_service._sync_vision_call(
        model=settings.COACH_MODEL,
        max_tokens=max_tokens,
        timeout=20.0,
        messages=[
            {
                "role": "user",
                "content": [
                    document_vision_service._build_vision_content_block(
                        image_base64,
                    ),
                    {"type": "text", "text": prompt},
                ],
            }
        ],
    )
    raw_text = response.content[0].text
    if not isinstance(raw_text, str):
        raise Pillar3aBeneficiaryAuthorityUnavailable
    cleaned_text = document_vision_service._strip_markdown_fences(raw_text)
    return json.loads(cleaned_text)


def extract_pillar3a_beneficiary_authority(
    image_base64: str,
) -> Pillar3aBeneficiaryAuthorityCandidateV1:
    """Return metadata only when two independent strict contracts both pass."""

    if not settings.ANTHROPIC_API_KEY:
        raise Pillar3aBeneficiaryAuthorityUnavailable

    try:
        _AuthorityClassification.model_validate(
            _call_json(
                image_base64,
                _AUTHORITY_CLASSIFICATION_PROMPT,
                max_tokens=160,
            )
        )

        payload = Pillar3aBeneficiaryAuthorityVisionPayloadV1.model_validate(
            _call_json(
                image_base64,
                _AUTHORITY_EXTRACTION_PROMPT,
                max_tokens=700,
            )
        )
        return Pillar3aBeneficiaryAuthorityCandidateV1(
            schema_version=1,
            document_authority_id=uuid4(),
            document_kind=payload.document_kind,
            source_date=payload.source_date,
            legal_year=payload.legal_year,
            institution_attested=True,
            contract_scoped=True,
            temporal_basis=payload.temporal_basis,
            needs_review=True,
        )
    except Pillar3aBeneficiaryAuthorityUnavailable:
        raise
    except Exception:
        # External transport, JSON and schema failures share one opaque public
        # result so private document content cannot escape through diagnostics.
        raise Pillar3aBeneficiaryAuthorityUnavailable from None
