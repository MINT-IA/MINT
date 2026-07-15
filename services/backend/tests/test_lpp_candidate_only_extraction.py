"""G1 PROV-02: LPP Vision extraction stays candidate-only until review."""

import base64
from datetime import datetime, timezone
import json
import logging
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.database import Base
from app.core.auth import require_current_user
from app.main import app
from app.models.document import DocumentModel
from app.models.document_audit import DocumentAuditLog
from app.models.document_memory import DocumentMemory
from app.models.profile_model import ProfileModel
from app.schemas.document_scan import (
    ConfidenceLevel,
    DocumentClassificationResult,
    DocumentType,
    ExtractedFieldConfirmation,
    VisionExtractionResponse,
)
from app.services.document_vision_service import (
    _validate_fields,
    classify_document,
    detect_lpp_plan_type,
    extract_with_vision,
)
from tests.conftest import TestingSessionLocal, engine


_LPP_FIXTURE_DIR = Path(__file__).parent / "fixtures" / "documents"
_LEGACY_LPP_FIELD_NAMES = {
    "avoirLppTotal",
    "avoirLppObligatoire",
    "avoirLppSurobligatoire",
    "tauxConversion",
    "rachatMaximum",
    "salaireAssure",
    "bonificationVieillesse",
}


def _lpp_candidate() -> VisionExtractionResponse:
    return VisionExtractionResponse(
        document_type=DocumentType.lpp_certificate,
        extracted_fields=[
            ExtractedFieldConfirmation(
                field_name="avoirLppTotal",
                value=250_000,
                confidence=ConfidenceLevel.high,
                source_text="Avoir de vieillesse total: CHF 250'000",
            ),
        ],
        overall_confidence=0.95,
        raw_analysis="RAW-LPP-ANALYSIS-SENTINEL",
    )


def _vision_transport_response(payload: dict) -> MagicMock:
    response = MagicMock()
    response.content = [MagicMock(text=json.dumps(payload))]
    return response


def _exact_lpp_certificate_classification() -> DocumentClassificationResult:
    return DocumentClassificationResult(
        is_financial=True,
        detected_type="lpp_certificate",
        confidence=ConfidenceLevel.high,
    )


_SYNTHETIC_LPP_PLAN_BYTES = (
    b"Plan de prevoyance Bonus\n"
    b"Salaire assure CHF 98000\n"
    b"Taux de conversion 5.2 percent\n"
)


@pytest.mark.parametrize(
    ("case_name", "classification"),
    [
        (
            "plan_base_bonus",
            DocumentClassificationResult(
                is_financial=True,
                detected_type="lpp_plan",
                confidence=ConfidenceLevel.high,
            ),
        ),
        (
            "unknown",
            DocumentClassificationResult(
                is_financial=True,
                detected_type="unknown",
                confidence=ConfidenceLevel.high,
            ),
        ),
        (
            "medium_certificate",
            DocumentClassificationResult(
                is_financial=True,
                detected_type="lpp_certificate",
                confidence=ConfidenceLevel.medium,
            ),
        ),
        (
            "low_certificate",
            DocumentClassificationResult(
                is_financial=True,
                detected_type="lpp_certificate",
                confidence=ConfidenceLevel.low,
            ),
        ),
        (
            "non_financial",
            DocumentClassificationResult(
                is_financial=False,
                detected_type="lpp_certificate",
                confidence=ConfidenceLevel.high,
            ),
        ),
        (
            "absent_type",
            DocumentClassificationResult(
                is_financial=True,
                detected_type=None,
                confidence=ConfidenceLevel.high,
            ),
        ),
    ],
)
def test_lpp_document_kind_gate_rejects_before_audit_and_extraction(
    client,
    case_name,
    classification,
):
    """Only an exact, high-confidence personal LPP certificate may proceed."""
    encoded_document = base64.b64encode(_SYNTHETIC_LPP_PLAN_BYTES).decode("ascii")
    Base.metadata.create_all(bind=engine, tables=[DocumentAuditLog.__table__])
    db = TestingSessionLocal()
    try:
        audit_count_before = db.query(DocumentAuditLog).count()
    finally:
        db.close()

    classifier = MagicMock(return_value=classification)
    extractor = MagicMock(
        side_effect=AssertionError(f"extraction ran for rejected case {case_name}"),
    )
    audit_factory = MagicMock(
        side_effect=AssertionError(f"audit created for rejected case {case_name}"),
    )

    with (
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=AsyncMock(return_value=False),
        ),
        patch(
            "app.services.document_vision_service.classify_document",
            new=classifier,
        ),
        patch(
            "app.services.document_vision_service.extract_with_vision",
            new=extractor,
        ),
        patch(
            "app.models.document_audit.create_audit_log",
            new=audit_factory,
        ),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": encoded_document,
                "documentType": "lpp_certificate",
            },
        )

    assert response.status_code == 422, response.text
    classifier.assert_called_once_with(encoded_document)
    extractor.assert_not_called()
    audit_factory.assert_not_called()
    db = TestingSessionLocal()
    try:
        assert db.query(DocumentAuditLog).count() == audit_count_before
    finally:
        db.close()


