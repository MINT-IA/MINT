"""
Tests for PR A — Prompt hardening (2026-04-15).

Fixes 4 observed regressions on the user's 2026-04-15 iPhone test:
  1. Follow-up chips regurgitate canonical prompt examples verbatim.
  2. Internal doctrine labels ("Couche 2 :", "Layer 1:") leak into
     user-visible coach responses.
  3. Coach drifts to formal "vous" when speaking about the couple.
  4. Anonymous path emits 175-word paragraphs instead of the "3 phrases max"
     prompt contract.

This test module asserts:
  - Prompt-level directives are present in both prompts (anonymous + authed).
  - No canonical chip example ("Ça vaut le coup de racheter du LPP") in the
    coach prompts (previous anti-pattern — LLMs regurgitate prompt examples).
  - ComplianceGuardrails post-filters actually scrub markers, count formal
    "vous", drop echoed follow-ups, and truncate to 3 sentences.
  - The anonymous orchestrator passes max_tokens=180 to the LLM client.

Run: cd services/backend && python3 -m pytest tests/test_prompt_hardening.py -v
"""

from __future__ import annotations

import logging
import os
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

os.environ.setdefault("TESTING", "1")
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-prompt-hardening")


# ───────────────────────────────────────────────────────────────────────────
# Task 1 — Canonical chip examples removed from prompts
# ───────────────────────────────────────────────────────────────────────────


def test_no_canonical_chip_example_in_coach_tools_description() -> None:
    """`coach_tools.py` must not contain the canonical LPP chip example
    (`Ça vaut le coup de racheter du LPP ?`). That example was being echoed
    verbatim by Claude as a follow-up suggestion."""
    from app.services.coach import coach_tools

    # Read the raw source so we catch the literal example in docstrings,
    # dict values, or anywhere else.
    import inspect

    source = inspect.getsource(coach_tools)
    assert "Ça vaut le coup de racheter du LPP" not in source, (
        "coach_tools.py must not expose canonical chip example — Claude echoes it verbatim."
    )


def test_no_canonical_chip_example_in_coach_system_prompt() -> None:
    """`claude_coach_service.build_system_prompt()` must not contain the
    canonical LPP chip example in any configuration."""
    from app.services.coach.claude_coach_service import build_system_prompt

    prompt = build_system_prompt(ctx=None, language="fr")
    assert "Ça vaut le coup de racheter du LPP" not in prompt, (
        "Coach system prompt must not expose canonical chip example — Claude echoes it verbatim."
    )


# ───────────────────────────────────────────────────────────────────────────
# Task 2 — Layer/Couche doctrine leak interdiction
# ───────────────────────────────────────────────────────────────────────────


def test_coach_system_prompt_forbids_couche_layer_niveau_explicitly() -> None:
    """Authed coach prompt must explicitly forbid emitting doctrine layer
    labels in user-visible text (positive interdict, not negative hint)."""
    from app.services.coach.claude_coach_service import build_system_prompt

    prompt = build_system_prompt(ctx=None, language="fr")
    # Must contain the absolute interdiction block.
    assert "INTERDICTION ABSOLUE" in prompt, (
        "Coach prompt must contain an INTERDICTION ABSOLUE block for layer markers."
    )
    # Must list the specific banned tokens.
    for token in ["couche 1", "couche 2", "couche 3", "couche 4"]:
        assert token in prompt.lower(), (
            f"Coach prompt must explicitly ban token '{token}' in user-visible output."
        )


def test_anonymous_prompt_forbids_couche_layer_niveau_explicitly() -> None:
    """Anonymous discovery prompt must explicitly forbid layer doctrine labels."""
    from app.api.v1.endpoints.anonymous_chat import build_discovery_system_prompt

    prompt = build_discovery_system_prompt(intent=None, language="fr")
    assert "INTERDICTION ABSOLUE" in prompt, (
        "Anonymous prompt must contain an INTERDICTION ABSOLUE block for layer markers."
    )
    for token in ["couche 1", "couche 2", "couche 3", "couche 4"]:
        assert token in prompt.lower(), (
            f"Anonymous prompt must explicitly ban token '{token}'."
        )


def test_anonymous_prompt_no_longer_uses_couche_as_directive() -> None:
    """The old v1 directive 'Couche 1 (fait) + couche 2 (traduction humaine)
    uniquement.' — which was itself a leak vector — must be gone."""
    from app.api.v1.endpoints.anonymous_chat import build_discovery_system_prompt

    prompt = build_discovery_system_prompt(intent=None, language="fr")
    # The old directive is gone — we should no longer prescribe "Couche 1 ... uniquement".
    assert "Couche 1 (fait) + couche 2" not in prompt, (
        "Anonymous prompt must not use 'Couche N' as a user-facing directive."
    )


