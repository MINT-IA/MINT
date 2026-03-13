"""
Pillar 3a provider comparator — fintech vs bank vs insurance.

Compares the main 3a provider types using publicly available data
(returns, fees, minimum amounts, engagement periods).

IMPORTANT: This comparator does NOT recommend a specific provider.
It shows the numbers to enable informed decision-making.

Sources:
    - OPP3 (Ordonnance sur le 3e pilier)
    - LIFD art. 33 al. 1 let. e (deduction fiscale 3a)
    - Publicly available fee schedules and performance data (2025/2026)

Sprint S16 — Gap G1: 3a Deep.
"""

from dataclasses import dataclass, field
from typing import List, Optional
from enum import Enum

from app.constants.social_insurance import PILIER_3A_PLAFOND_SANS_LPP


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en placement ni une recommandation de produit au sens de la "
    "LSFin. Les rendements passes ne prejugent pas des rendements futurs. "
    "Les frais et rendements proviennent de donnees publiques (2025/2026). "
    "Consultez un ou une specialiste avant de souscrire."
)


class ProfilRisque(str, Enum):
    """Risk profile for 3a investment."""
    prudent = "prudent"       # ~20% actions
    equilibre = "equilibre"   # ~40-60% actions
    dynamique = "dynamique"   # ~80-100% actions


# ---------------------------------------------------------------------------
# Provider data (publicly available, 2025/2026)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ProviderData:
    """Static data for a 3a provider type."""
    nom: str
    type_provider: str         # "fintech", "banque", "assurance"
    rendement_moyen: dict      # {profil_risque: taux} — historical average
    frais_gestion: float       # Annual management fee (%)
    montant_minimum: float     # Minimum contribution (CHF)
    engagement_annees: Optional[int]  # Minimum engagement (years), None if none
    note: str                  # Short description


PROVIDERS = [
    ProviderData(
        nom="VIAC",
        type_provider="fintech",
        rendement_moyen={
            "prudent": 0.025,
            "equilibre": 0.035,
            "dynamique": 0.045,
        },
        frais_gestion=0.0052,
        montant_minimum=0,
        engagement_annees=None,
        note="App mobile, strategies passives indexees, gestion automatisee",
    ),
    ProviderData(
        nom="Finpension",
        type_provider="fintech",
        rendement_moyen={
            "prudent": 0.030,
            "equilibre": 0.040,
            "dynamique": 0.055,
        },
        frais_gestion=0.0039,
        montant_minimum=0,
        engagement_annees=None,
        note="Frais parmi les plus bas, strategies globales, flexibilite",
    ),
    ProviderData(
        nom="Frankly (ZKB)",
        type_provider="fintech",
        rendement_moyen={
            "prudent": 0.020,
            "equilibre": 0.030,
            "dynamique": 0.040,
        },
        frais_gestion=0.0044,
        montant_minimum=0,
        engagement_annees=None,
        note="Solution digitale de la Zurcher Kantonalbank",
    ),
    ProviderData(
        nom="Banque classique (compte 3a)",
        type_provider="banque",
        rendement_moyen={
            "prudent": 0.015,
            "equilibre": 0.015,
            "dynamique": 0.015,
        },
        frais_gestion=0.0,
        montant_minimum=0,
        engagement_annees=None,
        note="Taux d'interet fixe, pas de risque de marche, rendement limite",
    ),
    ProviderData(
        nom="Assurance 3a (mixte)",
        type_provider="assurance",
        rendement_moyen={
            "prudent": 0.005,
            "equilibre": 0.008,
            "dynamique": 0.010,
        },
        frais_gestion=0.0175,  # Average 1.5-2.0%
        montant_minimum=0,
        engagement_annees=10,
        note=(
            "Combine epargne et couverture risque (deces, invalidite). "
            "Frais eleves, duree d'engagement longue. "
            "Avantage: liberation des primes en cas d'invalidite."
        ),
    ),
]


@dataclass
class ProviderProjection:
    """Projection for a single provider."""
    nom: str
    type_provider: str
    rendement_brut: float       # Gross return for selected risk profile (%)
    frais_gestion: float        # Management fee (%)
    rendement_net: float        # Net return after fees (%)
    capital_final: float        # Projected final capital (CHF)
    total_verse: float          # Total contributions (CHF)
    gain_net: float             # Capital gain (final - total_verse) (CHF)
    engagement_annees: Optional[int]
    note: str
    warning: Optional[str] = None  # Special warning (e.g. for insurance)