def test_lpp_document_kind_classifier_error_rejects_without_sensitive_output(
    client,
    caplog,
):
    sentinel = "LPP-KIND-CLASSIFIER-PRIVATE-SENTINEL"
    encoded_document = base64.b64encode(_SYNTHETIC_LPP_PLAN_BYTES).decode("ascii")
    Base.metadata.create_all(bind=engine, tables=[DocumentAuditLog.__table__])
    db = TestingSessionLocal()
    try:
        audit_count_before = db.query(DocumentAuditLog).count()
    finally:
        db.close()

    extractor = MagicMock(side_effect=AssertionError("extraction must not run"))
    audit_factory = MagicMock(side_effect=AssertionError("audit must not be created"))
    with (
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=AsyncMock(return_value=False),
        ),
        patch(
            "app.services.document_vision_service.classify_document",
            side_effect=RuntimeError(sentinel),
        ),
        patch(
            "app.services.document_vision_service.extract_with_vision",
            new=extractor,
        ),
        patch(
            "app.models.document_audit.create_audit_log",
            new=audit_factory,
        ),
        caplog.at_level(logging.WARNING),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": encoded_document,
                "documentType": "lpp_certificate",
            },
        )

    assert response.status_code == 422, response.text
    extractor.assert_not_called()
    audit_factory.assert_not_called()
    assert sentinel not in response.text
    assert sentinel not in caplog.text
    assert encoded_document[:32] not in caplog.text
    assert "error_type=RuntimeError" in caplog.text
    db = TestingSessionLocal()
    try:
        assert db.query(DocumentAuditLog).count() == audit_count_before
    finally:
        db.close()


@pytest.mark.parametrize("invalid_is_financial", ["true", 1, None])
def test_lpp_document_kind_gate_rejects_invalid_boolean_before_side_effects(
    client,
    invalid_is_financial,
):
    encoded_document = base64.b64encode(_SYNTHETIC_LPP_PLAN_BYTES).decode("ascii")
    Base.metadata.create_all(bind=engine, tables=[DocumentAuditLog.__table__])
    db = TestingSessionLocal()
    try:
        audit_count_before = db.query(DocumentAuditLog).count()
    finally:
        db.close()

    classifier_response = _vision_transport_response(
        {
            "is_financial": invalid_is_financial,
            "detected_type": "lpp_certificate",
            "confidence": "high",
        },
    )
    extractor = MagicMock(side_effect=AssertionError("extraction must not run"))
    audit_factory = MagicMock(side_effect=AssertionError("audit must not be created"))
    with (
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=AsyncMock(return_value=False),
        ),
        patch(
            "app.services.document_vision_service._sync_vision_call",
            return_value=classifier_response,
        ),
        patch(
            "app.services.document_vision_service.extract_with_vision",
            new=extractor,
        ),
        patch(
            "app.services.document_vision_service.settings.ANTHROPIC_API_KEY",
            "test-key",
        ),
        patch(
            "app.services.document_vision_service.settings.COACH_MODEL",
            "test-model",
        ),
        patch(
            "app.models.document_audit.create_audit_log",
            new=audit_factory,
        ),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": encoded_document,
                "documentType": "lpp_certificate",
            },
        )

    assert response.status_code == 422, response.text
    extractor.assert_not_called()
    audit_factory.assert_not_called()
    db = TestingSessionLocal()
    try:
        assert db.query(DocumentAuditLog).count() == audit_count_before
    finally:
        db.close()


