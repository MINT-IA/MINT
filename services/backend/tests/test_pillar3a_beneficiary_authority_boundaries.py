"""G1: exact 3a authority cannot fall into generic extraction writers."""

from datetime import datetime, timezone
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.main import app
from app.models.document import DocumentModel
from app.models.profile_model import ProfileModel
from app.schemas.document_scan import (
    DocumentType,
    Pillar3aBeneficiaryAuthorityVisionPayloadV1,
)
from app.services.document_vision_service import extract_with_vision
from app.services.pillar3a_beneficiary_authority import (
    extract_pillar3a_beneficiary_authority,
)
from tests.conftest import TestingSessionLocal


def test_generic_scan_confirmation_rejects_exact_authority_without_writes(client):
    db = TestingSessionLocal()
    try:
        db.add(
            ProfileModel(
                id="profile-exact-3a-boundary",
                user_id="test-user-id",
                data={"preExisting": "untouched"},
                updated_at=datetime.now(timezone.utc),
            )
        )
        db.commit()
        documents_before = db.query(DocumentModel).count()
    finally:
        db.close()

    response = client.post(
        "/api/v1/documents/scan-confirmation",
        json={
            "documentType": "pillar_3a_beneficiary_clause",
            "confirmedFields": [
                {
                    "fieldName": "pillar3aBalance",
                    "value": 987654,
                    "confidence": "high",
                }
            ],
            "overallConfidence": 1.0,
        },
    )

    assert response.status_code == 409, response.text
    assert response.json() == {
        "detail": {"code": "pillar3a_beneficiary_authority_candidate_only"}
    }
    db = TestingSessionLocal()
    try:
        profile = db.query(ProfileModel).filter_by(user_id="test-user-id").one()
        assert profile.data == {"preExisting": "untouched"}
        assert db.query(DocumentModel).count() == documents_before
    finally:
        db.close()


def test_generic_vision_extractor_hard_blocks_exact_authority_before_transport():
    transport = MagicMock()
    with (
        patch(
            "app.services.document_vision_service._sync_vision_call",
            new=transport,
        ),
        patch(
            "app.services.document_vision_service.settings.ANTHROPIC_API_KEY",
            "synthetic-test-key",
        ),
    ):
        with pytest.raises(ValueError, match="review-only"):
            extract_with_vision(
                image_base64="c3ludGhldGlj",
                doc_type=DocumentType.pillar_3a_beneficiary_clause,
            )

    assert transport.call_count == 0


@pytest.mark.parametrize(
    "payload",
    [
        {
            "documentKind": "confirmationInstitutionnelle",
            "sourceDate": "2026-07-18",
            "legalYear": 2026,
            "institutionAttested": True,
            "contractScoped": True,
            "temporalBasis": {
                "kind": "exactDates",
                "designationEffectiveDate": "2026-07-19",
                "lastAssignmentModificationDate": None,
            },
            "confidence": "high",
        },
        {
            "documentKind": "confirmationInstitutionnelle",
            "sourceDate": "2027-05-31",
            "legalYear": 2027,
            "institutionAttested": True,
            "contractScoped": True,
            "temporalBasis": {
                "kind": "attestedRegime",
                "regime": "post20270601",
            },
            "confidence": "high",
        },
    ],
)
def test_authority_payload_rejects_chronology_mobile_cannot_accept(payload):
    with pytest.raises(ValueError):
        Pillar3aBeneficiaryAuthorityVisionPayloadV1.model_validate(payload)


def test_openapi_requires_every_exact_authority_response_key():
    schema = app.openapi()["components"]["schemas"][
        "Pillar3aBeneficiaryAuthorityCandidateV1"
    ]

    assert set(schema["required"]) == {
        "schemaVersion",
        "documentAuthorityId",
        "documentKind",
        "sourceDate",
        "legalYear",
        "institutionAttested",
        "contractScoped",
        "temporalBasis",
        "needsReview",
    }


def _vision_response(payload: object, *, fenced: bool) -> MagicMock:
    encoded = json.dumps(payload)
    response = MagicMock()
    response.content = [
        MagicMock(text=f"```json\n{encoded}\n```" if fenced else encoded)
    ]
    return response


@pytest.mark.parametrize("fenced_call_index", [0, 1])
def test_exact_authority_accepts_known_markdown_fenced_vision_json(
    fenced_call_index,
):
    classification = {
        "is_financial": True,
        "detected_type": "pillar_3a_beneficiary_clause",
        "confidence": "high",
    }
    candidate = {
        "documentKind": "confirmationInstitutionnelle",
        "sourceDate": "2026-07-18",
        "legalYear": 2026,
        "institutionAttested": True,
        "contractScoped": True,
        "temporalBasis": {
            "kind": "exactDates",
            "designationEffectiveDate": "2026-01-15",
            "lastAssignmentModificationDate": None,
        },
        "confidence": "high",
    }
    transport = MagicMock(
        side_effect=[
            _vision_response(classification, fenced=fenced_call_index == 0),
            _vision_response(candidate, fenced=fenced_call_index == 1),
        ]
    )
    with (
        patch(
            "app.services.document_vision_service._sync_vision_call",
            new=transport,
        ),
        patch(
            "app.services.document_vision_service.settings.ANTHROPIC_API_KEY",
            "synthetic-test-key",
        ),
        patch(
            "app.services.document_vision_service.settings.COACH_MODEL",
            "synthetic-test-model",
        ),
    ):
        result = extract_pillar3a_beneficiary_authority("c3ludGhldGlj")

    assert result.document_kind == "confirmationInstitutionnelle"
    assert result.document_authority_id.version == 4
    assert transport.call_count == 2


def test_manual_partner_exact_authority_rejects_before_vision_transport(client):
    transport = MagicMock()
    flag_lookup = AsyncMock(return_value=True)
    with (
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=flag_lookup,
        ),
        patch(
            "app.services.document_vision_service._sync_vision_call",
            new=transport,
        ),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": "c3ludGhldGlj",
                "documentType": "pillar_3a_beneficiary_clause",
                "subjectKind": "manualPartner",
            },
        )

    assert response.status_code == 422, response.text
    assert response.json() == {
        "detail": {"code": "pillar3a_beneficiary_authority_unavailable"}
    }
    flag_lookup.assert_awaited_once_with(
        "PILLAR3A_BENEFICIARY_AUTHORITY_ENABLED",
        "test-user-id",
    )
    assert transport.call_count == 0
