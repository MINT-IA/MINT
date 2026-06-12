"""Tests — Phase 91 Wave 1 LLM extractor module.

Covers RESEARCH §4 Stage 1 T1.3 fixtures + retry behavior +
source_quote substring check + intents + edge cases.

Mock strategy: `_StubClient.generate(...)` pops responses off a queue
matching the real `LLMClient.generate(...)` signature
(`system_prompt`, `user_message`, `context_chunks`, `tools`,
`conversation_history`). The real `LLMClient` is never instantiated
in these tests.

Spec source: `.planning/phases/91-mvp-extractor-v2/91-01-PLAN.md`
Task 1.2.
"""
from __future__ import annotations

import json
from typing import Any

import pytest

from app.services.coach.extractor_schema import ExtractorOutput
from app.services.coach.llm_extractor import (
    EXTRACTOR_SYSTEM_PROMPT,
    run_llm_extractor,
)


class _StubClient:
    """Minimal stand-in for `LLMClient` — mirrors the real call-time
    signature (`system_prompt`, `user_message`, `context_chunks`,
    `tools`, `conversation_history`).

    Each `generate(...)` call pops from `responses`. If `responses` is
    empty, the call raises `RuntimeError` (signals the test setup is
    incorrect). If `raise_on_call` is set, the next call raises that
    exception (used to test the « unexpected exception » path).
    """

    def __init__(
        self,
        responses: list[Any] | None = None,
        raise_on_call: list[BaseException | None] | None = None,
    ) -> None:
        self.responses = list(responses or [])
        self.raise_on_call = list(raise_on_call or [])
        self.calls: list[dict[str, Any]] = []

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        context_chunks: list[str],
        tools: list[dict] | None = None,
        conversation_history: list[dict] | None = None,
    ) -> Any:
        self.calls.append(
            {
                "system_prompt": system_prompt,
                "user_message": user_message,
                "context_chunks": list(context_chunks or []),
                "tools": tools,
                "conversation_history": list(conversation_history or []),
            }
        )
        if self.raise_on_call:
            exc = self.raise_on_call.pop(0)
            if exc is not None:
                raise exc
        if not self.responses:
            raise RuntimeError("stub _StubClient: no more responses queued")
        return self.responses.pop(0)


def _wrap(payload: dict) -> str:
    """Serialize a dict into a raw JSON response (no fences)."""
    return json.dumps(payload, ensure_ascii=False)


def _wrap_fenced(payload: dict, lang: str = "json") -> str:
    """Serialize a dict inside a ```json fence — RESEARCH §6 Pitfall 1."""
    return f"```{lang}\n{json.dumps(payload, ensure_ascii=False)}\n```"


# ---------------------------------------------------------------------------
# Happy path + intents
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_happy_path_two_facts():
    """« j'ai 80k de salaire à Lausanne » → 2 facts (canton=VD,
    incomeGrossYearly=80000), substring-check passes for both quotes.
    """
    user_msg = "j'ai 80k de salaire à Lausanne"
    payload = {
        "facts": [
            {
                "key": "incomeGrossYearly",
                "value": 80000,
                "confidence": "high",
                "source_quote": "80k de salaire",
            },
            {
                "key": "canton",
                "value": "VD",
                "confidence": "high",
                "source_quote": "à Lausanne",
            },
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap(payload)])

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert isinstance(out, ExtractorOutput)
    assert len(out.facts) == 2
    keys = {f.key for f in out.facts}
    assert keys == {"incomeGrossYearly", "canton"}
    assert len(stub.calls) == 1


