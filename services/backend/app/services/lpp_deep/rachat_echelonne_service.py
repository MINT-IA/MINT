"""
Rachat LPP echelonne (stepped buyback) simulator.

Calculates the optimal spreading of voluntary pension fund buybacks over N years
to maximize tax savings. The core insight: buying back in one year wastes tax
potential because the marginal tax rate decreases less with a single large deduction
than with several smaller deductions spread across years.

Sources:
    - LPP art. 79b (voluntary buyback conditions)
    - LPP art. 79b al. 3 (no EPL withdrawal within 3 years after buyback)
    - LIFD art. 33 al. 1 let. d (tax deduction for buybacks)
    - OPP2 art. 60a (buyback conditions and restrictions)

Sprint S15 — Chantier 4: LPP approfondi.
"""

from dataclasses import dataclass, field
from typing import List, Optional


DISCLAIMER = (
    "MINT est un outil educatif. Ce service ne constitue pas un conseil "
    "en prevoyance au sens de la LSFin. Les economies fiscales estimees dependent "
    "de votre situation personnelle. Consultez un ou une specialiste en prevoyance "
    "et fiscalite pour une analyse personnalisee."
)


# ---------------------------------------------------------------------------
# Simplified marginal tax rates by canton (federal + cantonal + communal)
# These are approximations for educational purposes.
# ---------------------------------------------------------------------------

TAUX_MARGINAUX_PAR_CANTON = {
    "ZH": {100000: 0.28, 150000: 0.33, 200000: 0.36, 300000: 0.39},
    "BE": {100000: 0.30, 150000: 0.35, 200000: 0.38, 300000: 0.41},
    "VD": {100000: 0.32, 150000: 0.37, 200000: 0.40, 300000: 0.42},
    "GE": {100000: 0.33, 150000: 0.38, 200000: 0.41, 300000: 0.44},
    "LU": {100000: 0.24, 150000: 0.28, 200000: 0.31, 300000: 0.34},
    "AG": {100000: 0.27, 150000: 0.32, 200000: 0.35, 300000: 0.38},
    "SG": {100000: 0.28, 150000: 0.33, 200000: 0.36, 300000: 0.39},
    "BS": {100000: 0.30, 150000: 0.35, 200000: 0.38, 300000: 0.40},
    "TI": {100000: 0.29, 150000: 0.34, 200000: 0.37, 300000: 0.40},
    "VS": {100000: 0.26, 150000: 0.31, 200000: 0.34, 300000: 0.37},
    "FR": {100000: 0.30, 150000: 0.35, 200000: 0.38, 300000: 0.41},
    "NE": {100000: 0.32, 150000: 0.37, 200000: 0.40, 300000: 0.43},
    "JU": {100000: 0.32, 150000: 0.37, 200000: 0.40, 300000: 0.43},
    "SO": {100000: 0.28, 150000: 0.33, 200000: 0.36, 300000: 0.39},
    "BL": {100000: 0.28, 150000: 0.33, 200000: 0.36, 300000: 0.39},
    "GR": {100000: 0.27, 150000: 0.32, 200000: 0.35, 300000: 0.38},
    "TG": {100000: 0.26, 150000: 0.31, 200000: 0.34, 300000: 0.37},
    "SZ": {100000: 0.20, 150000: 0.24, 200000: 0.27, 300000: 0.30},
    "ZG": {100000: 0.18, 150000: 0.22, 200000: 0.25, 300000: 0.28},
    "NW": {100000: 0.20, 150000: 0.24, 200000: 0.27, 300000: 0.30},
    "OW": {100000: 0.21, 150000: 0.25, 200000: 0.28, 300000: 0.31},
    "UR": {100000: 0.22, 150000: 0.26, 200000: 0.29, 300000: 0.32},
    "SH": {100000: 0.27, 150000: 0.32, 200000: 0.35, 300000: 0.38},
    "AR": {100000: 0.26, 150000: 0.31, 200000: 0.34, 300000: 0.37},
    "AI": {100000: 0.22, 150000: 0.26, 200000: 0.29, 300000: 0.32},
    "GL": {100000: 0.26, 150000: 0.31, 200000: 0.34, 300000: 0.37},
}

# Default for unknown cantons
_DEFAULT_RATES = {100000: 0.28, 150000: 0.33, 200000: 0.36, 300000: 0.39}


@dataclass
class RachatAnnuelEntry:
    """A single year's buyback entry in the stepped plan."""
    annee: int                    # Year number (1-based)
    montant_rachat: float         # Buyback amount for this year (CHF)
    revenu_imposable_avant: float # Taxable income before buyback
    revenu_imposable_apres: float # Taxable income after buyback deduction
    taux_marginal_avant: float    # Marginal tax rate before buyback
    taux_marginal_apres: float    # Marginal tax rate after buyback
    economie_fiscale: float       # Tax savings for this year (CHF)
    cout_net: float               # Net cost (buyback - tax savings)


