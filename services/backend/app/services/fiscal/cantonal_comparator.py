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


# Impôt cantonal+communal (chef-lieu) sur une PRESTATION EN CAPITAL de
# prévoyance (retrait LPP/3a) en CHF — 26 cantons x 5 montants, API
# officielle ESTV API_calculateManyCapitalTaxes (collecte 2026-07-23,
# beads MINT_nosync-2i2). Profil : célibataire, sans enfant, sans
# confession, homme 65 ans (TI/VS sensibles âge/sexe — documenté).
# L'IFD (art. 38 LIFD) N'EST PAS incluse : elle vaut exactement 1/5 du
# barème revenu (vérifié sur les 130 points : 537/3'901/10'501/17'101/
# 23'000) et se calcule via les FEDERAL_BRACKETS.
# Données brutes : .planning/.../constants-audit/capital_tax_2026/.
CAPITAL_TAX_POINTS_AMOUNT = [100_000, 250_000, 500_000, 750_000, 1_000_000]

CANTONAL_CAPITAL_TAX_CHF = {
    "AG": [4142, 13287, 29398, 45815, 62233],
    "AI": [2774, 7600, 15200, 22800, 30400],
    "AR": [7400, 18500, 39042, 63708, 88374],
    "BE": [4091, 12422, 30758, 51708, 73154],
    "BL": [3300, 8250, 23100, 47850, 72600],
    "BS": [4750, 16750, 36750, 56750, 76750],
    "FR": [2700, 13500, 36000, 58500, 81000],
    "GE": [3588, 11650, 26550, 42203, 58069],
    "GL": [4828, 12070, 24140, 36210, 48280],
    "GR": [2700, 6750, 18000, 27000, 36000],
    "JU": [5637, 17495, 37682, 57870, 78057],
    "LU": [3016, 9106, 19256, 29406, 39556],
    "NE": [5139, 15661, 31775, 48148, 64519],
    "NW": [3035, 8520, 17045, 25570, 34095],
    "OW": [5119, 12798, 25596, 38394, 51192],
    "SG": [5346, 13365, 26730, 40095, 53460],
    "SH": [2542, 7870, 15741, 23611, 31482],
    "SO": [4489, 13799, 28350, 42525, 56700],
    "SZ": [1389, 8140, 21375, 32063, 42750],
    "TG": [6024, 15060, 30120, 45180, 60240],
    "TI": [3860, 9650, 24841, 43425, 57900],  # sensible âge/sexe (homme/65 retenu)
    "UR": [3705, 9263, 18525, 27788, 37050],
    "VD": [4052, 13460, 31446, 49542, 67638],
    "VS": [4200, 11434, 33420, 60000, 80000],  # sensible âge/sexe (homme/65 retenu)
    "ZG": [2197, 7352, 17752, 28152, 38552],
    "ZH": [4280, 10700, 24567, 52601, 86542],
}

# Impôt cantonal+communal (chef-lieu) sur une prestation en capital, état civil
# MARIÉ — MÊME grille/points que CANTONAL_CAPITAL_TAX_CHF, API officielle ESTV
# API_calculateManyCapitalTaxes (Relationship=2, collecte 2026-07-28). Remplace
# le rabais forfaitaire inventé MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON (8/26 +
# FALLBACK 0.82) : le traitement marié est un effet de BARÈME (splitting), pas
# un coefficient plat — ex. ZH sans réduction ≤ 250k puis 0.61 à 750k.
# Vérification : le même pipeline reproduit EXACTEMENT les 130 points
# célibataires committés (0 écart) -> collecte mariée aussi autoritaire.
# Données brutes : .planning/audit-etat-des-lieux-2026-07/constants-audit/
# capital_marie_2026/. L'IFD (art. 38) reste dérivée du barème célibataire
# (FEDERAL_BRACKETS) — approximation pré-existante hors périmètre (cantonal).
CANTONAL_CAPITAL_TAX_MARRIED_CHF = {
    "AG": [2846, 11208, 26573, 42377, 58795],
    "AI": [2220, 7258, 15200, 22800, 30400],
    "AR": [5550, 13876, 29282, 47782, 66282],
    "BE": [3438, 11297, 27484, 47071, 67903],
    "BL": [3300, 8250, 23100, 47850, 72600],
    "BS": [4750, 16750, 36750, 56750, 76750],
    "FR": [2340, 12600, 35100, 57600, 80100],
    "GE": [2365, 9680, 23302, 37817, 53101],
    "GL": [4828, 12070, 24140, 36210, 48280],
    "GR": [2700, 6750, 13500, 27000, 36000],
    "JU": [4687, 13822, 29259, 44697, 60134],
    "LU": [3016, 9106, 19256, 29406, 39556],
    "NE": [4725, 13931, 31333, 47302, 63625],
    "NW": [2480, 8157, 17041, 25566, 34091],
    "OW": [5119, 12798, 25596, 38394, 51192],
    "SG": [4860, 12150, 24300, 36450, 48600],
    "SH": [1810, 6929, 15741, 23611, 31482],
    "SO": [3442, 12244, 27769, 42526, 56701],  # 750k/1M : ESTV arrondit +1 CHF (pas de réduction à haut montant)
    "SZ": [917, 4419, 16999, 32063, 42750],
    "TG": [5020, 12550, 25100, 37650, 50200],
    "TI": [3860, 9650, 19300, 28950, 54019],  # sensible âge/sexe (homme/65 retenu)
    "UR": [3705, 9263, 18525, 27788, 37050],
    "VD": [3281, 11360, 27705, 45743, 63840],
    "VS": [4116, 11206, 32751, 58800, 78400],  # sensible âge/sexe (homme/65 retenu)
    "ZG": [1558, 6546, 17205, 27605, 38005],
    "ZH": [4280, 10700, 21400, 32100, 57652],
}