@pytest.mark.parametrize(
    "documents_v2_enabled,accept_header",
    [
        (False, "application/json"),
        (True, "application/json"),
        (True, "text/event-stream"),
    ],
)
@pytest.mark.parametrize(
    "fixture_name,expected_block_type,expected_media_type",
    [
        ("cpe_plan_maxi_julien.pdf", "document", "application/pdf"),
        ("hotela_lauren.pdf", "document", "application/pdf"),
        ("crumpled_scan.jpg", "image", "image/jpeg"),
    ],
)
def test_lpp_endpoint_uses_exact_legacy_candidate_contract_for_every_flag(
    client,
    caplog,
    documents_v2_enabled,
    accept_header,
    fixture_name,
    expected_block_type,
    expected_media_type,
):
    """LPP scans stay on one reviewed candidate contract for every flag.

    The HTTP endpoint and all three production Vision stages run normally; only
    the Anthropic transport is replaced. This protects both mobile raster and
    PDF acquisition from changing vocabulary when DOCUMENTS_V2 flips, while
    also proving that PDFs are never mislabeled as ``image/jpeg``.
    """
    document_bytes = (_LPP_FIXTURE_DIR / fixture_name).read_bytes()
    if expected_block_type == "document":
        assert document_bytes.startswith(b"%PDF-")
    document_base64 = base64.b64encode(document_bytes).decode("ascii")
    user_id = f"LPP-DOCUMENT-USER-{documents_v2_enabled}-{fixture_name}"
    _override_user_id(user_id)

    Base.metadata.create_all(
        bind=engine,
        tables=[DocumentAuditLog.__table__, DocumentMemory.__table__],
    )
    db = TestingSessionLocal()
    try:
        db.add(
            ProfileModel(
                id=f"profile-{documents_v2_enabled}-{fixture_name}",
                user_id=user_id,
                data={"preExisting": "untouched"},
                updated_at=datetime.now(timezone.utc),
            ),
        )
        db.commit()
        before = {
            "documents": db.query(DocumentModel).count(),
            "memories": db.query(DocumentMemory).count(),
            "audits": db.query(DocumentAuditLog).count(),
        }
    finally:
        db.close()

    source_sentinel = "LPP-DOCUMENT-SOURCE-TEXT-DO-NOT-LOG"
    analysis_sentinel = "LPP-DOCUMENT-ANALYSIS-DO-NOT-LOG"
    transport_responses = [
        _vision_transport_response(
            {
                "is_financial": True,
                "detected_type": "lpp_certificate",
                "confidence": "high",
            },
        ),
        _vision_transport_response(
            {"plan_type": "surobligatoire", "confidence": "high"},
        ),
        _vision_transport_response(
            {
                "fields": [
                    {
                        "name": "avoirLppTotal",
                        "value": 250_000,
                        "confidence": "high",
                        "source_text": source_sentinel,
                    },
                    {
                        "name": "avoirLppObligatoire",
                        "value": 150_000,
                        "confidence": "high",
                        "source_text": source_sentinel,
                    },
                    {
                        "name": "avoirLppSurobligatoire",
                        "value": 100_000,
                        "confidence": "high",
                        "source_text": source_sentinel,
                    },
                    {
                        "name": "tauxConversion",
                        "value": 0.068,
                        "confidence": "high",
                        "source_text": source_sentinel,
                    },
                    {
                        "name": "rachatMaximum",
                        "value": 50_000,
                        "confidence": "high",
                        "source_text": source_sentinel,
                    },
                    {
                        "name": "salaireAssure",
                        "value": 90_000,
                        "confidence": "high",
                        "source_text": source_sentinel,
                    },
                    {
                        "name": "bonificationVieillesse",
                        "value": 0.12,
                        "confidence": "high",
                        "source_text": source_sentinel,
                    },
                ],
                "analysis": analysis_sentinel,
            },
        ),
    ]
    transport_calls: list[dict] = []

    def _mock_vision_transport(**kwargs):
        transport_calls.append(kwargs)
        return transport_responses[len(transport_calls) - 1]

    fused_call = AsyncMock(
        side_effect=AssertionError("LPP must keep the legacy response contract"),
    )
    stream_call = MagicMock(
        side_effect=AssertionError("LPP must not expose an SSE extraction facade"),
    )
    idempotency_lookup = AsyncMock(
        side_effect=AssertionError("LPP candidate must not read idempotency"),
    )
    idempotency_store = AsyncMock(
        side_effect=AssertionError("LPP candidate must not write idempotency"),
    )
    memory_upsert = MagicMock(
        side_effect=AssertionError("LPP candidate must not write memory"),
    )
    rag_index = MagicMock(
        side_effect=AssertionError("LPP candidate must not enter RAG"),
    )
    coach_insight = MagicMock(
        side_effect=AssertionError("LPP candidate must not enter coach insight"),
    )
    coach_token = AsyncMock(
        side_effect=AssertionError("LPP candidate must not mutate coach tokens"),
    )

    with (
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=AsyncMock(return_value=documents_v2_enabled),
        ),
        patch(
            "app.services.document_vision_service.understand_document",
            new=fused_call,
        ),
        patch(
            "app.services.document_stream.stream_understanding",
            new=stream_call,
        ),
        patch(
            "app.services.document_vision_service._sync_vision_call",
            side_effect=_mock_vision_transport,
        ),
        patch(
            "app.services.document_vision_service._idempotency.lookup_by_file_sha",
            new=idempotency_lookup,
        ),
        patch(
            "app.services.document_vision_service._idempotency.store_by_file_sha",
            new=idempotency_store,
        ),
        patch(
            "app.services.document_vision_service._upsert_and_diff",
            new=memory_upsert,
        ),
        patch(
            "app.api.v1.endpoints.documents._index_in_rag",
            new=rag_index,
        ),
        patch(
            "app.api.v1.endpoints.documents.generate_document_insight",
            new=coach_insight,
        ),
        patch(
            "app.services.coach.token_budget.TokenBudget.consume",
            new=coach_token,
        ),
        patch(
            "app.services.document_vision_service.settings.ANTHROPIC_API_KEY",
            "test-key",
        ),
        patch(
            "app.services.document_vision_service.settings.COACH_MODEL",
            "test-model",
        ),
        caplog.at_level(logging.INFO),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": document_base64,
                "documentType": "lpp_certificate",
                "canton": "VD",
                "languageHint": "fr",
            },
            headers={"Accept": accept_header},
        )

    assert response.status_code == 200, response.text
    assert response.headers["content-type"].startswith("application/json")
    payload = response.json()
    assert {field["fieldName"] for field in payload["extractedFields"]} == (
        _LEGACY_LPP_FIELD_NAMES
    )
    assert len(transport_calls) == 3
    for call in transport_calls:
        content_block = call["messages"][0]["content"][0]
        assert content_block == {
            "type": expected_block_type,
            "source": {
                "type": "base64",
                "media_type": expected_media_type,
                "data": document_base64,
            },
        }

    fused_call.assert_not_awaited()
    stream_call.assert_not_called()
    idempotency_lookup.assert_not_awaited()
    idempotency_store.assert_not_awaited()
    memory_upsert.assert_not_called()
    rag_index.assert_not_called()
    coach_insight.assert_not_called()
    coach_token.assert_not_awaited()
    assert user_id not in caplog.text
    assert source_sentinel not in caplog.text
    assert analysis_sentinel not in caplog.text
    assert document_base64[:64] not in caplog.text

    db = TestingSessionLocal()
    try:
        profile = db.query(ProfileModel).filter_by(user_id=user_id).one()
        assert profile.data == {"preExisting": "untouched"}
        assert db.query(DocumentModel).count() == before["documents"]
        assert db.query(DocumentMemory).count() == before["memories"]
        assert db.query(DocumentAuditLog).count() == before["audits"] + 1
        audit = (
            db.query(DocumentAuditLog)
            .order_by(DocumentAuditLog.created_at.desc())
            .first()
        )
        assert audit is not None
        assert audit.document_type == "lpp_certificate"
        assert audit.field_count == len(_LEGACY_LPP_FIELD_NAMES)
        assert audit.overall_confidence == 1.0
        assert audit.error_message is None
        assert audit.deleted_at is not None
        audit_metadata = repr(audit.__dict__)
        assert source_sentinel not in audit_metadata
        assert analysis_sentinel not in audit_metadata
        assert document_base64[:64] not in audit_metadata
    finally:
        db.close()


