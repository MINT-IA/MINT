"""Immutable golden contract and opt-in live eval for the LPP kind classifier."""

from __future__ import annotations

import base64
from io import BytesIO
from hashlib import sha256
import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
import pytest

from app.schemas.document_scan import ConfidenceLevel
from app.services import document_vision_service as dvs
from app.services.llm.router import LLMRouter


_FIXTURE_ROOT = Path(__file__).parent / "fixtures"
_CORPUS_PATH = _FIXTURE_ROOT / "lpp_document_kind_classifier_golden.json"
_CORPUS_SHA256 = "9bdfa8489d7779d319f6eaf00d36c65b9e508868994f38d32f2ba5387e19f3f0"
_LIVE_EVAL_ENV = "MINT_RUN_LPP_CLASSIFIER_LIVE_EVAL"


class _AlwaysOffRouteFlags:
    async def is_enabled(self, _name: str, _user_id: str | None) -> bool:
        return False


def _load_corpus() -> dict:
    return json.loads(_CORPUS_PATH.read_text(encoding="utf-8"))


def _document_base64(case: dict) -> str:
    input_contract = case["input"]
    if input_contract["kind"] == "tracked_pdf":
        path = (_FIXTURE_ROOT / input_contract["relativePath"]).resolve()
        assert _FIXTURE_ROOT.resolve() in path.parents
        document_bytes = path.read_bytes()
        assert document_bytes.startswith(b"%PDF-")
        assert sha256(document_bytes).hexdigest() == input_contract["sha256"]
    else:
        assert input_contract["kind"] == "generated_png"
        image = Image.new("RGB", (1200, 1000), "white")
        draw = ImageDraw.Draw(image)
        font = ImageFont.load_default(size=28)
        draw.multiline_text(
            (60, 60),
            "\n".join(input_contract["lines"]),
            fill="black",
            font=font,
            spacing=14,
        )
        buffer = BytesIO()
        image.save(buffer, format="PNG")
        document_bytes = buffer.getvalue()
        assert document_bytes.startswith(b"\x89PNG\r\n\x1a\n")
    return base64.b64encode(document_bytes).decode("ascii")


def test_lpp_document_kind_golden_corpus_and_prompt_are_immutable():
    assert sha256(_CORPUS_PATH.read_bytes()).hexdigest() == _CORPUS_SHA256
    corpus = _load_corpus()

    assert set(corpus) == {
        "schemaVersion",
        "classifierPromptSha256",
        "liveEval",
        "cases",
    }
    assert corpus["schemaVersion"] == 1
    assert corpus["liveEval"] == {
        "provider": "anthropic",
        "model": "claude-sonnet-4-20250514",
    }
    assert corpus["classifierPromptSha256"] == sha256(
        dvs._CLASSIFICATION_PROMPT.encode("utf-8"),
    ).hexdigest()
    assert [case["id"] for case in corpus["cases"]] == [
        "personal_certificate_positive",
        "base_bonus_plan_negative",
    ]
    assert [case["expected"] for case in corpus["cases"]] == [
        {
            "isFinancial": True,
            "detectedType": "lpp_certificate",
            "confidence": "high",
        },
        {
            "isFinancial": True,
            "detectedType": "lpp_plan",
            "confidence": "high",
        },
    ]

    for case in corpus["cases"]:
        encoded_document = _document_base64(case)
        content_block = dvs._build_vision_content_block(encoded_document)
        expected_block = (
            ("document", "application/pdf")
            if case["input"]["kind"] == "tracked_pdf"
            else ("image", "image/png")
        )
        assert content_block["type"] == expected_block[0]
        assert content_block["source"]["media_type"] == expected_block[1]
        assert content_block["source"]["data"] == encoded_document

    assert '"lpp_certificate"' in dvs._CLASSIFICATION_PROMPT
    assert '"lpp_plan"' in dvs._CLASSIFICATION_PROMPT
    assert "plan_type" in dvs._CLASSIFICATION_PROMPT
    assert "orthogonal" in dvs._CLASSIFICATION_PROMPT.lower()


def test_lpp_document_kind_live_golden_eval(monkeypatch):
    """Call the real classifier only when the operator explicitly opts in."""
    if os.environ.get(_LIVE_EVAL_ENV) != "1":
        pytest.skip(f"live eval disabled; set {_LIVE_EVAL_ENV}=1")
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        pytest.skip("live eval requires ANTHROPIC_API_KEY")

    corpus = _load_corpus()
    live_contract = corpus["liveEval"]
    assert live_contract["provider"] == "anthropic"
    monkeypatch.setattr(dvs.settings, "ANTHROPIC_API_KEY", api_key)
    monkeypatch.setattr(dvs.settings, "COACH_MODEL", live_contract["model"])
    anthropic_router = LLMRouter(flags=_AlwaysOffRouteFlags())
    monkeypatch.setattr(dvs, "get_router", lambda: anthropic_router)

    for case in corpus["cases"]:
        result = dvs.classify_document(_document_base64(case))
        expected = case["expected"]
        assert result.is_financial is expected["isFinancial"], case["id"]
        assert result.detected_type == expected["detectedType"], case["id"]
        assert result.confidence == ConfidenceLevel(expected["confidence"]), case["id"]
