"""Wave 1c-A1 byte-stability tests for TOP+BOTTOM MANDATE duplication.

Locks the doctrine-position contract introduced by Wave 1c-A1:

- The MANDATE substring « OBLIGATOIRE d'invoquer d'abord l'outil
  correspondant » MUST appear EXACTLY twice in
  `CITATION_GRAMMAR_FRAGMENT` (TOP + BOTTOM).
- Same contract for `build_intent_scoped_citation_grammar(intents)`.
- The BOTTOM repeat MUST sit AFTER the « Règle de placement » section.
- The new `_TOOL_USE_MANDATE_REPEAT` constant MUST contain the anti-
  deferral guidance (« n'attends pas que l'utilisateur fournisse les
  données »), which is the specific failure mode observed in the
  staging probe (`probe-2026-05-15-1958-payload.jsonl`).

Rationale: Liu 2024 lost-in-the-middle. Wave A's single-position
MANDATE at ~51% of a 45,879-char system prompt was insufficient.
Wave A1 adds a BOTTOM repeat in the grammar fragment AND a tail
injection in coach_chat.py:_build_system_prompt_with_memory so the
narrator reads the doctrine three times: ~51%, ~64%, ~100%.
"""
from __future__ import annotations

from app.services.coach.citation_grammar import (
    CITATION_GRAMMAR_FRAGMENT,
    _TOOL_USE_MANDATE,
    _TOOL_USE_MANDATE_REPEAT,
    build_intent_scoped_citation_grammar,
)

_NEEDLE = "OBLIGATOIRE d'invoquer d'abord l'outil correspondant"


def test_full_fragment_has_mandate_at_top_and_bottom() -> None:
    """Wave 1c-A1: MANDATE must appear twice in the full fragment."""
    assert CITATION_GRAMMAR_FRAGMENT.count(_NEEDLE) == 2


def test_intent_scoped_fragment_has_mandate_at_top_and_bottom() -> None:
    """Wave 1c-A1: MANDATE must appear twice in the intent-scoped variant
    (here exercised with the `retirement` intent, the most-used bucket).
    """
    out = build_intent_scoped_citation_grammar(["retirement"])
    assert out.count(_NEEDLE) == 2


def test_bottom_mandate_sits_after_rule_section() -> None:
    """Wave 1c-A1: the BOTTOM repeat must sit AFTER the « Règle de
    placement » section (not before, not interleaved). This is what
    makes it the BOTTOM occurrence per the Liu 2024 mitigation pattern.
    """
    rule_pos = CITATION_GRAMMAR_FRAGMENT.index("Règle de placement")
    last_mandate_pos = CITATION_GRAMMAR_FRAGMENT.rindex(_NEEDLE)
    assert rule_pos < last_mandate_pos, (
        "Wave 1c-A1: BOTTOM MANDATE must sit after the rule section, "
        "not before"
    )


def test_repeat_constant_includes_no_data_anti_deferral_guidance() -> None:
    """Wave 1c-A1: the staging probe showed the narrator deflecting with
    « j'ai besoin de récupérer tes données ». The repeat block must
    explicitly anti-pattern that phrase so the narrator reads the
    correction at the BOTTOM position too.
    """
    assert "n'attends pas que l'utilisateur fournisse les données" in (
        _TOOL_USE_MANDATE_REPEAT
    )


def test_repeat_constant_distinguishes_via_rappel_header() -> None:
    """Wave 1c-A1: the BOTTOM repeat uses « RAPPEL — INVOCATION
    OBLIGATOIRE D'OUTIL (seconde occurrence, post-règles) » as section
    header so the two MANDATE occurrences are not byte-identical
    paragraphs. This avoids the model treating the second copy as a
    duplicate to ignore.
    """
    assert "RAPPEL — INVOCATION OBLIGATOIRE D'OUTIL" in _TOOL_USE_MANDATE_REPEAT
    assert "DOCTRINE — INVOCATION OBLIGATOIRE D'OUTIL" in _TOOL_USE_MANDATE
    # And the two headers are NOT byte-identical.
    assert _TOOL_USE_MANDATE_REPEAT[:200] != _TOOL_USE_MANDATE[:200]
