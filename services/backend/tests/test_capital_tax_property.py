"""Tests de propriété sur le domaine continu de l'impôt capital (#1095).

Balaye 0 -> 3'000'000 CHF par pas fins sur les 26 cantons, célibataire ET
marié, et fige les INVARIANTS structurels de ``estimate_capital_withdrawal_tax``
(filet de sécurité du refresh ESTV annuel — une re-collecte qui casserait la
monotonie, l'ordre marié/célibataire ou la borne de taux échoue ici) :

  (a) impôt CROISSANT avec le montant (célibataire et marié) ;
  (b) marié <= célibataire PARTOUT (aurait attrapé le croisement TI vers
      ~1.09M et l'arrondi ESTV +1 CHF de SO) ;
  (c) taux moyen borné [0, 0.30] (max observé ~0.142 : ZH célibataire 3M).

Ces invariants sont indépendants des VALEURS de barème : ils testent la forme,
pas les points calibrés (couverts par test_capital_marie_calibration.py).
"""

import pytest

from app.services.fiscal.cantonal_comparator import (
    CANTONAL_CAPITAL_TAX_CHF,
    estimate_capital_withdrawal_tax,
)

CANTONS = sorted(CANTONAL_CAPITAL_TAX_CHF)
STEP = 5_000
MAX_AMOUNT = 3_000_000
# Amounts swept: 0, 5k, 10k, …, 3M.
AMOUNTS = list(range(0, MAX_AMOUNT + STEP, STEP))
# Borne de taux moyen : max observé ~0.142 (ZH célibataire 3M) ; 0.30 laisse
# ~2x de marge (attrape une erreur grossière de calibration sans bloquer la
# dérive normale d'un refresh annuel).
MAX_AVG_RATE = 0.30


@pytest.mark.parametrize("canton", CANTONS)
def test_tax_is_monotonic_in_amount(canton):
    """(a) L'impôt ne décroît jamais quand le montant croît (les 2 états)."""
    for is_married in (False, True):
        prev = -1.0
        for amount in AMOUNTS:
            tax = estimate_capital_withdrawal_tax(amount, canton, is_married=is_married)
            assert tax >= prev - 1e-6, (
                f"{canton} married={is_married} @ {amount}: {tax} < {prev} "
                f"(non-monotone)"
            )
            prev = tax


@pytest.mark.parametrize("canton", CANTONS)
def test_married_never_exceeds_single(canton):
    """(b) Marié <= célibataire sur toute la grille continue."""
    for amount in AMOUNTS:
        single = estimate_capital_withdrawal_tax(amount, canton)
        married = estimate_capital_withdrawal_tax(amount, canton, is_married=True)
        assert married <= single + 1e-6, (
            f"{canton} @ {amount}: marié {married} > célibataire {single}"
        )


@pytest.mark.parametrize("canton", CANTONS)
def test_average_rate_within_bounds(canton):
    """(c) Taux moyen dans [0, 0.30] pour tout montant > 0 (les 2 états)."""
    for is_married in (False, True):
        for amount in AMOUNTS:
            if amount == 0:
                assert (
                    estimate_capital_withdrawal_tax(amount, canton, is_married=is_married)
                    == 0.0
                )
                continue
            rate = (
                estimate_capital_withdrawal_tax(amount, canton, is_married=is_married)
                / amount
            )
            assert 0.0 <= rate <= MAX_AVG_RATE, (
                f"{canton} married={is_married} @ {amount}: taux moyen "
                f"{rate:.4f} hors [0, {MAX_AVG_RATE}]"
            )


def test_ti_married_does_not_cross_single_beyond_grid():
    """Régression ciblée : TI marié CROISAIT le célibataire vers ~1.09M
    (pentes d'extrapolation divergentes) avant la post-condition min()."""
    for amount in (1_050_000, 1_091_585, 1_200_000, 2_000_000, 3_000_000):
        single = estimate_capital_withdrawal_tax(amount, "TI")
        married = estimate_capital_withdrawal_tax(amount, "TI", is_married=True)
        assert married <= single, f"TI @ {amount}: marié {married} > {single}"


def test_so_married_rounding_absorbed():
    """Régression ciblée : SO 750k/1M — l'ESTV arrondit le marié +1 CHF au
    dessus du célibataire ; la post-condition min() l'absorbe."""
    for amount in (750_000, 1_000_000):
        single = estimate_capital_withdrawal_tax(amount, "SO")
        married = estimate_capital_withdrawal_tax(amount, "SO", is_married=True)
        assert married <= single, f"SO @ {amount}: marié {married} > {single}"
