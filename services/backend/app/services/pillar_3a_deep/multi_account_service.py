"""
Multi-account 3a staggered withdrawal simulator.

Simulates the tax impact of withdrawing 3a capital in a single block
vs staggering across multiple accounts over several years.

The core insight: Swiss progressive taxation on capital withdrawals means
splitting 3a across N accounts and withdrawing one per year results in
significantly lower total taxes than withdrawing everything at once.

Sources:
    - OPP3 art. 1 (3e pilier lie)
    - LIFD art. 33 al. 1 let. e (deduction fiscale 3a)
    - LIFD art. 38 (imposition prestations en capital — taux reduit, progressif)

Sprint S16 — Gap G1: 3a Deep.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en prevoyance au sens de la LSFin. Les economies fiscales "
    "dependent de votre situation personnelle et des baremes en vigueur au "
    "moment du retrait. Consultez un ou une specialiste en fiscalite."
)

# ---------------------------------------------------------------------------
# Cantonal capital withdrawal tax rates (simplified, educational estimates)
# Same as used in lpp_deep/epl_service.py for consistency
# ---------------------------------------------------------------------------

TAUX_IMPOT_RETRAIT_CAPITAL = {
    "ZH": 0.065,
    "BE": 0.070,
    "VD": 0.080,
    "GE": 0.075,
    "LU": 0.050,
    "AG": 0.060,
    "SG": 0.065,
    "BS": 0.075,
    "TI": 0.070,
    "VS": 0.060,
    "FR": 0.075,
    "NE": 0.080,
    "JU": 0.080,
    "SO": 0.065,
    "BL": 0.065,
    "GR": 0.060,
    "TG": 0.055,
    "SZ": 0.040,
    "ZG": 0.035,
    "NW": 0.040,
    "OW": 0.045,
    "UR": 0.050,
    "SH": 0.060,
    "AR": 0.055,
    "AI": 0.045,
    "GL": 0.055,
}

_DEFAULT_TAUX_RETRAIT = 0.065

# Progressive surcharge on large capital withdrawals (simplified model)
# In many cantons, the effective rate increases with the amount withdrawn.
# This table models the progressivity as a multiplier on the base rate.
_PROGRESSIVITY_BRACKETS = [
    (0,       100_000,  1.0),    # 0-100k: base rate
    (100_000, 200_000,  1.15),   # 100k-200k: +15%
    (200_000, 500_000,  1.30),   # 200k-500k: +30%
    (500_000, 1_000_000, 1.50),  # 500k-1M: +50%
    (1_000_000, float("inf"), 1.70),  # >1M: +70%
]


@dataclass
class YearlyWithdrawalEntry:
    """A single year in the staggered withdrawal plan."""
    annee: int                    # Year number (1-based)
    age: int                     # Age at withdrawal
    montant_retrait: float       # Amount withdrawn this year (CHF)
    taux_imposition: float       # Effective tax rate for this withdrawal
    impot: float                 # Tax paid on this withdrawal (CHF)
    net_recu: float              # Net amount received (CHF)


@dataclass
class StaggeredWithdrawalResult:
    """Complete result of staggered vs bloc withdrawal comparison."""

    # Bloc (single withdrawal)
    bloc_tax: float              # Tax if withdrawn all at once (CHF)
    bloc_taux_effectif: float    # Effective tax rate for bloc withdrawal

    # Staggered (over N years)
    staggered_tax: float         # Total tax with staggered withdrawal (CHF)
    staggered_taux_effectif: float  # Average effective rate for staggered

    # Delta
    economy: float               # Tax savings from staggering (CHF)
    economy_pct: float           # Savings as percentage

    # Plan details
    optimal_accounts: int        # Recommended number of accounts (2-5)
    yearly_plan: List[YearlyWithdrawalEntry]

    # Metadata
    avoir_total: float
    nb_comptes: int
    canton: str

    # Compliance
    chiffre_choc: str
    alerts: List[str] = field(default_factory=list)
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class MultiAccountService:
    """Simulate staggered vs bloc 3a withdrawal for tax optimization.

    Key rules:
    - 3a can only be withdrawn 5 years before / after ordinary retirement age
      (women: 64, men: 65) — OPP3 art. 3
    - Each 3a account must be withdrawn in full (no partial withdrawal)
    - Multiple accounts enable staggered withdrawal across years
    - Capital withdrawal tax is progressive in most cantons (LIFD art. 38)
    - Optimal: 2-5 accounts, one withdrawn per year in the last years before retirement

    Sources:
        - OPP3 art. 1, 3 (conditions retrait 3a)
        - LIFD art. 33 al. 1 let. e (deduction fiscale)
        - LIFD art. 38 (imposition prestations en capital)
    """

    MIN_COMPTES = 1
    MAX_COMPTES = 5

    def simulate_staggered_withdrawal(
        self,
        avoir_total: float,
        nb_comptes: int,
        canton: str,
        revenu_imposable: float,
        age_retrait_debut: int,
        age_retrait_fin: int,
    ) -> StaggeredWithdrawalResult:
        """Simulate staggered vs bloc 3a withdrawal.

        Args:
            avoir_total: Total 3a savings across all accounts (CHF).
            nb_comptes: Number of 3a accounts to split across.
            canton: Canton code for tax estimation (e.g. "VD", "ZH").
            revenu_imposable: Annual taxable income (CHF) — for context.
            age_retrait_debut: Age at first withdrawal.
            age_retrait_fin: Age at last withdrawal.

        Returns:
            StaggeredWithdrawalResult with comparison and plan.
        """
        avoir_total = max(0.0, avoir_total)
        nb_comptes = max(self.MIN_COMPTES, min(self.MAX_COMPTES, nb_comptes))
        canton_upper = canton.upper() if canton else "ZH"
        age_retrait_debut = max(59, min(70, age_retrait_debut))
        age_retrait_fin = max(age_retrait_debut, min(70, age_retrait_fin))

        # Ensure we have enough years for the accounts
        annees_disponibles = age_retrait_fin - age_retrait_debut + 1
        nb_comptes_effectif = min(nb_comptes, annees_disponibles)
        nb_comptes_effectif = max(1, nb_comptes_effectif)

        base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton_upper, _DEFAULT_TAUX_RETRAIT)

        # 1. Calculate bloc tax (all at once)
        bloc_taux = self._calc_effective_rate(avoir_total, base_rate)
        bloc_tax = round(avoir_total * bloc_taux, 2)

        # 2. Calculate staggered tax (split across N years)
        montant_par_compte = round(avoir_total / nb_comptes_effectif, 2)
        yearly_plan: List[YearlyWithdrawalEntry] = []
        total_staggered_tax = 0.0

        for i in range(nb_comptes_effectif):
            # Last account gets remainder to avoid rounding issues
            if i == nb_comptes_effectif - 1:
                montant = round(
                    avoir_total - sum(e.montant_retrait for e in yearly_plan), 2
                )
            else:
                montant = montant_par_compte

            taux = self._calc_effective_rate(montant, base_rate)
            impot = round(montant * taux, 2)
            net = round(montant - impot, 2)

            yearly_plan.append(YearlyWithdrawalEntry(
                annee=i + 1,
                age=age_retrait_debut + i,
                montant_retrait=montant,
                taux_imposition=round(taux, 5),
                impot=impot,
                net_recu=net,
            ))
            total_staggered_tax += impot

        total_staggered_tax = round(total_staggered_tax, 2)

        # 3. Economy
        economy = round(bloc_tax - total_staggered_tax, 2)
        economy_pct = (
            round((economy / bloc_tax) * 100, 2) if bloc_tax > 0 else 0.0
        )

        # 4. Staggered effective rate
        staggered_taux = (
            round(total_staggered_tax / avoir_total, 5)
            if avoir_total > 0 else 0.0
        )

        # 5. Optimal accounts recommendation
        optimal = self._recommend_optimal_accounts(avoir_total, base_rate, annees_disponibles)

        # 6. Chiffre choc
        if economy > 0:
            chiffre_choc = (
                f"Economie fiscale estimee : {economy:,.0f} CHF "
                f"grace a l'echelonnement sur {nb_comptes_effectif} comptes"
            ).replace(",", "'")
        else:
            chiffre_choc = (
                f"Impot total estime au retrait : {total_staggered_tax:,.0f} CHF"
            ).replace(",", "'")

        # 7. Alerts
        alerts = self._generate_alerts(
            avoir_total, nb_comptes_effectif, canton_upper,
            age_retrait_debut, age_retrait_fin, economy,
        )

        # 8. Sources
        sources = [
            "OPP3 art. 1 (3e pilier lie — conditions)",
            "OPP3 art. 3 (retrait: 5 ans avant / apres age de retraite)",
            "LIFD art. 33 al. 1 let. e (deduction fiscale 3a)",
            "LIFD art. 38 (imposition prestations en capital — taux progressif)",
        ]

        return StaggeredWithdrawalResult(
            bloc_tax=bloc_tax,
            bloc_taux_effectif=round(bloc_taux, 5),
            staggered_tax=total_staggered_tax,
            staggered_taux_effectif=staggered_taux,
            economy=economy,
            economy_pct=economy_pct,
            optimal_accounts=optimal,
            yearly_plan=yearly_plan,
            avoir_total=avoir_total,
            nb_comptes=nb_comptes_effectif,
            canton=canton_upper,
            chiffre_choc=chiffre_choc,
            alerts=alerts,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _calc_effective_rate(self, montant: float, base_rate: float) -> float:
        """Calculate the effective capital withdrawal tax rate with progressivity.

        In most Swiss cantons, the capital withdrawal tax is levied at a
        reduced rate compared to income tax, but it is still progressive.
        Larger amounts are taxed at higher effective rates.

        Args:
            montant: Amount being withdrawn (CHF).
            base_rate: Base cantonal rate.

        Returns:
            Effective tax rate (0-1).
        """
        if montant <= 0:
            return 0.0

        total_tax = 0.0
        remaining = montant

        for low, high, multiplier in _PROGRESSIVITY_BRACKETS:
            if remaining <= 0:
                break
            bracket_amount = min(remaining, high - low)
            if montant > low:
                taxable_in_bracket = min(bracket_amount, montant - low)
                if taxable_in_bracket <= 0:
                    continue
                total_tax += taxable_in_bracket * base_rate * multiplier

        effective_rate = total_tax / montant if montant > 0 else 0.0
        return min(effective_rate, 0.25)  # Cap at 25% for realism

    def _recommend_optimal_accounts(
        self, avoir_total: float, base_rate: float, annees_max: int,
    ) -> int:
        """Recommend the optimal number of 3a accounts.

        Tests 2-5 accounts and returns the one with the best tax savings.
        Considers diminishing returns and practical limits.

        Args:
            avoir_total: Total 3a savings (CHF).
            base_rate: Base cantonal rate.
            annees_max: Maximum years available.

        Returns:
            Optimal number of accounts (2-5).
        """
        if avoir_total <= 0:
            return 2  # Default recommendation

        best_n = 2
        best_saving = 0.0

        bloc_taux = self._calc_effective_rate(avoir_total, base_rate)
        bloc_tax = avoir_total * bloc_taux

        for n in range(2, min(6, annees_max + 1)):
            part = avoir_total / n
            part_taux = self._calc_effective_rate(part, base_rate)
            total_tax = part * part_taux * n
            saving = bloc_tax - total_tax

            # Account for diminishing returns — marginal benefit must be > 500 CHF
            if saving > best_saving and (n == 2 or saving - best_saving > 500):
                best_saving = saving
                best_n = n

        return best_n

    def _generate_alerts(
        self,
        avoir_total: float,
        nb_comptes: int,
        canton: str,
        age_debut: int,
        age_fin: int,
        economy: float,
    ) -> List[str]:
        """Generate alerts and recommendations.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        if nb_comptes == 1:
            alerts.append(
                "Avec un seul compte 3a, aucun echelonnement n'est possible. "
                "Ouvrez au moins 2-3 comptes des maintenant pour beneficier "
                "de l'echelonnement fiscal au moment du retrait."
            )

        if avoir_total > 200_000 and nb_comptes < 3:
            alerts.append(
                f"Avec {avoir_total:,.0f} CHF d'avoir 3a, au moins 3 comptes "
                f"sont recommandes pour optimiser l'echelonnement fiscal.".replace(",", "'")
            )

        if age_fin - age_debut < nb_comptes - 1:
            alerts.append(
                "La periode de retrait est trop courte pour le nombre de comptes. "
                "Planifiez le retrait au plus tot 5 ans avant l'age de la retraite."
            )

        if canton in ("GE", "VD", "NE", "JU", "BS"):
            alerts.append(
                f"Canton {canton}: taux d'imposition eleves sur le retrait en capital. "
                f"L'echelonnement est particulierement avantageux."
            )

        alerts.append(
            "Rappel: chaque compte 3a doit etre retire en totalite. "
            "Il n'est pas possible de retirer partiellement un compte 3a."
        )

        if economy > 10_000:
            alerts.append(
                "L'economie estimee est significative. Contactez votre banque 3a "
                "pour ouvrir des comptes supplementaires le plus tot possible."
            )

        return alerts
