"""Phase 28-01 / Task 5: schema mapping + endpoint flag-gated behaviour."""
from __future__ import annotations

from app.schemas.document_understanding import (
    ConfidenceLevel,
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractedField,
    ExtractionStatus,
    FieldDiff,
    RenderMode,
)


def test_minimal_schema_validates():
    r = DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        overall_confidence=0.9,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
    )
    assert r.schema_version == "1.0"
    assert r.extracted_fields == []
    assert r.questions_for_user == []
    assert r.third_party_detected is False


def test_questions_for_user_max_length_3():
    import pytest
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        DocumentUnderstandingResult(
            document_class=DocumentClass.lpp_certificate,
            classification_confidence=0.9,
            overall_confidence=0.9,
            extraction_status=ExtractionStatus.success,
            render_mode=RenderMode.ask,
            questions_for_user=["q1", "q2", "q3", "q4"],
        )


def test_camel_case_alias_round_trip():
    r = DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        issuer_guess="CPE",
        extracted_fields=[
            ExtractedField(field_name="x", value=1.0, confidence=ConfidenceLevel.high, source_text="x"),
        ],
        overall_confidence=0.9,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
        third_party_detected=True,
        third_party_name="Marc Dupont",
        diff_from_previous={"x": FieldDiff(old=1.0, new=2.0, delta_pct=100.0)},
    )
    js = r.model_dump(by_alias=True, mode="json")
    assert "documentClass" in js
    assert "issuerGuess" in js
    assert "thirdPartyDetected" in js
    assert "diffFromPrevious" in js
    # Round-trip parse
    r2 = DocumentUnderstandingResult.model_validate(js)
    assert r2.issuer_guess == "CPE"
    assert r2.third_party_detected is True
    assert r2.diff_from_previous["x"].delta_pct == 100.0


def test_fingerprint_field_optional():
    r = DocumentUnderstandingResult(
        document_class=DocumentClass.bank_statement,
        classification_confidence=0.5,
        overall_confidence=0.5,
        extraction_status=ExtractionStatus.partial,
        render_mode=RenderMode.narrative,
    )
    assert r.fingerprint is None
    r.fingerprint = "abc123"
    assert r.fingerprint == "abc123"