def test_lpp_legacy_extract_vision_persists_audit_metadata_only(client):
    Base.metadata.create_all(bind=engine, tables=[DocumentAuditLog.__table__])
    db = TestingSessionLocal()
    try:
        db.add(
            ProfileModel(
                id="lpp-legacy-candidate-profile",
                user_id="test-user-id",
                data={"preExisting": "untouched"},
                updated_at=datetime.now(timezone.utc),
            ),
        )
        db.commit()
        audit_count_before = db.query(DocumentAuditLog).count()
    finally:
        db.close()

    with (
        patch(
            "app.services.document_vision_service.classify_document",
            return_value=_exact_lpp_certificate_classification(),
        ),
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=AsyncMock(return_value=False),
        ),
        patch(
            "app.services.document_vision_service.extract_with_vision",
            return_value=_lpp_candidate(),
        ),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": "ZmFrZQ==",
                "documentType": "lpp_certificate",
            },
        )

    assert response.status_code == 200, response.text
    db = TestingSessionLocal()
    try:
        profile = db.query(ProfileModel).filter_by(user_id="test-user-id").one()
        assert profile.data == {"preExisting": "untouched"}
        assert db.query(DocumentModel).count() == 0
        assert db.query(DocumentAuditLog).count() == audit_count_before + 1
        audit = (
            db.query(DocumentAuditLog)
            .order_by(DocumentAuditLog.created_at.desc())
            .first()
        )
        assert audit is not None
        assert audit.document_type == "lpp_certificate"
        assert audit.field_count == 1
        assert audit.overall_confidence == 0.95
        assert audit.deleted_at is not None
        assert audit.error_message is None
    finally:
        db.close()


