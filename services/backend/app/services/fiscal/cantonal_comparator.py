"""
Cantonal tax comparator — 26 Swiss cantons.

Estimates the total tax burden (federal + cantonal + communal) for a given
profile (income, civil status, children) across all 26 Swiss cantons.
Uses simplified effective rates based on published federal statistics.

The approach:
    1. Base effective rate for each canton at CHF 100'000 (single, chef-lieu)
    2. Linear interpolation for income level adjustment
    3. Family situation adjustment (splitting + deductions)
    4. Federal tax estimated separately (same everywhere, progressive)

Sources:
    - Administration federale des contributions — Charge fiscale en Suisse 2024
    - LIFD art. 36 (bareme federal)
    - LHID art. 1 (harmonisation fiscale)

Sprint S20 — Fiscalite cantonale — Comparateur 26 cantons.
"""

from dataclasses import dataclass
from typing import List


# ---------------------------------------------------------------------------
# Constants — Taux effectifs 2024/2026 (simplifies)
# ---------------------------------------------------------------------------

# Effective tax rates by canton (single, no children, 100k income, chef-lieu)
# Source: Administration federale des contributions — Charge fiscale 2024
# DÉPRÉCIÉ pour les calculs d'impôt (beads -97h) : remplacé par
# estimate_income_tax v2 (interpolation CANTONAL_COMMUNAL_TAX_CHF, 130
# points ESTV) dans RvC et rachat échelonné. Reste consommé UNIQUEMENT par
# compare() (écran comparaison cantonale) — à migrer vers v2 dans une
# itération dédiée ; ne PAS brancher de nouveau calcul dessus.
EFFECTIVE_RATES_100K_SINGLE = {
    "ZG": 0.0823,   # Zoug — lowest
    "NW": 0.0891,
    "OW": 0.0934,
    "AI": 0.0956,
    "AR": 0.1012,
    "SZ": 0.1034,
    "UR": 0.1067,
    "LU": 0.1089,
    "GL": 0.1102,
    "TG": 0.1145,
    "SH": 0.1167,
    "AG": 0.1189,
    "GR": 0.1203,
    # FL (Liechtenstein) removed — not a Swiss canton
    "BL": 0.1256,
    "SG": 0.1278,
    "ZH": 0.1290,
    "FR": 0.1312,
    "SO": 0.1334,
    "TI": 0.1356,
    "BE": 0.1389,
    "NE": 0.1423,
    "VS": 0.1456,
    "VD": 0.1489,
    "JU": 0.1512,
    "GE": 0.1545,
    "BS": 0.1578,   # Bale-Ville — highest
}

# Adjustment factors by income level (relative to 100k)
# Progressive: higher income -> higher effective rate (marginal effect)
INCOME_ADJUSTMENT = {
    50000: 0.75,    # Lower income -> lower effective rate
    80000: 0.90,
    100000: 1.00,
    150000: 1.10,
    200000: 1.18,
    300000: 1.25,
    500000: 1.32,
}

# Family adjustment (married with children -> splitting + deductions)
FAMILY_ADJUSTMENTS = {
    "celibataire": 1.00,
    "marie_sans_enfant": 0.85,   # Splitting effect
    "marie_1_enfant": 0.78,
    "marie_2_enfants": 0.72,
    "marie_3_enfants": 0.66,
}

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

# Federal tax simplified progressive brackets (LIFD art. 36)
# (upper_bound, marginal_rate) — simplified for estimation
# Barème IFD personnes seules, ANNÉE FISCALE 2026 (LIFD art. 36, seuils
# compensés de la progression à froid — DFF 2026). Audit -zaw 2026-07-23 :
# l'ancien barème portait des seuils pré-2024 ET des taux marginaux faux aux
# positions 6-10 (5.10/6.40/6.80/8.90/11.00 au lieu de
# 5.94/6.60/8.80/11.00/13.20) -> sous-estimation de l'IFD des revenus
# moyens-hauts. Sources : ESTV/AFC barèmes IFD ; compensation progression à
# froid 2026 (DFF). Revue ANNUELLE requise (indexation des seuils).
FEDERAL_BRACKETS = [
    (15_200, 0.0000),
    (33_200, 0.0077),
    (43_500, 0.0088),
    (58_000, 0.0264),
    (76_200, 0.0297),
    (82_100, 0.0594),
    (108_900, 0.0660),
    (141_500, 0.0880),
    (185_100, 0.1100),
    (794_000, 0.1320),
    (float("inf"), 0.1150),  # au-delà : taux moyen max 11.5% (art. 36 al. 1)
]