@pytest.mark.asyncio
async def test_intents_extracted():
    payload = {"facts": [], "intents": ["debt"]}
    stub = _StubClient(responses=[_wrap(payload)])

    out = await run_llm_extractor(
        user_message="j'ai trop de dettes",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert out.intents == ["debt"]


# ---------------------------------------------------------------------------
# Retry behavior
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_prose_response_triggers_retry_then_empty():
    """Attempt 1 returns French prose (no JSON), attempt 2 also fails →
    empty `ExtractorOutput`. Mock asserts called twice (retry happened).
    """
    stub = _StubClient(
        responses=[
            "Voici les faits que j'ai compris : tu vis à Lausanne ...",
            "Encore un peu de prose, désolé.",
        ]
    )

    out = await run_llm_extractor(
        user_message="je vis à Lausanne",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert out.intents == []
    assert len(stub.calls) == 2  # retry happened


@pytest.mark.asyncio
async def test_prose_then_valid_json():
    """Attempt 1 prose, attempt 2 valid JSON → returns the validated
    facts. Confirms retry path is exercised AND retry success returns
    non-empty output.
    """
    user_msg = "j'ai 80k de salaire"
    valid = {
        "facts": [
            {
                "key": "incomeGrossYearly",
                "value": 80000,
                "confidence": "high",
                "source_quote": "80k de salaire",
            }
        ],
        "intents": [],
    }
    stub = _StubClient(
        responses=[
            "Pas de JSON ici, désolé.",
            _wrap(valid),
        ]
    )

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert len(out.facts) == 1
    assert out.facts[0].key == "incomeGrossYearly"
    assert out.facts[0].value == 80000
    assert len(stub.calls) == 2


# ---------------------------------------------------------------------------
# Schema-level rejection (RESEARCH §4 T1.3)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_hallucinated_key_rejected():
    """LLM returns `{"key": "customField", ...}` → Pydantic
    `ValidationError` → retry → empty (assuming retry also fails).
    """
    bad = {
        "facts": [
            {
                "key": "customField",  # not in whitelist
                "value": 42,
                "confidence": "high",
                "source_quote": "42",
            }
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap(bad), _wrap(bad)])

    out = await run_llm_extractor(
        user_message="some message containing 42",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert len(stub.calls) == 2  # ValidationError triggered retry


@pytest.mark.asyncio
async def test_low_confidence_rejected_at_schema():
    """LLM emits `confidence="low"` → Pydantic `ValidationError` →
    retry → empty.
    """
    bad = {
        "facts": [
            {
                "key": "canton",
                "value": "VD",
                "confidence": "low",  # forbidden per RESEARCH §3
                "source_quote": "à Lausanne",
            }
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap(bad), _wrap(bad)])

    out = await run_llm_extractor(
        user_message="je suis à Lausanne",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert len(stub.calls) == 2


# ---------------------------------------------------------------------------
# source_quote substring check (RESEARCH §6 Pitfall 3)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_hallucinated_quote_dropped():
    """LLM returns valid JSON but `source_quote` is fabricated (not
    substring of `user_message`) → fact dropped post-validation.
    `ExtractorOutput` returns with empty facts list (single fact was
    dropped). NO retry triggered (the LLM JSON validated cleanly;
    the substring filter is post-validation).
    """
    user_msg = "j'ai 80k de salaire"
    payload = {
        "facts": [
            {
                "key": "canton",
                "value": "VD",
                "confidence": "high",
                "source_quote": "le ciel est bleu",  # not in user_msg
            }
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap(payload)])

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert len(stub.calls) == 1  # single attempt; no retry (validated cleanly)


@pytest.mark.asyncio
async def test_quote_substring_check_is_case_insensitive():
    """LLM source_quote with different casing/whitespace still matches
    user_message — `_drop_hallucinated_quotes` is case-insensitive
    and whitespace-collapsed.
    """
    user_msg = "J'ai     80k    de salaire à LAUSANNE"
    payload = {
        "facts": [
            {
                "key": "canton",
                "value": "VD",
                "confidence": "high",
                "source_quote": "à lausanne",  # lowercase, single-spaced
            }
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap(payload)])

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert len(out.facts) == 1
    assert out.facts[0].key == "canton"


# ---------------------------------------------------------------------------
# RESEARCH §4 T1.3 fixtures — already-known + 0-fact
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_already_known_fact_still_emitted():
    """When the extractor returns a fact that matches the profile
    snapshot, the schema accepts it. Suppression of redundant facts
    is a Wave 2 merge concern — Wave 1's job is structural validation
    only.
    """
    user_msg = "je confirme, à Lausanne, canton de Vaud"
    payload = {
        "facts": [
            {
                "key": "canton",
                "value": "VD",
                "confidence": "high",
                "source_quote": "à Lausanne",
            }
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap(payload)])

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={"canton": "VD"},  # already known
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert len(out.facts) == 1  # not suppressed (Wave 2 concern)
    assert out.facts[0].key == "canton"


@pytest.mark.asyncio
async def test_zero_facts_response():
    """LLM returns `{"facts": [], "intents": []}` — happy path with
    nothing to extract (« merci ! »). NO retry triggered.
    """
    payload = {"facts": [], "intents": []}
    stub = _StubClient(responses=[_wrap(payload)])

    out = await run_llm_extractor(
        user_message="merci !",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert out.intents == []
    assert len(stub.calls) == 1


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_empty_user_message_short_circuits():
    """`user_message=""` → returns `ExtractorOutput()` WITHOUT calling
    the LLM (mock not called).
    """
    stub = _StubClient(responses=[])  # no responses; would raise if called

    out = await run_llm_extractor(
        user_message="",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert out.intents == []
    assert len(stub.calls) == 0


@pytest.mark.asyncio
async def test_whitespace_only_user_message_short_circuits():
    """`user_message="   \\n  "` short-circuits the same as empty."""
    stub = _StubClient(responses=[])

    out = await run_llm_extractor(
        user_message="   \n  ",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert len(stub.calls) == 0


@pytest.mark.asyncio
async def test_json_inside_fences():
    """LLM returns ```json\\n{...}\\n``` → fence stripped, parses
    correctly (RESEARCH §6 Pitfall 1).
    """
    user_msg = "j'ai 80k de salaire"
    payload = {
        "facts": [
            {
                "key": "incomeGrossYearly",
                "value": 80000,
                "confidence": "high",
                "source_quote": "80k de salaire",
            }
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap_fenced(payload)])

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert len(out.facts) == 1
    assert out.facts[0].key == "incomeGrossYearly"


@pytest.mark.asyncio
async def test_json_inside_generic_fences():
    """LLM returns ``` ... ``` (no `json` lang tag) → still parses."""
    user_msg = "j'ai 80k"
    payload = {
        "facts": [
            {
                "key": "incomeGrossYearly",
                "value": 80000,
                "confidence": "high",
                "source_quote": "80k",
            }
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap_fenced(payload, lang="")])

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert len(out.facts) == 1


@pytest.mark.asyncio
async def test_llm_returns_dict_with_text_key():
    """The real `LLMClient.generate(...)` returns `dict` when usage
    metadata is attached (`{"text": "...", "usage_tokens": 42}`).
    `_normalize_text` MUST extract the `text` field.
    """
    user_msg = "j'ai 80k"
    payload = {
        "facts": [
            {
                "key": "incomeGrossYearly",
                "value": 80000,
                "confidence": "high",
                "source_quote": "80k",
            }
        ],
        "intents": [],
    }
    stub = _StubClient(
        responses=[{"text": _wrap(payload), "usage_tokens": 42}]
    )

    out = await run_llm_extractor(
        user_message=user_msg,
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert len(out.facts) == 1
    assert out.facts[0].value == 80000


@pytest.mark.asyncio
async def test_unexpected_exception_returns_empty():
    """`_call_once` raises `RuntimeError` (network down, etc.) →
    no retry on non-Validation exception → returns empty
    `ExtractorOutput`.
    """
    stub = _StubClient(
        responses=[],
        raise_on_call=[RuntimeError("network down")],
    )

    out = await run_llm_extractor(
        user_message="j'ai 80k",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert len(stub.calls) == 1  # NO retry on non-Validation exception


@pytest.mark.asyncio
async def test_too_many_facts_in_llm_output_triggers_retry():
    """LLM returns 13 facts (over `max_length=12`) → Pydantic
    `ValidationError` → retry. Pins the schema's list bound is
    enforced post-LLM.
    """
    too_many = {
        "facts": [
            {
                "key": "canton",
                "value": "VD",
                "confidence": "high",
                "source_quote": f"q{i}",
            }
            for i in range(13)
        ],
        "intents": [],
    }
    stub = _StubClient(responses=[_wrap(too_many), _wrap(too_many)])

    out = await run_llm_extractor(
        user_message="some message",
        conversation_history=[],
        profile_snapshot={},
        api_key="sk-test",
        provider="claude",
        client=stub,
    )

    assert out.facts == []
    assert len(stub.calls) == 2


# ---------------------------------------------------------------------------
# Module-level invariants
# ---------------------------------------------------------------------------


def test_extractor_system_prompt_is_french_and_json_only():
    """Pin module-level constant: extractor prompt is FR + JSON-only
    skeleton from RESEARCH §3.
    """
    assert "EXTRACTEUR de faits financiers" in EXTRACTOR_SYSTEM_PROMPT
    assert "JSON STRICT" in EXTRACTOR_SYSTEM_PROMPT
    assert "N'émets jamais" in EXTRACTOR_SYSTEM_PROMPT
    assert '"low"' in EXTRACTOR_SYSTEM_PROMPT  # literal mentioning the rule


# NOTE (mint-grounded-coach-m1 Plan 07): the
# `test_run_llm_extractor_imported_by_coach_chat_in_wave_2` wiring-invariant
# test was removed. The dual-LLM extractor stage (COACH_DUAL_LLM_ENABLED) was
# deleted as a flag-OFF façade (WS-C activate-or-delete, NEVER #6), so
# coach_chat.py no longer imports `run_llm_extractor`. The `llm_extractor`
# library module itself is retained and is still covered by the unit tests
# above (system prompt, schema, parsing); only the now-false coach_chat
# import-wiring assertion was dropped.
