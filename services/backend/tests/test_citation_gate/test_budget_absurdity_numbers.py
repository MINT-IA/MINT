"""Phase 22 — budget absurdity numbers must be cited.

The gate does not decide whether a budget number is economically plausible.
Its job is stricter and simpler: any CHF/% claim the narrator emits must be
grounded by an allowed citation or rejected before the user sees it.
"""

from app.services.coach.citation_parser import GateVerdict, gate


def test_budget_absurd_currency_numbers_without_citation_are_rejected():
    text = (
        "Loyer possible: 19'272'200 CHF. "
        "Prime LAMal: 420'420 CHF. "
        "Economie fiscale en jeu: 999'999 CHF."
    )

    result = gate(text, ctx=None, citation_allowlist={"budget_test"})

    assert result.verdict == GateVerdict.REJECTED_UNCITED
    assert result.retry_needed is True
    assert result.uncited_numbers_count == 3


def test_budget_absurd_percentage_without_citation_is_rejected():
    result = gate(
        "Taux fiscal implicite: 87 %.",
        ctx=None,
        citation_allowlist={"budget_test"},
    )

    assert result.verdict == GateVerdict.REJECTED_UNCITED
    assert result.uncited_numbers_count == 1


def test_budget_number_with_allowed_adjacent_citation_passes_gate():
    result = gate(
        "Marge libre: 2'239 CHF {{cite:budget_test}}.",
        ctx=None,
        citation_allowlist={"budget_test"},
    )

    assert result.verdict == GateVerdict.PASS
