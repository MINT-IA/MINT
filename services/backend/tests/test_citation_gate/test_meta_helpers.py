"""Phase 94 Wave 0 — D-03 meta-helper correctness (port of Wave-4 scorer).

Pin the public `is_meta_quoted` / `is_meta_negation` helpers shipped in
`app/services/coach/citation_parser.py`. Coverage shape mirrors the
existing `tests/test_eval_narrator_meta_scorer.py` suite (15 tests) but
calls the helpers DIRECTLY with computed `(match_start, match_end)`
integers — H2 fix iter 1 because the source suite consumes the eval-time
`_score_banned_terms`, which is a different surface and not portable.

Coverage map (15 tests) :
- 6 negation excused (`is_meta_negation` returns True)
- 3 quoted excused (`is_meta_quoted` returns True)
- 3 plain assertions (NEITHER helper excuses — both return False)
- 1 mixed scenario (refute-then-assert — first occurrence excused, second NOT)
- 2 edge cases (empty response, isolated punctuation)

The pre-existing `tests/test_eval_narrator_meta_scorer.py` is left
UNCHANGED — it stays green via the eval module's re-import alias and
serves as the 0-trust receipt that the SSOT refactor preserved behavior.
"""
from __future__ import annotations

import pytest

from app.services.coach.citation_parser import is_meta_negation, is_meta_quoted


def _span_of(response: str, term: str) -> tuple[int, int]:
    """Compute (match_start, match_end) for the first occurrence of `term`."""
    idx = response.find(term)
    assert idx != -1, f"term {term!r} not found in {response!r}"
    return idx, idx + len(term)


# ---------------------------------------------------------------------------
# 6 negation-excused cases (mirror test_eval_narrator_meta_scorer.py:42-81)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "response,term,reason",
    [
        (
            "**Aucun 3a n'est garanti** (sauf le compte bancaire classique).",
            "garanti",
            "aucun + n'est + banned-term — meta-negation",
        ),
        (
            "**Aucun placement financier n'est sans risque** (LSFin).",
            "sans risque",
            "aucun + n'est + banned-term — meta-negation",
        ),
        (
            "Pas de meilleur universel.",
            "meilleur",
            "pas de + banned-term",
        ),
        (
            "Le rendement garanti n'existe pas dans les marchés actions.",
            "garanti",
            "n'existe pas — meta-negation",
        ),
        (
            "Il n'y a pas de placement parfait.",
            "parfait",
            "il n'y a pas de — meta-negation",
        ),
        (
            "On ne peut jamais dire qu'un placement est sans risque.",
            "sans risque",
            "jamais — meta-negation",
        ),
    ],
)
def test_meta_negation_excused(response, term, reason):
    start, end = _span_of(response, term)
    assert is_meta_negation(response, start, end) is True, (
        f"Expected is_meta_negation=True ({reason}) for term {term!r}"
    )


# ---------------------------------------------------------------------------
# 3 quoted-excused cases (mirror test_eval_narrator_meta_scorer.py:97-118)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "response,term,reason",
    [
        (
            'Pas de "meilleur" universel.',
            "meilleur",
            'meta-quoted with "',
        ),
        (
            "Le concept de « garanti » n'existe que pour la garantie des dépôts FINMA.",
            "garanti",
            "« » — meta-quoted",
        ),
        (
            "L'idée d'un placement “sans risque” n'a pas de sens en marchés.",
            "sans risque",
            "curly quotes — meta-quoted",
        ),
    ],
)
def test_meta_quoted_excused(response, term, reason):
    start, end = _span_of(response, term)
    assert is_meta_quoted(response, start, end) is True, (
        f"Expected is_meta_quoted=True ({reason}) for term {term!r}"
    )


# ---------------------------------------------------------------------------
# 3 plain assertions — NEITHER helper excuses (both return False)
# (mirror test_eval_narrator_meta_scorer.py:133-156)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "response,term,reason",
    [
        (
            "Ton 3a est garanti à 4% par an, c'est le meilleur rendement.",
            "garanti",
            "plain assertion of banned terms",
        ),
        (
            # negation in PRIOR sentence does NOT excuse the banned term
            # in the NEXT sentence — sentence-isolation pin.
            "Aucun 3a n'est risqué. Mais le LPP est garanti à vie.",
            # second occurrence — find from offset
            "garanti",
            "negation in prior sentence does not cross sentence boundary",
        ),
        (
            "Le compte bancaire classique est garanti jusqu'à 100'000 CHF par FINMA.",
            "garanti",
            "factual citation — Phase 94 will excuse via citation parser, "
            "but the meta-helper alone returns False",
        ),
    ],
)
def test_plain_assertion_neither_excused(response, term, reason):
    # Always pick the LAST occurrence — for the multi-sentence case the
    # banned term is in the second sentence, not the first.
    last_idx = response.rfind(term)
    start, end = last_idx, last_idx + len(term)
    assert is_meta_quoted(response, start, end) is False, (
        f"Expected is_meta_quoted=False ({reason})"
    )
    assert is_meta_negation(response, start, end) is False, (
        f"Expected is_meta_negation=False ({reason})"
    )


# ---------------------------------------------------------------------------
# 1 mixed scenario — refute then assert (mirror :171-181)
# ---------------------------------------------------------------------------


def test_mixed_meta_then_real_use():
    """Narrator refutes 'garanti' in sentence 1, then uses it as positive
    claim in sentence 2. is_meta_negation MUST be True for the FIRST
    occurrence and False for the SECOND.
    """
    response = (
        "Aucun placement n'est garanti.\n\n"
        "Mais ton 3a Swisscanto rapporte un 4% garanti à vie."
    )
    first_idx = response.find("garanti")
    last_idx = response.rfind("garanti")
    assert first_idx != last_idx, "fixture must contain 2 occurrences"

    # First occurrence — within the negation sentence — excused
    assert is_meta_negation(response, first_idx, first_idx + len("garanti")) is True
    # Second occurrence — past the blank-line sentence boundary — NOT excused
    assert is_meta_negation(response, last_idx, last_idx + len("garanti")) is False
    # Neither is quoted
    assert is_meta_quoted(response, first_idx, first_idx + len("garanti")) is False
    assert is_meta_quoted(response, last_idx, last_idx + len("garanti")) is False


# ---------------------------------------------------------------------------
# 2 edge cases
# ---------------------------------------------------------------------------


def test_empty_response_does_not_crash():
    """Edge — empty response, both helpers must return False without crashing."""
    assert is_meta_quoted("", 0, 0) is False
    assert is_meta_negation("", 0, 0) is False


def test_single_token_no_negation_no_quote():
    """Edge — bare term, no quote, no negation — both False."""
    response = "garanti"
    start, end = _span_of(response, "garanti")
    assert is_meta_quoted(response, start, end) is False
    assert is_meta_negation(response, start, end) is False
