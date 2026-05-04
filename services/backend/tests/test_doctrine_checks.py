"""Unit tests for doctrine_checks — Wave 6.5.

Verifies each of the 6 mechanical checks behaves as specified in the
amended rule. Pure unit tests, no fixtures.
"""

from __future__ import annotations

import pytest

from app.services.coach.doctrine_checks import (
    QuestionMeta,
    check_action_or_handoff,
    check_archetype_aware,
    check_banned_terms,
    check_concision,
    check_escalation_aware,
    check_numeric_anchor,
    score_response,
)


# ---------------------------------------------------------------------------
# check_numeric_anchor
# ---------------------------------------------------------------------------


def test_numeric_anchor_pass_on_standard() -> None:
    r = "Plafond 7'258 CHF/an (OPP3 art. 7). **Vérifie** avant de verser."
    assert check_numeric_anchor(r, QuestionMeta()).passed


def test_numeric_anchor_fail_when_opener_has_no_number() -> None:
    r = "C'est une bonne idée. Plafond 7'258 CHF/an. **Vérifie** avant de verser."
    # "C'est une bonne idée." has no digit+unit
    # "Plafond 7'258 CHF/an." does — head = first two sentences = pass
    assert check_numeric_anchor(r, QuestionMeta()).passed


def test_numeric_anchor_fail_on_no_digits_anywhere() -> None:
    r = "Ça dépend de ton profil. **Vérifie** avec un·e spécialiste."
    result = check_numeric_anchor(r, QuestionMeta())
    assert not result.passed


def test_numeric_anchor_existential_accepts_delayed_number() -> None:
    r = (
        "Respire, tu t'en sors. Voyons ensemble. "
        "Partage LPP 50/50 (CC art. 122), tu reçois ~180'000 CHF."
    )
    meta = QuestionMeta(existential=True)
    assert check_numeric_anchor(r, meta).passed


def test_numeric_anchor_existential_still_fails_if_no_number_at_all() -> None:
    r = "Respire. Tu t'en sors. Voyons ensemble."
    meta = QuestionMeta(existential=True)
    assert not check_numeric_anchor(r, meta).passed


# ---------------------------------------------------------------------------
# check_concision
# ---------------------------------------------------------------------------


def test_concision_pass_short() -> None:
    r = "Plafond 7'258 CHF (OPP3 art. 7). **Vérifie** avant de verser."
    assert check_concision(r, QuestionMeta()).passed


def test_concision_fail_when_sentence_too_long() -> None:
    sentence = " ".join(["mot"] * 25) + "."
    r = sentence + " **Vérifie**."
    assert not check_concision(r, QuestionMeta()).passed


def test_concision_fail_when_too_many_total_words() -> None:
    r = (" ".join(["mot"] * 10) + ". ") * 14  # 140 words, but per-sentence under 20
    assert not check_concision(r, QuestionMeta()).passed


def test_concision_irreversible_allows_longer_opener() -> None:
    opener = " ".join(["mot"] * 35) + "."  # 35 words > 20
    r = opener + " **Prends** un rendez-vous avec un·e spécialiste."
    meta = QuestionMeta(irreversible=True)
    assert check_concision(r, meta).passed


# ---------------------------------------------------------------------------
# check_banned_terms
# ---------------------------------------------------------------------------


def test_banned_terms_pass_on_clean() -> None:
    r = "Rente 33'892 CHF/an (LPP art. 14)."
    assert check_banned_terms(r, QuestionMeta()).passed


def test_banned_terms_fail_on_hit() -> None:
    r = "C'est la meilleure option. Plafond 7'258 CHF."
    assert not check_banned_terms(r, QuestionMeta()).passed


def test_banned_terms_fail_on_gerund() -> None:
    r = "Le fonds te verse 5% en garantissant le rendement annuel."
    assert not check_banned_terms(r, QuestionMeta()).passed


# ---------------------------------------------------------------------------
# check_action_or_handoff
# ---------------------------------------------------------------------------


def test_action_pass_on_imperative() -> None:
    r = "Plafond 7'258 CHF. **Vérifie** avant de verser."
    assert check_action_or_handoff(r, QuestionMeta()).passed


