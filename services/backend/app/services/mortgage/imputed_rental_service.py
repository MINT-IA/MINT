"""
Imputed rental value (Eigenmietwert / valeur locative) calculator.

Swiss homeowners are taxed on the "imputed rental value" of their property
(a fictional income), but can deduct mortgage interest, maintenance costs,
and building insurance premiums.

This service calculates the net fiscal impact of homeownership.

Sources:
    - LIFD art. 21 al. 1 let. b (valeur locative comme revenu)
    - LIFD art. 32 (frais d'entretien deductibles)
    - LIFD art. 33 al. 1 let. a (interets passifs deductibles)
    - Pratique cantonale (taux de valeur locative)

Sprint S17 — Mortgage & Real Estate.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil fiscal au sens de la LSFin. Les taux de valeur locative "
    "varient selon les cantons et les communes. "
    "Consultez un ou une specialiste fiscal·e pour une analyse personnalisee."
)

# Simplified cantonal imputed rental rates (% of market value, educational)
TAUX_VALEUR_LOCATIVE = {
    "ZH": 0.035, "BE": 0.038, "VD": 0.040, "GE": 0.045,
    "LU": 0.033, "AG": 0.036, "SG": 0.034, "BS": 0.042,
    "TI": 0.037, "VS": 0.035, "FR": 0.038, "NE": 0.040,
    "JU": 0.039, "SO": 0.036, "BL": 0.037, "GR": 0.034,
    "TG": 0.033, "SZ": 0.030, "ZG": 0.028, "NW": 0.031,
    "OW": 0.032, "UR": 0.033, "SH": 0.035, "AR": 0.034,
    "AI": 0.032, "GL": 0.033,
}

_DEFAULT_TAUX_VALEUR_LOCATIVE = 0.035

# Maintenance cost flat-rate rules (federal level, cantons may vary)
SEUIL_AGE_BIEN_FORFAIT = 10  # years
FORFAIT_ENTRETIEN_NEUF = 0.10   # 10% if property < 10 years old
FORFAIT_ENTRETIEN_ANCIEN = 0.20  # 20% if property >= 10 years old


@dataclass
class PremierEclairage:
    """Shock figure with amount and explanatory text."""
    montant: float
    texte: str


@dataclass
class ImputedRentalResult:
    """Complete result of the imputed rental value calculation."""

    # Imputed rental value
    valeur_locative: float          # Annual imputed rental value (CHF)
    taux_valeur_locative: float     # Rate used for the canton

    # Deductions
    deduction_interets: float       # Mortgage interest deduction (CHF)
    deduction_entretien: float      # Maintenance deduction (CHF)
    deduction_assurance: float      # Building insurance deduction (CHF)
    deductions_total: float         # Total deductions (CHF)

    # Net fiscal impact
    impact_revenu_imposable: float  # Net addition to taxable income (CHF)
    impact_fiscal_net: float        # Net tax impact (CHF) — positive = costs more
    est_avantage_fiscal: bool       # True if deductions exceed imputed rental value

    # Maintenance cost recommendation
    forfait_entretien_applicable: float   # Applicable flat rate (10% or 20%)
    forfait_entretien_montant: float      # Flat-rate amount (CHF)
    recommandation_forfait_vs_reel: str   # "forfait" or "reel"

    # Shock figure
    premier_eclairage: PremierEclairage

    # Input metadata
    valeur_venale: float
    canton: str
    age_bien_ans: int
    taux_marginal_imposition: float

    # Compliance
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class ImputedRentalService:
    """Calculate the imputed rental value and net fiscal impact.

    Swiss rule: homeowners must declare the "valeur locative"
    (imputed rental value) as income but can deduct:
    - Mortgage interest (LIFD art. 33 al. 1 let. a)
    - Maintenance costs: actual or flat-rate (LIFD art. 32)
    - Building insurance premiums

    Sources:
        - LIFD art. 21 al. 1 let. b (valeur locative)
        - LIFD art. 32 (deduction frais d'entretien)
        - LIFD art. 33 al. 1 let. a (deduction interets passifs)
    """

    def calculate(
        self,
        valeur_venale: float,
        canton: str = "ZH",
        interets_hypothecaires_annuels: float = 0.0,
        frais_entretien_annuels: float = 0.0,
        prime_assurance_batiment: float = 0.0,
        age_bien_ans: int = 5,
        taux_marginal_imposition: float = 0.30,
    ) -> ImputedRentalResult:
        """Calculate the imputed rental value and net fiscal impact.

        Args:
            valeur_venale: Market value of the property (CHF).
            canton: Canton code (determines imputed rental rate).
            interets_hypothecaires_annuels: Annual mortgage interest paid (CHF).
            frais_entretien_annuels: Actual annual maintenance costs (CHF).
            prime_assurance_batiment: Annual building insurance premium (CHF).
            age_bien_ans: Age of the property in years (affects flat-rate deduction).
            taux_marginal_imposition: Marginal tax rate (0-1).

        Returns:
            ImputedRentalResult with complete analysis.
        """
        # Sanitize inputs
        valeur_venale = max(0.0, valeur_venale)
        canton = (canton.upper() if canton else "ZH")[:2]
        interets_hypothecaires_annuels = max(0.0, interets_hypothecaires_annuels)
        frais_entretien_annuels = max(0.0, frais_entretien_annuels)
        prime_assurance_batiment = max(0.0, prime_assurance_batiment)
        age_bien_ans = max(0, age_bien_ans)
        taux_marginal_imposition = max(0.0, min(0.50, taux_marginal_imposition))

        # 1. Imputed rental value
        taux_vl = TAUX_VALEUR_LOCATIVE.get(canton, _DEFAULT_TAUX_VALEUR_LOCATIVE)
        valeur_locative = round(valeur_venale * taux_vl, 2)

        # 2. Flat-rate maintenance deduction
        if age_bien_ans < SEUIL_AGE_BIEN_FORFAIT:
            forfait_pct = FORFAIT_ENTRETIEN_NEUF
        else:
            forfait_pct = FORFAIT_ENTRETIEN_ANCIEN

        forfait_montant = round(valeur_locative * forfait_pct, 2)

        # 3. Recommendation: flat-rate vs actual costs
        if frais_entretien_annuels > forfait_montant:
            recommandation = "reel"
            deduction_entretien = frais_entretien_annuels
        else:
            recommandation = "forfait"
            deduction_entretien = forfait_montant

        # 4. Total deductions
        deduction_interets = round(interets_hypothecaires_annuels, 2)
        deduction_assurance = round(prime_assurance_batiment, 2)
        deductions_total = round(
            deduction_interets + deduction_entretien + deduction_assurance, 2
        )

        # 5. Net impact on taxable income
        impact_revenu_imposable = round(valeur_locative - deductions_total, 2)

        # 6. Net tax impact = impact_revenu_imposable * marginal rate
        impact_fiscal_net = round(impact_revenu_imposable * taux_marginal_imposition, 2)
        est_avantage = impact_revenu_imposable < 0

        # 7. Chiffre choc
        if est_avantage:
            economie = abs(impact_fiscal_net)
            premier_eclairage = PremierEclairage(
                montant=economie,
                texte=(
                    f"Tes deductions depassent ta valeur locative : tu economises "
                    f"environ {economie:,.0f} CHF d'impots par an grace a la propriete."
                ),
            )
        else:
            premier_eclairage = PremierEclairage(
                montant=abs(impact_fiscal_net),
                texte=(
                    f"La valeur locative te coute environ {abs(impact_fiscal_net):,.0f} CHF "
                    f"d'impots supplementaires par an (revenu imposable additionnel "
                    f"de {abs(impact_revenu_imposable):,.0f} CHF)."
                ),
            )

        # 8. Sources
        sources = [
            "LIFD art. 21 al. 1 let. b (valeur locative comme revenu)",
            "LIFD art. 32 (deduction des frais d'entretien immobilier)",
            "LIFD art. 33 al. 1 let. a (deduction des interets passifs)",
            f"Taux valeur locative educatif pour {canton} : {taux_vl * 100:.1f}%",
        ]

        return ImputedRentalResult(
            valeur_locative=valeur_locative,
            taux_valeur_locative=taux_vl,
            deduction_interets=deduction_interets,
            deduction_entretien=round(deduction_entretien, 2),
            deduction_assurance=deduction_assurance,
            deductions_total=deductions_total,
            impact_revenu_imposable=impact_revenu_imposable,
            impact_fiscal_net=impact_fiscal_net,
            est_avantage_fiscal=est_avantage,
            forfait_entretien_applicable=forfait_pct,
            forfait_entretien_montant=forfait_montant,
            recommandation_forfait_vs_reel=recommandation,
            premier_eclairage=premier_eclairage,
            valeur_venale=valeur_venale,
            canton=canton,
            age_bien_ans=age_bien_ans,
            taux_marginal_imposition=taux_marginal_imposition,
            sources=sources,
            disclaimer=DISCLAIMER,
        )
