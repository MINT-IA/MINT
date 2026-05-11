"""Phase 94 Wave 1 — D-08 retry-once + D-09 reprompt addendum verbatim.

Pins :
- D-08 : the gate's `is_retry=True` branch NEVER returns
  `retry_needed=True` ; this is the structural invariant that proves the
  wrapper cannot be tricked into a third call.
- D-09 / D-13 / D-10 : the three verbatim FR string constants are
  byte-equal to the spec in `94-CONTEXT.md`.
"""
from __future__ import annotations

from app.services.coach.citation_parser import (
    FALLBACK_TEMPLATED_TEXT,
    REPROMPT_ADDENDUM_BANNED_CLAIM,
    REPROMPT_ADDENDUM_UNCITED,
    GateVerdict,
    gate,
)


# ---------------------------------------------------------------------------
# D-09 / D-10 / D-13 verbatim FR — byte-equality contract.
# Expected reference values copied from 94-CONTEXT.md (UTF-8, full accents).
# ---------------------------------------------------------------------------

_EXPECTED_D09 = (
    "\n\nRAPPEL — Cite chaque chiffre via {{cite:<key>}} ou ne l'émets pas. "
    "Si tu n'as pas la source pour un chiffre, écris "
    "« je n'ai pas cette donnée » à la place."
)

_EXPECTED_D13 = (
    "\n\nRAPPEL — Une projection est une scénario, pas une promesse. "
    "Reformule au conditionnel (« pourrait », « selon ce scénario », "
    "« si X reste constant »)."
)

_EXPECTED_D10 = (
    "Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, "
    "dis-moi un peu plus sur ta situation (canton, salaire, structure familiale) "
    "et je peux t'orienter vers ce qui s'applique chez toi."
)


def test_reprompt_addendum_verbatim_d09():
    """D-09 — uncited reprompt addendum byte-equal to spec."""
    assert REPROMPT_ADDENDUM_UNCITED == _EXPECTED_D09


def test_reprompt_addendum_verbatim_d13():
    """D-13 — banned-claim reprompt addendum byte-equal to spec."""
    assert REPROMPT_ADDENDUM_BANNED_CLAIM == _EXPECTED_D13


def test_fallback_text_verbatim_d10():
    """D-10 — templated fallback byte-equal to spec."""
    assert FALLBACK_TEMPLATED_TEXT == _EXPECTED_D10


def test_d09_contains_french_accents():
    """Defensive — guard against accent stripping by future contributors."""
    assert "n'as" in REPROMPT_ADDENDUM_UNCITED
    assert "n'ai" in REPROMPT_ADDENDUM_UNCITED
    assert "émets" in REPROMPT_ADDENDUM_UNCITED
    assert "écris" in REPROMPT_ADDENDUM_UNCITED
    assert "donnée" in REPROMPT_ADDENDUM_UNCITED
    assert "« " in REPROMPT_ADDENDUM_UNCITED and " »" in REPROMPT_ADDENDUM_UNCITED


def test_d13_contains_french_quotes_and_accents():
    """Defensive — D-13 must keep its FR doctrine vocabulary."""
    assert "scénario" in REPROMPT_ADDENDUM_BANNED_CLAIM
    assert "« pourrait »" in REPROMPT_ADDENDUM_BANNED_CLAIM
    assert "« selon ce scénario »" in REPROMPT_ADDENDUM_BANNED_CLAIM
    assert "« si X reste constant »" in REPROMPT_ADDENDUM_BANNED_CLAIM


# ---------------------------------------------------------------------------
# D-08 — retry budget hard-cap : `is_retry=True` NEVER returns
# `retry_needed=True`. The wrapper relies on this invariant to bound the
# number of `_run_agent_loop` calls at 2 per request.
# ---------------------------------------------------------------------------


def test_max_one_retry_uncited_branch():
    """is_retry=True + uncited → FALLBACK, retry_needed=False."""
    result = gate(
        response_text="Tu peux mettre 6883 CHF par an.",
        ctx=None,
        citation_allowlist=[],
        is_retry=True,
    )
    assert result.verdict == GateVerdict.FALLBACK
    assert result.retry_needed is False
    assert result.reprompt_addendum is None
    assert result.gated_text == FALLBACK_TEMPLATED_TEXT


def test_max_one_retry_banned_branch():
    """is_retry=True + banned-claim → FALLBACK, retry_needed=False."""
    result = gate(
        response_text="Vous ferez 4% par an {{cite:r3a_plafond_salarie_2026}}.",
        ctx=None,
        citation_allowlist=["r3a_plafond_salarie_2026"],
        is_retry=True,
    )
    assert result.verdict == GateVerdict.FALLBACK
    assert result.retry_needed is False
    assert result.reprompt_addendum is None
    assert result.gated_text == FALLBACK_TEMPLATED_TEXT


def test_first_pass_uncited_returns_d09_addendum():
    """First-pass uncited → REJECTED_UNCITED + D-09 verbatim addendum."""
    result = gate(
        response_text="Tu peux mettre 6883 CHF par an.",
        ctx=None,
        citation_allowlist=[],
        is_retry=False,
    )
    assert result.verdict == GateVerdict.REJECTED_UNCITED
    assert result.retry_needed is True
    assert result.reprompt_addendum == REPROMPT_ADDENDUM_UNCITED
    # gated_text is the original (caller decides what to do with it).
    assert result.gated_text == "Tu peux mettre 6883 CHF par an."
    assert result.uncited_numbers_count == 1


def test_first_pass_banned_returns_d13_addendum():
    """First-pass banned-claim → REJECTED_BANNED_CLAIM + D-13 verbatim addendum."""
    result = gate(
        response_text="Vous ferez 4% par an {{cite:r3a_plafond_salarie_2026}}.",
        ctx=None,
        citation_allowlist=["r3a_plafond_salarie_2026"],
        is_retry=False,
    )
    assert result.verdict == GateVerdict.REJECTED_BANNED_CLAIM
    assert result.retry_needed is True
    assert result.reprompt_addendum == REPROMPT_ADDENDUM_BANNED_CLAIM
    assert len(result.banned_claims_found) >= 1