def test_action_pass_on_handoff_for_irreversible() -> None:
    r = (
        "Rente 33'892 CHF/an. Capital 677'847 CHF. "
        "Décision lourde: prends un rendez-vous avec un·e spécialiste."
    )
    assert check_action_or_handoff(r, QuestionMeta(irreversible=True)).passed


def test_action_fail_on_irreversible_imperative_without_handoff() -> None:
    r = "Rente 33'892 CHF/an. Capital 677'847 CHF. **Compare** les deux."
    assert not check_action_or_handoff(
        r, QuestionMeta(irreversible=True)
    ).passed


def test_action_fail_on_nothing() -> None:
    r = "Plafond 7'258 CHF. Déductible fiscalement."
    assert not check_action_or_handoff(r, QuestionMeta()).passed


# ---------------------------------------------------------------------------
# check_archetype_aware
# ---------------------------------------------------------------------------


def test_archetype_aware_pass_swiss_native() -> None:
    r = "Plafond 7'258 CHF."
    assert check_archetype_aware(r, QuestionMeta()).passed


def test_archetype_aware_fail_when_expat_us_ignores_fatca() -> None:
    r = "Verse 7'258 CHF avant fin décembre."
    meta = QuestionMeta(archetype="expat_us")
    assert not check_archetype_aware(r, meta).passed


def test_archetype_aware_pass_when_expat_us_names_fatca() -> None:
    r = (
        "Plafond 7'258 CHF. Attention: côté IRS, ton 3a est un foreign trust "
        "et potentiellement PFIC."
    )
    meta = QuestionMeta(archetype="expat_us")
    assert check_archetype_aware(r, meta).passed


def test_archetype_aware_cross_border() -> None:
    r = "Retrait capital taxé à la source au canton de ta caisse. Permis G oblige."
    meta = QuestionMeta(archetype="cross_border")
    assert check_archetype_aware(r, meta).passed


# ---------------------------------------------------------------------------
# check_escalation_aware
# ---------------------------------------------------------------------------


def test_escalation_noop_on_standard() -> None:
    r = "Plafond 7'258 CHF."
    assert check_escalation_aware(r, QuestionMeta()).passed


def test_escalation_fail_on_existential_without_recognition() -> None:
    r = "Partage LPP 50/50. **Demande** ton relevé."
    assert not check_escalation_aware(
        r, QuestionMeta(existential=True)
    ).passed


def test_escalation_pass_on_existential_with_recognition() -> None:
    r = (
        "Oui, tu t'en sors. Partage LPP 50/50 (CC art. 122). "
        "**Demande** ton relevé."
    )
    assert check_escalation_aware(
        r, QuestionMeta(existential=True)
    ).passed


def test_escalation_fail_on_irreversible_without_handoff() -> None:
    r = "Rente 33'892 CHF/an. Capital 677'847 CHF. **Compare** les deux."
    assert not check_escalation_aware(
        r, QuestionMeta(irreversible=True)
    ).passed


def test_escalation_pass_on_irreversible_with_handoff() -> None:
    r = (
        "Rente 33'892 CHF/an. Prends un rendez-vous avec un·e spécialiste."
    )
    assert check_escalation_aware(
        r, QuestionMeta(irreversible=True)
    ).passed


# ---------------------------------------------------------------------------
# score_response integration
# ---------------------------------------------------------------------------


def test_score_response_clean_baseline() -> None:
    r = "Plafond 7'258 CHF/an (OPP3 art. 7). **Vérifie** avant de verser."
    report = score_response(r, QuestionMeta())
    assert report.passed_count == 6
    assert report.score == 100.0


def test_score_response_partial_failure() -> None:
    r = "Rente 33'892 CHF. **Compare** les deux."
    report = score_response(r, QuestionMeta(irreversible=True))
    # action_or_handoff fails (imperative without handoff) + escalation fails
    # → 4/6 pass = 66.7%
    assert report.passed_count == 4
    assert 60.0 <= report.score <= 70.0
