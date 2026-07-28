"""
Housing Sale Service — Vente immobiliere.

Simulates the financial outcome of selling a property in Switzerland,
including capital gains tax (impot sur les gains immobiliers), EPL repayment
obligations, mortgage payoff, and reinvestment deferral (remploi).

L'impot sur les gains immobiliers est delegue au modele calibre
``fiscal.gains_immobiliers_calibres`` : ZH / VD / GE sont chiffres depuis des
sources primaires, les autres cantons ne portent AUCUN chiffre fabrique (impot
None + renvoi au calculateur cantonal). Voir ADR 2026-07-28 (P5).

Sources:
    - LIFD art. 12 (impot sur les gains immobiliers au niveau federal)
    - Lois cantonales sur l'impot sur les gains immobiliers (voir verdict)
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
from typing import List, Optional

from app.services.fiscal.gains_immobiliers_calibres import verdict_gain_immobilier


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

DISCLAIMER: str = (
    "Cet outil educatif fournit une estimation indicative et ne constitue "
    "pas un conseil financier, fiscal ou juridique au sens de la LSFin. "
    "Les taux d'imposition sur les gains immobiliers varient selon le canton, "
    "la commune et la situation personnelle. Consulte un·e spécialiste "
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
    annees_occupation: int = 0                        # Proven owner-occupation years (VD double-count)


@dataclass
class HousingSaleResult:
    """Result of housing sale simulation.

    Pour un canton non calibre (hors ZH / VD / GE), l'impot sur les gains
    immobiliers n'est pas chiffre : ``taux_imposition_plus_value``,
    ``impot_plus_value``, ``remploi_report``, ``impot_effectif`` et
    ``produit_net`` valent alors ``None`` et ``gain_immobilier`` porte le
    mecanisme + le renvoi au calculateur cantonal officiel.
    """
    plus_value_brute: float                                # prix_vente - prix_achat
    plus_value_imposable: float                            # After deductions
    duree_detention: int                                   # Years of ownership
    modele_gain: str                                       # "calibre" | "mecanisme" | "inconnu"
    taux_imposition_plus_value: Optional[float]            # Effective rate (None si non calibre)
    impot_plus_value: Optional[float]                      # Tax on capital gain (None si non calibre)
    remploi_report: Optional[float]                        # Tax deferred if reinvesting (None si non calibre)
    impot_effectif: Optional[float]                        # Actual tax due (None si non calibre)
    remboursement_epl_lpp: float                           # EPL LPP to repay
    remboursement_epl_3a: float                            # EPL 3a to repay
    solde_hypotheque: float                                # Mortgage payoff
    produit_net: Optional[float]                           # Net proceeds (None si impot inconnu)
    gain_immobilier: dict                                  # Verdict calibre / mecanisme / inconnu
    checklist: List[str]                                   # Action items
    alerts: List[str]                                      # Warning messages
    disclaimer: str                                        # Legal disclaimer
    sources: List[str]                                     # Legal references
    premier_eclairage: dict                                # Impact number


# ══════════════════════════════════════════════════════════════════════════════
# Service
# ══════════════════════════════════════════════════════════════════════════════

class HousingSaleService:
    """Simulate the financial outcome of selling a property in Switzerland.

    Covers:
    - Capital gains tax (impot sur les gains immobiliers), delegue au modele
      calibre (ZH / VD / GE chiffres, autres cantons = mecanisme sans chiffre)
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

        # Capital gains tax — delegated to the calibrated canton model.
        verdict = verdict_gain_immobilier(
            input_data.canton,
            plus_value_imposable,
            duree_detention,
            input_data.annees_occupation,
        )
        modele_gain = str(verdict["modele"])
        impot_chf = verdict["impot_chf"]

        taux_imposition: Optional[float]
        impot_plus_value: Optional[float]
        remploi_report: Optional[float]
        impot_effectif: Optional[float]
        produit_net: Optional[float]

        if impot_chf is None:
            # Canton non calibre : aucun impot fabrique.
            taux_imposition = None
            impot_plus_value = None
            remploi_report = None
            impot_effectif = None
            produit_net = None
        else:
            impot_plus_value = round(float(impot_chf), 2)
            taux_imposition = (
                round(impot_plus_value / plus_value_imposable, 4)
                if plus_value_imposable > 0
                else 0.0
            )
            remploi_report = self._compute_remploi(input_data, impot_plus_value)
            impot_effectif = round(impot_plus_value - remploi_report, 2)
            produit_net = self._compute_produit_net(
                input_data.prix_vente,
                impot_effectif,
                input_data.epl_lpp_utilise if input_data.residence_principale else 0.0,
                input_data.epl_3a_utilise if input_data.residence_principale else 0.0,
                input_data.hypotheque_restante,
            )

        # EPL repayment (only for primary residence — LPP art. 30d, OPP2 art. 30e)
        remboursement_epl_lpp = input_data.epl_lpp_utilise if input_data.residence_principale else 0.0
        remboursement_epl_3a = input_data.epl_3a_utilise if input_data.residence_principale else 0.0

        # Mortgage payoff
        solde_hypotheque = input_data.hypotheque_restante

        # Sources — cite the exact cantonal source used by the verdict.
        sources = list(SOURCES)
        verdict_source = str(verdict.get("source", ""))
        if verdict_source and verdict_source not in sources:
            sources.append(verdict_source)

        # Compliance outputs
        checklist = self._generate_checklist(input_data)
        alerts = self._generate_alerts(
            input_data, plus_value_imposable, duree_detention,
            produit_net, remboursement_epl_lpp + remboursement_epl_3a,
            verdict,
        )
        premier_eclairage = self._generate_premier_eclairage(
            produit_net, impot_effectif, input_data.prix_vente, verdict,
        )

        return HousingSaleResult(
            plus_value_brute=round(plus_value_brute, 2),
            plus_value_imposable=round(plus_value_imposable, 2),
            duree_detention=duree_detention,
            modele_gain=modele_gain,
            taux_imposition_plus_value=taux_imposition,
            impot_plus_value=impot_plus_value,
            remploi_report=remploi_report,
            impot_effectif=impot_effectif,
            remboursement_epl_lpp=round(remboursement_epl_lpp, 2),
            remboursement_epl_3a=round(remboursement_epl_3a, 2),
            solde_hypotheque=round(solde_hypotheque, 2),
            produit_net=round(produit_net, 2) if produit_net is not None else None,
            gain_immobilier=dict(verdict),
            checklist=checklist,
            alerts=alerts,
            disclaimer=DISCLAIMER,
            sources=sources,
            premier_eclairage=premier_eclairage,
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

    def _compute_remploi(
        self, data: HousingSaleInput, impot_plus_value: float
    ) -> float:
        """Compute reinvestment deferral (remploi) on the tax due.

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
        produit_net: Optional[float],
        epl_total: float,
        verdict: dict,
    ) -> List[str]:
        """Generate warning alerts.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        # Canton non calibre : dire honnetement qu'aucun impot n'est chiffre.
        if verdict.get("impot_chf") is None:
            mecanismes = verdict.get("mecanismes") or []
            if mecanismes:
                alerts.append(str(mecanismes[0]))

        if plus_value_imposable > 100_000:
            alerts.append(
                "Plus-value elevee : envisage le remploi pour reporter l'impot"
            )

        if duree_detention < 5:
            alerts.append(
                "Duree de detention courte : taux d'imposition majore"
            )

        if produit_net is not None and produit_net < 0:
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

    def _generate_premier_eclairage(
        self,
        produit_net: Optional[float],
        impot_effectif: Optional[float],
        prix_vente: float,
        verdict: dict,
    ) -> dict:
        """Generate the impact number (premier éclairage).

        Returns:
            dict with montant and texte.
        """
        if produit_net is None:
            # Canton non calibre : pas de montant chiffre, on renvoie le mecanisme.
            mecanismes = verdict.get("mecanismes") or []
            texte = (
                str(mecanismes[0])
                if mecanismes
                else "Impot sur le gain a estimer aupres de l'administration cantonale."
            )
            return {"montant": None, "texte": texte}

        if prix_vente > 0 and impot_effectif is not None and impot_effectif > 0:
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
