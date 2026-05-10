"""Phase 94 Wave 0 — D-02 5-family number detection regex coverage (GATE-01).

Pins the 5 compiled regex behavior :
- _RE_CURRENCY (CHF / EUR / USD / fr. / francs)
- _RE_PERCENT
- _RE_LEGAL_ARTICLE (Swiss law abbreviations)
- _RE_DURATION (ans / mois / jours / semaines / années / trimestres)
- _RE_REGULATORY (taux de conversion / plafond 3a / barème LIFD / coefficient)
- _RE_CITE_PLACEHOLDER (`{{cite:<key>}}`)

+ hypothesis property : no token from the strict subset escapes detection.
+ legal-article-eats-interior-digits sanity (D-04 + RESEARCH §Pitfall 7).

Forward note (M3 fix iter 1) : `test_d04_exception_4_placeholder_body_stripped`
lands in Plan 94-02 — it tests the integrated `gate()` pre-strip, not the
raw regex (raw regex DOES match digits inside placeholder bodies ; only
the gate's pre-strip exempts them).
"""
from __future__ import annotations

import time

import pytest

from app.services.coach.citation_parser import (
    _RE_CITE_PLACEHOLDER,
    _RE_CURRENCY,
    _RE_DURATION,
    _RE_LEGAL_ARTICLE,
    _RE_PERCENT,
    _RE_REGULATORY,
)


# ---------------------------------------------------------------------------
# 1. Currency — CHF / EUR / USD / fr. / francs
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "text",
    [
        "80'000 CHF",
        "80 000 CHF",
        "80000.50 CHF",
        "80'000 fr.",
        "80'000 fr",
        "80'000 francs",
        "80'000 franc",
        "50000 EUR",
        "100 USD",
        "3 chf",  # case insensitive on currency token
        "100 eur",
    ],
)
def test_currency_matches_amount_with_unit(text):
    assert _RE_CURRENCY.search(text), f"Expected currency match in {text!r}"


@pytest.mark.parametrize(
    "text",
    [
        "80000",  # no unit
        "CHF 80000",  # unit precedes — out of D-02 spec
        "Just text",
    ],
)
def test_currency_does_not_match(text):
    assert _RE_CURRENCY.search(text) is None, f"Unexpected match in {text!r}"


# ---------------------------------------------------------------------------
# 2. Percentages — `4%`, `4.5%`, `4,5%`, `100 %`
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "text",
    [
        "4%",
        "4.5%",
        "4,5%",
        "100 %",
        "0.5%",
    ],
)
def test_percent_matches(text):
    assert _RE_PERCENT.search(text), f"Expected % match in {text!r}"


@pytest.mark.parametrize(
    "text",
    [
        "4",
        "4.5",
        "100",
        "percent",
    ],
)
def test_percent_does_not_match(text):
    assert _RE_PERCENT.search(text) is None, f"Unexpected match in {text!r}"


# ---------------------------------------------------------------------------
# 3. Legal article references — Swiss law abbreviations
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "text",
    [
        "art. 38 LIFD",
        "art 38 al. 2 LPP",
        "art.38 LAVS",
        "art. 60 al. 1 OPP2",
        "art. 12 OPP3",
        "art. 4 LCA",
        "art. 5 LPCC",
        "art. 7 LHID",
        "art. 100 CO",
        "art. 8 OCC",
    ],
)
def test_legal_article_matches(text):
    assert _RE_LEGAL_ARTICLE.search(text), f"Expected legal-article match in {text!r}"


@pytest.mark.parametrize(
    "text",
    [
        "article 38",  # no law abbreviation
        "art. 38",  # no law
        "LIFD",  # no article number
    ],
)
def test_legal_article_does_not_match(text):
    assert _RE_LEGAL_ARTICLE.search(text) is None, f"Unexpected match in {text!r}"


# ---------------------------------------------------------------------------
# 4. Time durations
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "text",
    [
        "5 ans",
        "1 an",
        "3 mois",
        "30 jours",
        "1 jour",
        "2 années",
        "1 année",
        "4 trimestres",
        "12 semaines",
        "1 semaine",
    ],
)
def test_duration_matches(text):
    assert _RE_DURATION.search(text), f"Expected duration match in {text!r}"


@pytest.mark.parametrize(
    "text",
    [
        "5",
        "ans",
        "5 enfants",  # not in duration unit list
        "5 minutes",  # not in duration unit list
    ],
)
def test_duration_does_not_match(text):
    assert _RE_DURATION.search(text) is None, f"Unexpected match in {text!r}"


# ---------------------------------------------------------------------------
# 5. Regulatory constants by name (case insensitive)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "text",
    [
        "taux de conversion",
        "Taux de Conversion",
        "plafond 3a",
        "PLAFOND 3a",
        "barème LIFD",
        "bareme LIFD",
        "coefficient cantonal",
        "coefficient communal",
    ],
)
def test_regulatory_matches(text):
    assert _RE_REGULATORY.search(text), f"Expected regulatory match in {text!r}"