@dataclass
class ProviderComparisonResult:
    """Complete comparison of 3a providers."""

    projections: List[ProviderProjection]

    # Best/worst
    meilleur_capital: str        # Name of provider with highest final capital
    pire_capital: str            # Name of provider with lowest final capital
    difference_max: float        # CHF difference between best and worst

    # Input summary
    age: int
    versement_annuel: float
    duree: int
    profil_risque: str

    # Compliance
    chiffre_choc: str
    base_legale: str
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class ProviderComparatorService:
    """Compare 3a providers (fintech, bank, insurance).

    This service does NOT recommend a specific provider.
    It calculates projections based on publicly available data and
    lets the user make an informed decision.

    Sources:
        - OPP3 (conditions 3a)
        - LIFD art. 33 al. 1 let. e (deduction fiscale)
        - Public fee schedules and performance data
    """

    def compare_providers(
        self,
        age: int,
        versement_annuel: float,
        duree: int,
        profil_risque: str = "equilibre",
    ) -> ProviderComparisonResult:
        """Compare all providers for given profile.

        Args:
            age: Current age of the person.
            versement_annuel: Annual 3a contribution (CHF).
            duree: Investment duration in years.
            profil_risque: Risk profile ("prudent", "equilibre", "dynamique").

        Returns:
            ProviderComparisonResult with all projections.
        """
        age = max(18, min(70, age))
        versement_annuel = max(0.0, min(PILIER_3A_PLAFOND_SANS_LPP, versement_annuel))
        duree = max(1, min(50, duree))

        if profil_risque not in ("prudent", "equilibre", "dynamique"):
            profil_risque = "equilibre"

        projections: List[ProviderProjection] = []
        total_verse = round(versement_annuel * duree, 2)

        for provider in PROVIDERS:
            rendement_brut = provider.rendement_moyen.get(profil_risque, 0.015)
            rendement_net = rendement_brut - provider.frais_gestion

            # Compound annual contributions
            capital = 0.0
            for _ in range(duree):
                capital = (capital + versement_annuel) * (1 + rendement_net)
            capital = round(capital, 2)
            gain = round(capital - total_verse, 2)

            # Warning for insurance if young
            warning = None
            if provider.type_provider == "assurance" and age < 35 and duree > 20:
                perte_vs_fintech = round(
                    projections[1].capital_final - capital, 2
                ) if len(projections) > 1 else round(capital * 0.3, 2)
                warning = (
                    f"L'assurance 3a coute environ {perte_vs_fintech:,.0f} CHF de rendement "
                    f"perdu sur {duree} ans par rapport a une solution fintech. "
                    f"Privilegiez une solution bancaire ou fintech sauf si besoin "
                    f"specifique (liberation de primes en cas d'invalidite)."
                ).replace(",", "'")

            projections.append(ProviderProjection(
                nom=provider.nom,
                type_provider=provider.type_provider,
                rendement_brut=round(rendement_brut, 5),
                frais_gestion=round(provider.frais_gestion, 5),
                rendement_net=round(rendement_net, 5),
                capital_final=capital,
                total_verse=total_verse,
                gain_net=gain,
                engagement_annees=provider.engagement_annees,
                note=provider.note,
                warning=warning,
            ))

        # Find best and worst
        projections_sorted = sorted(projections, key=lambda p: p.capital_final, reverse=True)
        meilleur = projections_sorted[0]
        pire = projections_sorted[-1]
        difference = round(meilleur.capital_final - pire.capital_final, 2)

        # Chiffre choc
        chiffre_choc = (
            f"Difference entre meilleur fintech et assurance sur {duree} ans : "
            f"{difference:,.0f} CHF"
        ).replace(",", "'")

        # Sources
        sources = [
            "OPP3 (Ordonnance sur le 3e pilier — conditions)",
            "LIFD art. 33 al. 1 let. e (deduction fiscale 3a)",
            "Donnees publiques de frais et rendements (2025/2026)",
        ]

        base_legale = "OPP3, LIFD art. 33 al. 1 let. e"

        return ProviderComparisonResult(
            projections=projections,
            meilleur_capital=meilleur.nom,
            pire_capital=pire.nom,
            difference_max=difference,
            age=age,
            versement_annuel=versement_annuel,
            duree=duree,
            profil_risque=profil_risque,
            chiffre_choc=chiffre_choc,
            base_legale=base_legale,
            sources=sources,
            disclaimer=DISCLAIMER,
        )
