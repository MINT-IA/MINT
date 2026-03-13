"""
EPL (Encouragement a la propriete du logement) simulator.

Simulates the withdrawal of LPP funds for purchasing a primary residence.
Critical: this withdrawal reduces death and disability benefits!

Sources:
    - LPP art. 30a-30g (EPL: conditions, montants, remboursement)
    - OPP2 art. 5-5f (EPL: details d'application)
    - LPP art. 79b al. 3 (blocage: pas de retrait EPL si rachat < 3 ans)

Sprint S15 — Chantier 4: LPP approfondi.
"""

from dataclasses import dataclass
from typing import List, Optional

from app.constants.social_insurance import (
    EPL_MONTANT_MINIMUM,
    EPL_BLOCAGE_RACHAT_ANNEES,
    TAUX_IMPOT_RETRAIT_CAPITAL,
    TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT,
    calculate_progressive_capital_tax,
)


DISCLAIMER = (
    "MINT est un outil educatif. Ce service ne constitue pas un conseil "
    "en prevoyance au sens de la LSFin. Le retrait EPL a des consequences "
    "importantes sur vos prestations de prevoyance. Consultez un ou une specialiste "
    "avant toute demande de retrait."
)

_DEFAULT_TAUX_RETRAIT = TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT


@dataclass
class ImpactPrestations:
    """Impact on death and disability benefits from EPL withdrawal."""
    rente_invalidite_reduction_pct: float    # % reduction of disability pension
    capital_deces_reduction_pct: float       # % reduction of death capital
    rente_invalidite_reduction_chf: float    # CHF reduction estimate
    capital_deces_reduction_chf: float       # CHF reduction estimate
    message: str                             # Human-readable explanation


@dataclass
class EPLResult:
    """Complete result of the EPL simulation."""

    # Withdrawal calculation
    montant_retirable_max: float     # Maximum withdrawable amount (CHF)
    montant_demande: float           # Requested amount (CHF)
    montant_effectif: float          # Effective withdrawal (min of requested and max)

    # Minimum rule
    respecte_minimum: bool           # Whether the min 20'000 CHF rule is respected

    # Age 50 rule
    age: int
    regle_age_50_appliquee: bool     # Whether the age >= 50 limitation applies
    avoir_a_50_ans: Optional[float]  # Estimated savings at age 50 (if applicable)

    # Tax
    impot_retrait_estime: float      # Estimated one-time capital withdrawal tax
    canton: str
    taux_impot_retrait: float

    # Impact on benefits (CRITICAL)
    impact_prestations: ImpactPrestations

    # Buyback blocage
    blocage_rachat: bool             # Whether a recent buyback blocks the withdrawal
    annees_depuis_rachat: Optional[int]
    annees_restantes_blocage: int    # Years until EPL withdrawal is possible

    # Checklist
    checklist: List[str]
    alertes: List[str]
    sources: List[str]
    disclaimer: str = DISCLAIMER