@dataclass
class RachatEchelonneResult:
    """Complete result of a stepped buyback simulation."""

    # Stepped plan
    plan: List[RachatAnnuelEntry]
    horizon_annees: int
    total_rachat: float
    total_economie_fiscale: float
    total_cout_net: float

    # Bloc comparison (all in year 1)
    bloc_economie_fiscale: float
    bloc_cout_net: float

    # Delta: how much more you save by spreading
    economie_vs_bloc: float
    economie_vs_bloc_pct: float

    # Metadata
    canton: str
    blocage_epl_fin: int          # Year number when EPL withdrawal becomes possible again

    # Alerts & compliance
    alerts: List[str] = field(default_factory=list)
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class RachatEchelonneService:
    """Simulate stepped LPP buyback to maximize tax savings.

    The core insight: Swiss progressive taxation means spreading a large
    buyback over multiple years generates higher total tax savings because
    each year's deduction hits a higher marginal rate.

    Example:
        A 50'000 CHF buyback on a 150'000 CHF income:
        - Bloc (1 year): 50'000 x 33% = 16'500 CHF saved
        - Echelonne (5 years): 5 x 10'000 x 33% = 16'500 CHF
          BUT the marginal rate stays at 33% for each 10'000 slice
          instead of dropping to ~28% for the bottom slice of 50'000.

    Sources:
        - LPP art. 79b (rachat volontaire)
        - LPP art. 79b al. 3 (blocage EPL 3 ans apres rachat)
        - LIFD art. 33 al. 1 let. d (deduction fiscale du rachat)
        - OPP2 art. 60a (conditions de rachat)
    """

    EPL_BLOCAGE_ANNEES = 3  # LPP art. 79b al. 3

    def simulate(
        self,
        avoir_actuel: float,
        rachat_max: float,
        revenu_imposable: float,
        taux_marginal_estime: Optional[float],
        canton: str,
        horizon_rachat_annees: int = 3,
    ) -> RachatEchelonneResult:
        """Simulate stepped buyback over N years.

        Args:
            avoir_actuel: Current LPP savings (CHF).
            rachat_max: Maximum buyback amount (from LPP certificate) (CHF).
            revenu_imposable: Annual taxable income (CHF).
            taux_marginal_estime: Estimated marginal tax rate (0-1). If None, derived from canton.
            canton: Canton code (e.g. "VD", "ZH", "GE").
            horizon_rachat_annees: Number of years to spread the buyback (1-5).

        Returns:
            RachatEchelonneResult with the stepped plan and comparison.
        """
        # Validate inputs
        horizon_rachat_annees = max(1, min(5, horizon_rachat_annees))
        rachat_max = max(0.0, rachat_max)
        revenu_imposable = max(0.0, revenu_imposable)

        canton_upper = canton.upper() if canton else "ZH"

        # Calculate yearly buyback amount (equal split)
        rachat_annuel = round(rachat_max / horizon_rachat_annees, 2) if horizon_rachat_annees > 0 else 0.0

        # Build stepped plan
        plan: List[RachatAnnuelEntry] = []
        total_economie = 0.0

        for year in range(1, horizon_rachat_annees + 1):
            # For the last year, use the remainder to avoid rounding issues
            if year == horizon_rachat_annees:
                montant = rachat_max - sum(e.montant_rachat for e in plan)
            else:
                montant = rachat_annuel

            montant = round(montant, 2)

            revenu_avant = revenu_imposable
            revenu_apres = revenu_imposable - montant

            taux_avant = self._get_marginal_rate(
                revenu_avant, canton_upper, taux_marginal_estime
            )
            taux_apres = self._get_marginal_rate(
                revenu_apres, canton_upper, None  # Always compute from table after deduction
            )

            # Tax savings: use the average marginal rate across the deduction range
            taux_effectif = (taux_avant + taux_apres) / 2
            economie = round(montant * taux_effectif, 2)
            cout_net = round(montant - economie, 2)

            plan.append(RachatAnnuelEntry(
                annee=year,
                montant_rachat=montant,
                revenu_imposable_avant=round(revenu_avant, 2),
                revenu_imposable_apres=round(revenu_apres, 2),
                taux_marginal_avant=round(taux_avant, 4),
                taux_marginal_apres=round(taux_apres, 4),
                economie_fiscale=economie,
                cout_net=cout_net,
            ))

            total_economie += economie

        total_economie = round(total_economie, 2)
        total_cout_net = round(rachat_max - total_economie, 2)

        # Bloc comparison: entire amount in year 1
        bloc_taux_avant = self._get_marginal_rate(
            revenu_imposable, canton_upper, taux_marginal_estime
        )
        bloc_revenu_apres = revenu_imposable - rachat_max
        bloc_taux_apres = self._get_marginal_rate(
            bloc_revenu_apres, canton_upper, None
        )
        bloc_taux_effectif = (bloc_taux_avant + bloc_taux_apres) / 2
        bloc_economie = round(rachat_max * bloc_taux_effectif, 2)
        bloc_cout_net = round(rachat_max - bloc_economie, 2)

        # Delta
        economie_vs_bloc = round(total_economie - bloc_economie, 2)
        economie_vs_bloc_pct = (
            round((economie_vs_bloc / bloc_economie) * 100, 2)
            if bloc_economie > 0
            else 0.0
        )

        # EPL blocage
        blocage_epl_fin = horizon_rachat_annees + self.EPL_BLOCAGE_ANNEES

        # Alerts
        alerts = self._generate_alerts(
            rachat_max, revenu_imposable, horizon_rachat_annees, canton_upper
        )

        # Sources
        sources = [
            "LPP art. 79b (rachat volontaire)",
            "LPP art. 79b al. 3 (blocage EPL 3 ans apres rachat)",
            "LIFD art. 33 al. 1 let. d (deduction fiscale du rachat)",
            "OPP2 art. 60a (conditions de rachat)",
        ]

        return RachatEchelonneResult(
            plan=plan,
            horizon_annees=horizon_rachat_annees,
            total_rachat=rachat_max,
            total_economie_fiscale=total_economie,
            total_cout_net=total_cout_net,
            bloc_economie_fiscale=bloc_economie,
            bloc_cout_net=bloc_cout_net,
            economie_vs_bloc=economie_vs_bloc,
            economie_vs_bloc_pct=economie_vs_bloc_pct,
            canton=canton_upper,
            blocage_epl_fin=blocage_epl_fin,
            alerts=alerts,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _get_marginal_rate(
        self,
        revenu: float,
        canton: str,
        override: Optional[float] = None,
    ) -> float:
        """Get the marginal tax rate for a given income and canton.

        If an override is provided, use it directly. Otherwise, look up
        the canton's rate table (simplified for educational purposes).

        Args:
            revenu: Taxable income (CHF).
            canton: Canton code (uppercase).
            override: If provided, use this rate directly (0-1).

        Returns:
            Marginal tax rate as a float (0-1).
        """
        if override is not None:
            return max(0.0, min(1.0, override))

        rates = TAUX_MARGINAUX_PAR_CANTON.get(canton, _DEFAULT_RATES)

        # Find the appropriate bracket
        applicable_rate = 0.15  # Base rate for low incomes
        for threshold, rate in sorted(rates.items()):
            if revenu >= threshold:
                applicable_rate = rate
            else:
                break

        return applicable_rate

    def _generate_alerts(
        self,
        rachat_max: float,
        revenu_imposable: float,
        horizon: int,
        canton: str,
    ) -> List[str]:
        """Generate relevant alerts for the buyback plan.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        # EPL blocage alert
        blocage_fin = horizon + self.EPL_BLOCAGE_ANNEES
        alerts.append(
            f"Blocage EPL: apres le dernier rachat (annee {horizon}), "
            f"aucun retrait EPL n'est possible pendant 3 ans, "
            f"soit jusqu'a l'annee {blocage_fin} (LPP art. 79b al. 3)."
        )

        # Large buyback relative to income
        if rachat_max > revenu_imposable * 0.5:
            alerts.append(
                "Le montant de rachat represente plus de 50% du revenu imposable. "
                "L'echelonnement est particulierement recommande dans ce cas."
            )

        # Very short horizon
        if horizon == 1:
            alerts.append(
                "Un rachat en bloc (1 an) ne profite pas de l'effet d'echelonnement. "
                "Envisagez un horizon de 3 a 5 ans pour optimiser l'economie fiscale."
            )

        # Canton-specific note
        if canton in ("GE", "VD", "NE", "JU", "BS"):
            alerts.append(
                f"Canton {canton}: taux marginaux eleves — l'echelonnement "
                f"a un impact fiscal proportionnellement plus important."
            )

        # 3a interaction reminder
        alerts.append(
            "Rappel: combinez le rachat LPP avec vos versements 3a pour maximiser "
            "la deduction fiscale totale (LIFD art. 33 al. 1 let. d et e)."
        )

        return alerts