# Impôt cantonal+communal (chef-lieu) en CHF par revenu IMPOSABLE —
# 26 cantons x 5 points, API officielle ESTV (swisstaxcalculator,
# API_calculateSimpleTaxes, collecte 2026-07-23, beads MINT_nosync-97h).
# Profil : célibataire, sans enfant, sans confession, fortune 0 ;
# taxe personnelle incluse ; barèmes 2026 (SG et TI : 2025, l'ESTV
# n'avait pas encore publié leur 2026 — re-collecter à publication).
# Données brutes + vérifications : .planning/audit-etat-des-lieux-2026-07/
# constants-audit/effective_rates_2026/ (identité cantonal+communal+IFD
# == total ESTV validée sur les 130 points ; IFD recoupée Form. 58c 2026).
CANTONAL_TAX_POINTS_INCOME = [40_000, 70_000, 100_000, 150_000, 250_000]

CANTONAL_COMMUNAL_TAX_CHF = {
    "AG": [3186, 8183, 13806, 23656, 44288],
    "AI": [3146, 7022, 11096, 17860, 30400],
    "AR": [4272, 9806, 15852, 26396, 47856],
    "BE": [6839, 13129, 20273, 33232, 60810],
    "BL": [3579, 10563, 18511, 32802, 62251],
    "BS": [8400, 14700, 21000, 31500, 54844],
    "FR": [5027, 11704, 18992, 32619, 59400],
    "GE": [3706, 10593, 17967, 30803, 58279],
    "GL": [3790, 8942, 14373, 23990, 45027],
    "GR": [3097, 8622, 14368, 24362, 44579],
    "JU": [4875, 11430, 18651, 31852, 58743],
    "LU": [3410, 7760, 12110, 19648, 36020],
    "NE": [5511, 12657, 20555, 34781, 62646],
    "NW": [3220, 7634, 12191, 20054, 34130],
    "OW": [5119, 8959, 12798, 19197, 31995],
    "SG": [4238, 10356, 17071, 28492, 51334],  # barème 2025
    "SH": [3085, 7525, 12772, 21661, 39408],
    "SO": [4570, 11203, 18007, 30402, 55242],
    "SZ": [2813, 5936, 9270, 14828, 25943],
    "TG": [3703, 8974, 14440, 23852, 43827],
    "TI": [3720, 9979, 16987, 29443, 55098],  # barème 2025
    "UR": [5608, 9762, 13915, 20838, 34683],
    "VD": [5666, 12039, 19588, 33776, 65070],
    "VS": [3750, 9467, 16829, 32371, 59684],
    "ZG": [1882, 4162, 7325, 13435, 23835],
    "ZH": [2975, 7586, 13228, 23832, 48497],
}


