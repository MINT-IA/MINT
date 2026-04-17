"""Named-product detection in ComplianceGuard (LSFin "no-advice" rule).

Audit 2026-04-17: ComplianceGuard has banned-term coverage for superlatives
and prescriptive verbs but nothing caught ISIN codes or ticker symbols. A
coach response like "achète NESN" or "investis dans CH0012221716" would
slip through every filter. These tests pin the new regex patterns added to
PRESCRIPTIVE_PATTERNS so future edits cannot remove them silently.
"""

import re

from app.services.coach.compliance_guard import ComplianceGuard


def _any_match(text: str) -> list[str]:
    hits: list[str] = []
    for pattern in ComplianceGuard.PRESCRIPTIVE_PATTERNS:
        m = pattern.search(text)
        if m:
            hits.append(m.group(0))
    return hits


class TestISINDetection:
    """ISIN = 2 letters + 9 alphanumerics + 1 check digit (uppercase)."""

    def test_swiss_isin_detected(self):
        assert _any_match("achète CH0012221716 cette semaine")

    def test_us_isin_detected(self):
        assert _any_match("regarde US0378331005 dans ton portefeuille")

    def test_isin_inside_sentence(self):
        assert _any_match("Le titre DE000BASF111 a bien performé")

    def test_lowercase_isin_not_matched(self):
        # Real ISINs are uppercase; lowering case avoids matching mid-
        # sentence words like "ch000000000" that appear in prose.
        assert not _any_match("ch0012221716 not a real isin mention")

    def test_word_boundary_respected(self):
        # 'CH001222171699' is 14 chars (too long for ISIN) — no match.
        assert not _any_match("CH001222171699 is not an ISIN")


class TestTickerWithContext:
    """Tickers (2-5 upper letters) require an action verb or noun marker."""

    def test_ticker_plus_action_noun(self):
        assert _any_match("ajoute NESN actions à ton portefeuille")

    def test_ticker_plus_etf_marker(self):
        assert _any_match("le ROG ETF est liquide")

    def test_buy_ticker_imperative(self):
        assert _any_match("achète UBSG dès demain")

    def test_sell_ticker_imperative(self):
        assert _any_match("vends ROG tout de suite")

    def test_invest_in_ticker(self):
        assert _any_match("investis dans NESN")

    def test_bare_ticker_in_prose_not_matched(self):
        # "L'UBS a publié" — bare acronym without investment verb/noun
        # should not trigger (too many false positives on corporate names).
        assert not _any_match("L'UBS a publié ses résultats aujourd'hui")

    def test_french_word_not_matched_as_ticker(self):
        # "RENTE" / "DONC" / "CELA" uppercase common French words — the
        # context-word requirement prevents false positives.
        assert not _any_match("RENTE actuelle est 2 520 CHF")


class TestComplianceGuardLayer2PicksUpISIN:
    """End-to-end check: _check_prescriptive must flag an ISIN mention."""

    def test_isin_flagged_as_prescriptive(self):
        guard = ComplianceGuard()
        found = guard._check_prescriptive("Tu peux acheter CH0012221716 ce mois-ci")
        assert any(re.search(r"CH0012221716|ach[eè]te", hit) for hit in found)
