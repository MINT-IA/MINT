"""
Constantes d'assurances sociales suisses — source unique de verite.

Valeurs en vigueur: 2025
Derniere mise a jour: 2025-01-01

Sources officielles:
- OFAS (Office federal des assurances sociales)
- https://finpension.ch/fr/connaissances/salaire-minimum-et-maximum-lpp/
- OPP2 (Ordonnance sur la prevoyance professionnelle)
- OPP3 (Ordonnance sur les deductions admises en 3e pilier)
- LAVS / LAI / LAPG / LACI

Procedure de mise a jour annuelle:
1. Verifier les nouvelles valeurs sur le site de l'OFAS (publication ~octobre)
2. Modifier UNIQUEMENT ce fichier
3. Lancer la suite de tests: pytest
4. Mettre a jour le miroir Flutter: lib/constants/social_insurance.dart
"""

from typing import Dict, List, Tuple

# ══════════════════════════════════════════════════════════════════════════════
# LPP — Prevoyance professionnelle (2e pilier)
# Base legale: LPP art. 7, 8, 14, 16 / OPP2
# ══════════════════════════════════════════════════════════════════════════════

LPP_SEUIL_ENTREE: float = 22_680.0
"""Salaire annuel minimum pour etre soumis a la LPP (LPP art. 7)."""

LPP_DEDUCTION_COORDINATION: float = 26_460.0
"""Deduction de coordination (LPP art. 8). Salaire coordonne = brut - deduction."""

LPP_SALAIRE_COORDONNE_MIN: float = 3_780.0
"""Salaire coordonne minimum assure (LPP art. 8 al. 2)."""

LPP_SALAIRE_COORDONNE_MAX: float = 64_260.0
"""Salaire coordonne maximum assure (= LPP_SALAIRE_MAX - LPP_DEDUCTION_COORDINATION)."""

LPP_SALAIRE_MAX: float = 90_720.0
"""Salaire annuel maximum assure LPP (LPP art. 8 al. 1)."""

LPP_TAUX_CONVERSION_MIN: float = 6.8
"""Taux de conversion minimum LPP en % (LPP art. 14 al. 2). Capital -> rente."""

LPP_TAUX_CONVERSION_MIN_DECIMAL: float = 0.068
"""Taux de conversion minimum LPP en fraction decimale (0.068 = 6.8%)."""

LPP_TAUX_INTERET_MIN: float = 1.25
"""Taux d'interet minimum LPP en % (fixe par le Conseil federal)."""

LPP_BONIFICATIONS_VIEILLESSE: List[Tuple[int, int, float]] = [
    (25, 34, 0.07),   # 7%  du salaire coordonne
    (35, 44, 0.10),   # 10% du salaire coordonne
    (45, 54, 0.15),   # 15% du salaire coordonne
    (55, 65, 0.18),   # 18% du salaire coordonne
]
"""Taux de bonification de vieillesse par tranche d'age (LPP art. 16)."""

LPP_BONIFICATIONS_DICT: Dict[int, float] = {
    25: 0.07,
    35: 0.10,
    45: 0.15,
    55: 0.18,
}
"""Taux de bonification indexes par age de debut de tranche."""


def get_lpp_bonification_rate(age: int) -> float:
    """Retourne le taux de bonification LPP pour un age donne (LPP art. 16)."""
    if age >= 55:
        return 0.18
    elif age >= 45:
        return 0.15
    elif age >= 35:
        return 0.10
    elif age >= 25:
        return 0.07
    return 0.0


# ══════════════════════════════════════════════════════════════════════════════
# AVS — Assurance-vieillesse et survivants (1er pilier)
# Base legale: LAVS art. 34-40
# ══════════════════════════════════════════════════════════════════════════════

AVS_RENTE_MAX_MENSUELLE: float = 2_520.0
"""Rente AVS maximale individuelle mensuelle (LAVS art. 34)."""

AVS_RENTE_MIN_MENSUELLE: float = 1_260.0
"""Rente AVS minimale individuelle mensuelle (= 50% de la rente max)."""

AVS_RENTE_COUPLE_MAX_MENSUELLE: float = 3_780.0
"""Rente AVS maximale pour un couple mensuelle (= 150% de la rente max)."""

