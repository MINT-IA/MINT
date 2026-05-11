"""Phase 94 Wave 1 — D-12 affirmative verb + cited number rejection.

Pins :
- D-12 regex `(?:vous|tu)\\s+(?:ferez|feras|aurez|auras|gagnerez|gagneras)\\s+\\d`
  matches the 6 v1-scope verb forms ; rejection fires EVEN WITH a
  valid `{{cite:<key>}}` adjacent.
- D-13 retry KEEPS the citation placeholder in the gated text
  (only the verb is reframed at the conditional ; the cite stays).
- M2 fix iter 1 — 3 documented v1-scope false-negatives are
  measured (3rd-person `rapportera`, infinitive `faire`, LSFin
  banned term `garanti`).
"""
from __future__ import annotations

import pytest

from app.services.coach.citation_parser import (
    REPROMPT_ADDENDUM_BANNED_CLAIM,
    REPROMPT_ADDENDUM_UNCITED,
    GateVerdict,
    _BANNED_AFFIRMATIVE_VERB_RE,
    gate,
)


# ---------------------------------------------------------------------------
# Regex shape — matches v1-scope, ignores out-of-scope forms.
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "fragment",
    [
        "vous ferez 4",
        "tu feras 100",
        "vous gagnerez 2000",
        "tu auras 50",
        "Vous Aurez 30 CHF",
        "vous gagneRez 1",
    ],
)
def test_banned_regex_matches_vN_scope(fragment: str):
    assert _BANNED_AFFIRMATIVE_VERB_RE.search(fragment) is not None, fragment


@pytest.mark.parametrize(
    "fragment",
    [
        "vous pourriez faire 4%",                    # conditional — OK
        "selon ce scénario, vous ferez peut-être",   # no digit after verb
        "vous ferez peut-être",                      # no digit after verb
        "rapportera 4% par an",                      # 3rd person — out of scope
        "tu pourrais avoir 5",                       # conditional — OK
    ],
)
def test_banned_regex_does_not_match_oos(fragment: str):
    assert _BANNED_AFFIRMATIVE_VERB_RE.search(fragment) is None, fragment


# ---------------------------------------------------------------------------
# Test 8 — REJECTED_BANNED_CLAIM despite valid citation (D-12 ; GATE-04).
# ---------------------------------------------------------------------------


def test_affirmative_verb_with_citation():
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


# ---------------------------------------------------------------------------
# D-13 — banned reprompt KEEPS the citation placeholder in gated_text.
# ---------------------------------------------------------------------------


def test_d13_reprompt_keeps_citation():
    """REJECTED_BANNED_CLAIM gated_text retains the original placeholder.
    The reprompt instructs the narrator to reframe the VERB at the
    conditional ; the cited placeholder stays.
    """
    response = "Vous ferez 4% par an {{cite:r3a_plafond_salarie_2026}}."
    result = gate(
        response_text=response,
        ctx=None,
        citation_allowlist=["r3a_plafond_salarie_2026"],
        is_retry=False,
    )
    assert result.verdict == GateVerdict.REJECTED_BANNED_CLAIM
    # gated_text is the ORIGINAL response (no substitution on rejection).
    assert "{{cite:r3a_plafond_salarie_2026}}" in result.gated_text
    # Reprompt is D-13, NOT D-09 (uncited path).
    assert result.reprompt_addendum == REPROMPT_ADDENDUM_BANNED_CLAIM
    assert result.reprompt_addendum != REPROMPT_ADDENDUM_UNCITED


# ---------------------------------------------------------------------------
# 6 parametric verb forms — all rejected.
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "verb_form",
    [
        ("vous ferez", "vous ferez 100 CHF"),
        ("tu feras",   "tu feras 4% par an"),
        ("vous aurez", "vous aurez 50000 CHF en LPP"),
        ("tu auras",   "tu auras 30 années de cotisations"),
        ("vous gagnerez", "vous gagnerez 2000 CHF de plus"),
        ("tu gagneras",   "tu gagneras 5% de rendement"),
    ],
)
def test_six_verb_forms_all_rejected(verb_form):
    _label, fragment = verb_form
    response = f"{fragment} {{{{cite:r3a_plafond_salarie_2026}}}}."
    result = gate(
        response_text=response,
        ctx=None,
        citation_allowlist=["r3a_plafond_salarie_2026"],
        is_retry=False,
    )
    assert result.verdict == GateVerdict.REJECTED_BANNED_CLAIM, (
        f"verb form {_label!r} should fire D-12 regex"
    )


