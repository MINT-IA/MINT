"""
v2 profile_extractor pattern tests (phase B).

Expands anonymous-friendly patterns identified by the audit:
- Monthly salary sentences ("7600 Fr net par mois") must be annualised ×12
  with a plausibility gate (3k-40k/month ≈ 36k-480k/year).
- "valeur de rachat" / "caisse de pension" / "avoir de vieillesse" map to
  the LPP topic (user never says "LPP" explicitly in natural speech).
- Existing patterns must keep working — regression guard.
"""
from __future__ import annotations

import pytest

from app.services.coach.profile_extractor import extract_profile_facts


def _topics(message: str) -> set[str]:
    return {f.topic for f in extract_profile_facts(message)}


def _fact_by_topic(message: str, topic: str):
    for f in extract_profile_facts(message):
        if f.topic == topic:
            return f
    return None


# ---------------------------------------------------------------------------
# Monthly salary annualisation
# ---------------------------------------------------------------------------


def test_monthly_salary_fr_is_annualised():
    fact = _fact_by_topic(
        "je gagne 7600 Fr net par mois dans le Valais",
        "salary",
    )
    assert fact is not None, "7600 CHF/mois must be captured — it's the "\
        "commonest way Swiss residents state their salary."
    # 7600 × 12 = 91'200 — within 15k-500k plausibility band.
    assert fact.value == 7600 * 12
    assert "net" in fact.text
    assert "/an" in fact.text or "/mois" in fact.text


def test_monthly_salary_without_net_brut_marker():
    fact = _fact_by_topic("j'ai 8500 CHF par mois", "salary")
    assert fact is not None
    assert fact.value == 8500 * 12


def test_monthly_salary_mensuel_variant():
    fact = _fact_by_topic("mon salaire mensuel est de 6200 francs", "salary")
    assert fact is not None
    assert fact.value == 6200 * 12


def test_monthly_salary_implausibly_low_rejected():
    # 800/month × 12 = 9'600/year — below the 3k-40k/month band.
    assert _fact_by_topic(
        "je reçois 800 francs par mois de rente",
        "salary",
    ) is None


def test_monthly_salary_implausibly_high_rejected():
    # 80k/month × 12 = 960k/year — above 40k/month band.
    assert _fact_by_topic(
        "je gagne 80000 francs par mois",
        "salary",
    ) is None


def test_annual_salary_still_works_after_monthly_patch():
    """Regression guard — monthly pattern must not break existing annual
    extraction."""
    fact = _fact_by_topic("je gagne 95000 CHF brut par an", "salary")
    assert fact is not None
    assert fact.value == 95_000


# ---------------------------------------------------------------------------
# LPP natural language ("valeur de rachat", "caisse de pension")
# ---------------------------------------------------------------------------


def test_valeur_de_rachat_maps_to_lpp():
    fact = _fact_by_topic(
        "j'ai 300000 Fr de valeur de rachat dans ma caisse de pension",
        "lpp",
    )
    assert fact is not None, (
        "'valeur de rachat' is the dominant way Swiss residents refer to "
        "their LPP — regex must match or MSG1 insights drop the number."
    )
    assert fact.value == 300_000


def test_caisse_de_pension_alone_maps_to_lpp():
    fact = _fact_by_topic(
        "ma caisse de pension me verse 70377 CHF",
        "lpp",
    )
    assert fact is not None
    assert fact.value == 70_377


def test_avoir_de_vieillesse_maps_to_lpp():
    fact = _fact_by_topic(
        "mon avoir de vieillesse est de 120'000 CHF",
        "lpp",
    )
    assert fact is not None
    assert fact.value == 120_000


def test_lpp_explicit_keyword_still_works():
    """Regression guard for existing LPP path."""
    fact = _fact_by_topic("LPP 70'377 CHF", "lpp")
    assert fact is not None


# ---------------------------------------------------------------------------
# Multi-topic first-message sanity check
# ---------------------------------------------------------------------------


def test_full_first_message_all_topics_captured():
    msg = (
        "J'ai 49 ans, je gagne 7600 Fr net par mois dans le Valais, "
        "et j'ai 300 000 Fr de valeur de rachat dans ma caisse de pension. "
        "Qu'est-ce que je dois faire ?"
    )
    topics = _topics(msg)
    assert "identity" in topics  # age 49
    assert "salary" in topics    # 7600/mo × 12
    assert "location" in topics  # Valais → VS
    assert "lpp" in topics       # 300'000 via valeur de rachat

    salary = _fact_by_topic(msg, "salary")
    lpp = _fact_by_topic(msg, "lpp")
    age = _fact_by_topic(msg, "identity")
    assert salary.value == 7600 * 12
    assert lpp.value == 300_000
    assert age.value == 49


# ---------------------------------------------------------------------------
# Natural-language robustness
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "phrase",
    [
        "valeur de rachat de 300000 CHF",
        "j'ai 300'000 Fr de rachat possible",
        "rachat possible de 539414 CHF",
    ],
)
def test_rachat_variations(phrase: str):
    fact = _fact_by_topic(phrase, "lpp")
    assert fact is not None
    # Accept a range — the detector should pick *some* valid LPP figure.
    assert 70_000 <= fact.value <= 5_000_000


# ---------------------------------------------------------------------------
# Year-before-keyword collision (post-audit P2 #7)
# ---------------------------------------------------------------------------


def test_year_before_lpp_keyword_is_ignored():
    """'en 2025 la caisse de pension a valu 70'000' must not extract 2025
    as an LPP value. Require explicit currency marker on the BEFORE path."""
    fact = _fact_by_topic(
        "en 2025 la caisse de pension a valu 70'000",
        "lpp",
    )
    # 2025 is NOT an LPP value. 70'000 may or may not be captured via the
    # AFTER path (no keyword precedes it there) — either outcome is OK, as
    # long as we don't return 2025.
    if fact is not None:
        assert fact.value != 2025


def test_year_alone_never_captured_as_lpp():
    assert _fact_by_topic("depuis 2020 dans la caisse de pension", "lpp") is None


# ---------------------------------------------------------------------------
# T-13-05 forbidden lexicon — facts must never leak the banned tokens into
# the anonymous system prompt. Templated `text=` strings are the designed
# defence — this test locks it in so a future `_extract_profession` that
# emits "profil: cadre" or similar is caught at test time.
# ---------------------------------------------------------------------------


_FORBIDDEN = ("outil", "tool", "profil", "dossier", "memoire", "memory")


@pytest.mark.parametrize(
    "adversarial_message",
    [
        "j'utilise l'outil MINT pour mon dossier retraite",
        "je veux un profil financier et une memoire durable",
        "mon dossier est complet, memoire intacte, profil clair",
        "my tool is my memory",
        "49 ans, 7600 fr/mois, mon outil préféré c'est ce dossier",
    ],
)
def test_facts_never_contain_forbidden_lexicon(adversarial_message: str):
    facts = extract_profile_facts(adversarial_message)
    for fact in facts:
        lowered = fact.text.lower()
        for banned in _FORBIDDEN:
            assert banned not in lowered, (
                f"Fact {fact!r} leaks T-13-05 forbidden token '{banned}'. "
                f"Any future extractor that echoes user text into Fact.text "
                f"must scrub or reject these tokens."
            )
