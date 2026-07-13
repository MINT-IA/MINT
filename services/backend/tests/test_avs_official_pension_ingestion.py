"""G1 official AVS pension ingestion — deterministic candidate-only contract.

The shared oracle lives at repo level so backend and mobile implementations
must agree on the same 40 semantic cases.  This backend slice is deliberately
self-only and never writes a profile or document before mobile review.
"""

from __future__ import annotations

import ast
import inspect
import json
import logging
from pathlib import Path
import textwrap
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.models.document import DocumentModel
from app.models.profile_model import ProfileModel
from app.models.user import User
from app.schemas.document_parser import ConfidenceDeltaRequest, ParseDocumentRequest
from app.services.feature_flags import FeatureFlags
from tests.conftest import TestingSessionLocal


_ORACLE_PATH = (
    Path(__file__).resolve().parents[3]
    / "tests"
    / "fixtures"
    / "avs_official_pension_evidence_cases.json"
)
_ORACLE = json.loads(_ORACLE_PATH.read_text(encoding="utf-8"))
_CASES = _ORACLE["cases"]
_CASE_BY_ID = {case["id"]: case for case in _CASES}


def _flag(monkeypatch: pytest.MonkeyPatch, enabled: bool) -> None:
    monkeypatch.setenv(
        "AVS_OFFICIAL_PENSION_INGESTION_ENABLED",
        "true" if enabled else "false",
    )


def _official_payload(text: str) -> dict[str, object]:
    return {"documentType": "avs_official_pension", "text": text}


def _vision_payload(text: str) -> dict[str, object]:
    return {
        "documentType": "avs_official_pension",
        "imageBase64": text,
        "languageHint": "fr",
    }


def _confirmation_payload(amount: float = 1842) -> dict[str, object]:
    return {
        "documentType": "avs_official_pension",
        "overallConfidence": 0.99,
        "extractionMethod": "manual",
        "confirmedFields": [
            {
                "fieldName": "avs_official_monthly_pension",
                "value": amount,
                "confidence": "high",
                "sourceText": "personal official old-age pension",
            }
        ],
    }


def _seed_profile() -> None:
    db = TestingSessionLocal()
    try:
        user = User(
            id="test-user-id",
            email="avs-official@test.mint.ch",
            hashed_password="not-used",
        )
        profile = ProfileModel(
            id="avs-official-profile",
            user_id="test-user-id",
            data={"existingFact": "unchanged"},
        )
        db.add(user)
        db.add(profile)
        db.commit()
    finally:
        db.close()


def _database_snapshot() -> tuple[dict[str, object], int]:
    db = TestingSessionLocal()
    try:
        profile = db.query(ProfileModel).filter(ProfileModel.id == "avs-official-profile").one()
        document_count = db.query(DocumentModel).count()
        return dict(profile.data), document_count
    finally:
        db.close()


def test_shared_oracle_has_exactly_40_synthetic_cases() -> None:
    assert _ORACLE["schema_version"] == 2
    assert _ORACLE["data_classification"] == "synthetic_no_pii"
    assert len(_CASES) == 40
    assert sum(case["expected"]["rejection_reason"] is None for case in _CASES) == 12


@pytest.mark.parametrize("case", _CASES, ids=lambda case: case["id"])
def test_deterministic_parser_matches_shared_oracle(case: dict[str, object]) -> None:
    from app.services.document_parser.avs_official_pension_parser import (
        parse_avs_official_pension,
    )

    result = parse_avs_official_pension(str(case["input"]))
    expected = case["expected"]

    assert result.document_type.value == "avs_official_pension"
    assert result.rejection_reason == expected["rejection_reason"]

    if expected["rejection_reason"] is not None:
        assert result.fields == []
        return

    assert len(result.fields) == 1
    candidate = result.fields[0]
    assert candidate.field_name == expected["canonical_key"]
    assert candidate.value == expected["value_chf_month"]
    assert candidate.source == expected["source"]
    assert candidate.source_date == expected["source_date"]
    assert candidate.evidence_kind == expected["evidence_kind"]
    assert candidate.needs_review is True


