"""
Divorce Financial Simulator Service.

Simulates the financial impact of a divorce in Switzerland, including:
- LPP splitting (CC art. 122-124)
- AVS splitting (LAVS art. 29sexies)
- 3a pillar splitting (regime-dependent)
- Fortune splitting (CC art. 196-220 for acquets)
- Tax impact (LIFD art. 33 + 23: joint vs individual taxation)
- Pension alimentaire estimation

Sources:
    - CC art. 120-124 (divorce, partage LPP)
    - CC art. 196-220 (regime matrimonial, participation aux acquets)
    - CC art. 181-195 (communaute de biens)
    - CC art. 247-251 (separation de biens)
    - LAVS art. 29sexies (splitting AVS)
    - LIFD art. 33 al. 1 let. c (deduction pension alimentaire)
    - LIFD art. 23 let. f (imposition pension alimentaire)
    - OPP2 art. 22 (partage prestation de sortie LPP)

Ethical requirements:
    - Gender-neutral: no assumptions based on gender
    - Works identically for all family configurations
    - Same-sex partnerships treated identically
"""

from dataclasses import dataclass
from typing import List


@dataclass
class DivorceInput:
    """Input data for divorce financial simulation."""
    duree_mariage_annees: int                       # Marriage duration in years
    regime_matrimonial: str                         # "participation_acquets" | "communaute_biens" | "separation_biens"
    nombre_enfants: int                             # Number of children
    revenu_annuel_conjoint_1: float                 # Annual income spouse 1
    revenu_annuel_conjoint_2: float                 # Annual income spouse 2
    lpp_conjoint_1_pendant_mariage: float           # LPP accumulated during marriage (spouse 1)
    lpp_conjoint_2_pendant_mariage: float           # LPP accumulated during marriage (spouse 2)
    avoirs_3a_conjoint_1: float                     # 3a pillar savings (spouse 1)
    avoirs_3a_conjoint_2: float                     # 3a pillar savings (spouse 2)
    fortune_commune: float                          # Common fortune (real estate, savings)
    dette_commune: float                            # Common debt (mortgage, etc.)
    canton: str                                     # Canton of residence


@dataclass
class DivorceResult:
    """Result of divorce financial simulation."""
    partage_lpp: dict                               # LPP splitting details
    splitting_avs: dict                             # AVS splitting explanation
    partage_3a: dict                                # 3a pillar splitting
    partage_fortune: dict                           # Fortune splitting
    impact_fiscal_avant: dict                       # Tax before divorce (joint)
    impact_fiscal_apres: dict                       # Tax after divorce (individual)
    pension_alimentaire_estimee: float              # Estimated alimony
    checklist: List[str]                            # Action items
    alerts: List[str]                               # Warning messages
    disclaimer: str                                 # Legal disclaimer