class EPLService:
    """Simulate EPL (home ownership encouragement) withdrawal from LPP.

    Key rules:
    - Only for primary residence purchase (LPP art. 30a)
    - Minimum withdrawal: 20'000 CHF (OPP2 art. 5)
    - Age < 50: can withdraw full LPP amount
    - Age >= 50: limited to max(avoir_at_50, 50% of current avoir) (LPP art. 30c al. 2)
    - Cannot withdraw if buyback done in last 3 years (LPP art. 79b al. 3)
    - Must repay if property sold (LPP art. 30d)
    - Reduces death and disability benefits! (LPP art. 30e)
    - One-time capital withdrawal tax at reduced rate
    """

    MINIMUM_RETRAIT = EPL_MONTANT_MINIMUM       # OPP2 art. 5
    AGE_REGLE_50 = 50                            # LPP art. 30c al. 2
    BLOCAGE_RACHAT_ANNEES = EPL_BLOCAGE_RACHAT_ANNEES  # LPP art. 79b al. 3

    def simulate(
        self,
        avoir_lpp_total: float,
        avoir_obligatoire: float,
        avoir_surobligatoire: float,
        age: int,
        montant_retrait_souhaite: float,
        a_rachete_recemment: bool = False,
        annees_depuis_dernier_rachat: Optional[int] = None,
        avoir_a_50_ans: Optional[float] = None,
        canton: str = "ZH",
    ) -> EPLResult:
        """Simulate an EPL withdrawal.

        Args:
            avoir_lpp_total: Total LPP savings (CHF).
            avoir_obligatoire: Mandatory LPP portion (CHF).
            avoir_surobligatoire: Super-mandatory portion (CHF).
            age: Person's current age.
            montant_retrait_souhaite: Desired withdrawal amount (CHF).
            a_rachete_recemment: Whether a buyback was done recently.
            annees_depuis_dernier_rachat: Years since last buyback.
            avoir_a_50_ans: LPP savings at age 50 (if known, for age >= 50 rule).
            canton: Canton code for tax estimation.

        Returns:
            EPLResult with complete simulation.
        """
        avoir_lpp_total = max(0.0, avoir_lpp_total)
        avoir_obligatoire = max(0.0, avoir_obligatoire)
        avoir_surobligatoire = max(0.0, avoir_surobligatoire)
        montant_retrait_souhaite = max(0.0, montant_retrait_souhaite)
        age = max(18, min(70, age))
        canton_upper = canton.upper() if canton else "ZH"

        # 1. Calculate maximum withdrawable amount
        montant_max = self._calc_montant_max(
            avoir_lpp_total, age, avoir_a_50_ans
        )
        regle_age_50 = age >= self.AGE_REGLE_50

        # 2. Check minimum rule
        respecte_minimum = montant_retrait_souhaite >= self.MINIMUM_RETRAIT or montant_retrait_souhaite == 0

        # 3. Effective withdrawal
        montant_effectif = min(montant_retrait_souhaite, montant_max)
        if montant_effectif < self.MINIMUM_RETRAIT and montant_effectif > 0:
            montant_effectif = 0.0  # Below minimum: cannot withdraw

        # 4. Check buyback blocage
        blocage_rachat = False
        annees_restantes = 0
        if a_rachete_recemment:
            if annees_depuis_dernier_rachat is not None:
                if annees_depuis_dernier_rachat < self.BLOCAGE_RACHAT_ANNEES:
                    blocage_rachat = True
                    annees_restantes = self.BLOCAGE_RACHAT_ANNEES - annees_depuis_dernier_rachat
            else:
                # Assume blocked if no data on when the buyback happened
                blocage_rachat = True
                annees_restantes = self.BLOCAGE_RACHAT_ANNEES

        if blocage_rachat:
            montant_effectif = 0.0

        # 5. Tax estimate (progressive brackets — aligned with Flutter + pillar_3a_deep)
        taux_impot = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton_upper, _DEFAULT_TAUX_RETRAIT)
        impot_estime = calculate_progressive_capital_tax(montant_effectif, taux_impot)

        # 6. Impact on death and disability benefits
        impact = self._calc_impact_prestations(
            montant_effectif, avoir_lpp_total, avoir_obligatoire, avoir_surobligatoire
        )

        # 7. Checklist
        checklist = self._generate_checklist(
            montant_effectif, blocage_rachat, age, canton_upper
        )

        # 8. Alerts
        alertes = self._generate_alertes(
            montant_effectif, montant_max, avoir_lpp_total,
            blocage_rachat, annees_restantes, age,
            impact, respecte_minimum, montant_retrait_souhaite,
        )

        # Sources
        sources = [
            "LPP art. 30a-30g (EPL: conditions et montants)",
            "OPP2 art. 5-5f (EPL: details d'application)",
            "LPP art. 79b al. 3 (blocage rachat 3 ans avant EPL)",
            "LPP art. 30e (impact sur prestations de risque)",
        ]

        return EPLResult(
            montant_retirable_max=round(montant_max, 2),
            montant_demande=round(montant_retrait_souhaite, 2),
            montant_effectif=round(montant_effectif, 2),
            respecte_minimum=respecte_minimum,
            age=age,
            regle_age_50_appliquee=regle_age_50,
            avoir_a_50_ans=round(avoir_a_50_ans, 2) if avoir_a_50_ans is not None else None,
            impot_retrait_estime=impot_estime,
            canton=canton_upper,
            taux_impot_retrait=taux_impot,
            impact_prestations=impact,
            blocage_rachat=blocage_rachat,
            annees_depuis_rachat=annees_depuis_dernier_rachat,
            annees_restantes_blocage=annees_restantes,
            checklist=checklist,
            alertes=alertes,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _calc_montant_max(
        self,
        avoir_total: float,
        age: int,
        avoir_a_50_ans: Optional[float],
    ) -> float:
        """Calculate the maximum withdrawable EPL amount.

        Rules (LPP art. 30c):
        - Age < 50: full amount
        - Age >= 50: max(avoir_at_50, 50% of current avoir)

        Args:
            avoir_total: Total LPP savings (CHF).
            age: Person's current age.
            avoir_a_50_ans: LPP savings at age 50 (if known).

        Returns:
            Maximum EPL withdrawal amount (CHF).
        """
        if age < self.AGE_REGLE_50:
            return avoir_total

        # Age >= 50: apply limitation
        half_current = avoir_total * 0.5

        if avoir_a_50_ans is not None:
            return max(avoir_a_50_ans, half_current)

        # If avoir_at_50 is unknown, use 50% as conservative default
        return half_current

    def _calc_impact_prestations(
        self,
        montant_retrait: float,
        avoir_total: float,
        avoir_obligatoire: float,
        avoir_surobligatoire: float,
    ) -> ImpactPrestations:
        """Calculate the impact on death and disability benefits.

        LPP art. 30e: EPL withdrawal reduces the insured benefits
        proportionally to the reduction in savings.

        Args:
            montant_retrait: Effective withdrawal amount (CHF).
            avoir_total: Total LPP savings before withdrawal.
            avoir_obligatoire: Mandatory portion.
            avoir_surobligatoire: Super-mandatory portion.

        Returns:
            ImpactPrestations with reduction details.
        """
        if avoir_total <= 0 or montant_retrait <= 0:
            return ImpactPrestations(
                rente_invalidite_reduction_pct=0.0,
                capital_deces_reduction_pct=0.0,
                rente_invalidite_reduction_chf=0.0,
                capital_deces_reduction_chf=0.0,
                message="Aucun impact: pas de retrait effectif.",
            )

        # Proportional reduction
        reduction_pct = round((montant_retrait / avoir_total) * 100, 2)

        # Estimated CHF impact (simplified: based on typical benefit levels)
        # Typical disability pension = 40-70% of insured salary
        # Typical death capital = 3x annual salary or similar
        # We use a simplified approach: benefits reduce proportionally to savings
        rente_invalidite_reduction_chf = round(montant_retrait * 0.06, 2)  # ~6% of withdrawal as annual pension
        capital_deces_reduction_chf = round(montant_retrait * 3.0 / avoir_total * avoir_obligatoire * 0.5, 2) if avoir_total > 0 else 0.0

        message = (
            f"Le retrait de {montant_retrait:.0f} CHF reduit vos prestations de risque "
            f"d'environ {reduction_pct:.1f}%. La rente d'invalidite diminue d'environ "
            f"{rente_invalidite_reduction_chf:.0f} CHF/an. Le capital deces est egalement "
            f"reduit proportionnellement (LPP art. 30e). Une assurance complementaire "
            f"peut compenser cette perte — consultez un ou une specialiste."
        )

        return ImpactPrestations(
            rente_invalidite_reduction_pct=reduction_pct,
            capital_deces_reduction_pct=reduction_pct,
            rente_invalidite_reduction_chf=rente_invalidite_reduction_chf,
            capital_deces_reduction_chf=capital_deces_reduction_chf,
            message=message,
        )

    def _generate_checklist(
        self,
        montant: float,
        blocage: bool,
        age: int,
        canton: str,
    ) -> List[str]:
        """Generate the EPL checklist.

        Returns:
            List of checklist items in French.
        """
        items: List[str] = []

        items.append(
            "Confirmer que le bien immobilier sera votre residence principale "
            "(LPP art. 30a: EPL uniquement pour residence principale)."
        )

        if blocage:
            items.append(
                "BLOQUE: attendre la fin du delai de 3 ans apres le dernier rachat "
                "avant de demander un retrait EPL (LPP art. 79b al. 3)."
            )

        items.append(
            "Demander a la caisse de pension le formulaire de retrait EPL."
        )

        items.append(
            "Fournir les justificatifs: acte de vente ou promesse de vente, "
            "extrait du registre foncier."
        )

        if montant > 0:
            items.append(
                "Informer votre conjoint ou partenaire enregistre — "
                "leur consentement ecrit est requis (LPP art. 30c al. 5)."
            )

        items.append(
            "Verifier l'impact sur vos prestations de risque (deces, invalidite) "
            "et envisager une assurance complementaire si necessaire."
        )

        items.append(
            "Prevoir l'impot sur le retrait en capital "
            f"(canton {canton}, taux reduit applicable)."
        )

        items.append(
            "Mentionner l'obligation de remboursement en cas de vente du bien "
            "(LPP art. 30d) dans la planification financiere."
        )

        items.append(
            "Inscrire la restriction de vente au registre foncier "
            "(mention EPL obligatoire, OPP2 art. 5e)."
        )

        return items

    def _generate_alertes(
        self,
        montant_effectif: float,
        montant_max: float,
        avoir_total: float,
        blocage: bool,
        annees_restantes: int,
        age: int,
        impact: ImpactPrestations,
        respecte_minimum: bool,
        montant_souhaite: float,
    ) -> List[str]:
        """Generate alerts for the EPL simulation.

        Returns:
            List of alert strings in French.
        """
        alertes: List[str] = []

        if blocage:
            alertes.append(
                f"BLOQUE: Un rachat LPP a ete effectue il y a moins de 3 ans. "
                f"Le retrait EPL est interdit pendant {annees_restantes} an(s) "
                f"supplementaire(s) (LPP art. 79b al. 3)."
            )

        if not respecte_minimum and montant_souhaite > 0:
            alertes.append(
                f"Le montant demande ({montant_souhaite:.0f} CHF) est inferieur "
                f"au minimum legal de 20'000 CHF (OPP2 art. 5)."
            )

        if montant_souhaite > montant_max and montant_max > 0:
            alertes.append(
                f"Le montant demande ({montant_souhaite:.0f} CHF) depasse le maximum "
                f"retirable ({montant_max:.0f} CHF). Le retrait sera limite a {montant_max:.0f} CHF."
            )

        if impact.rente_invalidite_reduction_pct > 20:
            alertes.append(
                f"ATTENTION: Le retrait EPL reduit vos prestations de risque de "
                f"{impact.rente_invalidite_reduction_pct:.1f}%. Cela represente une "
                f"diminution significative de votre couverture en cas d'invalidite "
                f"ou de deces (LPP art. 30e)."
            )

        if age >= 50:
            alertes.append(
                f"Regle des 50 ans: a {age} ans, le retrait EPL est limite a "
                f"max(avoir a 50 ans, 50% de l'avoir actuel) = {montant_max:.0f} CHF "
                f"(LPP art. 30c al. 2)."
            )

        if montant_effectif > 0 and avoir_total > 0:
            pct_retrait = (montant_effectif / avoir_total) * 100
            if pct_retrait > 50:
                alertes.append(
                    f"Le retrait represente {pct_retrait:.0f}% de votre avoir LPP total. "
                    f"Votre prevoyance sera significativement reduite."
                )

        # Reminder: must repay if property sold
        if montant_effectif > 0:
            alertes.append(
                "En cas de vente du bien immobilier, le montant EPL doit etre "
                "rembourse a la caisse de pension (LPP art. 30d). "
                "Ce remboursement est deductible fiscalement."
            )

        return alertes
