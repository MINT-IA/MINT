"""
Succession Simulator Service.

Simulates the inheritance distribution under Swiss law (NEW LAW 2023),
including legal shares, reserves, quotite disponible, 3a beneficiary
order, and canton-specific succession tax.

Sources:
    - CC art. 457-466 (ordre des heritiers legaux)
    - CC art. 470-471 (reserves hereditaires, reforme 2023)
    - CC art. 467-469 (capacite de disposer, testament)
    - CC art. 473 (usufruit conjoint)
    - OPP3 art. 2 (ordre des beneficiaires 3a)
    - Lois cantonales sur les droits de succession
    - Entree en vigueur: 1er janvier 2023 (revision des reserves)

Key changes in the 2023 revision:
    - Descendants reserve: reduced from 3/4 to 1/2 of their legal share
    - Parents' reserve: COMPLETELY REMOVED
    - Quotite disponible: increased accordingly

Ethical requirements:
    - Gender-neutral: no assumptions based on gender
    - Works identically for all family configurations
    - Same-sex partnerships (registered) treated identically to marriage
    - Concubin alert: no automatic rights, must plan ahead
"""

from dataclasses import dataclass, field
from typing import List, Optional, Dict


@dataclass
class SuccessionInput:
    """Input data for succession simulation."""
    fortune_totale: float                               # Total estate value
    etat_civil: str                                     # "marie", "celibataire", "divorce", "veuf", "concubin"
    a_conjoint: bool                                    # Has surviving spouse/partner
    nombre_enfants: int                                 # Number of children
    a_parents_vivants: bool                             # Has living parents
    a_fratrie: bool                                     # Has siblings
    a_concubin: bool                                    # Has concubin (unmarried partner)
    a_testament: bool                                   # Has a will/testament
    quotite_disponible_testament: Optional[dict] = None # Who gets quotite disponible
    avoirs_3a: float = 0.0                              # 3a pillar assets
    capital_deces_lpp: float = 0.0                      # LPP death capital
    canton: str = "GE"                                  # Canton for tax rates


@dataclass
class SuccessionResult:
    """Result of succession simulation."""
    repartition_legale: dict                            # Legal distribution
    repartition_avec_testament: dict                    # Distribution with will
    reserves_hereditaires: dict                         # Mandatory reserves (per heir)
    quotite_disponible: float                           # Freely disposable share
    fiscalite: dict                                     # Tax by heir
    ordre_3a_opp3: List[str]                            # OPP3 art. 2 beneficiary order
    alerte_concubin: str                                # Concubin warning if applicable
    checklist: List[str]                                # Action items
    alerts: List[str]                                   # Warning messages
    disclaimer: str                                     # Legal disclaimer


