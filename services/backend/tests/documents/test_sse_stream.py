"""Phase 28-02 / Task 1: SSE streaming for understand_document.

Tests the document_stream.stream_understanding async generator and the
/extract-vision endpoint Accept-header content negotiation (JSON vs
text/event-stream) behind the DOCUMENTS_V2_ENABLED flag.
"""
from __future__ import annotations

import base64
import json
from unittest.mock import AsyncMock, patch

import pytest

from app.schemas.document_understanding import (
    CommitmentSuggestion,
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractedField,
    ExtractionStatus,
    RenderMode,
)
from app.schemas.document_scan import ConfidenceLevel


# ── Helpers ────────────────────────────────────────────────────────────────


def _png_b64() -> str:
    return (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lE"
        "QVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
    )


def _lpp_result(extra_fields: list[ExtractedField] | None = None) -> DocumentUnderstandingResult:
    """Build a controlled LPP result for stream tests (fields out of order)."""
    fields = extra_fields or [
        # Deliberately scrambled to prove EMOTIONAL_IMPORTANCE re-orders.
        ExtractedField(field_name="bonificationVieillesse", value=24, confidence=ConfidenceLevel.high, source_text="Bonif 24%"),
        ExtractedField(field_name="tauxConversion", value=6.0, confidence=ConfidenceLevel.high, source_text="6.0%"),
        ExtractedField(field_name="avoirLppTotal", value=70377, confidence=ConfidenceLevel.high, source_text="CHF 70'377"),
        ExtractedField(field_name="salaireAssure", value=91967, confidence=ConfidenceLevel.high, source_text="CHF 91'967"),
        ExtractedField(field_name="rachatMaximum", value=539414, confidence=ConfidenceLevel.medium, source_text="CHF 539'414"),
    ]
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        issuer_guess="CPE",
        subtype="cpe_plan_maxi",
        classification_confidence=0.95,
        extracted_fields=fields,
        overall_confidence=0.92,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
        summary="CPE Plan Maxi: avoir 70'377, bonif 24%.",
        narrative="Plan généreux. Au-dessus du minimum LPP.",
        commitment_suggestion=CommitmentSuggestion(action_label="Planifier rachat"),
        third_party_detected=False,
        fingerprint="fp-abc",
    )


def _reject_result() -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.non_financial,
        classification_confidence=0.92,
        extracted_fields=[],
        overall_confidence=0.0,
        extraction_status=ExtractionStatus.non_financial,
        render_mode=RenderMode.reject,
        summary="Pas un document financier.",
    )


def _encrypted_result() -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.unknown,
        classification_confidence=0.0,
        extracted_fields=[],
        overall_confidence=0.0,
        extraction_status=ExtractionStatus.encrypted_needs_password,
        render_mode=RenderMode.narrative,
        summary="Ce PDF est protégé par un mot de passe.",
    )


# ── Fixtures ───────────────────────────────────────────────────────────────


@pytest.fixture(autouse=True)
def _redis_fakes():
    import fakeredis.aioredis as fakeaio
    from app.core import redis_client
    redis_client.set_redis_client_for_tests(fakeaio.FakeRedis(decode_responses=True))
    yield
    redis_client.reset_for_tests()


# ── Generator tests (Tests 1-4, 7) ─────────────────────────────────────────


@pytest.mark.asyncio
async def test_stream_emits_events_in_canonical_order():
    """Test 1: stream emits [stage:received, stage:preflight,
    stage:classify_confirmed, field × N, narrative, done] with summary
    in classify_confirmed payload."""
    from app.services import document_stream as ds

    with patch.object(ds, "understand_document", new=AsyncMock(return_value=_lpp_result())):
        events = [ev async for ev in ds.stream_understanding(b"x", user_id="u1")]

    types = [(e["event"], e["data"].get("stage") if e["event"] == "stage" else None) for e in events]
    # Expected order: 2 pre-call stages, then classify_confirmed, then fields, narrative, done
    assert types[0] == ("stage", "received")
    assert types[1] == ("stage", "preflight")
    assert types[2] == ("stage", "classify_confirmed")
    classify = events[2]["data"]
    assert classify["payload"]["document_class"] == "lpp_certificate"
    assert classify["payload"]["issuer_guess"] == "CPE"
    assert "summary" in classify["payload"]

    # last event must be done
    assert events[-1]["event"] == "done"
    # narrative event present before done
    narrative_idx = next(i for i, e in enumerate(events) if e["event"] == "narrative")
    assert narrative_idx == len(events) - 2
    assert events[narrative_idx]["data"]["text"].startswith("Plan généreux")


@pytest.mark.asyncio
async def test_field_events_ordered_by_emotional_importance():
    """Test 2: Field events ordered by EMOTIONAL_IMPORTANCE rank
    (avoirLppTotal before salaireAssure before tauxConversion before
    rachatMaximum before bonificationVieillesse)."""
    from app.services import document_stream as ds

    with patch.object(ds, "understand_document", new=AsyncMock(return_value=_lpp_result())):
        events = [ev async for ev in ds.stream_understanding(b"x", user_id="u1")]

    field_names = [e["data"]["name"] for e in events if e["event"] == "field"]
    expected = [
        "avoirLppTotal",
        "salaireAssure",
        "tauxConversion",
        "rachatMaximum",
        "bonificationVieillesse",
    ]
    assert field_names == expected


