"""
Service d'estimation de l'impot ecclesiastique — 26 cantons suisses.

L'impot ecclesiastique est un prelevement additionnel calcule en
pourcentage de l'impot cantonal sur le revenu. Il est obligatoire
dans la plupart des cantons pour les membres d'une eglise reconnue
(catholique, protestante, chretienne-catholique).

Dans certains cantons (TI, VD, NE, GE), l'impot ecclesiastique est
volontaire ou deja integre dans l'impot cantonal.

Sources:
    - LHID art. 1 (harmonisation fiscale)
    - Lois fiscales cantonales (impot ecclesiastique)
    - RSM Switzerland — Church tax rates 2024
    - CC art. 303 (liberte religieuse)

Sprint S22+ — Chantier 1: Impot ecclesiastique.
"""

from dataclasses import dataclass
from typing import List


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Full canton names in French
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

# Church tax rates as percentage of cantonal income tax (2024/2026)
# Source: Cantonal tax laws + RSM Switzerland
CHURCH_TAX_RATES = {
    "ZH": 0.10,   # 10% of cantonal tax
    "BE": 0.15,   # 15%
    "LU": 0.10,
    "UR": 0.12,
    "SZ": 0.10,
    "OW": 0.10,
    "NW": 0.10,
    "GL": 0.14,
    "ZG": 0.08,
    "FR": 0.12,
    "SO": 0.12,
    "BS": 0.08,
    "BL": 0.10,
    "SH": 0.12,
    "AR": 0.10,
    "AI": 0.15,
    "SG": 0.12,
    "GR": 0.14,
    "AG": 0.10,
    "TG": 0.12,
    "TI": 0.00,   # No church tax (voluntary)
    "VD": 0.00,   # Covered by cantonal taxes
    "VS": 0.10,
    "NE": 0.00,   # No church tax (voluntary)
    "GE": 0.00,   # No church tax (voluntary)
    "JU": 0.10,
}

# Cantons where church tax is NOT mandatory
NO_MANDATORY_CHURCH_TAX = {"TI", "VD", "NE", "GE"}

DISCLAIMER = (
    "L'impot ecclesiastique est calcule en pourcentage de l'impot "
    "cantonal sur le revenu. Le taux exact depend de la commune, "
    "de la confession et du canton. "
    "Outil educatif — ne constitue pas un conseil fiscal (LSFin). "
    "Consulte ton administration fiscale cantonale ou un ou une "
    "specialiste fiscal-e."
)