# ---------------------------------------------------------------------------
# Conditional phrasing → PASS (no banned-verb pattern).
# ---------------------------------------------------------------------------


def test_conditional_phrasing_passes():
    response = "Vous pourriez faire 4% {{cite:lpp_taux_conv_obligatoire_2026}}."
    result = gate(
        response_text=response,
        ctx=None,
        citation_allowlist=["lpp_taux_conv_obligatoire_2026"],
        is_retry=False,
    )
    assert result.verdict == GateVerdict.PASS


# ---------------------------------------------------------------------------
# M2 fix iter 1 — documented v1-scope false-negatives.
# These fixtures document the GAP for the eval pack to measure.
# ---------------------------------------------------------------------------


def test_known_v1_banned_claim_false_negatives():
    """v1 regex scope per CONTEXT D-12 :
    - 3rd-person ('rapportera', 'sera de', 'atteindra') — eval pack
      measures false-negative rate ; not gated at parser layer.
    - Infinitive ('faire 4%', 'rapporter 100 CHF') — out of scope.
    - 'garanti' / 'optimal' / 'meilleur' — caught at compliance_guard
      layer (LSFin BANNED_TERMS), NOT here.

    This test asserts the v1 regex's ACTUAL behavior on each gap so
    the gap is visible in the test suite. When Phase 96 fattens the
    regex, this test must be updated together with the change.
    """
    # 1. 3rd-person futur — gate does NOT match « rapportera ».
    #    The number is cited so PASS is the expected verdict.
    response_3rd_person = (
        "Ce produit rapportera 4% par an {{cite:lpp_taux_conv_obligatoire_2026}}."
    )
    r1 = gate(
        response_text=response_3rd_person,
        ctx=None,
        citation_allowlist=["lpp_taux_conv_obligatoire_2026"],
        is_retry=False,
    )
    assert r1.verdict == GateVerdict.PASS, (
        "v1 regex scope per CONTEXT D-12 — 3rd-person 'rapportera' is "
        "OUT of scope at the parser layer ; eval pack measures the rate."
    )

    # 2. Infinitive — gate does NOT match « faire 4% ».
    #    The number is cited so PASS is the expected verdict.
    response_infinitive = (
        "Tu peux faire 4% par an {{cite:lpp_taux_conv_obligatoire_2026}}."
    )
    r2 = gate(
        response_text=response_infinitive,
        ctx=None,
        citation_allowlist=["lpp_taux_conv_obligatoire_2026"],
        is_retry=False,
    )
    assert r2.verdict == GateVerdict.PASS, (
        "v1 regex scope per CONTEXT D-12 — infinitive 'faire' is OUT "
        "of scope at the parser layer ; eval pack measures the rate."
    )

    # 3. LSFin term « garanti » — caught at compliance_guard.py layer
    #    (BANNED_TERMS), NOT at the citation gate. The phrase
    #    « tu auras un rendement garanti à 4% » DOES however fire
    #    the v1 regex because the verb « tu auras » is followed by a
    #    digit at distance via `\\s+(?:ferez|feras|aurez|auras|...)\\s+\\d`.
    #    To get a clean « garanti » false-negative AT THE PARSER LAYER
    #    we use a 3rd-person construct so `tu auras` does not appear.
    response_garanti_3rd = (
        "Le rendement est garanti à 4% par an {{cite:lpp_taux_conv_obligatoire_2026}}."
    )
    r3 = gate(
        response_text=response_garanti_3rd,
        ctx=None,
        citation_allowlist=["lpp_taux_conv_obligatoire_2026"],
        is_retry=False,
    )
    assert r3.verdict == GateVerdict.PASS, (
        "v1 regex scope per CONTEXT D-12 — 'garanti' as 3rd-person "
        "predicate is caught at compliance_guard.py layer, NOT here. "
        "The two gates run independently per CONTEXT specifics line 179."
    )