@pytest.mark.asyncio
async def test_reject_emits_no_field_events():
    """Test 3: render_mode=reject (non_financial) → stage:rejected + done,
    no field events."""
    from app.services import document_stream as ds

    with patch.object(ds, "understand_document", new=AsyncMock(return_value=_reject_result())):
        events = [ev async for ev in ds.stream_understanding(b"x", user_id="u1")]

    field_events = [e for e in events if e["event"] == "field"]
    assert field_events == []
    # done event carries render_mode=reject
    done = events[-1]
    assert done["event"] == "done"
    assert done["data"]["render_mode"] == "reject"


@pytest.mark.asyncio
async def test_encrypted_pdf_emits_no_field_events():
    """Test 4: encrypted PDF → no field events, done with encrypted status info."""
    from app.services import document_stream as ds

    with patch.object(ds, "understand_document", new=AsyncMock(return_value=_encrypted_result())):
        events = [ev async for ev in ds.stream_understanding(b"%PDF-1.4", user_id="u1")]

    assert [e for e in events if e["event"] == "field"] == []
    done = events[-1]
    assert done["event"] == "done"
    # Encrypted maps to narrative render_mode in selector; client surfaces password prompt.
    assert done["data"]["render_mode"] == "narrative"


@pytest.mark.asyncio
async def test_stream_idempotency_replay_emits_all_events():
    """Test 7: a second call with the same file_sha (cached result)
    still emits the canonical event sequence to the client."""
    from app.services import document_stream as ds

    mock_understand = AsyncMock(return_value=_lpp_result())
    with patch.object(ds, "understand_document", new=mock_understand):
        events1 = [ev async for ev in ds.stream_understanding(b"x", user_id="u1", file_sha="sha-1")]
        events2 = [ev async for ev in ds.stream_understanding(b"x", user_id="u1", file_sha="sha-1")]

    # Both replays produce the same shape (idempotency lives below understand_document)
    assert [e["event"] for e in events1] == [e["event"] for e in events2]
    assert events1[-1]["event"] == "done"
    assert events2[-1]["event"] == "done"


# ── Endpoint tests (Tests 5-6) ─────────────────────────────────────────────


def _patch_flag(monkeypatch, enabled: bool):
    from app.services import flags_service

    async def _is_enabled(name, user_id):
        return enabled

    monkeypatch.setattr(flags_service.flags, "is_enabled", _is_enabled, raising=False)


def test_endpoint_accept_json_returns_legacy_unary_response(client, monkeypatch):
    """Test 5: Accept: application/json → existing JSON response (backward compat)."""
    from app.services import document_vision_service as dvs
    from app.schemas.document_scan import VisionExtractionResponse

    _patch_flag(monkeypatch, enabled=False)  # legacy path

    fake_response = VisionExtractionResponse(
        document_type="lpp_certificate",
        extracted_fields=[],
        overall_confidence=0.0,
    )
    monkeypatch.setattr(dvs, "extract_with_vision", lambda **kw: fake_response)
    # Skip the local classify call so we don't hit Anthropic.
    from app.api.v1.endpoints import documents as docs_ep
    monkeypatch.setattr(docs_ep, "_classify_and_reject_if_needed", lambda _b: None)

    res = client.post(
        "/api/v1/documents/extract-vision",
        json={
            "documentType": "lpp_certificate",
            "imageBase64": _png_b64(),
        },
        headers={"Accept": "application/json"},
    )
    assert res.status_code == 200
    body = res.json()
    # Legacy contract — DocumentType + extracted_fields list
    assert "extractedFields" in body or "extracted_fields" in body


def test_endpoint_accept_event_stream_returns_sse(client, monkeypatch):
    """Test 6: Accept: text/event-stream + flag on → EventSourceResponse
    streaming the canonical event sequence."""
    from app.services import document_stream as ds

    _patch_flag(monkeypatch, enabled=True)
    monkeypatch.setattr(ds, "understand_document", AsyncMock(return_value=_lpp_result()))

    with client.stream(
        "POST",
        "/api/v1/documents/extract-vision",
        json={
            "documentType": "lpp_certificate",
            "imageBase64": _png_b64(),
        },
        headers={"Accept": "text/event-stream"},
    ) as res:
        assert res.status_code == 200
        ctype = res.headers.get("content-type", "")
        assert "text/event-stream" in ctype
        body = b"".join(res.iter_bytes()).decode("utf-8")

    # Parse the SSE frames
    lines = [ln for ln in body.splitlines() if ln.strip()]
    event_names = [ln.split(":", 1)[1].strip() for ln in lines if ln.startswith("event:")]
    # Must contain the canonical pre-call stages, then classify_confirmed,
    # at least one field, narrative, and done in order.
    assert event_names[0] == "stage"
    assert "field" in event_names
    assert event_names[-1] == "done"

    # Payload of done parses as JSON
    data_lines = [ln.split(":", 1)[1].strip() for ln in lines if ln.startswith("data:")]
    last_payload = json.loads(data_lines[-1])
    assert last_payload.get("render_mode") == "confirm"