def test_zero_field_warning_records_analysis_length_not_analysis(caplog):
    sentinel = "RAW-LPP-ANALYSIS-DO-NOT-LOG"
    key_sentinel = "PROMPT-CONTROLLED-KEY-DO-NOT-LOG"
    response = MagicMock()
    response.content = [
        MagicMock(
            text=json.dumps(
                {"fields": [], "analysis": sentinel, key_sentinel: "ignored"}
            )
        ),
    ]

    with (
        patch("app.services.document_vision_service.settings") as settings,
        patch(
            "app.services.document_vision_service.detect_lpp_plan_type",
            return_value=(None, ConfidenceLevel.low),
        ),
        patch(
            "app.services.document_vision_service._sync_vision_call",
            return_value=response,
        ),
        caplog.at_level(logging.WARNING),
    ):
        settings.ANTHROPIC_API_KEY = "test-key"
        settings.COACH_MODEL = "test-model"
        result = extract_with_vision("fake-base64", DocumentType.lpp_certificate)

    assert result.extraction_status == "no_fields_found"
    assert sentinel not in caplog.text
    assert key_sentinel not in caplog.text
    assert "analysis_length=" in caplog.text
    assert "parsed_key_count=3" in caplog.text


def test_parse_warning_records_response_length_not_raw_response(caplog):
    sentinel = "RAW-LPP-SOURCE-TEXT-DO-NOT-LOG"
    raw_response = f'{{"fields": ["{sentinel}"]'
    response = MagicMock()
    response.content = [MagicMock(text=raw_response)]

    with (
        patch("app.services.document_vision_service.settings") as settings,
        patch(
            "app.services.document_vision_service.detect_lpp_plan_type",
            return_value=(None, ConfidenceLevel.low),
        ),
        patch(
            "app.services.document_vision_service._sync_vision_call",
            return_value=response,
        ),
        caplog.at_level(logging.WARNING),
    ):
        settings.ANTHROPIC_API_KEY = "test-key"
        settings.COACH_MODEL = "test-model"
        result = extract_with_vision("fake-base64", DocumentType.lpp_certificate)

    assert result.extraction_status == "parse_error"
    assert sentinel not in caplog.text
    assert "response_length=" in caplog.text