def estimate_income_tax(
    taxable_income: float,
    canton: str,
    is_married: bool = False,
    income_factor_base: float | None = None,
) -> float:
    """Impôt sur le revenu estimé — modèle fiscal backend CANONIQUE (v2 -97h).

    IFD 2026 progressif (FEDERAL_BRACKETS, recoupé Form. 58c) + impôt
    cantonal+communal INTERPOLÉ LINÉAIREMENT entre points calibrés sur
    l'API officielle ESTV (CANTONAL_COMMUNAL_TAX_CHF, 26 cantons x 5
    points, chef-lieu, célibataire). Remplace le modèle
    « taux_effectif(100k) x clamp(revenu/100k) » quasi quadratique dont
    les DIFFÉRENCES d'impôt étaient fausses (taux marginal implicite
    47.5% à 140k VD ; le modèle interpolé donne ~38%, réaliste) — c'était
    le bloqueur de -81n (conclusions bloc/étalé inversées coach vs écran).

    Interpolation : linéaire sur l'IMPÔT entre points (monotone, vérifiée
    sur les 130 points) ; sous 40k : linéaire depuis (0, 0) ; au-dessus de
    250k : extrapolation à la pente du dernier segment. Marié : x0.80
    (splitting, approximation LHID). income_factor_base est CONSERVÉ pour
    compat de signature (l'ancien RvC le passait) mais IGNORÉ — le modèle
    v2 n'a plus de facteur d'échelle.

    Limites (dites, pas cachées) : célibataire chef-lieu sans confession ;
    les déductions réelles varient ; SG/TI barèmes 2025. Estimation
    éducative, jamais un conseil fiscal (LSFin).
    """
    impot_federal = 0.0
    prev_bound = 0.0
    for upper, rate in FEDERAL_BRACKETS:
        if taxable_income <= prev_bound:
            break
        taxable = min(taxable_income, upper) - prev_bound
        impot_federal += taxable * rate
        prev_bound = upper

    pts = CANTONAL_COMMUNAL_TAX_CHF.get(canton.upper())
    if pts is None:
        # Canton inconnu : moyenne simple des 26 (transparent, pas un 0.13 magique).
        pts = [
            sum(v[i] for v in CANTONAL_COMMUNAL_TAX_CHF.values())
            / len(CANTONAL_COMMUNAL_TAX_CHF)
            for i in range(len(CANTONAL_TAX_POINTS_INCOME))
        ]

    incomes = CANTONAL_TAX_POINTS_INCOME
    if taxable_income <= 0:
        impot_cantonal = 0.0
    elif taxable_income <= incomes[0]:
        impot_cantonal = pts[0] * (taxable_income / incomes[0])
    elif taxable_income >= incomes[-1]:
        slope = (pts[-1] - pts[-2]) / (incomes[-1] - incomes[-2])
        impot_cantonal = pts[-1] + slope * (taxable_income - incomes[-1])
    else:
        impot_cantonal = 0.0
        for i in range(len(incomes) - 1):
            if incomes[i] <= taxable_income <= incomes[i + 1]:
                ratio = (taxable_income - incomes[i]) / (incomes[i + 1] - incomes[i])
                impot_cantonal = pts[i] + ratio * (pts[i + 1] - pts[i])
                break

    total = impot_federal + impot_cantonal
    if is_married:
        total *= 0.80
    return round(total, 2)


DISCLAIMER = (
    "Estimations basées sur le barème IFD 2026 et des taux cantonaux simplifiés. "
    "Les taux effectifs varient selon la commune, la fortune, "
    "et les déductions individuelles. Consulte ton administration "
    "fiscale cantonale ou un ou une spécialiste fiscal·e. "
    "Ne constitue pas un conseil fiscal (LSFin)."
)

SOURCES = [
    "Administration fédérale des contributions — Charge fiscale en Suisse 2024",
    "LIFD art. 36 (barème fédéral)",
    "LHID art. 1 (harmonisation fiscale)",
]


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class TaxEstimate:
    """Estimated tax for a given profile in a specific canton."""
    canton: str
    canton_name: str
    revenu_imposable: float
    impot_federal: float
    impot_cantonal_communal: float
    charge_totale: float
    taux_effectif: float   # as percentage (e.g. 12.5 for 12.5%)


@dataclass
class CantonRanking:
    """A single canton entry in the ranked comparison."""
    rang: int
    canton: str
    canton_name: str
    charge_totale: float
    taux_effectif: float
    difference_vs_cheapest: float


@dataclass
class MoveSimulation:
    """Result of simulating a move between two cantons."""
    canton_depart: str
    canton_depart_nom: str
    canton_arrivee: str
    canton_arrivee_nom: str
    charge_depart: float
    charge_arrivee: float
    economie_annuelle: float
    economie_mensuelle: float
    economie_10_ans: float
    premier_eclairage: str
    alertes: List[str]
    checklist: List[str]
    disclaimer: str
    sources: List[str]


# ---------------------------------------------------------------------------
# Comparator class
# ---------------------------------------------------------------------------

