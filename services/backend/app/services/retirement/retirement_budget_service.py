"""
Retirement budget reconciliation and PC eligibility check.

Consolidates all retirement income sources (AVS, LPP, 3a, other) against
estimated expenses to determine the retirement surplus/deficit, replacement
rate, and potential eligibility for prestations complementaires (PC).

Sources:
    - LAVS art. 29 (rente AVS maximale)
    - LPP art. 14 (taux de conversion)
    - LPC / OPC (prestations complementaires cantonales)

Sprint S21 — Retraite complete.
"""

from dataclasses import dataclass, field
from typing import Dict, List


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de ton "
    "historique de cotisations, de ton canton et de ta situation personnelle. "
    "Ne constitue pas un conseil en prevoyance (LSFin). Consulte un ou une specialiste."
)


@dataclass
class RetirementBudget:
    """Complete retirement budget reconciliation."""
    revenus_garantis: Dict[str, float]    # guaranteed income by source (AVS, LPP rente, other)
    capital_epuisable: Dict[str, float]   # capital-based income by source (3a mensualisé)
    total_revenus_mensuels: float         # revenus_garantis + capital_epuisable
    depenses_mensuelles_estimees: float
    solde_mensuel: float                  # positive = surplus, negative = deficit
    taux_remplacement: float              # % of pre-retirement income
    pc_potentiellement_eligible: bool
    duree_capital_3a_ans: float           # how many years 3a capital lasts
    alertes: List[str] = field(default_factory=list)
    chiffre_choc: str = ""
    checklist: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER
    sources: List[str] = field(default_factory=list)