def estimate_capital_withdrawal_tax(
    amount: float,
    canton: str,
    is_married: bool = False,
) -> float:
    """Impôt total sur un retrait en capital 2e/3e pilier — modèle v2 -2i2.

    IFD art. 38 (1/5 du barème revenu progressif, plafond 11.5%/5) +
    impôt cantonal+communal INTERPOLÉ entre points calibrés ESTV.
    Remplace « taux de base cantonal x multiplicateurs par tranche »
    (approximation à ±40% sur certains cantons). Marié : part cantonale
    interpolée sur ``CANTONAL_CAPITAL_TAX_MARRIED_CHF`` (collecte ESTV
    état civil marié) — comme le célibataire, plus de rabais forfaitaire.
    L'IFD reste dérivée du barème célibataire (``FEDERAL_BRACKETS``,
    art. 36 al. 1) pour les deux états civils (approximation pré-existante).

    Interpolation : linéaire sur l'impôt ; <100k : linéaire depuis (0, 0) ;
    >1M : extrapolation à la pente du dernier segment. Estimation
    éducative, jamais un conseil fiscal (LSFin).
    """
    if amount <= 0:
        return 0.0

    # IFD art. 38 : 1/5 du barème revenu appliqué au montant.
    ifd_full = 0.0
    prev_bound = 0.0
    for upper, rate in FEDERAL_BRACKETS:
        if amount <= prev_bound:
            break
        taxable = min(amount, upper) - prev_bound
        ifd_full += taxable * rate
        prev_bound = upper
    ifd = ifd_full / 5.0

    table = (
        CANTONAL_CAPITAL_TAX_MARRIED_CHF if is_married else CANTONAL_CAPITAL_TAX_CHF
    )
    pts = table.get(canton.upper())
    if pts is None:
        pts = [
            sum(v[i] for v in table.values()) / len(table)
            for i in range(len(CAPITAL_TAX_POINTS_AMOUNT))
        ]
    amounts = CAPITAL_TAX_POINTS_AMOUNT
    if amount <= amounts[0]:
        cantonal = pts[0] * (amount / amounts[0])
    elif amount >= amounts[-1]:
        slope = (pts[-1] - pts[-2]) / (amounts[-1] - amounts[-2])
        cantonal = pts[-1] + slope * (amount - amounts[-1])
    else:
        cantonal = pts[-1]
        for i in range(len(amounts) - 1):
            if amounts[i] <= amount <= amounts[i + 1]:
                ratio = (amount - amounts[i]) / (amounts[i + 1] - amounts[i])
                cantonal = pts[i] + ratio * (pts[i + 1] - pts[i])
                break

    return round(ifd + cantonal, 2)


def estimate_income_tax_parts(
    taxable_income: float,
    canton: str,
    is_married: bool = False,
) -> tuple:
    """(impôt fédéral, impôt cantonal+communal) — mêmes conventions que
    ``estimate_income_tax`` (v2). Le facteur marié x0.80 (splitting,
    approximation LHID) est appliqué PROPORTIONNELLEMENT aux deux parts :
    la somme arrondie == le total canonique. Consommé par l'écran
    comparaison cantonale (beads compare-v2) qui doit afficher la
    décomposition sans recomposer un modèle parallèle."""
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

    if is_married:
        impot_federal *= 0.80
        impot_cantonal *= 0.80
    return impot_federal, impot_cantonal