class CantonalComparator:
    """Compare tax burden across 26 Swiss cantons."""

    def estimate_tax(
        self,
        income: float,
        canton: str,
        civil_status: str = "celibataire",
        children: int = 0,
    ) -> TaxEstimate:
        """Estimate total tax for a given profile in a canton.

        Args:
            income: Gross annual income (CHF).
            canton: Canton code (2 letters, e.g. "ZH", "GE").
            civil_status: "celibataire" or "marie".
            children: Number of children (0-10).

        Returns:
            TaxEstimate with federal + cantonal/communal breakdown.

        Raises:
            ValueError: If canton code is invalid or income is non-positive.
        """
        canton = canton.upper()

        if canton not in EFFECTIVE_RATES_100K_SINGLE:
            raise ValueError(
                f"Canton inconnu: '{canton}'. "
                f"Codes valides: {', '.join(sorted(EFFECTIVE_RATES_100K_SINGLE.keys()))}"
            )

        if income <= 0:
            raise ValueError("Le revenu doit etre superieur a 0 CHF.")

        # 1. Base rate for canton at 100k
        base_rate = EFFECTIVE_RATES_100K_SINGLE[canton]

        # 2. Adjust for income level
        income_factor = self._interpolate_income_adjustment(income)

        # 3. Adjust for family situation
        family_factor = self._get_family_adjustment(civil_status, children)

        # 4. Effective cantonal+communal rate
        cantonal_rate = base_rate * income_factor * family_factor

        # 5. Estimate revenu imposable (simplified: ~85% of gross for employed)
        revenu_imposable = income * 0.85

        # 6. Calculate federal tax (same everywhere)
        impot_federal = self._calculate_federal_tax(revenu_imposable, civil_status)

        # 7. Apply family adjustment to federal tax too
        if civil_status == "marie":
            # Splitting: federal tax on half income * 2 (already handled in brackets)
            # Simplified: apply family factor
            impot_federal = impot_federal * family_factor

        # 8. Cantonal + communal tax
        impot_cantonal_communal = round(income * cantonal_rate, 2)

        # 9. Total
        charge_totale = round(impot_federal + impot_cantonal_communal, 2)

        # 10. Effective rate (percentage)
        taux_effectif = round((charge_totale / income) * 100, 2)

        return TaxEstimate(
            canton=canton,
            canton_name=CANTON_NAMES.get(canton, canton),
            revenu_imposable=round(revenu_imposable, 2),
            impot_federal=round(impot_federal, 2),
            impot_cantonal_communal=impot_cantonal_communal,
            charge_totale=charge_totale,
            taux_effectif=taux_effectif,
        )

    def compare_all_cantons(
        self,
        income: float,
        civil_status: str = "celibataire",
        children: int = 0,
    ) -> List[CantonRanking]:
        """Rank all 26 cantons from cheapest to most expensive.

        Args:
            income: Gross annual income (CHF).
            civil_status: "celibataire" or "marie".
            children: Number of children.

        Returns:
            List of CantonRanking sorted by charge_totale ascending.
        """
        estimates = []
        # Use only the 26 cantons (exclude FL)
        cantons_to_compare = [
            c for c in EFFECTIVE_RATES_100K_SINGLE.keys() if c != "FL"
        ]

        for canton in cantons_to_compare:
            estimate = self.estimate_tax(income, canton, civil_status, children)
            estimates.append(estimate)

        # Sort by charge totale ascending
        estimates.sort(key=lambda e: e.charge_totale)

        # Build ranked list
        cheapest = estimates[0].charge_totale if estimates else 0
        rankings = []
        for i, est in enumerate(estimates):
            rankings.append(CantonRanking(
                rang=i + 1,
                canton=est.canton,
                canton_name=est.canton_name,
                charge_totale=est.charge_totale,
                taux_effectif=est.taux_effectif,
                difference_vs_cheapest=round(est.charge_totale - cheapest, 2),
            ))

        return rankings

    def simulate_move(
        self,
        income: float,
        canton_from: str,
        canton_to: str,
        civil_status: str = "celibataire",
        children: int = 0,
    ) -> MoveSimulation:
        """Simulate tax savings/cost of moving between cantons.

        Args:
            income: Gross annual income (CHF).
            canton_from: Current canton code.
            canton_to: Target canton code.
            civil_status: "celibataire" or "marie".
            children: Number of children.

        Returns:
            MoveSimulation with annual/monthly/10-year savings and alerts.
        """
        # Estimate both
        tax_from = self.estimate_tax(income, canton_from, civil_status, children)
        tax_to = self.estimate_tax(income, canton_to, civil_status, children)

        # Savings (positive = you save money by moving)
        economie_annuelle = round(tax_from.charge_totale - tax_to.charge_totale, 2)
        economie_mensuelle = round(economie_annuelle / 12, 2)
        economie_10_ans = round(economie_annuelle * 10, 2)

        # Build premier éclairage
        if economie_annuelle > 0:
            premier_eclairage = (
                f"En demenageant de {tax_from.canton_name} a {tax_to.canton_name}, "
                f"tu pourrais economiser environ {abs(economie_annuelle):,.0f} CHF/an "
                f"d'impots, soit {abs(economie_10_ans):,.0f} CHF sur 10 ans."
            )
        elif economie_annuelle < 0:
            premier_eclairage = (
                f"Attention: demenager de {tax_from.canton_name} a {tax_to.canton_name} "
                f"te couterait environ {abs(economie_annuelle):,.0f} CHF/an de plus "
                f"en impots, soit {abs(economie_10_ans):,.0f} CHF sur 10 ans."
            )
        else:
            premier_eclairage = (
                f"La charge fiscale est quasi identique entre "
                f"{tax_from.canton_name} et {tax_to.canton_name}."
            )

        # Alerts
        alertes = self._build_move_alerts(
            canton_from, canton_to, economie_annuelle, income
        )

        # Checklist
        checklist = self._build_move_checklist()

        return MoveSimulation(
            canton_depart=tax_from.canton,
            canton_depart_nom=tax_from.canton_name,
            canton_arrivee=tax_to.canton,
            canton_arrivee_nom=tax_to.canton_name,
            charge_depart=tax_from.charge_totale,
            charge_arrivee=tax_to.charge_totale,
            economie_annuelle=economie_annuelle,
            economie_mensuelle=economie_mensuelle,
            economie_10_ans=economie_10_ans,
            premier_eclairage=premier_eclairage,
            alertes=alertes,
            checklist=checklist,
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    # -------------------------------------------------------------------
    # Private helpers
    # -------------------------------------------------------------------

    def _interpolate_income_adjustment(self, income: float) -> float:
        """Linear interpolation between income brackets.

        Returns an adjustment factor relative to the 100k base rate.
        For incomes below 50k or above 500k, clamps to the boundary value.
        """
        sorted_brackets = sorted(INCOME_ADJUSTMENT.items())

        # Below minimum bracket
        if income <= sorted_brackets[0][0]:
            return sorted_brackets[0][1]

        # Above maximum bracket
        if income >= sorted_brackets[-1][0]:
            return sorted_brackets[-1][1]

        # Find surrounding brackets and interpolate
        for i in range(len(sorted_brackets) - 1):
            lower_income, lower_factor = sorted_brackets[i]
            upper_income, upper_factor = sorted_brackets[i + 1]

            if lower_income <= income <= upper_income:
                # Linear interpolation
                ratio = (income - lower_income) / (upper_income - lower_income)
                return lower_factor + ratio * (upper_factor - lower_factor)

        # Fallback (should never reach here)
        return 1.0

    def _get_family_adjustment(
        self, civil_status: str, children: int
    ) -> float:
        """Get adjustment factor for family situation.

        Combines civil status and number of children into a
        simplified lookup key for FAMILY_ADJUSTMENTS.
        """
        if civil_status == "celibataire":
            return FAMILY_ADJUSTMENTS["celibataire"]

        # Married / pacsé
        if children == 0:
            return FAMILY_ADJUSTMENTS["marie_sans_enfant"]
        elif children == 1:
            return FAMILY_ADJUSTMENTS["marie_1_enfant"]
        elif children == 2:
            return FAMILY_ADJUSTMENTS["marie_2_enfants"]
        else:
            # 3+ children: use marie_3_enfants as floor
            return FAMILY_ADJUSTMENTS["marie_3_enfants"]

    def _calculate_federal_tax(
        self, revenu_imposable: float, civil_status: str
    ) -> float:
        """Calculate simplified federal income tax (IFD).

        Uses progressive brackets from LIFD art. 36.
        For married couples, applies the splitting method (taxed on half,
        then doubled).
        """
        if civil_status == "marie":
            # Splitting: calculate on half, multiply by 2
            half_tax = self._apply_federal_brackets(revenu_imposable / 2)
            return round(half_tax * 2, 2)

        return round(self._apply_federal_brackets(revenu_imposable), 2)

    def _apply_federal_brackets(self, revenu: float) -> float:
        """Apply progressive federal tax brackets."""
        if revenu <= 0:
            return 0.0

        tax = 0.0
        previous_bound = 0.0

        for upper_bound, rate in FEDERAL_BRACKETS:
            if revenu <= upper_bound:
                tax += (revenu - previous_bound) * rate
                break
            else:
                tax += (upper_bound - previous_bound) * rate
                previous_bound = upper_bound

        return tax

    def _build_move_alerts(
        self,
        canton_from: str,
        canton_to: str,
        economie: float,
        income: float,
    ) -> List[str]:
        """Build alerts for a cantonal move simulation."""
        alertes = []

        alertes.append(
            "Les frais de demenagement, le nouveau loyer, et le cout de la vie "
            "local doivent etre pris en compte dans la decision."
        )

        if abs(economie) < income * 0.01:
            alertes.append(
                "L'ecart fiscal est faible (< 1% du revenu). D'autres facteurs "
                "(qualite de vie, trajet, ecoles) sont probablement plus determinants."
            )

        if economie > 0:
            alertes.append(
                "L'economie fiscale estimee ne tient pas compte des eventuelles "
                "differences de primes LAMal, de cout du logement, ou de frais de garde."
            )

        alertes.append(
            "Le demenagement doit etre effectif (residence principale) pour que "
            "le changement de domicile fiscal soit reconnu."
        )

        return alertes

    def _build_move_checklist(self) -> List[str]:
        """Build the checklist for a cantonal move."""
        return [
            "Verifier le taux d'imposition exact de ta future commune (pas seulement le canton)",
            "Comparer les primes LAMal entre les deux cantons",
            "Evaluer le cout du logement dans la nouvelle region",
            "Verifier les frais de garde d'enfants si applicable",
            "Annoncer ton depart a ta commune actuelle",
            "S'annoncer dans ta nouvelle commune dans les 14 jours",
            "Mettre a jour ton adresse aupres de l'AVS, LPP, et 3a",
            "Declarer le changement de domicile a ta caisse maladie",
        ]


# ---------------------------------------------------------------------------
# Convenience functions (functional style, like other modules)
# ---------------------------------------------------------------------------

def estimer_impot(
    income: float,
    canton: str,
    civil_status: str = "celibataire",
    children: int = 0,
) -> dict:
    """Convenience wrapper around CantonalComparator.estimate_tax()."""
    comparator = CantonalComparator()
    estimate = comparator.estimate_tax(income, canton, civil_status, children)
    return {
        "canton": estimate.canton,
        "canton_name": estimate.canton_name,
        "revenu_imposable": estimate.revenu_imposable,
        "impot_federal": estimate.impot_federal,
        "impot_cantonal_communal": estimate.impot_cantonal_communal,
        "charge_totale": estimate.charge_totale,
        "taux_effectif": estimate.taux_effectif,
    }


def comparer_cantons(
    income: float,
    civil_status: str = "celibataire",
    children: int = 0,
) -> dict:
    """Convenience wrapper around CantonalComparator.compare_all_cantons()."""
    comparator = CantonalComparator()
    rankings = comparator.compare_all_cantons(income, civil_status, children)
    return {
        "classement": [
            {
                "rang": r.rang,
                "canton": r.canton,
                "canton_name": r.canton_name,
                "charge_totale": r.charge_totale,
                "taux_effectif": r.taux_effectif,
                "difference_vs_cheapest": r.difference_vs_cheapest,
            }
            for r in rankings
        ],
        "ecart_max": rankings[-1].difference_vs_cheapest if rankings else 0,
    }


def simuler_demenagement(
    income: float,
    canton_from: str,
    canton_to: str,
    civil_status: str = "celibataire",
    children: int = 0,
) -> dict:
    """Convenience wrapper around CantonalComparator.simulate_move()."""
    comparator = CantonalComparator()
    sim = comparator.simulate_move(income, canton_from, canton_to, civil_status, children)
    return {
        "canton_depart": sim.canton_depart,
        "canton_depart_nom": sim.canton_depart_nom,
        "canton_arrivee": sim.canton_arrivee,
        "canton_arrivee_nom": sim.canton_arrivee_nom,
        "charge_depart": sim.charge_depart,
        "charge_arrivee": sim.charge_arrivee,
        "economie_annuelle": sim.economie_annuelle,
        "economie_mensuelle": sim.economie_mensuelle,
        "economie_10_ans": sim.economie_10_ans,
        "premier_eclairage": sim.premier_eclairage,
        "alertes": sim.alertes,
        "checklist": sim.checklist,
        "disclaimer": sim.disclaimer,
        "sources": sim.sources,
    }
