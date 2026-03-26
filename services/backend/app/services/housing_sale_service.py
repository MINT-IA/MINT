"""
Housing Sale Service — Vente immobiliere.

Simulates the financial outcome of selling a property in Switzerland,
including capital gains tax (impot sur les gains immobiliers), EPL repayment
obligations, mortgage payoff, and reinvestment deferral (remploi).

Sources:
    - LIFD art. 12 (impot sur les gains immobiliers au niveau federal)
    - Lois cantonales sur l'impot sur les gains immobiliers
    - OPP2 art. 30d (remboursement EPL LPP lors de la vente)
    - LPP art. 30d (obligation de remboursement de l'EPL)
    - CO art. 216 ss (contrat de vente immobiliere)
    - CC art. 655 (registre foncier, transfert de propriete)
    - LIFD art. 12 al. 3 (remploi: report de l'impot)

Ethical requirements:
    - Gender-neutral: no assumptions based on gender
    - Educational tone, never prescriptive
    - No banned terms: garanti, certain, assure, sans risque, optimal, meilleur, parfait
"""

from dataclasses import dataclass
from typing import List, Dict, Tuple


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

DISCLAIMER: str = (
    "Cet outil educatif fournit une estimation indicative et ne constitue "
    "pas un conseil financier, fiscal ou juridique au sens de la LSFin. "
    "Les taux d'imposition sur les gains immobiliers varient selon le canton, "
    "la commune et la situation personnelle. Consulte un·e specialiste "
    "(notaire, fiduciaire) pour ta situation concrete."
)

SOURCES: List[str] = [
    "LIFD art. 12 (impot sur les gains immobiliers)",
    "LIFD art. 12 al. 3 (remploi / report de l'impot)",
    "OPP2 art. 30d (remboursement EPL LPP)",
    "LPP art. 30d (obligation de rembourser l'EPL)",
    "CO art. 216 ss (contrat de vente immobiliere)",
    "CC art. 655 (transfert de propriete au registre foncier)",
    "Lois cantonales sur l'impot sur les gains immobiliers",
]

# Capital gains tax rates by canton and duration of ownership (years).
# Each entry is (min_years, max_years_exclusive, rate).
# The rate is degressive: longer ownership = lower tax rate.
TAUX_PLUS_VALUE_IMMOBILIERE: Dict[str, List[Tuple[int, int, float]]] = {
    "ZH": [
        (0, 2, 0.50), (2, 5, 0.40), (5, 10, 0.30),
        (10, 15, 0.20), (15, 20, 0.15), (20, 999, 0.0),
    ],
    "BE": [
        (0, 1, 0.45), (1, 4, 0.35), (4, 10, 0.25),
        (10, 15, 0.18), (15, 25, 0.10), (25, 999, 0.0),
    ],
    "VD": [
        (0, 1, 0.30), (1, 5, 0.25), (5, 10, 0.20),
        (10, 25, 0.15), (25, 999, 0.07),
    ],
    "GE": [
        (0, 2, 0.50), (2, 4, 0.40), (4, 6, 0.30),
        (6, 8, 0.25), (8, 10, 0.20), (10, 25, 0.10),
        (25, 999, 0.0),
    ],
    "LU": [
        (0, 1, 0.36), (1, 2, 0.33), (2, 5, 0.27),
        (5, 10, 0.21), (10, 15, 0.15), (15, 20, 0.09),
        (20, 999, 0.0),
    ],
    "BS": [
        (0, 5, 0.32), (5, 10, 0.25), (10, 15, 0.20),
        (15, 20, 0.15), (20, 999, 0.10),
    ],
}

# Default average rates for cantons not explicitly listed
TAUX_PLUS_VALUE_DEFAULT: List[Tuple[int, int, float]] = [
    (0, 2, 0.40), (2, 5, 0.30), (5, 10, 0.22),
    (10, 15, 0.16), (15, 25, 0.10), (25, 999, 0.05),
]