def estimate_marginal_rate(
    taxable_income: float,
    canton: str,
    is_married: bool = False,
) -> float:
    """Taux marginal — PENTE LOCALE du modele canonique, jamais une table.

    Le taux marginal n'est pas une donnee : c'est une DERIVEE de
    ``CANTONAL_COMMUNAL_TAX_CHF``. Toute table qui le stocke est, par
    construction, une copie qui divergera. Le depot en portait huit, qui
    donnaient pour Zurich 0.30, 0.28, 0.28, 0.34, 0.25 et 0.129 — jusqu'a
    dix points d'ecart entre deux surfaces du meme produit.

    Mesure du 2026-07-27 contre cette fonction, sur 12 couples
    canton/revenu : l'ancienne composition ``IFD_2024 + add-on cantonal``
    de ``rules_engine`` surestimait de +11.2 points en moyenne, soit une
    economie d'impot 3a annoncee jusqu'a +74 % au-dessus du reel a Zoug.

    Bornee a [0.0, 0.50]. Un plancher non nul inventerait une economie
    pour un revenu non impose.
    """
    if taxable_income <= 0:
        return 0.0
    delta = min(1000.0, taxable_income)
    hi = estimate_income_tax(taxable_income, canton, is_married=is_married)
    lo = estimate_income_tax(taxable_income - delta, canton, is_married=is_married)
    return max(0.0, min(0.50, (hi - lo) / delta))


def estimate_tax_saving(
    taxable_income: float,
    deduction: float,
    canton: str,
    is_married: bool = False,
) -> float:
    """Economie fiscale d'une deduction — DIFFERENCE d'impot, pas un produit.

    ``deduction x taux_marginal`` est une approximation qui se degrade des
    que la deduction traverse un palier : le taux marginal du dernier franc
    n'est pas celui des 7'258 francs precedents. La difference d'impot est
    exacte par construction.
    """
    if deduction <= 0 or taxable_income <= 0:
        return 0.0
    hi = estimate_income_tax(taxable_income, canton, is_married=is_married)
    lo = estimate_income_tax(
        max(0.0, taxable_income - deduction), canton, is_married=is_married
    )
    return max(0.0, hi - lo)


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
    # Review #997 : le facteur marié s'applique à la SOMME (ordre des
    # flottants bit-identique à l'ancien corps — les parités croisées
    # RvC/Dart sont gelées au centime ; x0.80 par part peut dévier d'un
    # centime après arrondi, ex. TG 280'195 marié).
    fed, cant = estimate_income_tax_parts(taxable_income, canton)
    total = fed + cant
    if is_married:
        total *= 0.80
    return round(total, 2)


def estimate_income_tax_on_rente(
    rente_annuelle: float,
    canton: str,
    is_married: bool = False,
) -> float:
    """Impôt revenu sur une rente LPP/AVS — convention CANONIQUE partagée.

    Revenu imposable ≈ 85% de la rente (déductions forfaitaires LIFD
    art. 33, simplification documentée) sur le modèle v2. Consommée par
    rente_vs_capital ET LppConversionService (beads MINT_nosync-amq —
    le 4e moteur taxait la rente à un taux marginal FLAT 25%).
    Comportement verrouillé par rvc_parity_v1.json + le miroir Dart
    estimateIncomeTaxOnRenteRvc.
    """
    return estimate_income_tax(
        rente_annuelle * 0.85,
        canton,
        is_married=is_married,
        income_factor_base=rente_annuelle,
    )


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

        if canton not in CANTONAL_COMMUNAL_TAX_CHF:
            raise ValueError(
                f"Canton inconnu: '{canton}'. "
                f"Codes valides: {', '.join(sorted(CANTONAL_COMMUNAL_TAX_CHF.keys()))}"
            )

        if income <= 0:
            raise ValueError("Le revenu doit etre superieur a 0 CHF.")

        # 1. Revenu imposable (simplification documentée : ~85% du brut)
        revenu_imposable = income * 0.85

        # 2. Modèle v2 canonique (beads compare-v2) : IFD progressif +
        # interpolation ESTV 130 points — remplace « taux effectif 100k x
        # facteur de revenu » dont les différences d'impôt étaient fausses.
        # FL rejeté comme avant (« not a Swiss canton », vérifié sur dev).
        is_married = civil_status == "marie"
        impot_federal, impot_cantonal_communal = estimate_income_tax_parts(
            revenu_imposable, canton, is_married=is_married
        )

        # 3. Enfants : réduction supplémentaire RELATIVE à marié sans
        # enfant (ratios de l'ancienne grille FAMILY_ADJUSTMENTS,
        # approximation des déductions par enfant). Célibataire avec
        # enfants : inchangé (comme avant), limite dite.
        if is_married and children > 0:
            child_factor = self._get_family_adjustment(
                civil_status, children
            ) / FAMILY_ADJUSTMENTS["marie_sans_enfant"]
            impot_federal *= child_factor
            impot_cantonal_communal *= child_factor

        impot_federal = round(impot_federal, 2)
        impot_cantonal_communal = round(impot_cantonal_communal, 2)
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
        cantons_to_compare = list(CANTONAL_COMMUNAL_TAX_CHF.keys())

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