class RetirementBudgetService:
    """Reconcile retirement income vs expenses and check PC eligibility.

    Key features:
    - Aggregates all income sources: AVS, LPP rente, 3a (mensualised), other
    - Calculates replacement rate (taux de remplacement)
    - Checks indicative PC eligibility (simplified national thresholds)
    - Generates actionable checklist and alerts

    Sources:
        - LAVS art. 29 (rente AVS)
        - LPP art. 14 (taux de conversion)
        - OPC (prestations complementaires cantonales)
    """

    # PC income thresholds (simplified national average)
    PC_SEUIL_CELIBATAIRE_MENSUEL = 3000.0   # ~CHF varies heavily by canton
    PC_SEUIL_COUPLE_MENSUEL = 4500.0

    # 3a capital spread assumption (years)
    DUREE_MENSUALISATION_3A = 20

    def reconcile(
        self,
        avs_mensuel: float,
        lpp_mensuel: float,
        capital_3a_net: float,
        autres_revenus: float,
        depenses_mensuelles: float,
        revenu_pre_retraite: float,
        is_couple: bool = False,
    ) -> RetirementBudget:
        """Reconcile retirement income against expenses.

        Args:
            avs_mensuel: Monthly AVS pension (CHF).
            lpp_mensuel: Monthly LPP pension (CHF).
            capital_3a_net: Net 3a capital after tax (CHF).
            autres_revenus: Other monthly income (CHF).
            depenses_mensuelles: Estimated monthly expenses (CHF).
            revenu_pre_retraite: Current monthly income before retirement (CHF).
            is_couple: Whether this is a couple assessment.

        Returns:
            RetirementBudget with complete reconciliation.
        """
        # Income breakdown — separated into guaranteed income and depletable capital.
        # 3a is consumption of capital, NOT guaranteed income like AVS/LPP rente.
        capital_epuisable_mensuel = round(
            capital_3a_net / (self.DUREE_MENSUALISATION_3A * 12), 2
        ) if capital_3a_net > 0 else 0.0

        revenus_garantis = {
            "avs": round(avs_mensuel, 2),
            "lpp": round(lpp_mensuel, 2),
            "autres": round(autres_revenus, 2),
        }
        capital_epuisable = {
            "3a_mensualise": capital_epuisable_mensuel,
        }
        total_revenus = round(
            sum(revenus_garantis.values()) + sum(capital_epuisable.values()), 2
        )
        solde = round(total_revenus - depenses_mensuelles, 2)

        # Replacement rate
        taux_remplacement = round(
            (total_revenus / revenu_pre_retraite * 100) if revenu_pre_retraite > 0 else 0,
            1,
        )

        # PC eligibility check (simplified)
        seuil = self.PC_SEUIL_COUPLE_MENSUEL if is_couple else self.PC_SEUIL_CELIBATAIRE_MENSUEL
        pc_eligible = total_revenus < seuil

        # 3a duration
        duree_3a = round(
            capital_3a_net / (depenses_mensuelles * 12), 1
        ) if depenses_mensuelles > 0 and capital_3a_net > 0 else 0.0

        # Alerts
        alertes = self._generate_alertes(
            solde, taux_remplacement, pc_eligible, duree_3a, capital_3a_net,
        )

        # Chiffre choc
        if solde >= 0:
            chiffre_choc = (
                f"Bonne nouvelle : tes revenus de retraite couvrent tes depenses "
                f"avec CHF {solde:,.0f}/mois de marge"
            )
        else:
            chiffre_choc = (
                f"Attention : il te manque CHF {abs(solde):,.0f}/mois a la retraite "
                f"— soit CHF {abs(solde * 12):,.0f}/an"
            )

        checklist = [
            "Demander un extrait de compte individuel AVS (CI) — gratuit sur ahv-iv.ch",
            "Demander une estimation de rente LPP a ta caisse de pension",
            "Consolider tous tes comptes 3a (nombre + montants)",
            "Etablir un budget retraite realiste (logement, sante, loisirs)",
            "Verifier les prestations complementaires (PC) si revenus insuffisants",
            "Planifier le retrait echelonne du 3a (2-5 comptes, sur 5 ans)",
            "Decider rente vs capital LPP au moins 6 mois avant la retraite",
            "Demander la rente AVS 3 mois avant le depart",
        ]

        sources = [
            "LAVS art. 29 (rente AVS maximale)",
            "LPP art. 14 (taux de conversion)",
            "OPC (prestations complementaires cantonales)",
        ]

        return RetirementBudget(
            revenus_garantis=revenus_garantis,
            capital_epuisable=capital_epuisable,
            total_revenus_mensuels=total_revenus,
            depenses_mensuelles_estimees=depenses_mensuelles,
            solde_mensuel=solde,
            taux_remplacement=taux_remplacement,
            pc_potentiellement_eligible=pc_eligible,
            duree_capital_3a_ans=duree_3a,
            alertes=alertes,
            chiffre_choc=chiffre_choc,
            checklist=checklist,
            disclaimer=DISCLAIMER,
            sources=sources,
        )

    def _generate_alertes(
        self,
        solde: float,
        taux_remplacement: float,
        pc_eligible: bool,
        duree_3a: float,
        capital_3a_net: float,
    ) -> List[str]:
        """Generate contextual alerts for the retirement budget.

        Args:
            solde: Monthly surplus/deficit.
            taux_remplacement: Replacement rate (%).
            pc_eligible: Whether PC threshold is met.
            duree_3a: How many years 3a capital lasts.
            capital_3a_net: Net 3a capital.

        Returns:
            List of alert strings in French.
        """
        alertes: List[str] = []

        if solde < 0:
            alertes.append(
                f"Deficit mensuel de CHF {abs(solde):,.0f}. "
                f"Ton train de vie actuel n'est pas soutenable a la retraite."
            )

        if taux_remplacement < 60:
            alertes.append(
                f"Taux de remplacement de {taux_remplacement}% "
                f"— en dessous du minimum recommande (60%)."
            )

        if pc_eligible:
            alertes.append(
                "Tu pourrais etre eligible aux prestations complementaires (PC). "
                "Contacte ton office cantonal."
            )

        if duree_3a < 5 and capital_3a_net > 0:
            alertes.append(
                f"Ton capital 3a ne couvre que {duree_3a} ans de depenses."
            )

        return alertes