def test_compliance_scrubs_couche_layer_markers() -> None:
    """ComplianceGuardrails must strip leaked doctrine markers from text."""
    from app.services.rag.guardrails import ComplianceGuardrails

    text = "Voici mon angle. Couche 2 : Il faudrait clarifier tes priorités."
    cleaned, count = ComplianceGuardrails._scrub_layer_markers(text)
    assert "Couche 2" not in cleaned, "Layer marker must be stripped."
    assert "Il faudrait clarifier" in cleaned, "Substantive content must be kept."
    assert count == 1, f"Expected 1 scrubbed marker, got {count}."


def test_compliance_scrubs_multiple_layer_variants() -> None:
    """Markdown-wrapped, numbered, and French variants must all be stripped."""
    from app.services.rag.guardrails import ComplianceGuardrails

    text = (
        "Intro.\n**Couche 1:** Faits.\nLayer 2 - La traduction humaine.\n"
        "Niveau 3 : ta perspective.\nÉtape 4: questions."
    )
    cleaned, count = ComplianceGuardrails._scrub_layer_markers(text)
    assert "Couche 1" not in cleaned
    assert "Layer 2" not in cleaned
    assert "Niveau 3" not in cleaned
    assert "Étape 4" not in cleaned
    assert count >= 4, f"Expected at least 4 scrubbed markers, got {count}."


def test_compliance_filter_response_integrates_layer_scrub(caplog) -> None:
    """`filter_response()` must scrub markers end-to-end and log telemetry."""
    from app.services.rag.guardrails import ComplianceGuardrails

    # Use a non-FR language to bypass the ComplianceGuard (FR) delegation and
    # hit the scrubber cleanly with minimal other transformations.
    guardrails = ComplianceGuardrails()
    caplog.set_level(logging.INFO, logger="app.services.rag.guardrails")
    result = guardrails.filter_response(
        "Analysis summary. Layer 2: this means your LPP is locked.",
        language="en",
    )
    assert "Layer 2" not in result["text"]
    assert any("layer_leak_scrubbed" in rec.message for rec in caplog.records), (
        "Expected compliance.layer_leak_scrubbed telemetry log."
    )


# ───────────────────────────────────────────────────────────────────────────
# Task 3 — Tutoiement strict (including for couple)
# ───────────────────────────────────────────────────────────────────────────


def test_coach_system_prompt_tutoiement_strict_block_present() -> None:
    """Coach prompt must include the strict tutoiement directive (covers
    couple case: 'vous' as formal singular is banned)."""
    from app.services.coach.claude_coach_service import build_system_prompt

    prompt = build_system_prompt(ctx=None, language="fr")
    assert "TUTOIEMENT STRICT" in prompt
    assert "votre situation" in prompt.lower() or "ta situation" in prompt.lower()
    # Sanity: must mention the couple case explicitly
    assert "couple" in prompt.lower() or "vous deux" in prompt.lower()


def test_anonymous_prompt_tutoiement_strict_directive_present() -> None:
    from app.api.v1.endpoints.anonymous_chat import build_discovery_system_prompt

    prompt = build_discovery_system_prompt(intent=None, language="fr")
    assert "TUTOIEMENT STRICT" in prompt
    assert "vous deux" in prompt.lower()


def test_compliance_detects_formal_vous(caplog) -> None:
    """Formal singular `vous avez` must be detected and logged, but not rewritten."""
    from app.services.rag.guardrails import ComplianceGuardrails

    count = ComplianceGuardrails._count_formal_vous("Vous avez 16 ans devant vous.")
    assert count >= 1

    guardrails = ComplianceGuardrails()
    caplog.set_level(logging.INFO, logger="app.services.rag.guardrails")
    result = guardrails.filter_response(
        "Vous avez 16 ans devant vous.", language="en",
    )
    # Text not rewritten (too risky to auto-convert vous → tu in v1).
    assert "Vous avez" in result["text"] or "vous avez" in result["text"]
    assert any("formal_vous_detected" in rec.message for rec in caplog.records)


def test_compliance_ignores_vous_deux_plural() -> None:
    """`vous deux avez` is natural plural and must NOT be flagged."""
    from app.services.rag.guardrails import ComplianceGuardrails

    count = ComplianceGuardrails._count_formal_vous(
        "Vous deux avez construit un patrimoine solide."
    )
    assert count == 0, "Natural plural 'vous deux avez' must not trigger formal-vous."


# ───────────────────────────────────────────────────────────────────────────
# Task 1c — Follow-up chip echo filter
# ───────────────────────────────────────────────────────────────────────────


def test_compliance_drops_echoed_follow_ups() -> None:
    """A follow-up that paraphrases the user's message is anti-listening — drop."""
    from app.services.rag.guardrails import ComplianceGuardrails

    user_msg = "Ça vaut le coup de racheter le LPP ?"
    follow_ups = ["Ça vaut le coup de racheter du LPP ?"]
    kept = ComplianceGuardrails.filter_follow_up_questions(follow_ups, user_msg)
    assert kept == [], (
        "Follow-up paraphrasing the user's question must be dropped (Jaccard > 0.6)."
    )


