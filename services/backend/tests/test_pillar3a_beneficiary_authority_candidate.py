"""G1: exact pillar-3a beneficiary authority stays review-only.

The generic 3a attestation proves balances/contributions only.  A beneficiary
clause needs its own fail-closed candidate before the mobile review can write
the typed ledger evidence.
"""

from __future__ import annotations

import base64
from datetime import datetime, timezone
import json
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID

import pytest

from app.main import app
from app.models.document_memory import DocumentMemory
from app.models.profile_model import ProfileModel
from app.services.flags_service import FlagsService, REGISTERED_FLAGS
from tests.conftest import TestingSessionLocal


_PATH = "/api/v1/documents/extract-vision"
_DOCUMENT_TYPE = "pillar_3a_beneficiary_clause"
_FEATURE_FLAG = "PILLAR3A_BENEFICIARY_AUTHORITY_ENABLED"
_ERROR_CODE = "pillar3a_beneficiary_authority_unavailable"
_DOCUMENT_BYTES = (
    b"Synthetic provider acknowledgement without names, shares, or contract number"
)
_IMAGE_BASE64 = base64.b64encode(_DOCUMENT_BYTES).decode("ascii")
_CONTRACT_REFERENCE_ID = UUID("11111111-1111-4111-8111-111111111111")
_FUTURE_LEDGER_REFERENCE_ID = UUID("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
_RESPONSE_KEYS = {
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
_FORBIDDEN_RESPONSE_KEYS = {
    "beneficiaryName",
    "beneficiaryNames",
    "beneficiaryOrder",
    "beneficiaryShare",
    "order",
    "share",
    "sourceText",
    "rawAnalysis",
    "rawOcr",
    "ocrText",
    "contractNumber",
    "contractReferenceId",
    "referenceId",
}
_DEFAULT_TEMPORAL_BASIS = object()


def _vision_response(payload: object = None, *, raw: str | None = None) -> MagicMock:
    response = MagicMock()
    response.content = [
        MagicMock(text=raw if raw is not None else json.dumps(payload))
    ]
    return response


def _classification(
    *,
    detected_type: object = _DOCUMENT_TYPE,
    confidence: object = "high",
    is_financial: object = True,
) -> dict[str, object]:
    return {
        "is_financial": is_financial,
        "detected_type": detected_type,
        "confidence": confidence,
    }


def _candidate(
    *,
    document_kind: object = "confirmationInstitutionnelle",
    source_date: object = "2026-07-18",
    legal_year: object = 2026,
    institution_attested: object = True,
    contract_scoped: object = True,
    temporal_basis: object = _DEFAULT_TEMPORAL_BASIS,
    confidence: object = "high",
    **extra: object,
) -> dict[str, object]:
    if temporal_basis is _DEFAULT_TEMPORAL_BASIS:
        temporal_basis = {
            "kind": "exactDates",
            "designationEffectiveDate": "2026-01-15",
            "lastAssignmentModificationDate": None,
        }
    return {
        "documentKind": document_kind,
        "sourceDate": source_date,
        "legalYear": legal_year,
        "institutionAttested": institution_attested,
        "contractScoped": contract_scoped,
        "temporalBasis": temporal_basis,
        "confidence": confidence,
        **extra,
    }


def _post_with_transport(
    client,
    side_effect: list[object],
    *,
    enabled: bool = True,
):
    transport = MagicMock(side_effect=side_effect)
    flag_lookup = AsyncMock(return_value=enabled)
    with (
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=flag_lookup,
        ),
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
        response = client.post(
            _PATH,
            json={
                "imageBase64": _IMAGE_BASE64,
                "documentType": _DOCUMENT_TYPE,
            },
        )
    return response, transport, flag_lookup


def _assert_stable_unavailable(response) -> None:
    assert response.status_code == 422, response.text
    assert response.json() == {"detail": {"code": _ERROR_CODE}}
    for forbidden_key in _FORBIDDEN_RESPONSE_KEYS:
        assert forbidden_key not in response.text


def _assert_uuid4(value: object) -> UUID:
    parsed = UUID(str(value))
    assert parsed.version == 4
    assert str(parsed) == value
    return parsed


@pytest.mark.asyncio
async def test_authority_flag_is_registered_and_defaults_false_without_redis():
    assert _FEATURE_FLAG in REGISTERED_FLAGS
    service = FlagsService()
    with patch.object(
        service,
        "_get_redis",
        new=AsyncMock(return_value=None),
    ):
        assert await service.is_enabled(_FEATURE_FLAG, "test-user-id") is False


def test_authority_flag_off_rejects_before_classification_or_extraction(client):
    response, transport, flag_lookup = _post_with_transport(
        client,
        [
            _vision_response(_classification()),
            _vision_response(_candidate()),
        ],
        enabled=False,
    )

    _assert_stable_unavailable(response)
    assert transport.call_count == 0
    flag_lookup.assert_awaited_once_with(_FEATURE_FLAG, "test-user-id")


@pytest.mark.parametrize(
    ("document_kind", "legal_year", "temporal_basis"),
    [
        (
            "confirmationInstitutionnelle",
            2027,
            {
                "kind": "exactDates",
                "designationEffectiveDate": "2026-01-15",
                "lastAssignmentModificationDate": None,
            },
        ),
        (
            "avenantAccuse",
            2026,
            {
                "kind": "exactDates",
                "designationEffectiveDate": None,
                "lastAssignmentModificationDate": "2026-05-20",
            },
        ),
        (
            "formulaireDesignationAccuse",
            2027,
            {"kind": "attestedRegime", "regime": "pre20270601"},
        ),
    ],
)
def test_exact_authority_returns_only_review_metadata_without_pre_review_writes(
    client,
    document_kind,
    legal_year,
    temporal_basis,
):
    db = TestingSessionLocal()
    try:
        db.add(
            ProfileModel(
                id=f"profile-{document_kind}",
                user_id="test-user-id",
                data={"preExisting": "untouched"},
                updated_at=datetime.now(timezone.utc),
            )
        )
        db.commit()
        memories_before = db.query(DocumentMemory).count()
    finally:
        db.close()

    response, transport, flag_lookup = _post_with_transport(
        client,
        [
            _vision_response(_classification()),
            _vision_response(
                _candidate(
                    document_kind=document_kind,
                    legal_year=legal_year,
                    temporal_basis=temporal_basis,
                )
            ),
        ],
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert set(payload) == _RESPONSE_KEYS
    assert payload == {
        "schemaVersion": 1,
        "documentAuthorityId": payload["documentAuthorityId"],
        "documentKind": document_kind,
        "sourceDate": "2026-07-18",
        "legalYear": legal_year,
        "institutionAttested": True,
        "contractScoped": True,
        "temporalBasis": temporal_basis,
        "needsReview": True,
    }
    _assert_uuid4(payload["documentAuthorityId"])
    assert not (_FORBIDDEN_RESPONSE_KEYS & set(payload))
    assert transport.call_count == 2
    flag_lookup.assert_awaited_once_with(_FEATURE_FLAG, "test-user-id")
    if temporal_basis["kind"] == "exactDates":
        assert "regime" not in payload["temporalBasis"]

    db = TestingSessionLocal()
    try:
        profile = db.query(ProfileModel).filter_by(user_id="test-user-id").one()
        assert profile.data == {"preExisting": "untouched"}
        assert db.query(DocumentMemory).count() == memories_before
    finally:
        db.close()


def test_authority_id_is_server_uuid4_unique_and_separate_from_ledger_ids(client):
    authorities: list[UUID] = []
    for document_kind in ("confirmationInstitutionnelle", "avenantAccuse"):
        response, _, _ = _post_with_transport(
            client,
            [
                _vision_response(_classification()),
                _vision_response(_candidate(document_kind=document_kind)),
            ],
        )
        assert response.status_code == 200, response.text
        payload = response.json()
        authorities.append(_assert_uuid4(payload["documentAuthorityId"]))
        assert "contractReferenceId" not in payload
        assert "referenceId" not in payload

    assert len(set(authorities)) == 2
    assert not (
        set(authorities)
        & {_CONTRACT_REFERENCE_ID, _FUTURE_LEDGER_REFERENCE_ID}
    )


def test_source_date_and_legal_year_never_infer_a_temporal_regime(client):
    exact_dates = {
        "kind": "exactDates",
        "designationEffectiveDate": "2026-01-15",
        "lastAssignmentModificationDate": None,
    }
    response, _, _ = _post_with_transport(
        client,
        [
            _vision_response(_classification()),
            _vision_response(
                _candidate(
                    source_date="2026-07-18",
                    legal_year=2027,
                    temporal_basis=exact_dates,
                )
            ),
        ],
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["sourceDate"] == "2026-07-18"
    assert payload["legalYear"] == 2027
    assert payload["temporalBasis"] == exact_dates
    assert "regime" not in payload["temporalBasis"]


@pytest.mark.parametrize("legal_year", [1900, 9999])
def test_legal_year_accepts_the_closed_contract_boundaries(client, legal_year):
    response, _, _ = _post_with_transport(
        client,
        [
            _vision_response(_classification()),
            _vision_response(_candidate(legal_year=legal_year)),
        ],
    )

    assert response.status_code == 200, response.text
    assert response.json()["legalYear"] == legal_year


@pytest.mark.parametrize(
    "classification_payload",
    [
        _classification(detected_type="pillar_3a_attestation"),
        _classification(detected_type="testament"),
        _classification(detected_type="raw_ocr_text"),
        _classification(detected_type=None),
        _classification(confidence="medium"),
        _classification(confidence="low"),
        _classification(confidence=1.0),
        _classification(is_financial=False),
        _classification(is_financial="true"),
    ],
)
def test_non_exact_document_classification_rejects_before_candidate_extraction(
    client,
    classification_payload,
):
    response, transport, _ = _post_with_transport(
        client,
        [_vision_response(classification_payload)],
    )

    _assert_stable_unavailable(response)
    assert transport.call_count == 1


@pytest.mark.parametrize(
    "candidate_payload",
    [
        {},
        _candidate(document_kind="blankForm"),
        _candidate(document_kind="testament"),
        _candidate(document_kind="pillar_3a_attestation"),
        _candidate(confidence="medium"),
        _candidate(confidence="low"),
        _candidate(confidence=1.0),
        _candidate(institution_attested=False),
        _candidate(institution_attested="true"),
        _candidate(contract_scoped=False),
        _candidate(contract_scoped="true"),
        _candidate(source_date=None),
        _candidate(source_date="18.07.2026"),
        _candidate(legal_year=None),
        _candidate(legal_year="2026"),
        _candidate(legal_year=2026.0),
        _candidate(legal_year=True),
        _candidate(legal_year=1899),
        _candidate(legal_year=10_000),
        {
            key: value
            for key, value in _candidate(
                source_date="2026-07-18",
                legal_year=2027,
            ).items()
            if key != "temporalBasis"
        },
        _candidate(temporal_basis=None),
        _candidate(temporal_basis={"kind": "exactDates"}),
        _candidate(
            temporal_basis={
                "kind": "exactDates",
                "designationEffectiveDate": None,
                "lastAssignmentModificationDate": None,
            }
        ),
        _candidate(
            temporal_basis={
                "kind": "exactDates",
                "designationEffectiveDate": "2026-01-15",
                "lastAssignmentModificationDate": None,
                "regime": "pre20270601",
            }
        ),
        _candidate(
            temporal_basis={
                "kind": "attestedRegime",
                "regime": "pre20270601",
                "designationEffectiveDate": "2026-01-15",
            }
        ),
        _candidate(temporal_basis={"kind": "attestedRegime"}),
        _candidate(temporal_basis={"kind": "attestedRegime", "regime": "unknown"}),
        _candidate(temporal_basis={"kind": "rawOcr", "text": "unreviewed"}),
    ],
)
def test_non_exact_candidate_contract_rejects_with_one_stable_422(
    client,
    candidate_payload,
):
    response, transport, _ = _post_with_transport(
        client,
        [
            _vision_response(_classification()),
            _vision_response(candidate_payload),
        ],
    )

    _assert_stable_unavailable(response)
    assert transport.call_count == 2


@pytest.mark.parametrize(
    "forbidden_key",
    [
        "beneficiaryName",
        "beneficiaryOrder",
        "beneficiaryShare",
        "sourceText",
        "rawAnalysis",
        "rawOcr",
        "ocrText",
        "contractNumber",
        "contractReferenceId",
        "referenceId",
        "documentAuthorityId",
    ],
)
def test_candidate_rejects_forbidden_identity_and_raw_document_fields(
    client,
    forbidden_key,
):
    sentinel = f"PRIVATE-{forbidden_key}-MUST-NOT-ESCAPE"
    response, transport, _ = _post_with_transport(
        client,
        [
            _vision_response(_classification()),
            _vision_response(_candidate(**{forbidden_key: sentinel})),
        ],
    )

    _assert_stable_unavailable(response)
    assert sentinel not in response.text
    assert transport.call_count == 2


@pytest.mark.parametrize(
    "transport_failure",
    [
        TimeoutError("PRIVATE-TIMEOUT-MUST-NOT-ESCAPE"),
        _vision_response(raw="not-json PRIVATE-JSON-MUST-NOT-ESCAPE"),
        _vision_response(None),
        _vision_response([]),
        _vision_response("raw OCR only"),
    ],
)
def test_candidate_transport_failures_are_fail_closed_and_stable(
    client,
    transport_failure,
):
    response, transport, _ = _post_with_transport(
        client,
        [_vision_response(_classification()), transport_failure],
    )

    _assert_stable_unavailable(response)
    assert "PRIVATE" not in response.text
    assert transport.call_count == 2


def test_generated_openapi_names_the_exact_candidate_response_contract():
    generated = app.openapi()
    schemas = generated["components"]["schemas"]
    assert "Pillar3aBeneficiaryAuthorityCandidateV1" in schemas

    operation = generated["paths"][_PATH]["post"]
    response_schema = operation["responses"]["200"]["content"][
        "application/json"
    ]["schema"]
    assert {
        "$ref": (
            "#/components/schemas/"
            "Pillar3aBeneficiaryAuthorityCandidateV1"
        )
    } in response_schema["anyOf"]
