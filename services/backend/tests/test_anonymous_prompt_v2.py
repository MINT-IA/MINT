"""
Contract tests for the v2 anonymous discovery system prompt (post-audit, phase A).

Asserts the new constraints that were absent from v1:
1. PROMPT_VERSION is bumped and exported (for telemetry / A/B).
2. Max-length directive is tight (≤ 3 phrases) — not the old "3-5 phrases max".
3. "Cite textuellement les chiffres donnés par la personne" directive exists.
4. Verdict-first directive exists.
5. No leak of the forbidden lexicon (`outil/dossier/profil/memoire/tool`)
   — the T-13-05 guard from v1 is preserved.
6. No hallucinatable Swiss-knowledge block (no hardcoded AVS/LPP/3a figures).
7. No `MANDATORY save_insight` or any tool-call directive (tools=None path —
   Claude would otherwise produce literal `save_insight(...)` in output).
8. When user-declared `facts` are provided, they appear verbatim inside a
   `<facts_user>` block distinct from the rest of the prompt.
"""
from __future__ import annotations

import pytest

from app.api.v1.endpoints.anonymous_chat import (
    PROMPT_VERSION,
    build_discovery_system_prompt,
)


# ---------------------------------------------------------------------------
# Versioning
# ---------------------------------------------------------------------------


def test_prompt_version_is_v3():
    assert PROMPT_VERSION == "v3", (
        "Prompt rewrite must bump PROMPT_VERSION so telemetry can segregate "
        "old vs new responses. Bump again on next rewrite."
    )


# ---------------------------------------------------------------------------
# Length discipline
# ---------------------------------------------------------------------------


def test_length_directive_is_tight_max_3_phrases():
    prompt = build_discovery_system_prompt()
    lowered = prompt.lower()
    # Either exact "3 phrases" OR the verdict-first shorthand — both acceptable.
    assert (
        "3 phrases" in lowered or "trois phrases" in lowered
    ), "New prompt must cap at 3 phrases (was 3-5 in v1 — too long)."
    # Regression guard: the old "3-5 phrases max" must be gone.
    assert "3-5 phrases" not in lowered, (
        "Old length band '3-5 phrases max' is incompatible with v2.7 "
        "density doctrine (max 3)."
    )


def test_verdict_first_directive_present():
    prompt = build_discovery_system_prompt()
    lowered = prompt.lower()
    assert "verdict" in lowered or "première ligne" in lowered or "chiffre" in lowered, (
        "Prompt must instruct Claude to lead with the verdict or the most "
        "relevant figure. Without this, responses regress to long-form "
        "educational text."
    )


# ---------------------------------------------------------------------------
# Quote-the-numbers doctrine (fixes "n'a pas vu les 300'000")
# ---------------------------------------------------------------------------


def test_cite_user_numbers_directive_present():
    prompt = build_discovery_system_prompt()
    lowered = prompt.lower()
    # Must tell the model to cite numbers the user provided.
    has_cite = any(
        kw in lowered
        for kw in (
            "cite",
            "reprends",
            "reprends les chiffres",
            "reprends les valeurs",
            "utilise les chiffres",
        )
    )
    assert has_cite, (
        "Prompt must tell Claude to echo user-provided numbers verbatim — "
        "otherwise it generalises ('le rachat possible') instead of using "
        "the actual figure ('tes 300'000 CHF')."
    )


# ---------------------------------------------------------------------------
# T-13-05 forbidden lexicon preserved (security regression guard)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "forbidden",
    ["outil", "tool", "profil", "memoire", "memory", "dossier"],
)
def test_forbidden_tokens_never_in_prompt(forbidden: str):
    prompt = build_discovery_system_prompt().lower()
    assert forbidden not in prompt, (
        f"T-13-05 information-disclosure guard: '{forbidden}' must not leak "
        "into anonymous discovery prompt."
    )


def test_no_mandatory_save_insight_directive():
    prompt = build_discovery_system_prompt().lower()
    # Tools=None on anonymous path — any save_* directive would cause Claude
    # to emit literal tool-call text in the response body.
    assert "save_insight" not in prompt
    assert "mandatory" not in prompt


# ---------------------------------------------------------------------------
# No hardcoded Swiss numbers (hallucination-detector defence)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "number",
    [
        "7'258",   # 3a plafond salarié LPP
        "36'288",  # 3a plafond indépendant
        "30'240",  # AVS rente max
        "6.8",     # LPP taux conversion
        "22'680",  # LPP seuil d'accès
    ],
)
def test_no_hardcoded_swiss_numbers_in_prompt(number: str):
    """Hard-coded figures in the prompt create two problems:
    (1) they drift when constants change (single source of truth = code),
    (2) if the legacy compliance_guard is ever re-enabled on the anonymous
        path, known_values=None triggers false-positive hallucination hits.
    """
    assert number not in build_discovery_system_prompt()


# ---------------------------------------------------------------------------
# User-declared facts injection (fixes "n'a pas vu les 300'000")
# ---------------------------------------------------------------------------


def test_facts_block_absent_when_no_facts_supplied():
    prompt = build_discovery_system_prompt(facts=None)
    assert "<facts_user>" not in prompt
    assert "</facts_user>" not in prompt


def test_facts_block_included_verbatim_when_supplied():
    prompt = build_discovery_system_prompt(
        facts=[
            "49 ans",
            "salaire 7'600 CHF net/mois",
            "LPP ≈ 300'000 CHF",
        ],
    )
    assert "<facts_user>" in prompt
    assert "</facts_user>" in prompt
    # Each fact is quoted literally in the block.
    assert "49 ans" in prompt
    assert "7'600" in prompt
    assert "300'000" in prompt


def test_facts_block_tells_model_to_use_them():
    prompt = build_discovery_system_prompt(facts=["49 ans"])
    # The instruction must sit near the facts so Claude does not ignore them.
    # Must not exceed prompt size: simple substring suffices.
    lowered = prompt.lower()
    assert "facts_user" in lowered
    # Some directive to leverage the facts (either cite/reprends/utilise).
    assert any(
        kw in lowered
        for kw in ("cite", "reprends", "utilise", "intègre", "appuie-toi")
    )


def test_intent_still_supported_alongside_facts():
    prompt = build_discovery_system_prompt(
        intent="Je me sens perdu",
        facts=["49 ans"],
    )
    assert "Je me sens perdu" in prompt
    assert "49 ans" in prompt


# ---------------------------------------------------------------------------
# Shape invariants — keep the prompt short and readable
# ---------------------------------------------------------------------------


def test_prompt_is_kept_compact():
    prompt = build_discovery_system_prompt()
    # v1 was ~900 chars. v2 should stay ≤ 1600 chars even with the new
    # directives — if it balloons, Claude gets lost.
    assert len(prompt) <= 1600, (
        f"Prompt must stay compact; got {len(prompt)} chars. "
        "Compactness is part of the contract — verbose prompts train verbose "
        "responses."
    )
