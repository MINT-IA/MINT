"""G1: exact 3a authority cannot fall into generic extraction writers."""

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest

from app.main import app
from app.models.document import DocumentModel
from app.models.profile_model import ProfileModel
from app.schemas.document_scan import (
    DocumentType,
    Pillar3aBeneficiaryAuthorityVisionPayloadV1,
)
from app.services.document_vision_service import extract_with_vision
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