def test_issue_date_day_thirteen_is_not_a_thirteenth_pension_marker() -> None:
    from app.services.document_parser.avs_official_pension_parser import (
        parse_avs_official_pension,
    )

    result = parse_avs_official_pension(str(_CASE_BY_ID["P11"]["input"]))

    assert result.rejection_reason is None
    assert result.fields[0].evidence_kind == "official_forecast"


@pytest.mark.parametrize(
    "text",
    [
        (
            "Caisse de compensation — Établi le 15.03.2026. "
            "Votre rente mensuelle de vieillesse AVS: CHF 1'930.00"
        ),
        (
            "Ausgleichskasse — Ausgestellt am 16.03.2026. "
            "Ihre monatliche Altersrente: CHF 1'940.00"
        ),
        (
            "Cassa di compensazione — Emesso il 17.03.2026. "
            "Sua rendita mensile di vecchiaia: CHF 1'950.00"
        ),
    ],
)
def test_ambiguous_accepted_official_result_falls_back_to_forecast(text: str) -> None:
    from app.services.document_parser.avs_official_pension_parser import (
        parse_avs_official_pension,
    )

    result = parse_avs_official_pension(text)

    assert result.rejection_reason is None
    assert result.fields[0].evidence_kind == "official_forecast"


def test_document_type_is_distinct_from_avs_contribution_extract() -> None:
    from app.schemas.document_scan import DocumentType as ApiDocumentType
    from app.services.document_parser.document_models import DocumentType

    assert DocumentType.avs_official_pension.value == "avs_official_pension"
    assert DocumentType.avs_official_pension is not DocumentType.avs_extract
    assert ApiDocumentType.avs_official_pension.value == "avs_official_pension"
    assert ApiDocumentType.avs_official_pension is not ApiDocumentType.avs_extract


def test_avs_contribution_extract_cannot_emit_official_pension_candidate() -> None:
    from app.services.document_parser.avs_extract_parser import parse_avs_extract

    result = parse_avs_extract(str(_CASES[0]["input"]))

    assert result.document_type.value == "avs_extract"
    assert result.get_field("avs_official_monthly_pension") is None


def test_internal_vision_service_also_blocks_official_type() -> None:
    from app.schemas.document_scan import DocumentType
    from app.services.document_vision_service import extract_with_vision

    with pytest.raises(ValueError, match="disabled pending privacy review"):
        extract_with_vision(
            image_base64="c2FmZS1zeW50aGV0aWM=",
            doc_type=DocumentType.avs_official_pension,
        )


def test_parse_schema_accepts_only_exact_current_official_type() -> None:
    request = ParseDocumentRequest(**_official_payload(str(_CASES[0]["input"])))
    assert request.document_type == "avs_official_pension"

    with pytest.raises(ValidationError):
        ParseDocumentRequest(
            documentType="avs_official_pension_v0",
            text=str(_CASES[0]["input"]),
        )

    confidence_request = ConfidenceDeltaRequest(
        **_official_payload(str(_CASES[0]["input"]))
    )
    assert confidence_request.document_type == "avs_official_pension"


@pytest.mark.parametrize("raw", [None, "", "false", "0", "no", "invalid", "TRUE-ish"])
def test_backend_kill_switch_defaults_and_fails_closed(
    monkeypatch: pytest.MonkeyPatch,
    raw: str | None,
) -> None:
    if raw is None:
        monkeypatch.delenv("AVS_OFFICIAL_PENSION_INGESTION_ENABLED", raising=False)
    else:
        monkeypatch.setenv("AVS_OFFICIAL_PENSION_INGESTION_ENABLED", raw)

    assert FeatureFlags.get_flags()["avs_official_pension_ingestion_enabled"] is False


