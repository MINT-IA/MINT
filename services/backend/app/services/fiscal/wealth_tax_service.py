"""
Service d'estimation de l'impot sur la fortune — 26 cantons suisses.

Estime la charge d'impot sur la fortune nette pour un contribuable
dans chacun des 26 cantons, en se basant sur les taux effectifs
simplifies publies par l'OFS (Charge Fiscale 2024).

Approche:
    1. Taux effectif de base par canton a CHF 500'000 (celibataire, chef-lieu)
    2. Ajustement par niveau de fortune (interpolation lineaire)
    3. Ajustement pour couples maries (exemption doublee, taux reduit)
    4. Seuils d'exoneration cantonaux

Sources:
    - LHID art. 14 (impot sur la fortune)
    - OFS — Charge fiscale en Suisse 2024
    - Lois fiscales cantonales
    - CC art. 196 ss (regime matrimonial)

Sprint S22+ — Chantier 1: Impot sur la fortune.
"""

from dataclasses import dataclass, field
from typing import List, Optional


# ---------------------------------------------------------------------------
# Constants — Taux effectifs fortune 2024/2026 (simplifies)
# ---------------------------------------------------------------------------

# Full canton names in French (reuse pattern from cantonal_comparator)
CANTON_NAMES = {
    "ZH": "Zurich",
    "BE": "Berne",
    "LU": "Lucerne",
    "UR": "Uri",
    "SZ": "Schwyz",
    "OW": "Obwald",
    "NW": "Nidwald",
    "GL": "Glaris",
    "ZG": "Zoug",
    "FR": "Fribourg",
    "SO": "Soleure",
    "BS": "Bale-Ville",
    "BL": "Bale-Campagne",
    "SH": "Schaffhouse",
    "AR": "Appenzell RE",
    "AI": "Appenzell RI",
    "SG": "Saint-Gall",
    "GR": "Grisons",
    "AG": "Argovie",
    "TG": "Thurgovie",
    "TI": "Tessin",
    "VD": "Vaud",
    "VS": "Valais",
    "NE": "Neuchatel",
    "GE": "Geneve",
    "JU": "Jura",
}

# Effective wealth tax rates (per mille of net wealth)
# At CHF 500'000, single, chef-lieu — Source: OFS Charge Fiscale 2024
# Lower = cheaper canton for wealth tax
EFFECTIVE_WEALTH_TAX_RATES_500K = {
    "NW": 0.75,   # per mille — Nidwald (lowest)
    "OW": 0.90,
    "AI": 1.00,
    "ZG": 1.10,
    "SZ": 1.20,
    "AR": 1.30,
    "UR": 1.40,
    "GL": 1.60,
    "LU": 1.70,
    "TG": 1.80,
    "SH": 1.90,
    "AG": 2.00,
    "GR": 2.10,
    "BL": 2.20,
    "SG": 2.30,
    "ZH": 2.50,
    "FR": 2.80,
    "SO": 2.90,
    "TI": 3.00,
    "BE": 3.40,
    "VS": 3.60,
    "NE": 3.80,
    "VD": 4.10,
    "JU": 4.30,
    "GE": 4.50,
    "BS": 5.10,   # Bale-Ville (highest)
}

# Wealth tax exemption thresholds by canton (fortune below this = 0 tax)
WEALTH_TAX_EXEMPTIONS = {
    "ZH": 77000,   # Per person
    "BE": 97000,
    "LU": 0,       # No exemption (progressive from 0)
    "UR": 0,
    "SZ": 50000,
    "OW": 0,
    "NW": 35000,
    "GL": 50000,
    "ZG": 0,
    "FR": 56000,
    "SO": 55000,
    "BS": 100000,
    "BL": 75000,
    "SH": 50000,
    "AR": 50000,
    "AI": 50000,
    "SG": 75000,
    "GR": 0,
    "AG": 56000,
    "TG": 50000,
    "TI": 0,
    "VD": 58000,
    "VS": 30000,
    "NE": 50000,
    "GE": 82040,   # Per adult
    "JU": 50000,
}

# Wealth level adjustment factors (relative to 500k base)
WEALTH_ADJUSTMENT = {
    100000: 0.60,    # Lower wealth -> proportionally lower effective rate
    200000: 0.75,
    500000: 1.00,    # Reference
    1000000: 1.15,
    2000000: 1.25,
    5000000: 1.35,
}

# Married couple adjustment factor (splitting effect on wealth tax)
MARRIED_RATE_FACTOR = 0.90

