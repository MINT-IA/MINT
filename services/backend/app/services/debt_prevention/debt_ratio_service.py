"""
Debt ratio calculator — surendettement risk assessment.

Calculates the debt-to-income ratio and classifies the risk level.
Also computes the minimum vital insaisissable (LP art. 93) to determine
how much of the income is legally protected from seizure.

Sources:
    - LP art. 93 (minimum vital insaisissable)
    - SchKG (Loi sur la poursuite et faillite)
    - Conference des preposes aux poursuites et faillites: directives

Sprint S16 — Gap G6: Prevention dette.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un avis juridique. Les montants du minimum vital sont des estimations "
    "basees sur les directives de la Conference des preposes. Consultez un ou "
    "une specialiste en desendettement pour une analyse personnalisee."
)


# Minimum vital insaisissable (LP art. 93)
# Based on the guidelines of the Conference des preposes aux poursuites
# These are simplified base amounts for educational purposes
MINIMUM_VITAL = {
    "celibataire": 1_200,    # Single person base
    "couple": 1_750,         # Couple base
    "supplement_enfant": 400,  # Per child supplement
}


@dataclass
class DebtRatioResult:
    """Complete result of debt ratio assessment."""

    # Ratio
    ratio_endettement: float       # Debt-to-income ratio (0-1)
    ratio_pct: float               # Same as percentage (0-100)
    niveau_risque: str             # "vert" (<15%), "orange" (15-30%), "rouge" (>30%)

    # Income breakdown
    revenus_mensuels: float
    charges_dette_mensuelles: float
    loyer: float
    autres_charges_fixes: float
    total_charges_fixes: float     # All fixed charges combined
    disponible_mensuel: float      # Income minus all fixed charges

    # Minimum vital
    minimum_vital: float           # LP art. 93 minimum vital
    marge_vs_minimum_vital: float  # disponible - minimum_vital
    en_dessous_minimum_vital: bool

    # Compliance
    chiffre_choc: str
    recommandations: List[str] = field(default_factory=list)
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class DebtRatioService:
    """Calculate debt-to-income ratio and assess overindebtedness risk.

    Thresholds (industry standard):
    - < 15%: Green — healthy debt level
    - 15-30%: Orange — attention needed, consider reduction plan
    - > 30%: Red — critical, professional help recommended

    Sources:
        - LP art. 93 (minimum vital insaisissable)
        - Conference des preposes: directives pour le calcul du minimum vital
    """

    SEUIL_VERT = 0.15
    SEUIL_ORANGE = 0.30

    def calculate_debt_ratio(
        self,
        revenus_mensuels: float,
        charges_dette_mensuelles: float,
        loyer: float,
        autres_charges_fixes: float,
        situation_familiale: str = "celibataire",
        nb_enfants: int = 0,
    ) -> DebtRatioResult:
        """Calculate the debt-to-income ratio.

        Args:
            revenus_mensuels: Monthly net income (CHF).
            charges_dette_mensuelles: Monthly debt payments (credits, leasing) (CHF).
            loyer: Monthly rent (CHF).
            autres_charges_fixes: Other fixed monthly charges (insurance, etc.) (CHF).
            situation_familiale: "celibataire" or "couple".
            nb_enfants: Number of dependent children.

        Returns:
            DebtRatioResult with ratio, risk level, and recommendations.
        """
        revenus_mensuels = max(0.0, revenus_mensuels)
        charges_dette_mensuelles = max(0.0, charges_dette_mensuelles)
        loyer = max(0.0, loyer)
        autres_charges_fixes = max(0.0, autres_charges_fixes)
        nb_enfants = max(0, nb_enfants)

        # 1. Debt ratio = debt charges (credits + leasing) / net income
        if revenus_mensuels > 0:
            ratio = charges_dette_mensuelles / revenus_mensuels
        else:
            ratio = 1.0 if charges_dette_mensuelles > 0 else 0.0

        ratio = round(ratio, 4)
        ratio_pct = round(ratio * 100, 1)

        # 2. Risk level
        if ratio < self.SEUIL_VERT:
            niveau = "vert"
        elif ratio < self.SEUIL_ORANGE:
            niveau = "orange"
        else:
            niveau = "rouge"

        # 3. Fixed charges total
        total_charges = round(charges_dette_mensuelles + loyer + autres_charges_fixes, 2)
        disponible = round(revenus_mensuels - total_charges, 2)

        # 4. Minimum vital (LP art. 93)
        base_key = situation_familiale if situation_familiale in MINIMUM_VITAL else "celibataire"
        minimum_vital = MINIMUM_VITAL[base_key]
        minimum_vital += MINIMUM_VITAL["supplement_enfant"] * nb_enfants
        # Add rent to minimum vital (standard practice)
        minimum_vital_total = minimum_vital + loyer

        marge = round(revenus_mensuels - total_charges - minimum_vital, 2)
        en_dessous = disponible < minimum_vital

        # 5. Recommendations
        recommandations = self._generate_recommendations(
            ratio, niveau, disponible, minimum_vital_total,
            revenus_mensuels, charges_dette_mensuelles, en_dessous,
        )

        # 6. Chiffre choc
        chiffre_choc = (
            f"Ton ratio d'endettement est de {ratio_pct}% "
            f"— seuil recommande : 30%"
        )

        # 7. Sources
        sources = [
            "LP art. 93 (minimum vital insaisissable)",
            "SchKG (Loi sur la poursuite et faillite)",
            "Conference des preposes: directives minimum vital",
        ]

        return DebtRatioResult(
            ratio_endettement=ratio,
            ratio_pct=ratio_pct,
            niveau_risque=niveau,
            revenus_mensuels=revenus_mensuels,
            charges_dette_mensuelles=charges_dette_mensuelles,
            loyer=loyer,
            autres_charges_fixes=autres_charges_fixes,
            total_charges_fixes=total_charges,
            disponible_mensuel=disponible,
            minimum_vital=float(minimum_vital_total),
            marge_vs_minimum_vital=marge,
            en_dessous_minimum_vital=en_dessous,
            chiffre_choc=chiffre_choc,
            recommandations=recommandations,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _generate_recommendations(
        self,
        ratio: float,
        niveau: str,
        disponible: float,
        minimum_vital: float,
        revenus: float,
        charges_dette: float,
        en_dessous: bool,
    ) -> List[str]:
        """Generate recommendations based on the debt ratio.

        Returns:
            List of recommendation strings in French.
        """
        recs: List[str] = []

        if niveau == "vert":
            recs.append(
                "Votre ratio d'endettement est dans la zone saine. "
                "Continuez a eviter les credits a la consommation inutiles."
            )
            if charges_dette > 0:
                recs.append(
                    "Envisagez de rembourser vos dettes plus rapidement "
                    "pour atteindre un ratio de 0%."
                )

        elif niveau == "orange":
            recs.append(
                "Votre ratio d'endettement est dans la zone d'attention. "
                "Evitez tout nouvel emprunt et elaborez un plan de remboursement."
            )
            recs.append(
                "Utilisez le planificateur de remboursement MINT pour "
                "comparer les strategies avalanche et boule de neige."
            )

        else:  # rouge
            recs.append(
                "Votre ratio d'endettement depasse 30% — seuil critique. "
                "Consultez un service de conseil en desendettement."
            )
            recs.append(
                "Contactez Dettes Conseils Suisse (dettes.ch) ou Caritas "
                "pour un accompagnement professionnel et confidentiel."
            )
            recs.append(
                "Priorite absolue : ne contractez aucun nouvel emprunt. "
                "Renegociez les taux existants si possible."
            )

        if en_dessous:
            recs.append(
                "ATTENTION : vos charges depassent le minimum vital insaisissable "
                "(LP art. 93). Vous avez droit a une protection legale. "
                "Contactez immediatement un service de conseil en desendettement."
            )

        return recs
