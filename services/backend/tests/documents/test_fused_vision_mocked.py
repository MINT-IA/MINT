"""Phase 28-01 / Task 5: fused understand_document() with mocked Anthropic."""
from __future__ import annotations

import base64
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.schemas.document_understanding import (
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractionStatus,
    RenderMode,
)


# ── Helpers ────────────────────────────────────────────────────────────────

def _mock_anthropic_response(tool_input: dict, tokens_in: int = 800, tokens_out: int = 400):
    """Build a stub anthropic response object with one tool_use block."""
    block = SimpleNamespace(type="tool_use", input=tool_input, name="route_and_extract")
    usage = SimpleNamespace(input_tokens=tokens_in, output_tokens=tokens_out)
    return SimpleNamespace(content=[block], usage=usage)


def _png_bytes() -> bytes:
    # 1x1 transparent PNG
    return base64.b64decode(
        b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
    )


@pytest.fixture(autouse=True)
def _redis_fakes():
    import fakeredis.aioredis as fakeaio
    from app.core import redis_client
    redis_client.set_redis_client_for_tests(fakeaio.FakeRedis(decode_responses=True))
    yield
    redis_client.reset_for_tests()


@pytest.fixture
def patch_settings(monkeypatch):
    from app.core.config import settings
    monkeypatch.setattr(settings, "ANTHROPIC_API_KEY", "test-key", raising=False)
    monkeypatch.setattr(settings, "COACH_MODEL", "claude-sonnet-4-5-20250929", raising=False)


# ── Test 1: happy path returns canonical contract with render_mode set ─────

@pytest.mark.asyncio
async def test_understand_document_returns_canonical_result(patch_settings):
    from app.services import document_vision_service as dvs

    tool_input = {
        "document_class": "lpp_certificate",
        "issuer_guess": "CPE",
        "subtype": "cpe_plan_maxi",
        "classification_confidence": 0.95,
        "extracted_fields": [
            {"field_name": "salaireAssure", "value": 91967, "confidence": "high", "source_text": "Salaire assuré: CHF 91'967.-"},
            {"field_name": "avoirLppTotal", "value": 70377, "confidence": "high", "source_text": "Avoir total CHF 70'377.-"},
        ],
        "overall_confidence": 0.93,
        "summary": "C'est un CPE Plan Maxi. Bonification 24%, au-dessus du minimum.",
        "questions_for_user": [],
        "narrative": None,
    }
    fake_resp = _mock_anthropic_response(tool_input)

    mock_client = MagicMock()
    mock_client.messages.create = AsyncMock(return_value=fake_resp)

    with patch.object(dvs, "AsyncAnthropic", return_value=mock_client) as ctor:
        result = await dvs.understand_document(
            file_bytes=_png_bytes(),
            user_id="user-julien",
            canton="VS",
            lang="fr",
            file_sha="deadbeef" * 8,
        )

    assert ctor.called
    assert mock_client.messages.create.await_count == 1, "exactly one fused Vision call"
    assert isinstance(result, DocumentUnderstandingResult)
    assert result.document_class == DocumentClass.lpp_certificate
    assert result.issuer_guess == "CPE"
    assert result.extraction_status == ExtractionStatus.success
    assert result.render_mode == RenderMode.confirm
    assert result.cost_tokens_in == 800
    assert result.cost_tokens_out == 400


# ── Test 2: AcroForm PDF skips Vision entirely ─────────────────────────────

@pytest.mark.asyncio
async def test_acroform_pdf_skips_vision(patch_settings, tmp_path):
    pymupdf = pytest.importorskip("pymupdf")
    from app.services import document_vision_service as dvs

    # Build an AcroForm PDF
    doc = pymupdf.open()
    page = doc.new_page()
    w = pymupdf.Widget()
    w.field_name = "salaireAssure"
    w.field_type = pymupdf.PDF_WIDGET_TYPE_TEXT
    w.field_value = "91967"
    w.rect = pymupdf.Rect(72, 72, 200, 100)
    page.add_widget(w)
    out = tmp_path / "form.pdf"
    doc.save(str(out))
    doc.close()

    mock_client = MagicMock()
    mock_client.messages.create = AsyncMock()
    with patch.object(dvs, "AsyncAnthropic", return_value=mock_client):
        result = await dvs.understand_document(
            file_bytes=out.read_bytes(),
            user_id="user-julien",
            file_sha="acroform" * 8,
        )

    assert mock_client.messages.create.await_count == 0
    assert result.cost_tokens_in == 0
    assert result.cost_tokens_out == 0
    assert result.extraction_status == ExtractionStatus.success
    field_names = {f.field_name for f in result.extracted_fields}
    assert "salaireAssure" in field_names


# ── Test 3: encrypted PDF returns clean status ─────────────────────────────

