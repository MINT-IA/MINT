"""Tests for runtime_temporal_gate (CJT-021).

Catches narrator answers that answer a current-year question with a past
month/year timing example. This is separate from runtime_freshness_gate:
7'258 can be the correct 2026 ceiling while "janvier 2025" is still the
wrong temporal anchor for "cette annee".
"""
from __future__ import annotations

from app.services.coach.runtime_temporal_gate import (
    _FALLBACK_FR,
    fallback_for_language,
    gate,
)


def test_gate_blocks_past_month_year_for_current_year_question():
    user_msg = "Combien je peux mettre sur mon 3a cette annee ?"
    narrator = (
        "Verser en janvier 2025 plutot qu'en decembre 2025 pourrait te "
        "rapporter un an de marche en plus."
    )

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is False
    assert output == _FALLBACK_FR


def test_gate_passes_current_year_months_for_current_year_question():
    user_msg = "Combien je peux mettre sur mon 3a cette annee ?"
    narrator = "Pour 2026, janvier 2026 et decembre 2026 restent dans la meme annee fiscale."

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is True
    assert output == narrator


def test_gate_passes_past_year_when_user_explicitly_asked_for_it():
    user_msg = "En janvier 2025, est-ce que mon versement 3a comptait pour 2025 ?"
    narrator = "Oui, janvier 2025 et decembre 2025 sont deux mois de l'annee fiscale 2025."

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is True
    assert output == narrator


def test_gate_does_not_block_historical_rule_without_month_anchor():
    user_msg = "Combien je peux mettre sur mon 3a cette annee ?"
    narrator = "Depuis 2025, le plafond salarie est reste a 7'258 CHF."

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is True
    assert output == narrator


def test_gate_does_not_block_unchanged_biennial_constant_context():
    user_msg = "Combien je peux mettre sur mon 3a cette annee ?"
    narrator = (
        "Pour 2026, le plafond salarie est de 7'258 CHF, "
        "inchange par rapport a 2025."
    )

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is True
    assert output == narrator


def test_gate_does_not_block_identical_prior_year_context():
    user_msg = "Combien je peux mettre sur mon 3a cette annee ?"
    narrator = "Le plafond 2026 est de 7'258 CHF; la valeur 2025 etait identique."

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is True
    assert output == narrator


def test_gate_blocks_past_year_ceiling_anchor_for_current_year_question():
    user_msg = "Combien je peux mettre sur mon 3a cette annee ?"
    narrator = "Tu peux verser jusqu'a 7'258 CHF en 2025 selon l'OPP3 art. 7."

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is False
    assert output == _FALLBACK_FR


def test_gate_blocks_german_current_year_3a_question_with_localized_fallback():
    user_msg = "Wie viel kann ich dieses Jahr in die Säule 3a einzahlen?"
    narrator = "Du kannst 7'258 CHF im Jahr 2025 in die Säule 3a einzahlen."
    fallback = fallback_for_language("de")

    passed, output = gate(
        narrator,
        user_message=user_msg,
        current_year=2026,
        fallback_text=fallback,
    )

    assert passed is False
    assert output == fallback


def test_gate_blocks_market_timing_for_current_3a_ceiling_question():
    user_msg = "Combien je peux mettre sur mon 3a cette annee ?"
    narrator = "Verser en janvier pourrait te rapporter un an de marche en plus."

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is False
    assert output == _FALLBACK_FR


def test_gate_allows_market_wording_when_user_asks_return_comparison():
    user_msg = "Quel rendement attendre avec un 3a titres par rapport au cash ?"
    narrator = "Le rendement depend du risque, des frais et de l'horizon."

    passed, output = gate(narrator, user_message=user_msg, current_year=2026)

    assert passed is True
    assert output == narrator
