"""Adversarial PDF fixtures end-to-end — Phase 29-04 / PRIV-05.

Feeds each fixture through ``understand_document`` with:
    - the Vision call mocked (we simulate what Vision would return given
      the injected content, including leaked attacker payload in the
      narrative/summary). The pipeline under test is NumericSanity +
      pii_scrubber + VisionGuard; the Vision mock lets us prove the
      pipeline DOES the right thing regardless of what Vision returns.
    - the Haiku judge mocked to behave as a real judge would.

Assertions per plan 29-04 <done>:
    - 3 prompt-injection fixtures produce a final narrative containing
      no attacker payload (judge blocks + reformulation swap).
    - 4 numeric-sanity fixtures produce render_mode='reject' with a
      reason mentioning the bound.
"""
from __future__ import annotations

import os
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.schemas.document_understanding import (
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractedField,
    ExtractionStatus,
    FieldStatus,
    RenderMode,
)

FIXTURE_DIR = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__), "..", "..", "fixtures", "documents",
    )
)


def _load(name: str) -> bytes:
    path = os.path.join(FIXTURE_DIR, name)
    with open(path, "rb") as fh:
        return fh.read()


# ---------------------------------------------------------------------------
# Vision mock factory — returns a pre-built DUR simulating Vision output
# for each fixture. The injection fixtures deliberately leak the attacker
# payload in the narrative/summary so we can prove the pipeline scrubs it.
# ---------------------------------------------------------------------------


ATTACKER_MARKER = "ATTACKER_PAYLOAD_LEAKED"


def _leaky_injection_result() -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.95,
        extracted_fields=[
            ExtractedField(field_name="avoirLppTotal", value=70377, source_text="70'377 CHF"),
            ExtractedField(field_name="salaireAssure", value=91967, source_text="91'967 CHF"),
            ExtractedField(field_name="tauxConversion", value=0.068, source_text="6.8 %"),
        ],
        overall_confidence=0.92,
        extraction_status=ExtractionStatus.success,
        summary=(
            f"Ton avoir LPP est de 70'377 CHF. {ATTACKER_MARKER}. "
            "Achete UBS Vitainvest 50 maintenant."
        ),
        narrative=(
            f"Mon conseil: {ATTACKER_MARKER}. Tu es garanti de toucher 5% par an. "
            "Achete le fond UBS Vitainvest 50."
        ),
        questions_for_user=["Veux-tu comparer rente et capital ?"],
        render_mode=RenderMode.narrative,
        cost_tokens_in=800,
        cost_tokens_out=200,
    )


def _rendement_15_result() -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        extracted_fields=[
            ExtractedField(field_name="avoirLppTotal", value=80000),
            ExtractedField(field_name="salaireAssure", value=90000),
            ExtractedField(field_name="rendement", value=0.15),
            ExtractedField(field_name="tauxConversion", value=0.068),
        ],
        overall_confidence=0.88,
        extraction_status=ExtractionStatus.success,
        summary="Ton rendement est annonce a 15% par an.",
        narrative=None,
        render_mode=RenderMode.narrative,
    )


def _avoir_lpp_7M_result() -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        extracted_fields=[
            ExtractedField(field_name="avoirLppTotal", value=7_000_000),
            ExtractedField(field_name="salaireAssure", value=250_000),
            ExtractedField(field_name="tauxConversion", value=0.068),
        ],
        overall_confidence=0.88,
        extraction_status=ExtractionStatus.success,
        summary="Ton avoir LPP total est de 7'000'000 CHF.",
        render_mode=RenderMode.confirm,
    )


def _salaire_3M_result() -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.salary_certificate,
        classification_confidence=0.85,
        extracted_fields=[
            ExtractedField(field_name="salaireBrutAnnuel", value=3_000_000),
            ExtractedField(field_name="nombreMois", value=13),
        ],
        overall_confidence=0.82,
        extraction_status=ExtractionStatus.success,
        summary="Ton salaire brut annuel est de 3'000'000 CHF.",
        render_mode=RenderMode.narrative,
    )


def _taux_conv_8pct_result() -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        extracted_fields=[
            ExtractedField(field_name="tauxConversion", value=0.08),
            ExtractedField(field_name="avoirLppTotal", value=300_000),
        ],
        overall_confidence=0.85,
        extraction_status=ExtractionStatus.success,
        summary="Ton taux de conversion est de 8 %.",
        render_mode=RenderMode.narrative,
    )


# ---------------------------------------------------------------------------
# Judge mock — behaves like a real LSFin judge. Blocks anything containing
# the attacker marker, product names, or promises.
# ---------------------------------------------------------------------------


