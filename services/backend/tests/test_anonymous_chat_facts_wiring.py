"""
Integration test for the anonymous-chat ↔ profile_extractor wiring (phase B).

Asserts:
1. Facts are extracted BEFORE the PII scrubber destroys numeric tokens.
2. The extracted facts are injected into the system prompt that reaches
   the orchestrator — via the <facts_user> block.
3. Session logs topics only (not values) — privacy invariant.
4. When the message carries no extractable facts, no facts block is emitted.
"""
from __future__ import annotations

import logging
import uuid

import pytest
from fastapi.testclient import TestClient

import app.api.v1.endpoints.anonymous_chat as anonymous_chat_module
from app.main import app


@pytest.fixture(autouse=True)
def _stub_orchestrator(monkeypatch):
    """Capture the system_prompt that reaches the LLM and return a stub reply."""
    captured: dict[str, str] = {}

    async def fake_query(self, *, question, system_prompt, **_):  # noqa: ANN001
        captured["system_prompt"] = system_prompt
        captured["question"] = question
        return {
            "answer": "Stub reply.",
            "tokens_used": 0,
            "sources": [],
            "disclaimers": [],
        }

    monkeypatch.setattr(
        anonymous_chat_module._NoRagOrchestrator,
        "query",
        fake_query,
    )

    # Also stub the ANTHROPIC_API_KEY check.
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-stub")

    return captured


@pytest.fixture
def client():
    return TestClient(app)


def _session() -> str:
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Happy path: the three expected facts end up in the prompt.
# ---------------------------------------------------------------------------


def test_facts_extracted_and_injected_in_prompt(client, _stub_orchestrator, caplog):
    caplog.set_level(logging.INFO)
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={
            "message": (
                "J'ai 49 ans, je gagne 7600 Fr net par mois dans le Valais, "
                "et j'ai 300 000 Fr de valeur de rachat dans ma caisse de pension. "
                "Qu'est-ce que je dois faire ?"
            ),
            "language": "fr",
        },
        headers={"X-Anonymous-Session": _session()},
    )
    assert resp.status_code == 200, resp.text

    prompt = _stub_orchestrator["system_prompt"]
    # Facts block present
    assert "<facts_user>" in prompt
    assert "</facts_user>" in prompt
    # Key figures landed verbatim inside the block
    assert "49 ans" in prompt
    assert "300'000" in prompt  # formatted LPP
    # Salary annualised — 7600×12 = 91'200
    assert "91'200" in prompt or "7'600" in prompt
    # Telemetry logs topics only, not raw values
    log_lines = [r.getMessage() for r in caplog.records]
    assert any("topics=" in line and "session=" in line for line in log_lines)
    # No raw value leaks into logs
    assert not any(
        "300000" in line or "300 000" in line or "7600" in line
        for line in log_lines
    )


# ---------------------------------------------------------------------------
# Missing data: no facts block emitted (keeps prompt compact).
# ---------------------------------------------------------------------------


def test_no_facts_block_when_message_is_abstract(client, _stub_orchestrator):
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={
            "message": "Je me sens un peu perdu avec mes finances.",
            "language": "fr",
        },
        headers={"X-Anonymous-Session": _session()},
    )
    assert resp.status_code == 200, resp.text

    prompt = _stub_orchestrator["system_prompt"]
    assert "<facts_user>" not in prompt
    assert "</facts_user>" not in prompt


# ---------------------------------------------------------------------------
# PII scrubbing still runs — extractor ran BEFORE scrub, not instead of.
# ---------------------------------------------------------------------------


def test_question_reaching_orchestrator_is_still_scrubbed(client, _stub_orchestrator):
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={
            "message": (
                "J'ai 49 ans et un IBAN CH93 0076 2011 6238 5295 7 et 8500 CHF par mois."
            ),
            "language": "fr",
        },
        headers={"X-Anonymous-Session": _session()},
    )
    assert resp.status_code == 200, resp.text

    sent_message = _stub_orchestrator["question"]
    # IBAN must have been replaced
    assert "CH93" not in sent_message or "[***]" in sent_message
    # But the extractor STILL captured the salary (ran pre-scrub) — visible
    # in the facts block of the prompt.
    prompt = _stub_orchestrator["system_prompt"]
    assert "<facts_user>" in prompt
    assert "102'000" in prompt  # 8500 × 12 annualised