def test_compliance_keeps_distinct_follow_ups() -> None:
    """A genuinely different follow-up must be preserved."""
    from app.services.rag.guardrails import ComplianceGuardrails

    user_msg = "Ça vaut le coup de racheter du LPP ?"
    follow_ups = ["Et si je retardais la retraite de 2 ans ?"]
    kept = ComplianceGuardrails.filter_follow_up_questions(follow_ups, user_msg)
    assert kept == follow_ups


def test_compliance_keeps_empty_follow_up_list() -> None:
    from app.services.rag.guardrails import ComplianceGuardrails

    kept = ComplianceGuardrails.filter_follow_up_questions([], "anything")
    assert kept == []


def test_compliance_keeps_follow_ups_when_user_message_short() -> None:
    """Short user messages (fewer than 4-char tokens) must not mask valid follow-ups."""
    from app.services.rag.guardrails import ComplianceGuardrails

    kept = ComplianceGuardrails.filter_follow_up_questions(
        ["Combien faut-il épargner chaque mois ?"], "Hi",
    )
    assert len(kept) == 1


# ───────────────────────────────────────────────────────────────────────────
# Task 4 — Length enforcement (anonymous path)
# ───────────────────────────────────────────────────────────────────────────


def test_truncate_to_three_sentences() -> None:
    from app.services.rag.guardrails import ComplianceGuardrails

    long_text = (
        "Phrase un. Phrase deux. Phrase trois. Phrase quatre. Phrase cinq."
    )
    truncated, was_truncated = ComplianceGuardrails.truncate_to_sentences(
        long_text, max_sentences=3,
    )
    assert was_truncated is True
    # Count resulting sentence terminators
    sentence_count = sum(truncated.count(c) for c in ".!?")
    assert sentence_count == 3, (
        f"Expected exactly 3 sentences after truncation, got {sentence_count}: {truncated!r}"
    )
    assert "Phrase quatre" not in truncated
    assert "Phrase cinq" not in truncated


def test_truncate_noop_when_under_limit() -> None:
    from app.services.rag.guardrails import ComplianceGuardrails

    text = "Une phrase. Deux phrases."
    truncated, was_truncated = ComplianceGuardrails.truncate_to_sentences(
        text, max_sentences=3,
    )
    assert was_truncated is False
    assert truncated == text


def test_truncate_handles_empty_input() -> None:
    from app.services.rag.guardrails import ComplianceGuardrails

    truncated, was_truncated = ComplianceGuardrails.truncate_to_sentences("", 3)
    assert was_truncated is False
    assert truncated == ""


@pytest.mark.asyncio
async def test_anonymous_orchestrator_passes_max_tokens_180() -> None:
    """The anonymous `_NoRagOrchestrator` must cap LLM generation at 180 tokens."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    fake_llm_instance = MagicMock()
    fake_llm_instance.generate = AsyncMock(return_value="Une phrase. Deux. Trois.")

    with patch(
        "app.services.rag.llm_client.LLMClient",
        return_value=fake_llm_instance,
    ):
        orch = _NoRagOrchestrator()
        await orch.query(
            question="Je gagne 100k par an, je fais quoi avec mon 3a ?",
            system_prompt="Tu es MINT.",
            api_key="sk-test",
            provider="claude",
            language="fr",
        )

    assert fake_llm_instance.generate.await_count == 1
    kwargs = fake_llm_instance.generate.await_args.kwargs
    assert kwargs.get("max_tokens") == 180, (
        f"Anonymous orchestrator must pass max_tokens=180, got {kwargs.get('max_tokens')!r}"
    )
    assert kwargs.get("tools") is None


@pytest.mark.asyncio
async def test_anonymous_orchestrator_truncates_long_response() -> None:
    """Response with > 3 sentences must be truncated before reaching the user."""
    from app.api.v1.endpoints.anonymous_chat import _NoRagOrchestrator

    long = (
        "Verdict. Traduction. Implication. Phrase quatre. Phrase cinq. Phrase six."
    )
    fake_llm_instance = MagicMock()
    fake_llm_instance.generate = AsyncMock(return_value=long)

    with patch(
        "app.services.rag.llm_client.LLMClient",
        return_value=fake_llm_instance,
    ):
        orch = _NoRagOrchestrator()
        result = await orch.query(
            question="Test",
            system_prompt="Tu es MINT.",
            api_key="sk-test",
            provider="claude",
            language="fr",
        )

    answer = result["answer"]
    # Exactly 3 sentences — "Phrase quatre", "Phrase cinq", "Phrase six" stripped.
    assert "Phrase quatre" not in answer
    assert "Phrase cinq" not in answer
    assert "Phrase six" not in answer