AVS_COTISATION_SALARIE: float = 0.053
"""Taux de cotisation AVS part salarie: 5.3% (total 10.6% avec part employeur)."""

AVS_COTISATION_TOTAL: float = 0.106
"""Taux de cotisation AVS total (salarie + employeur): 10.6%."""

AVS_DUREE_COTISATION_COMPLETE: int = 44
"""Nombre d'annees de cotisation pour une rente complete (LAVS art. 29ter)."""

AVS_AGE_REFERENCE_HOMME: int = 65
"""Age de reference AVS pour les hommes."""

AVS_AGE_REFERENCE_FEMME: int = 65
"""Age de reference AVS pour les femmes (depuis reforme AVS 21)."""

AVS_REDUCTION_ANTICIPATION: float = 0.068
"""Reduction par annee d'anticipation de la rente AVS: 6.8% (LAVS art. 40)."""

AVS_SUPPLEMENT_AJOURNEMENT: Dict[int, float] = {
    1: 0.052,    # +5.2% pour 1 an
    2: 0.106,    # +10.6% pour 2 ans
    3: 0.164,    # +16.4% pour 3 ans
    4: 0.227,    # +22.7% pour 4 ans
    5: 0.315,    # +31.5% pour 5 ans
}
"""Supplement de rente par annee d'ajournement (LAVS art. 39)."""

AVS_FRANCHISE_RETRAITE_MENSUELLE: float = 1_400.0
"""Franchise AVS pour retraites actifs, mensuelle (LAVS art. 4)."""

AVS_FRANCHISE_RETRAITE_ANNUELLE: float = 16_800.0
"""Franchise AVS pour retraites actifs, annuelle."""

AVS_SURVIVOR_FACTOR: float = 0.80
"""Facteur rente de survivant (80% de la rente du defunt)."""

# AVS volontaire (expatries)
AVS_VOLONTAIRE_COTISATION_MIN: float = 514.0
"""Cotisation annuelle minimale AVS volontaire (LAVS art. 2)."""

AVS_VOLONTAIRE_COTISATION_MAX: float = 25_700.0
"""Cotisation annuelle maximale AVS volontaire."""


# ══════════════════════════════════════════════════════════════════════════════
# AI — Assurance-invalidite
# Base legale: LAI
# ══════════════════════════════════════════════════════════════════════════════

AI_COTISATION_SALARIE: float = 0.007
"""Taux de cotisation AI part salarie: 0.7% (total 1.4%)."""

AI_COTISATION_TOTAL: float = 0.014
"""Taux de cotisation AI total: 1.4%."""

AI_RENTE_ENTIERE: float = 2_520.0
"""Rente AI entiere mensuelle (= rente AVS max). Degre invalidite >= 70%."""

AI_RENTE_DEMI: float = 1_260.0
"""Demi-rente AI mensuelle. Degre invalidite 50-69%."""

AI_BAREME: Dict[int, float] = {
    40: 0.25,     # quart de rente (40-49%)
    50: 0.50,     # demi-rente (50-59%)
    60: 0.75,     # trois-quarts de rente (60-69%)
    70: 1.00,     # rente entiere (70-100%)
    100: 1.00,
}
"""Bareme AI: degre d'invalidite -> fraction de rente."""


def get_ai_rente_monthly(disability_degree: int) -> float:
    """Return monthly AI rente based on disability degree (LAI art. 28 al. 1).

    ALL backend services MUST use this single function.
    Do NOT create local get_ai_rente_*() copies.

    Args:
        disability_degree: Disability degree in % (0-100).

    Returns:
        Monthly AI rente in CHF.
    """
    if disability_degree < 40:
        return 0.0
    if disability_degree < 50:
        return AI_RENTE_ENTIERE * AI_BAREME[40]   # 0.25 -> 630 CHF
    if disability_degree < 60:
        return AI_RENTE_ENTIERE * AI_BAREME[50]   # 0.50 -> 1260 CHF
    if disability_degree < 70:
        return AI_RENTE_ENTIERE * AI_BAREME[60]   # 0.75 -> 1890 CHF
    return AI_RENTE_ENTIERE * AI_BAREME[70]        # 1.00 -> 2520 CHF