def _override_user_id(user_id: str) -> None:
    user = MagicMock()
    user.id = user_id
    user.email = "candidate@example.invalid"
    app.dependency_overrides[require_current_user] = lambda: user


def test_lpp_candidate_endpoint_log_omits_user_identifier(client, caplog):
    user_id = "USER-ID-SENTINEL-DO-NOT-LOG"
    _override_user_id(user_id)

    with (
        patch(
            "app.services.document_vision_service.classify_document",
            return_value=_exact_lpp_certificate_classification(),
        ),
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=AsyncMock(return_value=False),
        ),
        patch(
            "app.services.document_vision_service.extract_with_vision",
            return_value=_lpp_candidate(),
        ),
        caplog.at_level(logging.INFO),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": "ZmFrZQ==",
                "documentType": "lpp_certificate",
            },
        )

    assert response.status_code == 200, response.text
    assert user_id not in caplog.text
    assert user_id[:8] not in caplog.text


@pytest.mark.parametrize(
    "failure",
    [
        ValueError("LEGACY-VALUE-ERROR-SENTINEL"),
        RuntimeError("LEGACY-RUNTIME-ERROR-SENTINEL"),
    ],
)
def test_lpp_legacy_failure_keeps_exception_text_out_of_logs_and_audit(
    client,
    caplog,
    failure,
):
    Base.metadata.create_all(bind=engine, tables=[DocumentAuditLog.__table__])
    db = TestingSessionLocal()
    try:
        audit_count_before = db.query(DocumentAuditLog).count()
    finally:
        db.close()

    with (
        patch(
            "app.services.document_vision_service.classify_document",
            return_value=_exact_lpp_certificate_classification(),
        ),
        patch(
            "app.services.flags_service.flags.is_enabled",
            new=AsyncMock(return_value=False),
        ),
        patch(
            "app.services.document_vision_service.extract_with_vision",
            side_effect=failure,
        ),
        caplog.at_level(logging.ERROR),
    ):
        response = client.post(
            "/api/v1/documents/extract-vision",
            json={
                "imageBase64": "ZmFrZQ==",
                "documentType": "lpp_certificate",
            },
        )

    assert response.status_code in {400, 502}
    assert str(failure) not in caplog.text
    assert str(failure) not in response.text

    db = TestingSessionLocal()
    try:
        assert db.query(DocumentAuditLog).count() == audit_count_before + 1
        audit = (
            db.query(DocumentAuditLog)
            .order_by(DocumentAuditLog.created_at.desc())
            .first()
        )
        assert audit is not None
        assert str(failure) not in (audit.error_message or "")
        assert audit.error_message == type(failure).__name__
    finally:
        db.close()