@pytest.mark.asyncio
async def test_encrypted_pdf_returns_password_status(patch_settings, tmp_path):
    pymupdf = pytest.importorskip("pymupdf")
    from app.services import document_vision_service as dvs

    doc = pymupdf.open()
    page = doc.new_page()
    page.insert_text((72, 72), "secret", fontsize=12)
    pdf_bytes = doc.tobytes(
        encryption=pymupdf.PDF_ENCRYPT_AES_256,
        owner_pw="ow",
        user_pw="us",
        permissions=int(pymupdf.PDF_PERM_PRINT),
    )
    doc.close()

    mock_client = MagicMock()
    mock_client.messages.create = AsyncMock()
    with patch.object(dvs, "AsyncAnthropic", return_value=mock_client):
        result = await dvs.understand_document(
            file_bytes=pdf_bytes,
            user_id="user-julien",
            file_sha="enc" * 22,  # >32 just for shape
        )

    assert mock_client.messages.create.await_count == 0
    assert result.extraction_status == ExtractionStatus.encrypted_needs_password
    assert result.render_mode == RenderMode.narrative
    assert result.summary is not None and "mot de passe" in result.summary.lower()


# ── Test 4: non_financial → reject + summary set ───────────────────────────

@pytest.mark.asyncio
async def test_non_financial_returns_reject(patch_settings):
    from app.services import document_vision_service as dvs

    tool_input = {
        "document_class": "non_financial",
        "classification_confidence": 0.97,
        "extracted_fields": [],
        "overall_confidence": 0.0,
        "summary": "Ce document ne semble pas financier.",
        "questions_for_user": [],
        "narrative": None,
    }
    fake_resp = _mock_anthropic_response(tool_input)
    mock_client = MagicMock()
    mock_client.messages.create = AsyncMock(return_value=fake_resp)

    with patch.object(dvs, "AsyncAnthropic", return_value=mock_client):
        result = await dvs.understand_document(
            file_bytes=_png_bytes(),
            user_id="user-julien",
            file_sha="nonfin01" * 8,
        )

    assert result.document_class == DocumentClass.non_financial
    assert result.extraction_status == ExtractionStatus.non_financial
    assert result.render_mode == RenderMode.reject
    assert result.summary is not None


# ── Test 5: ComplianceGuard scrubs summary + narrative + questions ────────

@pytest.mark.asyncio
async def test_compliance_guard_scrubs_free_text(patch_settings):
    from app.services import document_vision_service as dvs

    tool_input = {
        "document_class": "lpp_certificate",
        "classification_confidence": 0.92,
        "extracted_fields": [
            {"field_name": "salaireAssure", "value": 91967, "confidence": "high", "source_text": "Salaire assuré 91'967"},
        ],
        "overall_confidence": 0.92,
        # Banned terms in free text — must be sanitised before return
        "summary": "Ton rendement est garanti à 5% — c'est optimal pour toi.",
        "questions_for_user": ["Ton conseiller t'a-t-il proposé ce plan ?"],
        "narrative": None,
    }
    fake_resp = _mock_anthropic_response(tool_input)
    mock_client = MagicMock()
    mock_client.messages.create = AsyncMock(return_value=fake_resp)

    with patch.object(dvs, "AsyncAnthropic", return_value=mock_client):
        result = await dvs.understand_document(
            file_bytes=_png_bytes(),
            user_id="user-julien",
            file_sha="scrub" * 13,
        )

    assert "garanti" not in (result.summary or "").lower()
    assert "optimal" not in (result.summary or "").lower()
    assert all("conseiller" not in q.lower() for q in result.questions_for_user)


# ── Test 6: TokenBudget consumed with kind=vision ─────────────────────────

@pytest.mark.asyncio
async def test_token_budget_consumed(patch_settings):
    from app.services import document_vision_service as dvs

    tool_input = {
        "document_class": "lpp_certificate",
        "classification_confidence": 0.9,
        "extracted_fields": [
            {"field_name": "salaireAssure", "value": 91967, "confidence": "high", "source_text": "x"},
        ],
        "overall_confidence": 0.9,
        "summary": "Document lu.",
        "questions_for_user": [],
        "narrative": None,
    }
    fake_resp = _mock_anthropic_response(tool_input, tokens_in=1200, tokens_out=300)
    mock_client = MagicMock()
    mock_client.messages.create = AsyncMock(return_value=fake_resp)

    with patch.object(dvs, "AsyncAnthropic", return_value=mock_client):
        with patch("app.services.coach.token_budget.TokenBudget.consume", new_callable=AsyncMock) as mock_consume:
            await dvs.understand_document(
                file_bytes=_png_bytes(),
                user_id="user-julien",
                file_sha="bud" * 11,
            )

    assert mock_consume.await_count >= 1
    # Sum of in+out tokens passed
    args, kwargs = mock_consume.await_args
    # consume(user_id, tokens) — positional or kw
    total = (args[1] if len(args) > 1 else kwargs.get("tokens")) or 0
    assert total == 1500


# ── Test 7: Idempotency by file SHA short-circuits Vision ─────────────────

@pytest.mark.asyncio
async def test_idempotency_short_circuits_vision(patch_settings):
    from app.services import document_vision_service as dvs
    from app.services import idempotency

    # Pre-populate cache with a previous result
    cached = DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.99,
        overall_confidence=0.99,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
        summary="cached result",
    )
    sha = "cached00" * 8
    await idempotency.store_by_file_sha(sha, cached.model_dump(mode="json"))

    mock_client = MagicMock()
    mock_client.messages.create = AsyncMock()
    with patch.object(dvs, "AsyncAnthropic", return_value=mock_client):
        result = await dvs.understand_document(
            file_bytes=_png_bytes(),
            user_id="user-julien",
            file_sha=sha,
        )

    assert mock_client.messages.create.await_count == 0
    assert result.summary == "cached result"