# ══════════════════════════════════════════════════════════════════════════════
# APG — Allocations pour perte de gain
# Base legale: LAPG
# ══════════════════════════════════════════════════════════════════════════════

APG_COTISATION_SALARIE: float = 0.0025
"""Taux de cotisation APG part salarie: 0.25% (total 0.5%)."""

APG_COTISATION_TOTAL: float = 0.005
"""Taux de cotisation APG total: 0.5%."""

APG_MATERNITE_JOURS: int = 98
"""Duree du conge maternite: 98 jours = 14 semaines (LAPG art. 16d)."""

APG_MATERNITE_TAUX: float = 0.80
"""Taux d'indemnite de maternite: 80% du salaire (LAPG art. 16f)."""

APG_PATERNITE_JOURS: int = 10
"""Duree du conge paternite: 10 jours (LAPG art. 16i)."""


# ══════════════════════════════════════════════════════════════════════════════
# AC — Assurance-chomage
# Base legale: LACI
# ══════════════════════════════════════════════════════════════════════════════

AC_PLAFOND_SALAIRE_ASSURE: float = 148_200.0
"""Plafond du salaire assure AC (LACI art. 3)."""

AC_COTISATION_SALARIE: float = 0.011
"""Taux de cotisation AC part salarie: 1.1% (total 2.2%)."""

AC_COTISATION_TOTAL: float = 0.022
"""Taux de cotisation AC total: 2.2%."""

AC_COTISATION_SOLIDARITE_SALARIE: float = 0.005
"""Cotisation de solidarite AC part salarie: 0.5% (au-dessus du plafond)."""

AC_COTISATION_SOLIDARITE_TOTAL: float = 0.01
"""Cotisation de solidarite AC total: 1.0%."""

AC_INDEMNITE_TAUX: float = 0.70
"""Taux d'indemnite chomage standard: 70% (LACI art. 22)."""

AC_INDEMNITE_TAUX_CHARGE_FAMILLE: float = 0.80
"""Taux d'indemnite chomage avec charges de famille: 80%."""


# ══════════════════════════════════════════════════════════════════════════════
# Pilier 3a — Prevoyance individuelle liee
# Base legale: OPP3 art. 7
# ══════════════════════════════════════════════════════════════════════════════

PILIER_3A_PLAFOND_AVEC_LPP: float = 7_258.0
"""Plafond annuel 3a pour salaries affilies a la LPP (petit 3a)."""

PILIER_3A_PLAFOND_SANS_LPP: float = 36_288.0
"""Plafond annuel 3a pour independants sans LPP (grand 3a = 20% du revenu, max 36'288)."""

PILIER_3A_TAUX_REVENU_SANS_LPP: float = 0.20
"""Part du revenu determinant pour le grand 3a: 20%."""


# ══════════════════════════════════════════════════════════════════════════════
# Impot sur retrait de capital (2e/3e pilier) — Taux de base par canton
# Sources: Administrations fiscales cantonales, TaxWare
# ══════════════════════════════════════════════════════════════════════════════

TAUX_IMPOT_RETRAIT_CAPITAL: Dict[str, float] = {
    "ZH": 0.065, "BE": 0.075, "LU": 0.055, "UR": 0.050,
    "SZ": 0.040, "OW": 0.045, "NW": 0.040, "GL": 0.055,
    "ZG": 0.035, "FR": 0.070, "SO": 0.065, "BS": 0.075,
    "BL": 0.065, "SH": 0.060, "AR": 0.055, "AI": 0.045,
    "SG": 0.060, "GR": 0.055, "AG": 0.060, "TG": 0.055,
    "TI": 0.065, "VD": 0.080, "VS": 0.060, "NE": 0.070,
    "GE": 0.075, "JU": 0.065,
}
"""Taux de base de l'impot sur le retrait de capital par canton (LIFD + cantonal + communal)."""

RETRAIT_CAPITAL_TRANCHES: List[Tuple[float, float, float]] = [
    (0, 100_000, 1.00),
    (100_000, 200_000, 1.15),
    (200_000, 500_000, 1.30),
    (500_000, 1_000_000, 1.50),
    (1_000_000, float("inf"), 1.70),
]
"""Tranches progressives pour l'impot sur retrait de capital (multiplicateur)."""

