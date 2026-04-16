"""
Gender Gap Prevoyance Service.

Calculates the LPP pension gap due to part-time work and provides
factual analysis with actionable recommendations. Based on OFS 2024
statistics and Swiss pension law.

Sources:
    - LPP art. 8 (deduction de coordination: 26'460 CHF)
    - LPP art. 14 (taux de conversion: 6.8% part obligatoire)
    - LPP art. 16 (taux de cotisation par age)
    - LPP art. 79b (rachat volontaire)
    - OPP3 art. 7 (plafond 3a)
    - OFS 2024 (statistiques ecart de rente)

Ethical requirements:
    - Gender-neutral language throughout
    - NEVER use "garanti", "assure" (sens de garantie), "certain"
    - Factual, non-judgmental analysis based on OFS statistics
    - All recommendations include a source reference
    - Mandatory disclaimer on every response
"""

from dataclasses import dataclass
from typing import List

from app.constants.social_insurance import (
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MAX as _LPP_SALAIRE_COORDONNE_MAX,
    LPP_TAUX_CONVERSION_MIN,
    LPP_SEUIL_ENTREE,
    PILIER_3A_PLAFOND_AVEC_LPP,
    AVS_AGE_REFERENCE_HOMME,
)


# ---------------------------------------------------------------------------
# Constants — from app.constants.social_insurance (centralized source of truth)
# ---------------------------------------------------------------------------

# LPP art. 8: coordination deduction
COORDINATION_DEDUCTION = LPP_DEDUCTION_COORDINATION

# LPP: maximum coordinated salary = seuil superieur - deduction
SALAIRE_COORDONNE_MAX = _LPP_SALAIRE_COORDONNE_MAX

# LPP art. 14: conversion rate for mandatory part (centralized value is in %, convert to fraction)
CONVERSION_RATE = LPP_TAUX_CONVERSION_MIN / 100  # 6.8% -> 0.068

# LPP art. 16: contribution rates by age band (employee + employer combined)
LPP_CONTRIBUTION_RATES = {
    (25, 34): 0.07,
    (35, 44): 0.10,
    (45, 54): 0.15,
    (55, 64): 0.18,
}

# Retirement age (AVS/AHV)
RETIREMENT_AGE = AVS_AGE_REFERENCE_HOMME

# Minimum LPP entry threshold
SEUIL_ENTREE_LPP = LPP_SEUIL_ENTREE

# 3a plafond for salaried workers (OPP3 art. 7)
PLAFOND_3A_SALARIE = PILIER_3A_PLAFOND_AVEC_LPP

# Projected annual return on LPP capital (conservative estimate)
PROJECTED_RETURN = 0.015

# OFS 2024 statistic
OFS_GENDER_GAP_STAT = (
    "En Suisse, les femmes touchent en moyenne 37% de rente de moins "
    "que les hommes (OFS 2024)."
)


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class GenderGapInput:
    """Input data for gender gap pension analysis."""
    taux_activite: float       # 0-100 (percentage of full-time)
    age: int
    revenu_annuel: float       # Gross annual salary at current activity rate
    salaire_coordonne: float   # Coordinated salary (from LPP certificate)
    avoir_lpp: float           # Current LPP capital
    annees_cotisation: int     # Years already contributed to LPP
    canton: str                # Canton code (2 letters)


@dataclass
class GenderGapResult:
    """Result of gender gap pension analysis."""
    lacune_annuelle_chf: float
    lacune_cumulee_chf: float
    rente_estimee_plein_temps: float
    rente_estimee_actuelle: float
    impact_coordination: float
    recommandations: List[dict]
    statistiques: List[str]
    alerts: List[str]
    disclaimer: str