class DivorceSimulator:
    """Simulate financial impact of a divorce under Swiss law.

    Key principles:
    - LPP: 50/50 split of pension accumulated during marriage (CC art. 123)
    - AVS: Income splitting for married years (LAVS art. 29sexies)
    - Fortune: Depends on matrimonial regime
    - Tax: Joint taxation -> individual taxation

    Compliance: NEVER use "garanti", "assure", "certain".
    """

    # Simplified marginal tax rates by canton (combined: federal + cantonal + communal)
    # These are approximate effective rates for estimation purposes only
    CANTON_TAX_RATES = {
        "GE": {"married_rate": 0.30, "single_rate": 0.33, "single_child_rate": 0.28},
        "VD": {"married_rate": 0.32, "single_rate": 0.35, "single_child_rate": 0.30},
        "ZH": {"married_rate": 0.25, "single_rate": 0.28, "single_child_rate": 0.23},
        "BE": {"married_rate": 0.30, "single_rate": 0.33, "single_child_rate": 0.28},
        "BS": {"married_rate": 0.31, "single_rate": 0.34, "single_child_rate": 0.29},
        "LU": {"married_rate": 0.24, "single_rate": 0.27, "single_child_rate": 0.22},
        "TI": {"married_rate": 0.29, "single_rate": 0.32, "single_child_rate": 0.27},
        "SG": {"married_rate": 0.27, "single_rate": 0.30, "single_child_rate": 0.25},
        "AG": {"married_rate": 0.26, "single_rate": 0.29, "single_child_rate": 0.24},
        "VS": {"married_rate": 0.28, "single_rate": 0.31, "single_child_rate": 0.26},
        "FR": {"married_rate": 0.29, "single_rate": 0.32, "single_child_rate": 0.27},
        "NE": {"married_rate": 0.32, "single_rate": 0.35, "single_child_rate": 0.30},
    }

    DEFAULT_TAX_RATES = {"married_rate": 0.28, "single_rate": 0.31, "single_child_rate": 0.26}

    # Pension alimentaire: simplified "method du minimum vital"
    # Rough estimate: ~1/3 of income gap for children, 10-20% for spouse (short marriages get less)
    PENSION_CHILD_MONTHLY_BASE = 600.0       # Base per child (CHF/month)
    PENSION_CHILD_MONTHLY_TEEN = 800.0       # Teenager base (estimate)
    LONG_MARRIAGE_THRESHOLD = 10             # Years threshold for spousal maintenance

    def simulate(self, input_data: DivorceInput) -> DivorceResult:
        """Run full divorce financial simulation.

        Args:
            input_data: DivorceInput with all financial data.

        Returns:
            DivorceResult with splitting, tax impact, and recommendations.
        """
        partage_lpp = self._compute_lpp_split(input_data)
        splitting_avs = self._compute_avs_splitting(input_data)
        partage_3a = self._compute_3a_split(input_data)
        partage_fortune = self._compute_fortune_split(input_data)
        impact_fiscal_avant = self._compute_tax_before(input_data)
        impact_fiscal_apres = self._compute_tax_after(input_data, partage_fortune)
        pension_alimentaire = self._estimate_pension_alimentaire(input_data)
        checklist = self._generate_checklist(input_data)
        alerts = self._generate_alerts(input_data, partage_lpp, partage_fortune)

        return DivorceResult(
            partage_lpp=partage_lpp,
            splitting_avs=splitting_avs,
            partage_3a=partage_3a,
            partage_fortune=partage_fortune,
            impact_fiscal_avant=impact_fiscal_avant,
            impact_fiscal_apres=impact_fiscal_apres,
            pension_alimentaire_estimee=round(pension_alimentaire, 2),
            checklist=checklist,
            alerts=alerts,
            disclaimer=(
                "Outil educatif — ne constitue pas un conseil (LSFin). "
                "Estimation indicative. Consultez un·e specialiste "
                "en droit de la famille."
            ),
        )

    def _compute_lpp_split(self, data: DivorceInput) -> dict:
        """Compute LPP splitting per CC art. 122-124.

        Rule: The LPP accumulated by both spouses DURING the marriage
        is pooled and split 50/50. Each spouse receives half of the total.

        CC art. 123: Le tribunal ordonne le partage par moitie des
        prestations de sortie acquises pendant le mariage.

        Returns:
            dict with conjoint_1_recoit, conjoint_2_recoit, transfert_lpp
        """
        total_lpp_mariage = (
            data.lpp_conjoint_1_pendant_mariage + data.lpp_conjoint_2_pendant_mariage
        )
        moitie = total_lpp_mariage / 2.0

        # Each spouse gets half. The transfer is the difference between
        # what they accumulated and what they should have (half).
        # Positive transfert = conjoint_1 pays to conjoint_2
        transfert = data.lpp_conjoint_1_pendant_mariage - moitie

        return {
            "total_lpp_pendant_mariage": round(total_lpp_mariage, 2),
            "conjoint_1_recoit": round(moitie, 2),
            "conjoint_2_recoit": round(moitie, 2),
            "transfert_lpp": round(transfert, 2),
            "transfert_direction": (
                "conjoint_1_vers_conjoint_2" if transfert > 0
                else "conjoint_2_vers_conjoint_1" if transfert < 0
                else "aucun_transfert"
            ),
            "source": "CC art. 122-124, OPP2 art. 22",
        }

    def _compute_avs_splitting(self, data: DivorceInput) -> dict:
        """Compute AVS splitting explanation per LAVS art. 29sexies.

        Rule: All AVS-registered income during the marriage is split 50/50
        between the two spouses. This is done by the compensation office.

        Returns:
            dict with explanation and estimated impact
        """
        revenu_total_annuel = (
            data.revenu_annuel_conjoint_1 + data.revenu_annuel_conjoint_2
        )
        revenu_moyen_annuel_par_conjoint = revenu_total_annuel / 2.0
        revenu_total_pendant_mariage = revenu_total_annuel * data.duree_mariage_annees

        return {
            "explication": (
                "Les revenus AVS inscrits pendant le mariage sont partages "
                "50/50 entre les deux conjoints (LAVS art. 29sexies). "
                "Ce splitting est effectue d'office par la caisse de compensation "
                "lors du divorce."
            ),
            "revenu_total_pendant_mariage": round(revenu_total_pendant_mariage, 2),
            "revenu_annuel_moyen_apres_splitting": round(revenu_moyen_annuel_par_conjoint, 2),
            "duree_splitting_annees": data.duree_mariage_annees,
            "source": "LAVS art. 29sexies",
        }

    def _compute_3a_split(self, data: DivorceInput) -> dict:
        """Compute 3a pillar splitting based on matrimonial regime.

        Under participation aux acquets (default): 3a contributions made
        during the marriage are part of the acquets and split 50/50.

        Under communaute de biens: all 3a is shared.
        Under separation de biens: each keeps their own 3a.

        Returns:
            dict with conjoint_1_part, conjoint_2_part
        """
        total_3a = data.avoirs_3a_conjoint_1 + data.avoirs_3a_conjoint_2

        if data.regime_matrimonial == "participation_acquets":
            # 3a accumulated during marriage split 50/50
            moitie = total_3a / 2.0
            return {
                "conjoint_1_part": round(moitie, 2),
                "conjoint_2_part": round(moitie, 2),
                "regime": "participation_acquets",
                "explication": (
                    "Sous le regime de la participation aux acquets, "
                    "les avoirs 3a constitues pendant le mariage "
                    "font partie des acquets et sont partages 50/50."
                ),
                "source": "CC art. 196-220",
            }
        elif data.regime_matrimonial == "communaute_biens":
            # All shared equally
            moitie = total_3a / 2.0
            return {
                "conjoint_1_part": round(moitie, 2),
                "conjoint_2_part": round(moitie, 2),
                "regime": "communaute_biens",
                "explication": (
                    "Sous le regime de la communaute de biens, "
                    "les avoirs 3a font partie de la masse commune "
                    "et sont partages 50/50."
                ),
                "source": "CC art. 181-195",
            }
        else:
            # separation_biens: each keeps their own
            return {
                "conjoint_1_part": round(data.avoirs_3a_conjoint_1, 2),
                "conjoint_2_part": round(data.avoirs_3a_conjoint_2, 2),
                "regime": "separation_biens",
                "explication": (
                    "Sous le regime de la separation de biens, "
                    "chaque conjoint conserve ses propres avoirs 3a."
                ),
                "source": "CC art. 247-251",
            }

    def _compute_fortune_split(self, data: DivorceInput) -> dict:
        """Compute fortune splitting based on matrimonial regime.

        Participation aux acquets (default, CC art. 196-220):
        - Fortune nette commune = fortune_commune - dette_commune
        - Split 50/50 of acquets (property acquired during marriage)

        Communaute de biens (CC art. 181-195):
        - All assets pooled and split 50/50

        Separation de biens (CC art. 247-251):
        - Each keeps their own (no common property to split)

        Returns:
            dict with conjoint_1_part, conjoint_2_part, fortune_nette
        """
        fortune_nette = data.fortune_commune - data.dette_commune

        if data.regime_matrimonial == "participation_acquets":
            moitie = fortune_nette / 2.0
            return {
                "fortune_nette": round(fortune_nette, 2),
                "conjoint_1_part": round(moitie, 2),
                "conjoint_2_part": round(moitie, 2),
                "regime": "participation_acquets",
                "explication": (
                    "Sous le regime de la participation aux acquets, "
                    "la fortune nette commune (fortune - dettes) "
                    "est partagee 50/50."
                ),
                "source": "CC art. 196-220",
            }
        elif data.regime_matrimonial == "communaute_biens":
            moitie = fortune_nette / 2.0
            return {
                "fortune_nette": round(fortune_nette, 2),
                "conjoint_1_part": round(moitie, 2),
                "conjoint_2_part": round(moitie, 2),
                "regime": "communaute_biens",
                "explication": (
                    "Sous le regime de la communaute de biens, "
                    "tous les biens sont mis en commun et partages 50/50."
                ),
                "source": "CC art. 181-195",
            }
        else:
            # separation_biens: each party claims their own contributions.
            # For "fortune_commune" (shared property), CC art. 248 applies:
            # "A defaut de preuve, elle est partagee 50/50."
            # Since we don't know individual contributions, we apply 50/50.
            moitie = fortune_nette / 2.0
            return {
                "fortune_nette": round(fortune_nette, 2),
                "conjoint_1_part": round(moitie, 2),
                "conjoint_2_part": round(moitie, 2),
                "regime": "separation_biens",
                "explication": (
                    "Sous le regime de la separation de biens, "
                    "il n'y a pas de partage automatique. La fortune "
                    "commune doit etre repartie selon les apports de chacun. "
                    "A defaut de preuve, elle est partagee 50/50 (CC art. 248)."
                ),
                "source": "CC art. 247-251",
            }

    def _compute_tax_before(self, data: DivorceInput) -> dict:
        """Compute estimated joint tax (married couple taxation).

        Under Swiss law, married couples are taxed jointly on their
        combined income, with a specific (generally lower) rate schedule.

        LIFD art. 36: Bareme pour les epoux vivant en menage commun.

        Returns:
            dict with impot_commun estimate
        """
        rates = self.CANTON_TAX_RATES.get(data.canton, self.DEFAULT_TAX_RATES)
        revenu_total = data.revenu_annuel_conjoint_1 + data.revenu_annuel_conjoint_2

        # Simplified: apply married rate to combined income
        impot_commun = revenu_total * rates["married_rate"]

        return {
            "revenu_impose_commun": round(revenu_total, 2),
            "impot_commun": round(impot_commun, 2),
            "taux_applique": rates["married_rate"],
            "source": "LIFD art. 36",
        }

    def _compute_tax_after(
        self, data: DivorceInput, partage_fortune: dict
    ) -> dict:
        """Compute estimated individual tax after divorce.

        After divorce, each spouse is taxed individually.
        - The spouse receiving children may benefit from single-parent rate
        - Pension alimentaire: deductible for payer (LIFD art. 33),
          taxable for receiver (LIFD art. 23)

        Returns:
            dict with impot_conjoint_1, impot_conjoint_2, delta_total
        """
        rates = self.CANTON_TAX_RATES.get(data.canton, self.DEFAULT_TAX_RATES)

        # Determine who has higher income (used for pension alimentaire direction)
        pension_est = self._estimate_pension_alimentaire(data)

        # Determine rates (single with children gets reduced rate)
        # Simplified assumption: if children, the lower-income parent gets custody
        has_children = data.nombre_enfants > 0

        if has_children:
            # Lower income conjoint gets child rate, higher income stays single
            if data.revenu_annuel_conjoint_1 <= data.revenu_annuel_conjoint_2:
                rate_1 = rates["single_child_rate"]
                rate_2 = rates["single_rate"]
            else:
                rate_1 = rates["single_rate"]
                rate_2 = rates["single_child_rate"]
        else:
            rate_1 = rates["single_rate"]
            rate_2 = rates["single_rate"]

        # Tax on individual income
        # Pension alimentaire: payer deducts, receiver adds
        if data.revenu_annuel_conjoint_1 > data.revenu_annuel_conjoint_2:
            revenu_1_apres = data.revenu_annuel_conjoint_1 - pension_est
            revenu_2_apres = data.revenu_annuel_conjoint_2 + pension_est
        elif data.revenu_annuel_conjoint_2 > data.revenu_annuel_conjoint_1:
            revenu_1_apres = data.revenu_annuel_conjoint_1 + pension_est
            revenu_2_apres = data.revenu_annuel_conjoint_2 - pension_est
        else:
            revenu_1_apres = data.revenu_annuel_conjoint_1
            revenu_2_apres = data.revenu_annuel_conjoint_2

        impot_1 = max(0.0, revenu_1_apres) * rate_1
        impot_2 = max(0.0, revenu_2_apres) * rate_2
        impot_total_apres = impot_1 + impot_2

        impot_avant = (
            (data.revenu_annuel_conjoint_1 + data.revenu_annuel_conjoint_2)
            * rates["married_rate"]
        )
        delta = impot_total_apres - impot_avant

        return {
            "impot_conjoint_1": round(impot_1, 2),
            "impot_conjoint_2": round(impot_2, 2),
            "impot_total_apres": round(impot_total_apres, 2),
            "delta_total": round(delta, 2),
            "explication": (
                "Apres le divorce, chaque conjoint est impose individuellement. "
                "La pension alimentaire est deductible pour le debiteur "
                "(LIFD art. 33) et imposable pour le creancier (LIFD art. 23)."
            ),
            "source": "LIFD art. 33, LIFD art. 23",
        }

    def _estimate_pension_alimentaire(self, data: DivorceInput) -> float:
        """Estimate pension alimentaire (alimony).

        Rough estimation based on:
        - Revenue gap between spouses
        - Number of children
        - Duration of marriage (longer = more likely spousal maintenance)

        This is NOT legal advice. Actual amounts are determined by the judge.

        Returns:
            Monthly pension alimentaire estimate in CHF/month
        """
        # Children contribution (per child)
        pension_enfants_mensuelle = data.nombre_enfants * self.PENSION_CHILD_MONTHLY_BASE

        # Spousal maintenance: only for longer marriages with income disparity
        revenu_gap = abs(
            data.revenu_annuel_conjoint_1 - data.revenu_annuel_conjoint_2
        )

        if data.duree_mariage_annees >= self.LONG_MARRIAGE_THRESHOLD and revenu_gap > 0:
            # Simplified: ~15% of monthly income gap for long marriages
            pension_conjoint_mensuelle = (revenu_gap / 12.0) * 0.15
        elif data.duree_mariage_annees >= 5 and revenu_gap > 0:
            # Shorter marriages: reduced spousal maintenance
            pension_conjoint_mensuelle = (revenu_gap / 12.0) * 0.08
        else:
            pension_conjoint_mensuelle = 0.0

        total_mensuel = pension_enfants_mensuelle + pension_conjoint_mensuelle
        return round(total_mensuel, 2)

    def _generate_checklist(self, data: DivorceInput) -> List[str]:
        """Generate action checklist for divorce proceedings.

        Returns:
            List of actionable items in French.
        """
        checklist = [
            "Obtenir un extrait du compte individuel AVS (demande a la caisse de compensation).",
            "Demander les certificats de prevoyance LPP des deux conjoints.",
            "Faire evaluer les biens immobiliers par un expert independant.",
            "Rassembler les justificatifs de fortune (comptes bancaires, titres, 3a).",
            "Consulter un avocat specialise en droit de la famille.",
            "Verifier le regime matrimonial (contrat de mariage ou regime legal).",
        ]

        if data.nombre_enfants > 0:
            checklist.append(
                "Preparer un plan de garde et de contributions d'entretien "
                "pour les enfants."
            )
            checklist.append(
                "Anticiper les allocations familiales: a qui seront-elles versees?"
            )

        if data.fortune_commune > 500000:
            checklist.append(
                "Evaluer la valeur de marche des biens immobiliers "
                "et prevoir les frais de vente eventuels."
            )

        if data.dette_commune > 0:
            checklist.append(
                "Clarifier la repartition des dettes communes "
                "(hypotheque, credits)."
            )

        checklist.append(
            "Mettre a jour les beneficiaires des assurances-vie et du 3a."
        )
        checklist.append(
            "Prevoir la separation des comptes bancaires joints."
        )

        return checklist

    def _generate_alerts(
        self,
        data: DivorceInput,
        partage_lpp: dict,
        partage_fortune: dict,
    ) -> List[str]:
        """Generate warning alerts based on the simulation.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        # Large LPP transfer
        transfert = abs(partage_lpp.get("transfert_lpp", 0))
        if transfert > 100000:
            alerts.append(
                f"Le transfert LPP est important ({transfert:,.0f} CHF). "
                f"Verifiez que la caisse de pension peut effectuer ce transfert "
                f"sans mettre en danger la couverture de prevoyance."
            )

        # Negative net fortune
        fortune_nette = partage_fortune.get("fortune_nette", 0)
        if fortune_nette < 0:
            alerts.append(
                "La fortune nette est negative (dettes superieures aux avoirs). "
                "Les dettes communes devront etre reparties entre les conjoints."
            )

        # Large income gap
        revenu_gap = abs(
            data.revenu_annuel_conjoint_1 - data.revenu_annuel_conjoint_2
        )
        if revenu_gap > 50000:
            alerts.append(
                f"L'ecart de revenus est significatif ({revenu_gap:,.0f} CHF/an). "
                f"Une pension alimentaire pour le conjoint est probable."
            )

        # Short marriage with large LPP
        total_lpp = (
            data.lpp_conjoint_1_pendant_mariage + data.lpp_conjoint_2_pendant_mariage
        )
        if data.duree_mariage_annees < 3 and total_lpp > 50000:
            alerts.append(
                "Mariage de courte duree avec des avoirs LPP significatifs. "
                "Le juge pourrait limiter le partage LPP (CC art. 124b)."
            )

        # Many children
        if data.nombre_enfants >= 3:
            alerts.append(
                f"Avec {data.nombre_enfants} enfants, les contributions "
                f"d'entretien seront substantielles. Prevoyez un budget "
                f"detaille par enfant."
            )

        # No income for one spouse
        if data.revenu_annuel_conjoint_1 == 0 or data.revenu_annuel_conjoint_2 == 0:
            alerts.append(
                "L'un des conjoints n'a pas de revenu. "
                "La reprise d'une activite professionnelle devra etre "
                "planifiee (formation, reinsertion)."
            )

        # Near retirement
        # (Not in input, but we can warn if large LPP amounts suggest older age)
        if total_lpp > 300000:
            alerts.append(
                "Les avoirs LPP sont importants. Verifiez l'impact du "
                "partage sur la rente de retraite future de chaque conjoint."
            )

        return alerts