DISCLAIMER = (
    "Estimations basees sur les taux effectifs simplifies 2024-2026. "
    "L'impot sur la fortune varie selon la commune, les deductions, "
    "et la composition exacte du patrimoine. "
    "Outil educatif — ne constitue pas un conseil fiscal (LSFin). "
    "Consulte ton administration fiscale cantonale ou un ou une "
    "specialiste fiscal-e pour un calcul precis."
)

SOURCES = [
    "LHID art. 14 (impot sur la fortune)",
    "OFS — Charge fiscale en Suisse 2024",
    "Lois fiscales cantonales",
    "CC art. 196 ss (regime matrimonial — fortune des epoux)",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class WealthTaxEstimate:
    """Estimated wealth tax for a given fortune in a specific canton."""
    canton: str
    canton_name: str
    fortune_nette: float
    fortune_imposable: float  # After exemption
    impot_fortune: float
    taux_effectif_permille: float  # per mille
    disclaimer: str
    sources: List[str]
    chiffre_choc: str


@dataclass
class WealthTaxRanking:
    """A single canton entry in the ranked comparison by wealth tax."""
    rang: int
    canton: str
    canton_name: str
    impot_fortune: float
    taux_effectif_permille: float
    difference_vs_cheapest: float


@dataclass
class WealthTaxMoveSimulation:
    """Result of simulating a wealth tax move between two cantons."""
    canton_depart: str
    canton_depart_nom: str
    canton_arrivee: str
    canton_arrivee_nom: str
    impot_depart: float
    impot_arrivee: float
    economie_annuelle: float
    economie_mensuelle: float
    economie_10_ans: float
    chiffre_choc: str
    alertes: List[str]
    disclaimer: str
    sources: List[str]


# ---------------------------------------------------------------------------
# Service class
# ---------------------------------------------------------------------------

class WealthTaxService:
    """Estimate and compare wealth tax across 26 Swiss cantons."""

    def estimate_wealth_tax(
        self,
        fortune: float,
        canton: str,
        civil_status: str = "celibataire",
    ) -> WealthTaxEstimate:
        """Estimate wealth tax for a given fortune in a canton.

        Args:
            fortune: Net wealth (CHF). Must be >= 0.
            canton: Canton code (2 letters, e.g. "ZH", "GE").
            civil_status: "celibataire" or "marie".

        Returns:
            WealthTaxEstimate with tax breakdown and compliance fields.

        Raises:
            ValueError: If canton code is invalid or fortune is negative.
        """
        canton = canton.upper()
        self._validate_canton(canton)
        self._validate_fortune(fortune)

        # Zero fortune = zero tax
        if fortune == 0:
            return WealthTaxEstimate(
                canton=canton,
                canton_name=CANTON_NAMES.get(canton, canton),
                fortune_nette=0.0,
                fortune_imposable=0.0,
                impot_fortune=0.0,
                taux_effectif_permille=0.0,
                disclaimer=DISCLAIMER,
                sources=list(SOURCES),
                chiffre_choc="Avec une fortune nette de 0 CHF, tu ne paies pas d'impot sur la fortune.",
            )

        # 1. Determine exemption threshold
        exemption = WEALTH_TAX_EXEMPTIONS[canton]

        # For married: double the exemption
        if civil_status == "marie":
            exemption = exemption * 2

        # 2. Calculate fortune imposable
        fortune_imposable = max(0.0, fortune - exemption)

        # If fortune is below exemption, no tax
        if fortune_imposable <= 0:
            canton_name = CANTON_NAMES.get(canton, canton)
            return WealthTaxEstimate(
                canton=canton,
                canton_name=canton_name,
                fortune_nette=fortune,
                fortune_imposable=0.0,
                impot_fortune=0.0,
                taux_effectif_permille=0.0,
                disclaimer=DISCLAIMER,
                sources=list(SOURCES),
                chiffre_choc=(
                    f"Ta fortune de {fortune:,.0f} CHF est en dessous du seuil "
                    f"d'exoneration de {exemption:,.0f} CHF dans le canton "
                    f"de {canton_name}. Tu ne paies pas d'impot sur la fortune."
                ),
            )

        # 3. Base rate for canton at 500k
        base_rate_permille = EFFECTIVE_WEALTH_TAX_RATES_500K[canton]

        # 4. Adjust for wealth level
        wealth_factor = self._interpolate_wealth_adjustment(fortune)

        # 5. Adjust for married status
        if civil_status == "marie":
            effective_rate = base_rate_permille * wealth_factor * MARRIED_RATE_FACTOR
        else:
            effective_rate = base_rate_permille * wealth_factor

        # 6. Calculate tax (rate is per mille, apply to fortune_imposable)
        impot_fortune = round(fortune_imposable * effective_rate / 1000, 2)

        # 7. Actual effective rate (per mille of total fortune, not just imposable)
        taux_effectif = round((impot_fortune / fortune) * 1000, 4) if fortune > 0 else 0.0

        # 8. Build chiffre choc
        canton_name = CANTON_NAMES.get(canton, canton)
        chiffre_choc = (
            f"Sur une fortune de {fortune:,.0f} CHF dans le canton de "
            f"{canton_name}, l'impot sur la fortune est d'environ "
            f"{impot_fortune:,.0f} CHF/an, soit {impot_fortune / 12:,.0f} CHF/mois."
        )

        return WealthTaxEstimate(
            canton=canton,
            canton_name=canton_name,
            fortune_nette=fortune,
            fortune_imposable=round(fortune_imposable, 2),
            impot_fortune=impot_fortune,
            taux_effectif_permille=taux_effectif,
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
            chiffre_choc=chiffre_choc,
        )

    def compare_all_cantons(
        self,
        fortune: float,
        civil_status: str = "celibataire",
    ) -> List[WealthTaxRanking]:
        """Rank all 26 cantons from cheapest to most expensive for wealth tax.

        Args:
            fortune: Net wealth (CHF). Must be >= 0.
            civil_status: "celibataire" or "marie".

        Returns:
            List of WealthTaxRanking sorted by impot_fortune ascending.
        """
        self._validate_fortune(fortune)

        estimates = []
        for canton in EFFECTIVE_WEALTH_TAX_RATES_500K:
            estimate = self.estimate_wealth_tax(fortune, canton, civil_status)
            estimates.append(estimate)

        # Sort by tax ascending
        estimates.sort(key=lambda e: e.impot_fortune)

        # Build ranked list
        cheapest = estimates[0].impot_fortune if estimates else 0
        rankings = []
        for i, est in enumerate(estimates):
            rankings.append(WealthTaxRanking(
                rang=i + 1,
                canton=est.canton,
                canton_name=est.canton_name,
                impot_fortune=est.impot_fortune,
                taux_effectif_permille=est.taux_effectif_permille,
                difference_vs_cheapest=round(est.impot_fortune - cheapest, 2),
            ))

        return rankings

    def simulate_move_wealth(
        self,
        fortune: float,
        canton_from: str,
        canton_to: str,
        civil_status: str = "celibataire",
    ) -> WealthTaxMoveSimulation:
        """Simulate wealth tax savings from moving between cantons.

        Args:
            fortune: Net wealth (CHF).
            canton_from: Current canton code.
            canton_to: Target canton code.
            civil_status: "celibataire" or "marie".

        Returns:
            WealthTaxMoveSimulation with annual/monthly/10-year savings.
        """
        tax_from = self.estimate_wealth_tax(fortune, canton_from, civil_status)
        tax_to = self.estimate_wealth_tax(fortune, canton_to, civil_status)

        economie_annuelle = round(tax_from.impot_fortune - tax_to.impot_fortune, 2)
        economie_mensuelle = round(economie_annuelle / 12, 2)
        economie_10_ans = round(economie_annuelle * 10, 2)

        # Build chiffre choc
        if economie_annuelle > 0:
            chiffre_choc = (
                f"En demenageant de {tax_from.canton_name} a {tax_to.canton_name}, "
                f"tu pourrais economiser environ {abs(economie_annuelle):,.0f} CHF/an "
                f"d'impot sur la fortune, soit {abs(economie_10_ans):,.0f} CHF sur 10 ans."
            )
        elif economie_annuelle < 0:
            chiffre_choc = (
                f"Attention: demenager de {tax_from.canton_name} a {tax_to.canton_name} "
                f"te couterait environ {abs(economie_annuelle):,.0f} CHF/an de plus "
                f"en impot sur la fortune, soit {abs(economie_10_ans):,.0f} CHF sur 10 ans."
            )
        else:
            chiffre_choc = (
                f"L'impot sur la fortune est quasi identique entre "
                f"{tax_from.canton_name} et {tax_to.canton_name}."
            )

        # Build alerts
        alertes = self._build_move_alerts(
            tax_from.canton_name, tax_to.canton_name, economie_annuelle, fortune
        )

        return WealthTaxMoveSimulation(
            canton_depart=tax_from.canton,
            canton_depart_nom=tax_from.canton_name,
            canton_arrivee=tax_to.canton,
            canton_arrivee_nom=tax_to.canton_name,
            impot_depart=tax_from.impot_fortune,
            impot_arrivee=tax_to.impot_fortune,
            economie_annuelle=economie_annuelle,
            economie_mensuelle=economie_mensuelle,
            economie_10_ans=economie_10_ans,
            chiffre_choc=chiffre_choc,
            alertes=alertes,
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    # -------------------------------------------------------------------
    # Private helpers
    # -------------------------------------------------------------------

    def _validate_canton(self, canton: str) -> None:
        """Validate canton code."""
        if canton not in EFFECTIVE_WEALTH_TAX_RATES_500K:
            raise ValueError(
                f"Canton inconnu: '{canton}'. "
                f"Codes valides: {', '.join(sorted(EFFECTIVE_WEALTH_TAX_RATES_500K.keys()))}"
            )

    def _validate_fortune(self, fortune: float) -> None:
        """Validate fortune amount."""
        if fortune < 0:
            raise ValueError(
                "La fortune nette ne peut pas etre negative. "
                "Indique une valeur >= 0 CHF."
            )

    def _interpolate_wealth_adjustment(self, fortune: float) -> float:
        """Linear interpolation between wealth brackets.

        Returns an adjustment factor relative to the 500k base rate.
        For fortunes below 100k or above 5M, clamps to the boundary value.
        """
        sorted_brackets = sorted(WEALTH_ADJUSTMENT.items())

        # Below minimum bracket
        if fortune <= sorted_brackets[0][0]:
            return sorted_brackets[0][1]

        # Above maximum bracket
        if fortune >= sorted_brackets[-1][0]:
            return sorted_brackets[-1][1]

        # Find surrounding brackets and interpolate
        for i in range(len(sorted_brackets) - 1):
            lower_fortune, lower_factor = sorted_brackets[i]
            upper_fortune, upper_factor = sorted_brackets[i + 1]

            if lower_fortune <= fortune <= upper_fortune:
                ratio = (fortune - lower_fortune) / (upper_fortune - lower_fortune)
                return lower_factor + ratio * (upper_factor - lower_factor)

        # Fallback (should never reach here)
        return 1.0

    def _build_move_alerts(
        self,
        canton_from_name: str,
        canton_to_name: str,
        economie: float,
        fortune: float,
    ) -> List[str]:
        """Build alerts for a wealth tax move simulation."""
        alertes = []

        alertes.append(
            "L'impot sur la fortune ne represente qu'une partie de la charge "
            "fiscale totale. Pense aussi a l'impot sur le revenu et aux "
            "primes LAMal."
        )

        if fortune > 1_000_000:
            alertes.append(
                "Avec une fortune superieure a 1 million CHF, certains cantons "
                "appliquent un bouclier fiscal (Steuerbremse) qui plafonne "
                "la charge totale (revenu + fortune)."
            )

        if abs(economie) < fortune * 0.001:
            alertes.append(
                "L'ecart d'impot sur la fortune est faible. D'autres facteurs "
                "(qualite de vie, marche immobilier, ecoles) sont probablement "
                "plus determinants."
            )

        alertes.append(
            "Le demenagement doit etre effectif (residence principale) pour que "
            "le changement de domicile fiscal soit reconnu."
        )

        return alertes


# ---------------------------------------------------------------------------
# Convenience functions (functional style)
# ---------------------------------------------------------------------------

def estimer_impot_fortune(
    fortune: float,
    canton: str,
    civil_status: str = "celibataire",
) -> dict:
    """Convenience wrapper around WealthTaxService.estimate_wealth_tax()."""
    service = WealthTaxService()
    estimate = service.estimate_wealth_tax(fortune, canton, civil_status)
    return {
        "canton": estimate.canton,
        "canton_name": estimate.canton_name,
        "fortune_nette": estimate.fortune_nette,
        "fortune_imposable": estimate.fortune_imposable,
        "impot_fortune": estimate.impot_fortune,
        "taux_effectif_permille": estimate.taux_effectif_permille,
        "chiffre_choc": estimate.chiffre_choc,
        "disclaimer": estimate.disclaimer,
        "sources": estimate.sources,
    }


def comparer_fortune_cantons(
    fortune: float,
    civil_status: str = "celibataire",
) -> dict:
    """Convenience wrapper around WealthTaxService.compare_all_cantons()."""
    service = WealthTaxService()
    rankings = service.compare_all_cantons(fortune, civil_status)
    return {
        "classement": [
            {
                "rang": r.rang,
                "canton": r.canton,
                "canton_name": r.canton_name,
                "impot_fortune": r.impot_fortune,
                "taux_effectif_permille": r.taux_effectif_permille,
                "difference_vs_cheapest": r.difference_vs_cheapest,
            }
            for r in rankings
        ],
        "ecart_max": rankings[-1].difference_vs_cheapest if rankings else 0,
    }