def test_lpp_range_warning_omits_raw_financial_value(caplog):
    raw_value = 0.987654321
    field = ExtractedFieldConfirmation(
        field_name="tauxConversion",
        value=raw_value,
        confidence=ConfidenceLevel.high,
    )

    with caplog.at_level(logging.WARNING):
        validated = _validate_fields([field], DocumentType.lpp_certificate)

    assert validated[0].confidence == ConfidenceLevel.low
    assert str(raw_value) not in caplog.text
    assert "tauxConversion" not in caplog.text
    assert "reason=outside_range" in caplog.text


def test_lpp_missing_source_warning_omits_prompt_controlled_field_name(caplog):
    field_name = "PROMPT-FIELD-NAME-SENTINEL"
    response = MagicMock()
    response.content = [
        MagicMock(
            text=json.dumps(
                {
                    "fields": [
                        {
                            "name": field_name,
                            "value": 12,
                            "confidence": "high",
                        },
                    ],
                    "analysis": "metadata",
                }
            )
        ),
    ]

    with (
        patch("app.services.document_vision_service.settings") as settings,
        patch(
            "app.services.document_vision_service.detect_lpp_plan_type",
            return_value=(None, ConfidenceLevel.low),
        ),
        patch(
            "app.services.document_vision_service._sync_vision_call",
            return_value=response,
        ),
        caplog.at_level(logging.WARNING),
    ):
        settings.ANTHROPIC_API_KEY = "test-key"
        settings.COACH_MODEL = "test-model"
        result = extract_with_vision("fake-base64", DocumentType.lpp_certificate)

    assert result.extracted_fields[0].field_name == field_name
    assert field_name not in caplog.text
    assert "missing source_text count=1" in caplog.text


def test_lpp_rejected_field_warning_omits_prompt_controlled_names(caplog):
    field_name = "REJECTED-PROMPT-FIELD-SENTINEL"
    response = MagicMock()
    response.content = [
        MagicMock(
            text=json.dumps(
                {
                    "fields": [
                        {
                            "name": field_name,
                            "value": 42,
                            "confidence": "high",
                            "source_text": "candidate source",
                        },
                    ],
                    "analysis": "metadata",
                }
            )
        ),
    ]

    with (
        patch("app.services.document_vision_service.settings") as settings,
        patch(
            "app.services.document_vision_service.detect_lpp_plan_type",
            return_value=(None, ConfidenceLevel.low),
        ),
        patch(
            "app.services.document_vision_service._sync_vision_call",
            return_value=response,
        ),
        patch(
            "app.services.document_vision_service._validate_fields",
            return_value=[],
        ),
        caplog.at_level(logging.WARNING),
    ):
        settings.ANTHROPIC_API_KEY = "test-key"
        settings.COACH_MODEL = "test-model"
        result = extract_with_vision("fake-base64", DocumentType.lpp_certificate)

    assert result.extraction_status == "partial"
    assert field_name not in caplog.text
    assert "rejected_field_count=1" in caplog.text


def test_lpp_classification_errors_log_types_only(caplog):
    sentinel = "LPP-CLASSIFICATION-EXCEPTION-SENTINEL"

    with (
        patch("app.services.document_vision_service.settings") as settings,
        patch(
            "app.services.document_vision_service._sync_vision_call",
            side_effect=RuntimeError(sentinel),
        ),
        caplog.at_level(logging.WARNING),
    ):
        settings.ANTHROPIC_API_KEY = "test-key"
        settings.COACH_MODEL = "test-model"
        plan_type, confidence = detect_lpp_plan_type("fake-base64")
        classification = classify_document("fake-base64")

    assert plan_type is not None
    assert confidence == ConfidenceLevel.low
    assert classification.is_financial is True
    assert sentinel not in caplog.text
    assert caplog.text.count("error_type=RuntimeError") >= 2
