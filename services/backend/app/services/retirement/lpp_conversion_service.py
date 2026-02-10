"""
LPP capital vs rente comparison at retirement (LPP art. 14).

Compares two options at retirement:
    - Rente: lifelong pension at 6.8% conversion rate (mandatory minimum)
    - Capital: lump-sum withdrawal with one-time capital tax

Includes breakeven age calculation and neutral recommendation.

Sources:
    - LPP art. 14 (taux de conversion minimum 6.8%)
    - LIFD art. 38 (imposition prestations en capital — taux reduit)

Sprint S21 — Retraite complete.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimations educatives simplifiees. Le taux de conversion reel peut differer "
    "du minimum legal (6.8%) selon ton plan de prevoyance. Les taux d'imposition "
    "sont des approximations cantonales. Ne constitue pas un conseil en prevoyance "
    "(LSFin). Consulte un ou une specialiste."
)

# LPP minimum conversion rate (mandatory portion)
LPP_CONVERSION_RATE = 0.068  # 6.8%

# Capital withdrawal tax rates by canton (simplified educational estimates)
# Same base rates as lpp_deep/epl_service.py + pillar_3a_deep for consistency
TAUX_IMPOT_RETRAIT_CAPITAL = {
    "ZH": 0.065, "BE": 0.075, "LU": 0.055, "UR": 0.050,
    "SZ": 0.040, "OW": 0.045, "NW": 0.040, "GL": 0.055,
    "ZG": 0.035, "FR": 0.070, "SO": 0.065, "BS": 0.075,
    "BL": 0.065, "SH": 0.060, "AR": 0.055, "AI": 0.045,
    "SG": 0.060, "GR": 0.055, "AG": 0.060, "TG": 0.055,
    "TI": 0.065, "VD": 0.080, "VS": 0.060, "NE": 0.070,
    "GE": 0.075, "JU": 0.065,
}

_DEFAULT_TAUX_RETRAIT = 0.065

# Progressive brackets for capital withdrawal tax
PROGRESSIVITY_BRACKETS = [
    (0,       100_000,  1.0),
    (100_000, 200_000,  1.15),
    (200_000, 500_000,  1.30),
    (500_000, 1_000_000, 1.50),
]
LAST_MULTIPLIER = 1.70


@dataclass
class LppConversionResult:
    """Complete result of LPP rente vs capital comparison."""
    capital_total: float               # Total LPP capital (CHF)
    option_rente_mensuelle: float      # Monthly pension with conversion rate
    option_rente_annuelle: float       # Annual pension
    option_capital_brut: float         # Gross capital amount
    option_capital_impot: float        # Estimated capital withdrawal tax
    option_capital_net: float          # Net capital after tax
    breakeven_age: int                 # Age where cumulative rente > net capital
    recommandation_neutre: str         # Neutral comparison text
    chiffre_choc: str                  # Educational shock figure
    sources: List[str] = field(default_factory=list)


class LppConversionService:
    """Compare LPP rente vs capital withdrawal at retirement.

    Key rules:
    - Minimum conversion rate: 6.8% for mandatory portion (LPP art. 14)
    - Capital withdrawal taxed at reduced progressive rate (LIFD art. 38)
    - Rente is taxed as income each year (not modeled here — pure comparison)
    - No universal "better" option — depends on health, needs, heirs

    Sources:
        - LPP art. 14 (taux de conversion 6.8% minimum obligatoire)
        - LIFD art. 38 (imposition des prestations en capital)
    """

    def compare(
        self,
        capital_lpp: float,
        canton: str = "ZH",
        retirement_age: int = 65,
        life_expectancy: int = 87,
    ) -> LppConversionResult:
        """Compare rente vs capital withdrawal for given LPP capital.

        Args:
            capital_lpp: Total LPP capital at retirement (CHF).
            canton: Canton code for tax estimation.
            retirement_age: Age at retirement.
            life_expectancy: Assumed life expectancy.

        Returns:
            LppConversionResult with complete comparison.
        """
        capital_lpp = max(0.0, capital_lpp)
        canton_upper = canton.upper() if canton else "ZH"

        # Rente option
        rente_annuelle = round(capital_lpp * LPP_CONVERSION_RATE, 2)
        rente_mensuelle = round(rente_annuelle / 12, 2)

        # Capital option
        taux = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton_upper, _DEFAULT_TAUX_RETRAIT)
        impot = self._calculate_progressive_tax(capital_lpp, taux)
        capital_net = round(capital_lpp - impot, 2)

        # Breakeven
        duree = max(0, life_expectancy - retirement_age)
        breakeven = retirement_age
        if rente_annuelle > 0:
            cumul = 0.0
            for y in range(duree + 1):
                cumul += rente_annuelle
                if cumul >= capital_net:
                    breakeven = retirement_age + y
                    break
            else:
                breakeven = life_expectancy  # Never reached

        recommandation = (
            f"La rente LPP te verse CHF {rente_mensuelle:,.0f}/mois a vie. "
            f"Le capital te donne CHF {capital_net:,.0f} net apres impot. "
            f"Si tu vis au-dela de {breakeven} ans, la rente est plus avantageuse en cumul. "
            f"Aucune option n'est universellement meilleure — cela depend de ta situation."
        )

        chiffre_choc = (
            f"Rente = CHF {rente_mensuelle:,.0f}/mois a vie | "
            f"Capital = CHF {capital_net:,.0f} net (breakeven a {breakeven} ans)"
        )

        return LppConversionResult(
            capital_total=capital_lpp,
            option_rente_mensuelle=rente_mensuelle,
            option_rente_annuelle=rente_annuelle,
            option_capital_brut=capital_lpp,
            option_capital_impot=impot,
            option_capital_net=capital_net,
            breakeven_age=breakeven,
            recommandation_neutre=recommandation,
            chiffre_choc=chiffre_choc,
            sources=[
                "LPP art. 14 (taux de conversion 6.8% minimum obligatoire)",
                "LIFD art. 38 (imposition des prestations en capital)",
            ],
        )

    def _calculate_progressive_tax(self, montant: float, base_rate: float) -> float:
        """Calculate capital withdrawal tax using progressive brackets.

        Uses the same bracket structure as lpp_deep/epl_service.py and
        pillar_3a_deep/multi_account_service.py for consistency.

        Args:
            montant: Amount being withdrawn (CHF).
            base_rate: Base cantonal rate.

        Returns:
            Estimated tax amount (CHF).
        """
        if montant <= 0:
            return 0.0
        total_tax = 0.0
        remaining = montant
        for low, high, multiplier in PROGRESSIVITY_BRACKETS:
            tranche = high - low
            taxable = min(remaining, tranche)
            if taxable <= 0:
                break
            total_tax += taxable * base_rate * multiplier
            remaining -= taxable
        if remaining > 0:
            total_tax += remaining * base_rate * LAST_MULTIPLIER
        return round(total_tax, 2)