# ══════════════════════════════════════════════════════════════════════════════
# Data classes
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class HousingSaleInput:
    """Input data for housing sale simulation."""
    prix_achat: float                                 # Purchase price
    prix_vente: float                                 # Sale price
    annee_achat: int                                  # Year of purchase
    annee_vente: int = 2025                           # Year of sale
    investissements_valorisants: float = 0.0          # Value-adding renovations
    frais_acquisition: float = 0.0                    # Notary fees at purchase (typically 3-5%)
    canton: str = "GE"                                # Canton code
    residence_principale: bool = True                 # Primary residence?
    epl_lpp_utilise: float = 0.0                      # LPP EPL used for purchase
    epl_3a_utilise: float = 0.0                       # 3a EPL used for purchase
    hypotheque_restante: float = 0.0                  # Remaining mortgage balance
    projet_remploi: bool = False                      # Plans to buy new property within 2 years?
    prix_remploi: float = 0.0                         # Price of replacement property


@dataclass
class HousingSaleResult:
    """Result of housing sale simulation."""
    plus_value_brute: float                           # prix_vente - prix_achat
    plus_value_imposable: float                       # After deductions
    duree_detention: int                              # Years of ownership
    taux_imposition_plus_value: float                 # Tax rate (degressive)
    impot_plus_value: float                           # Tax amount on capital gain
    remploi_report: float                             # Tax deferred if reinvesting
    impot_effectif: float                             # Actual tax due (after remploi)
    remboursement_epl_lpp: float                      # EPL LPP to repay
    remboursement_epl_3a: float                       # EPL 3a to repay
    solde_hypotheque: float                           # Mortgage payoff
    produit_net: float                                # Net proceeds
    checklist: List[str]                              # Action items
    alerts: List[str]                                 # Warning messages
    disclaimer: str                                   # Legal disclaimer
    sources: List[str]                                # Legal references
    chiffre_choc: dict                                # Impact number


# ══════════════════════════════════════════════════════════════════════════════
# Service
# ══════════════════════════════════════════════════════════════════════════════