@pytest.mark.parametrize("raw", ["1", "true", "yes", "TRUE", "Yes"])
def test_backend_kill_switch_accepts_explicit_true_only(
    monkeypatch: pytest.MonkeyPatch,
    raw: str,
) -> None:
    monkeypatch.setenv("AVS_OFFICIAL_PENSION_INGESTION_ENABLED", raw)
    assert FeatureFlags.get_flags()["avs_official_pension_ingestion_enabled"] is True


def test_flag_off_parse_rejects_before_parser(monkeypatch: pytest.MonkeyPatch, client: TestClient) -> None:
    _flag(monkeypatch, False)

    with patch(
        "app.api.v1.endpoints.document_parser.parse_avs_official_pension"
    ) as parser:
        response = client.post(
            "/api/v1/document-parser/parse",
            json=_official_payload(str(_CASES[0]["input"])),
        )

    assert response.status_code == 403
    assert response.json()["detail"] == "Feature 'avs_official_pension_ingestion_enabled' is not enabled"
    parser.assert_not_called()


def test_flag_on_parse_returns_ephemeral_review_candidate(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
) -> None:
    _flag(monkeypatch, True)

    response = client.post(
        "/api/v1/document-parser/parse",
        json=_official_payload(str(_CASES[0]["input"])),
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["documentType"] == "avs_official_pension"
    assert body["rejectionReason"] is None
    assert body["extractionScore"] == 0.0
    assert body["overallConfidence"] == 0.0
    assert body["fields"] == [
        {
            "fieldName": "avs_official_monthly_pension",
            "value": 1842.0,
            "confidence": 1.0,
            "sourceText": "Votre rente mensuelle de vieillesse AVS: CHF 1'842.00",
            "needsReview": True,
            "source": "certificate",
            "sourceDate": "2026-02-14",
            "evidenceKind": "official_decision",
        }
    ]


@pytest.mark.parametrize(
    ("case_index", "evidence_kind"),
    [(1, "official_forecast"), (2, "official_statement")],
)
def test_parse_preserves_official_evidence_kind(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    case_index: int,
    evidence_kind: str,
) -> None:
    _flag(monkeypatch, True)

    response = client.post(
        "/api/v1/document-parser/parse",
        json=_official_payload(str(_CASES[case_index]["input"])),
    )

    assert response.status_code == 200, response.text
    assert response.json()["fields"][0]["evidenceKind"] == evidence_kind


@pytest.mark.parametrize("enabled, expected_status", [(False, 403), (True, 409)])
def test_confidence_delta_never_promotes_unreviewed_official_candidate(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    enabled: bool,
    expected_status: int,
) -> None:
    _flag(monkeypatch, enabled)

    response = client.post(
        "/api/v1/document-parser/confidence-delta",
        json=_official_payload(str(_CASES[0]["input"])),
    )

    assert response.status_code == expected_status, response.text


@pytest.mark.parametrize("enabled, expected_status", [(False, 403), (True, 409)])
def test_field_impact_never_promotes_unreviewed_official_candidate(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    enabled: bool,
    expected_status: int,
) -> None:
    _flag(monkeypatch, enabled)

    response = client.get(
        "/api/v1/document-parser/field-impact/avs_official_pension"
    )

    assert response.status_code == expected_status, response.text


@pytest.mark.parametrize(
    ("case_id", "expected_reason"),
    [
        ("N01", "statutory_reference_value"),
        ("N26", "authority_result_marker_missing"),
        ("N27", "monthly_amount_implausible"),
        ("N28", "monthly_amount_implausible"),
    ],
)
def test_parse_endpoint_round_trips_rejection_reasons(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    case_id: str,
    expected_reason: str,
) -> None:
    _flag(monkeypatch, True)

    response = client.post(
        "/api/v1/document-parser/parse",
        json=_official_payload(str(_CASE_BY_ID[case_id]["input"])),
    )

    assert response.status_code == 200, response.text
    assert response.json()["fields"] == []
    assert response.json()["rejectionReason"] == expected_reason


def test_pure_candidate_endpoint_performs_no_pre_review_database_write(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
) -> None:
    _flag(monkeypatch, True)
    _seed_profile()
    before = _database_snapshot()

    response = client.post(
        "/api/v1/document-parser/parse",
        json=_official_payload(str(_CASES[0]["input"])),
    )

    assert response.status_code == 200, response.text
    assert _database_snapshot() == before == ({"existingFact": "unchanged"}, 0)


@pytest.mark.parametrize("enabled, expected_status", [(False, 403), (True, 409)])
def test_vision_path_is_blocked_before_extraction_or_write(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    enabled: bool,
    expected_status: int,
) -> None:
    _flag(monkeypatch, enabled)
    _seed_profile()
    before = _database_snapshot()

    response = client.post(
        "/api/v1/documents/extract-vision",
        json=_vision_payload("c2FmZS1zeW50aGV0aWM="),
    )

    assert response.status_code == expected_status, response.text
    assert _database_snapshot() == before == ({"existingFact": "unchanged"}, 0)


@pytest.mark.parametrize("enabled, expected_status", [(False, 403), (True, 409)])
def test_legacy_scan_confirmation_cannot_write_official_candidate(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    enabled: bool,
    expected_status: int,
) -> None:
    _flag(monkeypatch, enabled)
    _seed_profile()
    before = _database_snapshot()

    response = client.post(
        "/api/v1/documents/scan-confirmation",
        json=_confirmation_payload(),
    )

    assert response.status_code == expected_status, response.text
    assert _database_snapshot() == before == ({"existingFact": "unchanged"}, 0)


def test_stale_unknown_type_cannot_bypass_or_write(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
) -> None:
    _flag(monkeypatch, True)
    _seed_profile()
    before = _database_snapshot()
    stale = _confirmation_payload()
    stale["documentType"] = "avs_official_pension_v0"

    response = client.post("/api/v1/documents/scan-confirmation", json=stale)

    assert response.status_code == 422
    assert _database_snapshot() == before == ({"existingFact": "unchanged"}, 0)


@pytest.mark.parametrize("enabled, expected_status", [(False, 403), (True, 409)])
def test_legacy_insight_path_cannot_forward_candidate_to_llm(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    enabled: bool,
    expected_status: int,
) -> None:
    _flag(monkeypatch, enabled)
    payload = {
        "documentType": "avs_official_pension",
        "overallConfidence": 1.0,
        "extractedFields": _confirmation_payload()["confirmedFields"],
    }

    with patch(
        "app.api.v1.endpoints.documents.generate_document_insight"
    ) as generate_insight:
        response = client.post("/api/v1/documents/premier-eclairage", json=payload)

    assert response.status_code == expected_status, response.text
    generate_insight.assert_not_called()


def test_official_path_logs_no_source_text_or_amount(
    monkeypatch: pytest.MonkeyPatch,
    client: TestClient,
    caplog: pytest.LogCaptureFixture,
) -> None:
    from app.api.v1.endpoints import document_parser as endpoint_module

    _flag(monkeypatch, True)
    source_text = str(_CASES[0]["input"])

    endpoint_tree = ast.parse(
        textwrap.dedent(inspect.getsource(endpoint_module.parse_document))
    )
    logging_methods = {
        "debug",
        "info",
        "warning",
        "error",
        "exception",
        "critical",
    }
    forbidden_calls = [
        node
        for node in ast.walk(endpoint_tree)
        if isinstance(node, ast.Call)
        and (
            (isinstance(node.func, ast.Attribute) and node.func.attr in logging_methods)
            or (isinstance(node.func, ast.Name) and node.func.id == "print")
        )
    ]
    assert forbidden_calls == []

    with caplog.at_level(logging.INFO):
        response = client.post(
            "/api/v1/document-parser/parse",
            json=_official_payload(source_text),
        )

    assert response.status_code == 200, response.text
    logged = caplog.text
    assert source_text not in logged
    assert "1'842" not in logged
    assert "1842" not in logged