# ---------------------------------------------------------------------------
# 6. Citation placeholder body
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "text",
    [
        "{{cite:r3a_plafond_2026}}",
        "{{cite:lifd_art_38_capital_taux}}",
        "see {{cite:lpp_taux_conv_obligatoire_2026}} now",
    ],
)
def test_cite_placeholder_matches(text):
    assert _RE_CITE_PLACEHOLDER.search(text), f"Expected cite match in {text!r}"


@pytest.mark.parametrize(
    "text",
    [
        "{cite:foo}",  # single brace
        "{{cite: foo}}",  # whitespace before key
        "{{ cite:foo }}",  # whitespace inside braces
        "{{cite:}}",  # empty key
    ],
)
def test_cite_placeholder_does_not_match(text):
    assert _RE_CITE_PLACEHOLDER.search(text) is None, f"Unexpected match in {text!r}"


# ---------------------------------------------------------------------------
# 7. Hypothesis property — no number from the strict subset escapes detection
# ---------------------------------------------------------------------------


def test_property_all_numbers_detected():
    """For every generated narrative containing at least one CHF / % /
    duration token, at least one of the 5 regex captures it.

    Defensive : skip cleanly if `hypothesis` is not installed.
    """
    try:
        from hypothesis import given, settings as h_settings, strategies as st
    except ImportError:  # pragma: no cover — defensive
        pytest.skip("hypothesis not installed")

    # Per D-02 the percent regex caps at \d{1,3} (≤999%) — beyond that is
    # out of spec scope (a 1234% return is not a finance figure MINT speaks).
    # The duration regex accepts unbounded \d+ ; the currency regex accepts
    # unbounded \d+ once we generate the contiguous-digit form.
    @given(
        kind=st.sampled_from(["chf", "percent", "duration"]),
        n=st.integers(min_value=1, max_value=999),
        prefix=st.text(
            alphabet="abcdefghijklmnopqrstuvwxyz ", min_size=0, max_size=20
        ),
        suffix=st.text(
            alphabet="abcdefghijklmnopqrstuvwxyz ", min_size=0, max_size=20
        ),
    )
    @h_settings(max_examples=80, deadline=None)
    def _check(kind, n, prefix, suffix):
        if kind == "chf":
            token = f"{n} CHF"
        elif kind == "percent":
            token = f"{n}%"
        else:
            token = f"{n} ans"
        text = f"{prefix} {token} {suffix}"
        any_match = any(
            r.search(text)
            for r in (_RE_CURRENCY, _RE_PERCENT, _RE_DURATION)
        )
        assert any_match, f"Number {token!r} in {text!r} escaped detection"

    _check()


# ---------------------------------------------------------------------------
# 8. Legal-article priority — D-04#3 + RESEARCH §Pitfall 7
# ---------------------------------------------------------------------------


def test_legal_article_eats_interior_digits_no_overlap_with_duration():
    """For input `"art. 38 LIFD prévoit 5 ans de prescription"`,
    `_RE_LEGAL_ARTICLE` matches the article reference (span containing 38)
    AND `_RE_DURATION` matches the `5 ans` span ; their spans do NOT overlap.
    """
    text = "art. 38 LIFD prévoit 5 ans de prescription"
    legal_match = _RE_LEGAL_ARTICLE.search(text)
    duration_match = _RE_DURATION.search(text)
    assert legal_match is not None, "expected legal-article match"
    assert duration_match is not None, "expected duration match"
    legal_span = legal_match.span()
    duration_span = duration_match.span()
    # Spans MUST NOT overlap (the `38` inside `art. 38 LIFD` is owned by
    # the legal-article regex ; the `5 ans` is owned by duration).
    assert legal_span[1] <= duration_span[0] or duration_span[1] <= legal_span[0], (
        f"legal_span={legal_span} overlaps duration_span={duration_span}"
    )


# ---------------------------------------------------------------------------
# 9. Smoke perf — 5 regex finditer over a 200-token-ish input ≤ 50ms.
# (Full 4kB worst-case test lives in test_regex_engine_performance.py.)
# ---------------------------------------------------------------------------


def test_regex_set_completes_under_50ms_smoke():
    text = (
        "Le plafond 3a 2026 est de 7'258 CHF (art. 38 LIFD) sur 5 ans, "
        "avec un taux de conversion de 6.0% et un barème LIFD progressif. "
    ) * 10
    start = time.perf_counter()
    for r in (_RE_CURRENCY, _RE_PERCENT, _RE_LEGAL_ARTICLE, _RE_DURATION, _RE_REGULATORY):
        list(r.finditer(text))
    elapsed = time.perf_counter() - start
    assert elapsed < 0.050, f"5-regex finditer took {elapsed*1000:.2f}ms (> 50ms budget)"