# ---------------------------------------------------------------------------
# Disclaimer
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Outil educatif — ne constitue pas un conseil (LSFin). "
    "Cette analyse est indicative et basee sur des hypotheses simplifiees. "
    "Les montants reels dependent de votre caisse de pension, du taux "
    "d'interet crediteur et de votre situation individuelle. "
    "Consultez un·e spécialiste en prevoyance pour une analyse personnalisee."
)


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class GenderGapService:
    """Analyse l'ecart de prevoyance lie au temps partiel.

    Calculs bases sur la LPP (prevoyance professionnelle) et les
    statistiques OFS 2024. Langage neutre, aucun terme banni.
    """

    def _get_contribution_rate(self, age: int) -> float:
        """Get LPP contribution rate for a given age (LPP art. 16)."""
        for (age_min, age_max), rate in LPP_CONTRIBUTION_RATES.items():
            if age_min <= age <= age_max:
                return rate
        # Default: if outside known ranges, use 0
        return 0.0

    def _compute_salaire_coordonne(
        self,
        revenu_annuel: float,
        taux_activite: float,
        proratise: bool = False,
    ) -> float:
        """Compute the coordinated salary (salaire coordonne).

        LPP art. 8: salaire coordonne = max(salary - coordination_deduction, 0)
        capped at SALAIRE_COORDONNE_MAX.

        The coordination deduction is often NOT prorated for part-time workers,
        which disproportionately impacts their insured salary.

        Args:
            revenu_annuel: Annual gross salary (at current activity rate).
            taux_activite: Activity rate (0-100).
            proratise: If True, prorate coordination deduction by activity rate.
        """
        if proratise and taux_activite > 0:
            deduction = COORDINATION_DEDUCTION * (taux_activite / 100.0)
        else:
            deduction = COORDINATION_DEDUCTION

        coordonne = max(revenu_annuel - deduction, 0.0)
        coordonne = min(coordonne, SALAIRE_COORDONNE_MAX)
        return round(coordonne, 2)

    def _project_lpp_capital(
        self,
        current_capital: float,
        salaire_coordonne: float,
        contribution_rate: float,
        years_remaining: int,
        annual_return: float = PROJECTED_RETURN,
    ) -> float:
        """Project LPP capital at retirement.

        Compounds existing capital + annual contributions over remaining years.
        """
        capital = current_capital
        annual_contribution = salaire_coordonne * contribution_rate

        for _ in range(years_remaining):
            capital = capital * (1 + annual_return) + annual_contribution

        return round(capital, 2)

    def _estimate_annual_rente(self, capital: float) -> float:
        """Estimate annual pension from LPP capital (LPP art. 14).

        Conversion rate: 6.8% for mandatory part.
        """
        return round(capital * CONVERSION_RATE, 2)

    def analyze(self, input_data: GenderGapInput) -> GenderGapResult:
        """Run gender gap pension analysis.

        Compares projected pension at current activity rate vs full-time (100%).

        Args:
            input_data: GenderGapInput with user's situation.

        Returns:
            GenderGapResult with gap analysis, recommendations, and statistics.
        """
        taux = input_data.taux_activite
        age = input_data.age
        years_remaining = max(0, RETIREMENT_AGE - age)

        # Current contribution rate
        contribution_rate = self._get_contribution_rate(age)

        # --- Scenario: current activity rate (coordination NOT prorated) ---
        salaire_coord_actuel = self._compute_salaire_coordonne(
            input_data.revenu_annuel, taux, proratise=False
        )
        capital_actuel = self._project_lpp_capital(
            input_data.avoir_lpp,
            salaire_coord_actuel,
            contribution_rate,
            years_remaining,
        )
        rente_actuelle = self._estimate_annual_rente(capital_actuel)

        # --- Scenario: full-time (100%) ---
        # Extrapolate salary to 100%
        if taux > 0:
            revenu_100 = input_data.revenu_annuel * (100.0 / taux)
        else:
            revenu_100 = 0.0

        salaire_coord_100 = self._compute_salaire_coordonne(
            revenu_100, 100.0, proratise=False
        )
        # For full-time projection, start from same current capital
        capital_100 = self._project_lpp_capital(
            input_data.avoir_lpp,
            salaire_coord_100,
            contribution_rate,
            years_remaining,
        )
        rente_100 = self._estimate_annual_rente(capital_100)

        # --- Gap analysis ---
        lacune_annuelle = round(rente_100 - rente_actuelle, 2)
        lacune_cumulee = round(lacune_annuelle * 20, 2)  # ~20 years of retirement

        # --- Coordination impact ---
        # Show how much the non-prorated deduction costs
        salaire_coord_proratise = self._compute_salaire_coordonne(
            input_data.revenu_annuel, taux, proratise=True
        )
        impact_coordination = round(
            salaire_coord_proratise - salaire_coord_actuel, 2
        )

        # --- Alerts ---
        alerts: List[str] = []

        if taux < 100 and impact_coordination > 0:
            alerts.append(
                f"La deduction de coordination (CHF {COORDINATION_DEDUCTION:,.0f}) "
                f"n'est pas proratisee dans votre cas. Si elle l'etait, votre "
                f"salaire coordonne augmenterait de CHF {impact_coordination:,.0f}."
            )

        if lacune_annuelle > 5000:
            alerts.append(
                f"Votre ecart de rente estime est de CHF {lacune_annuelle:,.0f}/an "
                f"par rapport a un plein temps. Sur 20 ans de retraite, cela "
                f"represente environ CHF {lacune_cumulee:,.0f}."
            )

        if taux > 0 and taux < 50:
            alerts.append(
                "Un taux d'activite inferieur a 50% peut entrainer un salaire "
                "coordonne tres faible, voire nul, en raison de la deduction de "
                "coordination non proratisee."
            )

        if input_data.revenu_annuel < SEUIL_ENTREE_LPP and taux < 100:
            alerts.append(
                f"Attention: votre revenu annuel est inferieur au seuil "
                f"d'entree LPP (CHF {SEUIL_ENTREE_LPP:,.0f}). "
                f"Vous pourriez ne pas etre affilie a la prevoyance "
                f"professionnelle obligatoire."
            )

        # --- Recommendations ---
        recommandations: List[dict] = []

        if lacune_annuelle > 0:
            recommandations.append({
                "id": "rachat_lpp",
                "titre": "Rachat LPP volontaire",
                "description": (
                    "Un rachat volontaire dans votre caisse de pension permet "
                    "de combler une partie de la lacune de prevoyance. "
                    "Le montant est integralement deductible du revenu imposable."
                ),
                "source": "LPP art. 79b",
                "priorite": "haute",
            })

        recommandations.append({
            "id": "maximiser_3a",
            "titre": "Maximiser le 3e pilier",
            "description": (
                f"Versez le maximum annuel dans votre 3e pilier "
                f"(CHF {PLAFOND_3A_SALARIE:,.0f} pour les salaries). "
                f"Cela compense partiellement la lacune LPP et offre "
                f"un avantage fiscal."
            ),
            "source": "OPP3 art. 7, LIFD art. 33",
            "priorite": "haute",
        })

        if taux < 100 and impact_coordination > 0:
            recommandations.append({
                "id": "verifier_proratisation",
                "titre": "Verifier la proratisation de la coordination",
                "description": (
                    "Demandez a votre employeur si la deduction de coordination "
                    "est proratisee selon votre taux d'activite. Plusieurs "
                    "caisses de pension le font volontairement, ce qui ameliore "
                    "significativement votre salaire coordonne."
                ),
                "source": "LPP art. 8",
                "priorite": "moyenne",
            })

        if years_remaining > 10:
            recommandations.append({
                "id": "augmenter_taux",
                "titre": "Evaluer une augmentation du taux d'activite",
                "description": (
                    "Meme une augmentation de 10-20% du taux d'activite "
                    "peut avoir un impact significatif sur la rente LPP future, "
                    "en particulier si la deduction de coordination n'est pas "
                    "proratisee."
                ),
                "source": "LPP art. 8, art. 16",
                "priorite": "basse",
            })

        # --- Statistics ---
        statistiques: List[str] = [
            OFS_GENDER_GAP_STAT,
            (
                f"A un taux d'activite de {taux:.0f}%, votre salaire coordonne "
                f"est de CHF {salaire_coord_actuel:,.0f} "
                f"(vs CHF {salaire_coord_100:,.0f} a 100%)."
            ),
            (
                f"Taux de cotisation LPP actuel ({age} ans): "
                f"{contribution_rate * 100:.0f}% du salaire coordonne "
                f"(LPP art. 16)."
            ),
        ]

        return GenderGapResult(
            lacune_annuelle_chf=lacune_annuelle,
            lacune_cumulee_chf=lacune_cumulee,
            rente_estimee_plein_temps=rente_100,
            rente_estimee_actuelle=rente_actuelle,
            impact_coordination=impact_coordination,
            recommandations=recommandations,
            statistiques=statistiques,
            alerts=alerts,
            disclaimer=DISCLAIMER,
        )