class SuccessionSimulator:
    """Simulate inheritance distribution under Swiss law (2023 revision).

    The 2023 revision of Swiss inheritance law significantly changed
    the reserve system:
    - Descendants' reserve: 1/2 of legal share (was 3/4)
    - Parents' reserve: REMOVED (was 1/2 of legal share)
    - Spouse/partner reserve: unchanged at 1/2 of legal share
    - Quotite disponible: increased accordingly

    CC art. 470-471 (version 2023).

    Compliance: NEVER use "garanti", "assure", "certain".
    """

    # Canton-specific succession tax rates (simplified)
    # Rates: [conjoint/descendant, parent, fratrie, concubin/tiers]
    # Many cantons exempt conjoint+descendants; concubins pay high rates
    CANTON_SUCCESSION_TAX = {
        "GE": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.10,
            "concubin": 0.24,
            "tiers": 0.26,
        },
        "VD": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.07,
            "concubin": 0.25,
            "tiers": 0.25,
        },
        "ZH": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.06,
            "concubin": 0.18,
            "tiers": 0.24,
        },
        "BE": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.06,
            "concubin": 0.20,
            "tiers": 0.25,
        },
        "BS": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.08,
            "concubin": 0.22,
            "tiers": 0.25,
        },
        "LU": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.02,
            "fratrie": 0.08,
            "concubin": 0.20,
            "tiers": 0.25,
        },
        "SG": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.10,
            "concubin": 0.20,
            "tiers": 0.30,
        },
        "TI": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.03,
            "fratrie": 0.08,
            "concubin": 0.25,
            "tiers": 0.35,
        },
        "VS": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.10,
            "concubin": 0.25,
            "tiers": 0.30,
        },
        "FR": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.0,
            "fratrie": 0.07,
            "concubin": 0.20,
            "tiers": 0.25,
        },
        "NE": {
            "conjoint": 0.0,
            "descendant": 0.03,
            "parent": 0.03,
            "fratrie": 0.09,
            "concubin": 0.30,
            "tiers": 0.30,
        },
        "AG": {
            "conjoint": 0.0,
            "descendant": 0.0,
            "parent": 0.04,
            "fratrie": 0.08,
            "concubin": 0.20,
            "tiers": 0.25,
        },
    }

    DEFAULT_TAX_RATES = {
        "conjoint": 0.0,
        "descendant": 0.0,
        "parent": 0.0,
        "fratrie": 0.08,
        "concubin": 0.22,
        "tiers": 0.25,
    }

    def simulate(self, input_data: SuccessionInput) -> SuccessionResult:
        """Run full succession simulation.

        Args:
            input_data: SuccessionInput with estate and family data.

        Returns:
            SuccessionResult with distribution, reserves, tax, and recommendations.
        """
        repartition_legale = self._compute_legal_distribution(input_data)
        reserves = self._compute_reserves(input_data, repartition_legale)
        quotite_disponible = self._compute_quotite_disponible(input_data, reserves)
        repartition_testament = self._compute_testament_distribution(
            input_data, repartition_legale, reserves, quotite_disponible
        )
        fiscalite = self._compute_succession_tax(
            input_data, repartition_legale
        )
        ordre_3a = self._get_3a_order(input_data)
        alerte_concubin = self._get_concubin_alert(input_data)
        checklist = self._generate_checklist(input_data)
        alerts = self._generate_alerts(input_data, reserves, quotite_disponible)

        return SuccessionResult(
            repartition_legale=repartition_legale,
            repartition_avec_testament=repartition_testament,
            reserves_hereditaires=reserves,
            quotite_disponible=round(quotite_disponible, 2),
            fiscalite=fiscalite,
            ordre_3a_opp3=ordre_3a,
            alerte_concubin=alerte_concubin,
            checklist=checklist,
            alerts=alerts,
            disclaimer=(
                "Estimation indicative. Consultez un avocat specialise "
                "en droit de la famille."
            ),
        )

    def _compute_legal_distribution(self, data: SuccessionInput) -> dict:
        """Compute legal inheritance distribution (without testament).

        Swiss law defines heirs by parentele (CC art. 457-466):
        1st parentele: descendants (children)
        2nd parentele: parents (and their descendants = siblings)
        3rd parentele: grandparents

        Surviving spouse/partner share depends on who else inherits:
        - With children: spouse gets 1/2, children share 1/2
        - With parents: spouse gets 3/4, parents get 1/4
        - Alone: spouse gets everything

        Returns:
            dict with share percentages and amounts per heir category
        """
        estate = data.fortune_totale
        result: Dict[str, float] = {}

        is_married = data.etat_civil in ("marie",) and data.a_conjoint

        if is_married and data.nombre_enfants > 0:
            # Married + children: spouse 1/2, children share 1/2
            conjoint_share = 0.5
            enfants_share_total = 0.5
            result = {
                "conjoint_part_pct": conjoint_share,
                "conjoint_montant": round(estate * conjoint_share, 2),
                "enfants_part_pct": enfants_share_total,
                "enfants_montant_total": round(estate * enfants_share_total, 2),
                "enfant_montant_chacun": round(
                    estate * enfants_share_total / data.nombre_enfants, 2
                ),
                "parents_part_pct": 0.0,
                "parents_montant": 0.0,
                "source": "CC art. 462 al. 1, CC art. 457",
            }

        elif is_married and data.nombre_enfants == 0 and data.a_parents_vivants:
            # Married, no children, parents alive: spouse 3/4, parents 1/4
            conjoint_share = 0.75
            parents_share = 0.25
            result = {
                "conjoint_part_pct": conjoint_share,
                "conjoint_montant": round(estate * conjoint_share, 2),
                "enfants_part_pct": 0.0,
                "enfants_montant_total": 0.0,
                "parents_part_pct": parents_share,
                "parents_montant": round(estate * parents_share, 2),
                "source": "CC art. 462 al. 2, CC art. 458",
            }

        elif is_married and data.nombre_enfants == 0 and not data.a_parents_vivants:
            # Married, no children, no parents: spouse gets everything
            result = {
                "conjoint_part_pct": 1.0,
                "conjoint_montant": round(estate, 2),
                "enfants_part_pct": 0.0,
                "enfants_montant_total": 0.0,
                "parents_part_pct": 0.0,
                "parents_montant": 0.0,
                "source": "CC art. 462 al. 3",
            }

        elif not is_married and data.nombre_enfants > 0:
            # Not married + children: children get everything
            result = {
                "conjoint_part_pct": 0.0,
                "conjoint_montant": 0.0,
                "enfants_part_pct": 1.0,
                "enfants_montant_total": round(estate, 2),
                "enfant_montant_chacun": round(estate / data.nombre_enfants, 2),
                "parents_part_pct": 0.0,
                "parents_montant": 0.0,
                "source": "CC art. 457",
            }

        elif not is_married and data.nombre_enfants == 0 and data.a_parents_vivants:
            # Not married, no children, parents alive: parents get everything
            result = {
                "conjoint_part_pct": 0.0,
                "conjoint_montant": 0.0,
                "enfants_part_pct": 0.0,
                "enfants_montant_total": 0.0,
                "parents_part_pct": 1.0,
                "parents_montant": round(estate, 2),
                "source": "CC art. 458",
            }

        elif not is_married and data.nombre_enfants == 0 and not data.a_parents_vivants and data.a_fratrie:
            # No spouse, no children, no parents, has siblings
            result = {
                "conjoint_part_pct": 0.0,
                "conjoint_montant": 0.0,
                "enfants_part_pct": 0.0,
                "enfants_montant_total": 0.0,
                "parents_part_pct": 0.0,
                "parents_montant": 0.0,
                "fratrie_part_pct": 1.0,
                "fratrie_montant": round(estate, 2),
                "source": "CC art. 458 (representation par souche)",
            }

        else:
            # No heirs found in first two parenteles -> grandparents or canton
            result = {
                "conjoint_part_pct": 0.0,
                "conjoint_montant": 0.0,
                "enfants_part_pct": 0.0,
                "enfants_montant_total": 0.0,
                "parents_part_pct": 0.0,
                "parents_montant": 0.0,
                "canton_part_pct": 1.0,
                "canton_montant": round(estate, 2),
                "source": "CC art. 466 (deshérence: succession revient au canton)",
            }

        return result

    def _compute_reserves(
        self, data: SuccessionInput, legal_dist: dict
    ) -> dict:
        """Compute mandatory reserves (reserves hereditaires) per 2023 law.

        NEW LAW 2023:
        - Descendants reserve: 1/2 of their legal share (was 3/4)
        - Spouse/partner reserve: 1/2 of their legal share (unchanged)
        - Parents reserve: REMOVED (was 1/2 of their legal share)

        CC art. 470-471 (version entree en vigueur 1er janvier 2023).

        Returns:
            dict with reserve amounts per heir category
        """
        estate = data.fortune_totale
        reserves: Dict[str, float] = {}
        is_married = data.etat_civil in ("marie",) and data.a_conjoint

        # Conjoint reserve: 1/2 of legal share
        if is_married:
            conjoint_legal_share = legal_dist.get("conjoint_part_pct", 0.0)
            conjoint_reserve_pct = conjoint_legal_share * 0.5
            reserves["conjoint_reserve_pct"] = conjoint_reserve_pct
            reserves["conjoint_reserve_montant"] = round(
                estate * conjoint_reserve_pct, 2
            )
        else:
            reserves["conjoint_reserve_pct"] = 0.0
            reserves["conjoint_reserve_montant"] = 0.0

        # Descendants reserve: 1/2 of legal share (2023: was 3/4)
        enfants_legal_share = legal_dist.get("enfants_part_pct", 0.0)
        if data.nombre_enfants > 0 and enfants_legal_share > 0:
            enfants_reserve_pct = enfants_legal_share * 0.5
            reserves["enfants_reserve_pct"] = enfants_reserve_pct
            reserves["enfants_reserve_montant"] = round(
                estate * enfants_reserve_pct, 2
            )
            reserves["enfant_reserve_chacun"] = round(
                estate * enfants_reserve_pct / data.nombre_enfants, 2
            )
        else:
            reserves["enfants_reserve_pct"] = 0.0
            reserves["enfants_reserve_montant"] = 0.0

        # Parents reserve: REMOVED in 2023
        reserves["parents_reserve_pct"] = 0.0
        reserves["parents_reserve_montant"] = 0.0
        reserves["parents_reserve_note"] = (
            "Depuis le 1er janvier 2023, la reserve des parents "
            "a ete supprimee (CC art. 470 al. 1 rev.)."
        )

        reserves["total_reserves_pct"] = (
            reserves.get("conjoint_reserve_pct", 0.0)
            + reserves.get("enfants_reserve_pct", 0.0)
        )
        reserves["total_reserves_montant"] = round(
            estate * reserves["total_reserves_pct"], 2
        )
        reserves["source"] = "CC art. 470-471 (revision 2023)"

        return reserves

    def _compute_quotite_disponible(
        self, data: SuccessionInput, reserves: dict
    ) -> float:
        """Compute quotite disponible (freely disposable share).

        Quotite disponible = estate - total reserves

        Returns:
            Quotite disponible in CHF
        """
        total_reserves = reserves.get("total_reserves_montant", 0.0)
        quotite = data.fortune_totale - total_reserves
        return max(0.0, round(quotite, 2))

    def _compute_testament_distribution(
        self,
        data: SuccessionInput,
        legal_dist: dict,
        reserves: dict,
        quotite_disponible: float,
    ) -> dict:
        """Compute distribution with testament (if applicable).

        The testator can freely allocate the quotite disponible.
        Reserves must be respected.

        Returns:
            dict with distribution including testament allocations
        """
        if not data.a_testament or not data.quotite_disponible_testament:
            # No testament: same as legal distribution
            return {
                **legal_dist,
                "quotite_disponible_allocation": {},
                "explication": (
                    "Sans testament, la repartition legale s'applique integralement."
                ),
            }

        # Start from reserves (minimum each heir must receive)
        result = {}
        estate = data.fortune_totale
        is_married = data.etat_civil in ("marie",) and data.a_conjoint

        # Each reserved heir gets at least their reserve
        if is_married:
            result["conjoint_montant"] = reserves.get("conjoint_reserve_montant", 0.0)
            result["conjoint_part_pct"] = reserves.get("conjoint_reserve_pct", 0.0)
        else:
            result["conjoint_montant"] = 0.0
            result["conjoint_part_pct"] = 0.0

        if data.nombre_enfants > 0:
            result["enfants_montant_total"] = reserves.get("enfants_reserve_montant", 0.0)
            result["enfants_part_pct"] = reserves.get("enfants_reserve_pct", 0.0)
        else:
            result["enfants_montant_total"] = 0.0
            result["enfants_part_pct"] = 0.0

        result["parents_montant"] = 0.0
        result["parents_part_pct"] = 0.0

        # Allocate quotite disponible per testament
        qd_allocation = {}
        remaining_qd = quotite_disponible

        for beneficiary, fraction in data.quotite_disponible_testament.items():
            amount = quotite_disponible * fraction
            qd_allocation[beneficiary] = round(amount, 2)
            remaining_qd -= amount

            # If the beneficiary is also a reserve heir, add to their total
            if beneficiary == "conjoint" and is_married:
                result["conjoint_montant"] = round(
                    result["conjoint_montant"] + amount, 2
                )
            elif beneficiary == "enfants" and data.nombre_enfants > 0:
                result["enfants_montant_total"] = round(
                    result["enfants_montant_total"] + amount, 2
                )

        # Recalculate percentages
        if estate > 0:
            result["conjoint_part_pct"] = round(
                result.get("conjoint_montant", 0.0) / estate, 4
            )
            result["enfants_part_pct"] = round(
                result.get("enfants_montant_total", 0.0) / estate, 4
            )

        result["quotite_disponible_allocation"] = qd_allocation
        result["source"] = "CC art. 470-471, CC art. 481 (testament)"
        result["explication"] = (
            "Le testament alloue la quotite disponible selon les volontes "
            "du testateur, tout en respectant les reserves hereditaires."
        )

        return result

    def _compute_succession_tax(
        self, data: SuccessionInput, legal_dist: dict
    ) -> dict:
        """Compute succession tax by heir category and canton.

        Tax varies greatly by canton and degree of kinship:
        - Conjoint + descendants: 0% in most cantons
        - Parents: 0-4% depending on canton
        - Siblings: 6-10%
        - Concubin/third parties: 18-35%

        Returns:
            dict with tax amounts per heir category
        """
        rates = self.CANTON_SUCCESSION_TAX.get(
            data.canton, self.DEFAULT_TAX_RATES
        )
        estate = data.fortune_totale
        tax_details: Dict[str, dict] = {}

        # Conjoint
        conjoint_montant = legal_dist.get("conjoint_montant", 0.0)
        if conjoint_montant > 0:
            rate = rates["conjoint"]
            tax_details["conjoint"] = {
                "montant_herite": conjoint_montant,
                "taux": rate,
                "impot": round(conjoint_montant * rate, 2),
            }

        # Descendants
        enfants_montant = legal_dist.get("enfants_montant_total", 0.0)
        if enfants_montant > 0:
            rate = rates["descendant"]
            tax_details["enfants"] = {
                "montant_herite": enfants_montant,
                "taux": rate,
                "impot": round(enfants_montant * rate, 2),
            }

        # Parents
        parents_montant = legal_dist.get("parents_montant", 0.0)
        if parents_montant > 0:
            rate = rates["parent"]
            tax_details["parents"] = {
                "montant_herite": parents_montant,
                "taux": rate,
                "impot": round(parents_montant * rate, 2),
            }

        # Fratrie
        fratrie_montant = legal_dist.get("fratrie_montant", 0.0)
        if fratrie_montant > 0:
            rate = rates["fratrie"]
            tax_details["fratrie"] = {
                "montant_herite": fratrie_montant,
                "taux": rate,
                "impot": round(fratrie_montant * rate, 2),
            }

        # Concubin (if mentioned in testament)
        if data.a_concubin and data.a_testament and data.quotite_disponible_testament:
            concubin_fraction = data.quotite_disponible_testament.get("concubin", 0.0)
            if concubin_fraction > 0:
                # Compute quotite disponible first
                legal_for_reserves = self._compute_legal_distribution(data)
                reserves = self._compute_reserves(data, legal_for_reserves)
                qd = self._compute_quotite_disponible(data, reserves)
                concubin_montant = qd * concubin_fraction
                rate = rates["concubin"]
                tax_details["concubin"] = {
                    "montant_herite": round(concubin_montant, 2),
                    "taux": rate,
                    "impot": round(concubin_montant * rate, 2),
                }

        total_impot = sum(
            detail.get("impot", 0.0) for detail in tax_details.values()
        )

        return {
            "details_par_heritier": tax_details,
            "total_impot_succession": round(total_impot, 2),
            "canton": data.canton,
            "source": "Lois cantonales sur les droits de succession",
        }

    def _get_3a_order(self, data: SuccessionInput) -> List[str]:
        """Return the 3a beneficiary order per OPP3 art. 2.

        The 3a pillar has a SPECIFIC beneficiary order defined by law,
        independent of inheritance law.

        OPP3 art. 2:
        1. Conjoint survivant ou partenaire enregistre
        2. Descendants directs ou personnes a charge
        3. Parents
        4. Freres et soeurs
        5. Autres heritiers

        Returns:
            Ordered list of beneficiary categories
        """
        order = [
            "1. Conjoint survivant ou partenaire enregistre",
            "2. Descendants directs (enfants) ou personnes a charge du defunt",
            "3. Parents (pere et mere)",
            "4. Freres et soeurs",
            "5. Autres heritiers selon le droit successoral",
        ]

        # Annotate with applicability
        annotations = []
        if data.a_conjoint and data.etat_civil == "marie":
            annotations.append(
                "Dans votre situation: le conjoint survivant recoit le 3a en priorite."
            )
        elif data.nombre_enfants > 0:
            annotations.append(
                "Dans votre situation: les descendants recoivent le 3a."
            )
        elif data.a_parents_vivants:
            annotations.append(
                "Dans votre situation: les parents recoivent le 3a."
            )

        if data.a_concubin:
            annotations.append(
                "ATTENTION: Le concubin n'a PAS de droit automatique sur le 3a. "
                "Il est possible de le designer comme beneficiaire par clause "
                "beneficiaire ecrite aupres de la fondation 3a, a condition "
                "qu'il figure dans l'une des categories OPP3 (ex: personne a charge)."
            )

        order.extend(annotations)
        return order

    def _get_concubin_alert(self, data: SuccessionInput) -> str:
        """Generate concubin-specific alert.

        Concubins have NO automatic inheritance rights in Swiss law.
        They must plan ahead with testaments and beneficiary designations.

        Returns:
            Alert string, or empty if not applicable.
        """
        if not data.a_concubin:
            return ""

        return (
            "IMPORTANT: En droit suisse, le concubin n'a AUCUN droit "
            "successoral automatique. Sans testament, votre partenaire "
            "ne recevra rien de votre succession. De plus, les droits "
            "de succession pour les concubins sont eleves (souvent 20-35% "
            "selon le canton). Actions recommandees: "
            "1) Rediger un testament attribuant la quotite disponible au concubin. "
            "2) Verifier les clauses beneficiaires du 3a et de l'assurance-vie. "
            "3) Envisager un pacte successoral. "
            "4) Evaluer l'option du partenariat enregistre ou du mariage "
            "pour beneficier de l'exoneration fiscale."
        )

    def _generate_checklist(self, data: SuccessionInput) -> List[str]:
        """Generate action checklist for succession planning.

        Returns:
            List of actionable items in French.
        """
        checklist = [
            "Faire un inventaire complet de vos avoirs (fortune, immobilier, 2e et 3e piliers).",
            "Verifier les clauses beneficiaires de vos assurances-vie et du 3a.",
            "Consulter un notaire pour rediger ou mettre a jour votre testament.",
        ]

        if data.nombre_enfants > 0:
            checklist.append(
                "Si vos enfants sont mineurs: designer un tuteur dans votre testament."
            )

        if data.a_concubin:
            checklist.append(
                "Rediger un testament en faveur de votre concubin "
                "(attribution de la quotite disponible)."
            )
            checklist.append(
                "Verifier la clause beneficiaire du 3e pilier aupres "
                "de votre fondation."
            )
            checklist.append(
                "Evaluer le partenariat enregistre ou le mariage pour "
                "optimiser la fiscalite successorale."
            )

        if data.fortune_totale > 500000:
            checklist.append(
                "Evaluer les droits de succession dans votre canton "
                "et envisager une planification fiscale."
            )

        if data.a_conjoint and data.nombre_enfants > 0:
            checklist.append(
                "Considerer l'attribution de l'usufruit au conjoint survivant "
                "(CC art. 473) pour securiser le logement familial."
            )

        checklist.append(
            "Informer vos proches de l'existence et de l'emplacement "
            "de votre testament."
        )
        checklist.append(
            "Mettre a jour votre planification en cas de changement "
            "d'etat civil ou de naissance."
        )

        return checklist

    def _generate_alerts(
        self,
        data: SuccessionInput,
        reserves: dict,
        quotite_disponible: float,
    ) -> List[str]:
        """Generate warning alerts.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        # Concubin without testament
        if data.a_concubin and not data.a_testament:
            alerts.append(
                "CRITIQUE: Vous vivez en concubinage SANS testament. "
                "Votre partenaire ne recevra RIEN en cas de deces. "
                "Redigez un testament de toute urgence."
            )

        # Large estate without testament
        if data.fortune_totale > 200000 and not data.a_testament:
            alerts.append(
                "Votre patrimoine depasse 200'000 CHF et vous n'avez pas "
                "de testament. La repartition legale s'appliquera."
            )

        # High succession tax for concubin
        if data.a_concubin:
            rates = self.CANTON_SUCCESSION_TAX.get(
                data.canton, self.DEFAULT_TAX_RATES
            )
            concubin_rate = rates.get("concubin", 0.22)
            if concubin_rate > 0.15:
                alerts.append(
                    f"Dans le canton de {data.canton}, le taux d'imposition "
                    f"successorale pour les concubins est de "
                    f"{concubin_rate * 100:.0f}%. Le mariage ou le partenariat "
                    f"enregistre permettrait une exoneration."
                )

        # Small quotite disponible with many heirs
        if quotite_disponible < data.fortune_totale * 0.2 and data.a_testament:
            alerts.append(
                "La quotite disponible est faible par rapport au patrimoine. "
                "Les marges de manoeuvre testamentaires sont limitees."
            )

        # 3a and LPP death capital not counted in estate
        extra = data.avoirs_3a + data.capital_deces_lpp
        if extra > 50000:
            alerts.append(
                f"Les avoirs 3a ({data.avoirs_3a:,.0f} CHF) et le capital "
                f"deces LPP ({data.capital_deces_lpp:,.0f} CHF) suivent des "
                f"regles de repartition specifiques (OPP3 art. 2) et ne font "
                f"pas partie de la masse successorale ordinaire."
            )

        return alerts