MARRIED_CAPITAL_TAX_DISCOUNT: float = 0.85
"""Reduction d'impot pour les couples maries (splitting cantonal ~15%)."""


def calculate_progressive_capital_tax(montant: float, base_rate: float) -> float:
    """Progressive capital withdrawal tax (LIFD art. 38).

    ALL backend services MUST use this single function.
    Do NOT create local _calculate_progressive_tax() copies.

    Args:
        montant: Capital amount being withdrawn (CHF).
        base_rate: Base cantonal tax rate from TAUX_IMPOT_RETRAIT_CAPITAL.

    Returns:
        Estimated tax amount (CHF), rounded to 2 decimals.
    """
    if montant <= 0:
        return 0.0
    total_tax = 0.0
    remaining = montant
    for low, high, multiplier in RETRAIT_CAPITAL_TRANCHES:
        tranche_size = high - low
        taxable = min(remaining, tranche_size)
        if taxable <= 0:
            break
        total_tax += taxable * base_rate * multiplier
        remaining -= taxable
    return round(total_tax, 2)

# ══════════════════════════════════════════════════════════════════════════════
# EPL — Encouragement a la propriete du logement
# Base legale: LPP art. 30c, OPP2 art. 5
# ══════════════════════════════════════════════════════════════════════════════

EPL_MONTANT_MINIMUM: float = 20_000.0
"""Montant minimum pour un retrait EPL (OPP2 art. 5)."""

EPL_BLOCAGE_RACHAT_ANNEES: int = 3
"""Delai de blocage des rachats LPP apres un retrait EPL (LPP art. 79b al. 3)."""

# ══════════════════════════════════════════════════════════════════════════════
# Hypotheque — Pratique bancaire suisse (ASB / FINMA)
# ══════════════════════════════════════════════════════════════════════════════

HYPOTHEQUE_TAUX_THEORIQUE: float = 0.05
"""Taux d'interet theorique pour le calcul de capacite (5%)."""

HYPOTHEQUE_TAUX_AMORTISSEMENT: float = 0.01
"""Taux d'amortissement annuel minimum (1%)."""

HYPOTHEQUE_TAUX_FRAIS_ACCESSOIRES: float = 0.01
"""Taux de frais accessoires annuels (entretien, assurance) (1%)."""

HYPOTHEQUE_TAUX_CHARGES_TOTAL: float = 0.07
"""Taux de charges theoriques combines (5% + 1% + 1% = 7%)."""

HYPOTHEQUE_RATIO_CHARGES_MAX: float = 1.0 / 3.0
"""Ratio maximal des charges par rapport au revenu brut (regle du 1/3)."""

HYPOTHEQUE_FONDS_PROPRES_MIN: float = 0.20
"""Part minimale de fonds propres (20% du prix d'achat)."""

HYPOTHEQUE_PART_2E_PILIER_MAX: float = 0.10
"""Part maximale du 2e pilier dans les fonds propres (10% du prix d'achat)."""


AVS_COTISATION_MIN_INDEPENDANT: float = 530.0
"""Cotisation AVS minimale annuelle pour independants (LAVS art. 8)."""

AVS_RENTE_MAX_ANNUELLE: float = 30_240.0
"""Rente AVS maximale individuelle annuelle (= 12 x 2'520)."""


# ══════════════════════════════════════════════════════════════════════════════
# Cotisations totales salarie (resume)
# ══════════════════════════════════════════════════════════════════════════════

COTISATIONS_SALARIE_TOTAL: float = AVS_COTISATION_SALARIE + AC_COTISATION_SALARIE
"""Total cotisations sociales part salarie (hors LPP): 5.3% + 1.1% = 6.4%.

AVS_COTISATION_SALARIE (5.3%) = combined AVS (4.35%) + AI (0.70%) + APG (0.25%)
— matching OFAS "taux AVS/AI/APG" (10.6% total, 5.3% per side).
AI_COTISATION_SALARIE & APG_COTISATION_SALARIE are kept separately for
disability-gap and APG-specific calculations, but must NOT be added again here.
"""