class HousingSaleService:
    """Simulate the financial outcome of selling a property in Switzerland.

    Covers:
    - Capital gains tax (impot sur les gains immobiliers), degressive by duration
    - Remploi (reinvestment deferral, LIFD art. 12 al. 3)
    - EPL repayment obligation (OPP2 art. 30d / LPP art. 30d)
    - Mortgage payoff
    - Net proceeds calculation

    Compliance: NEVER use "garanti", "assure", "certain", "sans risque".
    """

    def calculate(self, input_data: HousingSaleInput) -> HousingSaleResult:
        """Run the full housing sale simulation.

        Args:
            input_data: HousingSaleInput with property and financial data.

        Returns:
            HousingSaleResult with tax, EPL, mortgage, and net proceeds.
        """
        # Duration of ownership
        duree_detention = self._compute_duree_detention(input_data)

        # Capital gain
        plus_value_brute = self._compute_plus_value_brute(input_data)
        plus_value_imposable = self._compute_plus_value_imposable(input_data)

        # Tax rate and amount
        taux = self._get_tax_rate(input_data.canton, duree_detention)
        impot_plus_value = self._compute_impot_plus_value(
            plus_value_imposable, taux
        )

        # Remploi (reinvestment deferral)
        remploi_report = self._compute_remploi(input_data, impot_plus_value)
        impot_effectif = round(impot_plus_value - remploi_report, 2)

        # EPL repayment (only for primary residence — LPP art. 30d, OPP2 art. 30e)
        remboursement_epl_lpp = input_data.epl_lpp_utilise if input_data.residence_principale else 0.0
        remboursement_epl_3a = input_data.epl_3a_utilise if input_data.residence_principale else 0.0

        # Mortgage payoff
        solde_hypotheque = input_data.hypotheque_restante

        # Net proceeds
        produit_net = self._compute_produit_net(
            input_data.prix_vente,
            impot_effectif,
            remboursement_epl_lpp,
            remboursement_epl_3a,
            solde_hypotheque,
        )

        # Compliance outputs
        checklist = self._generate_checklist(input_data)
        alerts = self._generate_alerts(
            input_data, plus_value_imposable, duree_detention,
            produit_net, remboursement_epl_lpp + remboursement_epl_3a,
        )
        chiffre_choc = self._generate_chiffre_choc(
            produit_net, impot_effectif, input_data.prix_vente,
        )

        return HousingSaleResult(
            plus_value_brute=round(plus_value_brute, 2),
            plus_value_imposable=round(plus_value_imposable, 2),
            duree_detention=duree_detention,
            taux_imposition_plus_value=taux,
            impot_plus_value=round(impot_plus_value, 2),
            remploi_report=round(remploi_report, 2),
            impot_effectif=impot_effectif,
            remboursement_epl_lpp=round(remboursement_epl_lpp, 2),
            remboursement_epl_3a=round(remboursement_epl_3a, 2),
            solde_hypotheque=round(solde_hypotheque, 2),
            produit_net=round(produit_net, 2),
            checklist=checklist,
            alerts=alerts,
            disclaimer=DISCLAIMER,
            sources=SOURCES,
            chiffre_choc=chiffre_choc,
        )

    # ------------------------------------------------------------------
    # Private computation methods
    # ------------------------------------------------------------------

    def _compute_duree_detention(self, data: HousingSaleInput) -> int:
        """Compute duration of ownership in years.

        Returns:
            Number of years (minimum 0).
        """
        return max(0, data.annee_vente - data.annee_achat)

    def _compute_plus_value_brute(self, data: HousingSaleInput) -> float:
        """Compute gross capital gain.

        plus_value_brute = prix_vente - prix_achat

        Returns:
            Gross capital gain (can be negative = loss).
        """
        return data.prix_vente - data.prix_achat

    def _compute_plus_value_imposable(self, data: HousingSaleInput) -> float:
        """Compute taxable capital gain after deductions.

        plus_value_imposable = prix_vente - prix_achat
                             - investissements_valorisants
                             - frais_acquisition

        Minimum is 0 (no tax on losses).

        Returns:
            Taxable capital gain (>= 0).
        """
        pv = (
            data.prix_vente
            - data.prix_achat
            - data.investissements_valorisants
            - data.frais_acquisition
        )
        return max(0.0, pv)

    def _get_tax_rate(self, canton: str, duree_detention: int) -> float:
        """Get the capital gains tax rate for a given canton and duration.

        The rate is degressive: the longer you hold the property,
        the lower the tax rate. Each canton has its own schedule.

        Args:
            canton: Canton code (e.g. "GE", "VD", "ZH").
            duree_detention: Years of ownership.

        Returns:
            Tax rate as decimal (e.g. 0.30 for 30%).
        """
        brackets = TAUX_PLUS_VALUE_IMMOBILIERE.get(
            canton, TAUX_PLUS_VALUE_DEFAULT
        )
        for min_years, max_years, rate in brackets:
            if min_years <= duree_detention < max_years:
                return rate
        # Fallback (should not happen with 999 upper bound)
        return 0.0

    def _compute_impot_plus_value(
        self, plus_value_imposable: float, taux: float
    ) -> float:
        """Compute capital gains tax amount.

        impot = plus_value_imposable * taux

        Returns:
            Tax amount (>= 0).
        """
        if plus_value_imposable <= 0:
            return 0.0
        return round(plus_value_imposable * taux, 2)

    def _compute_remploi(
        self, data: HousingSaleInput, impot_plus_value: float
    ) -> float:
        """Compute reinvestment deferral (remploi).

        LIFD art. 12 al. 3: If the seller buys a replacement property
        in Switzerland within 2 years, the capital gains tax can be
        deferred (fully or partially).

        - Full deferral if prix_remploi >= prix_vente
        - Partial deferral: report = impot * (prix_remploi / prix_vente)

        Args:
            data: HousingSaleInput with remploi data.
            impot_plus_value: Computed capital gains tax.

        Returns:
            Amount of tax deferred (0 if no remploi).
        """
        if not data.projet_remploi or data.prix_remploi <= 0:
            return 0.0

        if impot_plus_value <= 0:
            return 0.0

        if data.prix_remploi >= data.prix_vente:
            # Full deferral
            return impot_plus_value
        else:
            # Partial deferral proportional to reinvestment
            ratio = data.prix_remploi / data.prix_vente
            return round(impot_plus_value * ratio, 2)

    def _compute_produit_net(
        self,
        prix_vente: float,
        impot_effectif: float,
        remboursement_epl_lpp: float,
        remboursement_epl_3a: float,
        solde_hypotheque: float,
    ) -> float:
        """Compute net proceeds from the sale.

        produit_net = prix_vente - hypotheque - impot - EPL_LPP - EPL_3a

        Returns:
            Net proceeds (can be negative).
        """
        return round(
            prix_vente
            - solde_hypotheque
            - impot_effectif
            - remboursement_epl_lpp
            - remboursement_epl_3a,
            2,
        )

    # ------------------------------------------------------------------
    # Compliance outputs
    # ------------------------------------------------------------------

    def _generate_checklist(self, data: HousingSaleInput) -> List[str]:
        """Generate action checklist for housing sale.

        Returns:
            List of actionable items in French (tu/toi).
        """
        checklist = [
            "Demande une estimation immobiliere professionnelle avant de fixer le prix",
            "Contacte ton notaire pour les frais de transfert",
            "Previens ta banque pour le remboursement hypothecaire",
        ]

        if data.epl_lpp_utilise > 0 or data.epl_3a_utilise > 0:
            checklist.append(
                "Le remboursement de l'EPL LPP/3a est requis sur le produit de la vente "
                "(OPP2 art. 30d)"
            )
            checklist.append(
                "Verifie le montant exact de ton EPL aupres de ta caisse de pension"
            )

        if data.projet_remploi:
            checklist.append(
                "Si tu prevois un remploi, commence les recherches avant la vente"
            )
            checklist.append(
                "Le remploi doit etre effectue dans un delai de 2 ans "
                "pour beneficier du report d'impot (LIFD art. 12 al. 3)"
            )

        checklist.append(
            "Fais verifier par ta fiduciaire les deductions possibles "
            "(investissements valorisants, frais de courtage, etc.)"
        )
        checklist.append(
            "Prevois la declaration de la plus-value dans ta prochaine "
            "declaration d'impot"
        )

        return checklist

    def _generate_alerts(
        self,
        data: HousingSaleInput,
        plus_value_imposable: float,
        duree_detention: int,
        produit_net: float,
        epl_total: float,
    ) -> List[str]:
        """Generate warning alerts.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        if plus_value_imposable > 100_000:
            alerts.append(
                "Plus-value elevee : envisage le remploi pour reporter l'impot"
            )

        if duree_detention < 5:
            alerts.append(
                "Duree de detention courte : taux d'imposition majore"
            )

        if produit_net < 0:
            alerts.append(
                "ATTENTION : le produit net est negatif"
            )

        if epl_total > 0:
            alerts.append(
                f"Remboursement EPL obligatoire : {epl_total:,.0f} CHF"
            )

        if data.projet_remploi and data.prix_remploi > 0 and data.prix_remploi < data.prix_vente:
            alerts.append(
                "Le remploi est partiel (prix de remploi inferieur au prix de vente) : "
                "le report d'impot sera proportionnel"
            )

        return alerts

    def _generate_chiffre_choc(
        self,
        produit_net: float,
        impot_effectif: float,
        prix_vente: float,
    ) -> dict:
        """Generate the impact number (chiffre choc).

        Returns:
            dict with montant and texte.
        """
        if prix_vente > 0 and impot_effectif > 0:
            pct = round(impot_effectif / prix_vente * 100, 1)
            return {
                "montant": round(produit_net, 2),
                "texte": (
                    f"Produit net de la vente : {produit_net:,.0f} CHF "
                    f"(apres {impot_effectif:,.0f} CHF d'impot sur la plus-value, "
                    f"soit {pct}% du prix de vente)"
                ),
            }
        return {
            "montant": round(produit_net, 2),
            "texte": (
                f"Produit net de la vente : {produit_net:,.0f} CHF"
            ),
        }