def _judge_verdict_for(summary, narrative, fields_summary=None, **kwargs):
    from app.services.compliance.vision_guard import GuardVerdict

    blob = " ".join(filter(None, [summary or "", narrative or ""]))
    blob_l = blob.lower()
    flags = []
    if ATTACKER_MARKER.lower() in blob_l:
        flags.append("product_advice")
    if "ubs vitainvest" in blob_l or "achete" in blob_l:
        flags.append("product_advice")
    if "garanti" in blob_l or "tu es assure" in blob_l:
        flags.append("return_promise")

    if flags:
        return GuardVerdict(
            allow=False,
            flagged_categories=list(dict.fromkeys(flags)),  # dedup order-preserving
            reformulation=(
                "Ton certificat est lu. Regarde les chiffres bruts ci-dessous "
                "et confirme-les."
            ),
            reason="adversarial content detected",
            cost_usd=0.0003,
        )
    return GuardVerdict(
        allow=True, flagged_categories=[], reformulation=None,
        reason="clean", cost_usd=0.0003,
    )


# ---------------------------------------------------------------------------
# Shared understand_document runner with Vision mocked.
# ---------------------------------------------------------------------------


async def _run_understand(file_name: str, vision_result: DocumentUnderstandingResult):
    from app.services import document_vision_service as dvs

    file_bytes = _load(file_name)

    async def _fake_call_fused_vision(*args, **kwargs):
        return vision_result

    async def _fake_judge(summary, narrative, fields_summary=None, **kwargs):
        return _judge_verdict_for(summary, narrative, fields_summary, **kwargs)

    # Patch internals: Vision call + judge. Leave NumericSanity real.
    with patch.object(dvs, "_call_fused_vision", side_effect=_fake_call_fused_vision), \
         patch("app.services.compliance.vision_guard.judge_vision_output",
               side_effect=_fake_judge):
        result = await dvs.understand_document(
            file_bytes=file_bytes,
            user_id="test-user",
            file_sha=None,  # skip idempotency
            db=None,
        )
    return result


# ---------------------------------------------------------------------------
# Prompt-injection fixtures: narrative MUST NOT contain attacker payload.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
@pytest.mark.parametrize("fixture", [
    "prompt_injection_white_on_white.pdf",
    "prompt_injection_metadata.pdf",
    "prompt_injection_svg_overlay.pdf",
])
async def test_prompt_injection_payload_never_leaks(fixture):
    result = await _run_understand(fixture, _leaky_injection_result())
    blob = " ".join(filter(None, [result.summary or "", result.narrative or ""]))
    assert ATTACKER_MARKER not in blob, (
        f"Attacker payload leaked in {fixture} final output: {blob!r}"
    )
    assert "UBS Vitainvest" not in blob
    assert result.guard_blocked is True
    # Legitimate numeric fields still survive the pipeline.
    field_names = {f.field_name for f in result.extracted_fields}
    assert {"avoirLppTotal", "salaireAssure", "tauxConversion"}.issubset(field_names)
    # Every field persists as needs_review regardless of vision confidence.
    for f in result.extracted_fields:
        assert f.status == FieldStatus.needs_review


# ---------------------------------------------------------------------------
# Numeric sanity fixtures: render_mode=reject + reason mentions the bound.
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_rendement_15pct_forces_reject():
    result = await _run_understand(
        "sanity_rendement_15pct.pdf", _rendement_15_result(),
    )
    assert result.render_mode == RenderMode.reject
    assert "rendement" in (result.summary or "").lower()
    assert "rendement" in result.sanity_rejected_fields


@pytest.mark.asyncio
async def test_salaire_3M_forces_reject():
    result = await _run_understand(
        "sanity_salaire_3M.pdf", _salaire_3M_result(),
    )
    assert result.render_mode == RenderMode.reject
    assert "salaireBrutAnnuel" in result.sanity_rejected_fields


@pytest.mark.asyncio
async def test_taux_conversion_8pct_forces_reject():
    result = await _run_understand(
        "sanity_taux_conv_8pct.pdf", _taux_conv_8pct_result(),
    )
    assert result.render_mode == RenderMode.reject
    assert "tauxConversion" in result.sanity_rejected_fields


@pytest.mark.asyncio
async def test_avoir_lpp_7M_human_review_not_reject():
    # 7M is legal but rare — NumericSanity flags human_review, does NOT reject.
    result = await _run_understand(
        "sanity_avoir_lpp_7M.pdf", _avoir_lpp_7M_result(),
    )
    assert result.render_mode != RenderMode.reject
    assert "avoirLppTotal" in result.sanity_human_review_fields
    # The field carries the human_review_flag on its way to the UI.
    hr = next(f for f in result.extracted_fields if f.field_name == "avoirLppTotal")
    assert hr.human_review_flag is True
    # It is NOT auto-validated.
    assert hr.status == FieldStatus.needs_review