SOURCES = [
    "LHID art. 1 (harmonisation fiscale)",
    "Lois fiscales cantonales (impot ecclesiastique)",
    "RSM Switzerland — Church tax rates 2024",
    "CC art. 303 (liberte religieuse)",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class ChurchTaxEstimate:
    """Estimated church tax for a given cantonal tax in a specific canton."""
    canton: str
    canton_name: str
    is_mandatory: bool
    church_tax_rate: float  # as percentage of cantonal tax (0.10 = 10%)
    impot_cantonal_base: float  # cantonal tax used as base
    impot_eglise: float     # absolute amount
    chiffre_choc: str
    disclaimer: str
    sources: List[str]


# ---------------------------------------------------------------------------
# Service class
# ---------------------------------------------------------------------------

class ChurchTaxService:
    """Estimate church tax across 26 Swiss cantons."""

    def estimate_church_tax(
        self,
        cantonal_tax: float,
        canton: str,
    ) -> ChurchTaxEstimate:
        """Estimate church tax for a given cantonal tax in a canton.

        Args:
            cantonal_tax: Cantonal income tax amount (CHF). Must be >= 0.
            canton: Canton code (2 letters, e.g. "ZH", "GE").

        Returns:
            ChurchTaxEstimate with tax breakdown and compliance fields.

        Raises:
            ValueError: If canton code is invalid or cantonal_tax is negative.
        """
        canton = canton.upper()
        self._validate_canton(canton)

        if cantonal_tax < 0:
            raise ValueError(
                "L'impot cantonal ne peut pas etre negatif. "
                "Indique une valeur >= 0 CHF."
            )

        is_mandatory = canton not in NO_MANDATORY_CHURCH_TAX
        rate = CHURCH_TAX_RATES[canton]
        impot_eglise = round(cantonal_tax * rate, 2)
        canton_name = CANTON_NAMES.get(canton, canton)

        # Build chiffre choc
        if not is_mandatory:
            chiffre_choc = (
                f"Dans le canton de {canton_name}, l'impot ecclesiastique "
                f"est volontaire ou integre dans l'impot cantonal. "
                f"Tu ne paies pas de supplement obligatoire."
            )
        elif impot_eglise > 0:
            chiffre_choc = (
                f"En tant que membre d'une eglise reconnue dans le canton "
                f"de {canton_name}, tu paies environ {impot_eglise:,.0f} CHF/an "
                f"d'impot ecclesiastique ({rate * 100:.0f}% de l'impot cantonal). "
                f"En sortant de l'eglise, tu economiserais cette somme."
            )
        else:
            chiffre_choc = (
                "Avec un impot cantonal de 0 CHF, l'impot ecclesiastique "
                "est egalement de 0 CHF."
            )

        return ChurchTaxEstimate(
            canton=canton,
            canton_name=canton_name,
            is_mandatory=is_mandatory,
            church_tax_rate=rate,
            impot_cantonal_base=cantonal_tax,
            impot_eglise=impot_eglise,
            chiffre_choc=chiffre_choc,
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    def is_church_tax_mandatory(self, canton: str) -> bool:
        """Check if church tax is mandatory in a canton.

        Args:
            canton: Canton code (2 letters).

        Returns:
            True if church tax is mandatory.

        Raises:
            ValueError: If canton code is invalid.
        """
        canton = canton.upper()
        self._validate_canton(canton)
        return canton not in NO_MANDATORY_CHURCH_TAX

    def compare_church_tax_all_cantons(
        self,
        cantonal_tax: float,
    ) -> List[ChurchTaxEstimate]:
        """Estimate church tax for all 26 cantons.

        Args:
            cantonal_tax: Cantonal income tax amount (CHF).

        Returns:
            List of ChurchTaxEstimate sorted by impot_eglise descending.
        """
        estimates = []
        for canton in CHURCH_TAX_RATES:
            estimate = self.estimate_church_tax(cantonal_tax, canton)
            estimates.append(estimate)

        # Sort by church tax descending (most expensive first for awareness)
        estimates.sort(key=lambda e: e.impot_eglise, reverse=True)
        return estimates

    # -------------------------------------------------------------------
    # Private helpers
    # -------------------------------------------------------------------

    def _validate_canton(self, canton: str) -> None:
        """Validate canton code."""
        if canton not in CHURCH_TAX_RATES:
            raise ValueError(
                f"Canton inconnu: '{canton}'. "
                f"Codes valides: {', '.join(sorted(CHURCH_TAX_RATES.keys()))}"
            )


# ---------------------------------------------------------------------------
# Convenience functions (functional style)
# ---------------------------------------------------------------------------

def estimer_impot_eglise(
    cantonal_tax: float,
    canton: str,
) -> dict:
    """Convenience wrapper around ChurchTaxService.estimate_church_tax()."""
    service = ChurchTaxService()
    estimate = service.estimate_church_tax(cantonal_tax, canton)
    return {
        "canton": estimate.canton,
        "canton_name": estimate.canton_name,
        "is_mandatory": estimate.is_mandatory,
        "church_tax_rate": estimate.church_tax_rate,
        "impot_cantonal_base": estimate.impot_cantonal_base,
        "impot_eglise": estimate.impot_eglise,
        "chiffre_choc": estimate.chiffre_choc,
        "disclaimer": estimate.disclaimer,
        "sources": estimate.sources,
    }
