"""
Constantes d'assurances sociales suisses — facade sur RegulatoryRegistry.

Valeurs en vigueur: 2025
Derniere mise a jour: 2025-01-01

Ce fichier est une FACADE (bridge) qui lit toutes les valeurs depuis
RegulatoryRegistry. Les 43+ consumers existants continuent a importer
depuis ce module — zero breaking change.

Architecture:
    - RegulatoryRegistry = single source of truth (app.services.regulatory.registry)
    - Ce module = thin bridge pour compatibilite avec les imports existants
    - Lazy loading via _get() pour eviter les imports circulaires

Sources officielles:
- OFAS (Office federal des assurances sociales)
- https://finpension.ch/fr/connaissances/salaire-minimum-et-maximum-lpp/
- OPP2 (Ordonnance sur la prevoyance professionnelle)
- OPP3 (Ordonnance sur les deductions admises en 3e pilier)
- LAVS / LAI / LAPG / LACI

Procedure de mise a jour annuelle:
1. Mettre a jour RegulatoryRegistry (app/services/regulatory/registry.py)
2. Les valeurs ici se mettent a jour automatiquement via _get()
3. Lancer la suite de tests: pytest
4. Mettre a jour le miroir Flutter: lib/constants/social_insurance.dart
"""

from typing import Dict, List, Tuple


# ══════════════════════════════════════════════════════════════════════════════
# Bridge helper — lazy import to avoid circular dependencies
# ══════════════════════════════════════════════════════════════════════════════


def _get(key: str, jurisdiction: str = "CH") -> float:
    """Lazy lookup from RegulatoryRegistry. Returns value or raises KeyError."""
    from app.services.regulatory.registry import RegulatoryRegistry
    reg = RegulatoryRegistry.instance()
    val = reg.get_value(key, jurisdiction=jurisdiction)
    if val is None:
        raise KeyError(f"RegulatoryRegistry missing key: {key}")
    return val


def _get_cantonal_rates() -> Dict[str, float]:
    """Build cantonal tax rate dict from registry."""
    from app.services.regulatory.registry import RegulatoryRegistry
    reg = RegulatoryRegistry.instance()
    cantons = [
        "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG", "FR",
        "SO", "BS", "BL", "SH", "AR", "AI", "SG", "GR", "AG", "TG",
        "TI", "VD", "VS", "NE", "GE", "JU",
    ]
    rates: Dict[str, float] = {}
    for c in cantons:
        param = reg.get(f"capital_tax.cantonal.{c}", jurisdiction=c)
        if param is not None:
            rates[c] = param.value
    return rates


def _get_capital_tranches() -> List[Tuple[float, float, float]]:
    """Build progressive capital tax brackets from registry."""
    return [
        (0, 100_000, _get("capital_tax.bracket.0_100k")),
        (100_000, 200_000, _get("capital_tax.bracket.100k_200k")),
        (200_000, 500_000, _get("capital_tax.bracket.200k_500k")),
        (500_000, 1_000_000, _get("capital_tax.bracket.500k_1m")),
        (1_000_000, float("inf"), _get("capital_tax.bracket.1m_plus")),
    ]


def _get_avs_deferral_supplements() -> Dict[int, float]:
    """Build AVS deferral supplement dict from registry."""
    return {
        years: _get(f"avs.deferral_supplement.{years}")
        for years in range(1, 6)
    }


def _get_lpp_bonifications_list() -> List[Tuple[int, int, float]]:
    """Build LPP bonification list from registry."""
    return [
        (25, 34, _get("lpp.bonification.25_34")),
        (35, 44, _get("lpp.bonification.35_44")),
        (45, 54, _get("lpp.bonification.45_54")),
        (55, 65, _get("lpp.bonification.55_65")),
    ]


def _get_lpp_bonifications_dict() -> Dict[int, float]:
    """Build LPP bonification dict from registry."""
    return {
        25: _get("lpp.bonification.25_34"),
        35: _get("lpp.bonification.35_44"),
        45: _get("lpp.bonification.45_54"),
        55: _get("lpp.bonification.55_65"),
    }


# ══════════════════════════════════════════════════════════════════════════════
# LPP — Prevoyance professionnelle (2e pilier)
# Base legale: LPP art. 7, 8, 14, 16 / OPP2
# ══════════════════════════════════════════════════════════════════════════════

LPP_SEUIL_ENTREE: float = _get("lpp.entry_threshold")
"""Salaire annuel minimum pour etre soumis a la LPP (LPP art. 7)."""

LPP_DEDUCTION_COORDINATION: float = _get("lpp.coordination_deduction")
"""Deduction de coordination (LPP art. 8). Salaire coordonne = brut - deduction."""

LPP_SALAIRE_COORDONNE_MIN: float = _get("lpp.min_coordinated_salary")
"""Salaire coordonne minimum assure (LPP art. 8 al. 2)."""

LPP_SALAIRE_COORDONNE_MAX: float = _get("lpp.max_coordinated_salary")
"""Salaire coordonne maximum assure (= LPP_SALAIRE_MAX - LPP_DEDUCTION_COORDINATION)."""

LPP_SALAIRE_MAX: float = _get("lpp.max_insured_salary")
"""Salaire annuel maximum assure LPP (LPP art. 8 al. 1)."""

LPP_TAUX_CONVERSION_MIN: float = round(_get("lpp.conversion_rate") * 100, 1)
"""Taux de conversion minimum LPP en % (LPP art. 14 al. 2). Capital -> rente."""

LPP_TAUX_CONVERSION_MIN_DECIMAL: float = _get("lpp.conversion_rate")
"""Taux de conversion minimum LPP en fraction decimale (0.068 = 6.8%)."""

LPP_TAUX_INTERET_MIN: float = _get("lpp.min_interest_rate")
"""Taux d'interet minimum LPP en % (fixe par le Conseil federal)."""

LPP_BONIFICATIONS_VIEILLESSE: List[Tuple[int, int, float]] = _get_lpp_bonifications_list()
"""Taux de bonification de vieillesse par tranche d'age (LPP art. 16)."""

LPP_BONIFICATIONS_DICT: Dict[int, float] = _get_lpp_bonifications_dict()
"""Taux de bonification indexes par age de debut de tranche."""


def get_lpp_bonification_rate(age: int) -> float:
    """Retourne le taux de bonification LPP pour un age donne (LPP art. 16)."""
    if age >= 55:
        return _get("lpp.bonification.55_65")
    elif age >= 45:
        return _get("lpp.bonification.45_54")
    elif age >= 35:
        return _get("lpp.bonification.35_44")
    elif age >= 25:
        return _get("lpp.bonification.25_34")
    return 0.0


# ══════════════════════════════════════════════════════════════════════════════
# AVS — Assurance-vieillesse et survivants (1er pilier)
# Base legale: LAVS art. 34-40
# ══════════════════════════════════════════════════════════════════════════════

AVS_RENTE_MAX_MENSUELLE: float = _get("avs.max_monthly_pension")
"""Rente AVS maximale individuelle mensuelle (LAVS art. 34)."""

AVS_RENTE_MIN_MENSUELLE: float = _get("avs.min_monthly_pension")
"""Rente AVS minimale individuelle mensuelle (= 50% de la rente max)."""

AVS_RENTE_COUPLE_MAX_MENSUELLE: float = _get("avs.couple_max_monthly")
"""Rente AVS maximale pour un couple mensuelle (= 150% de la rente max)."""

AVS_RAMD_MIN: float = _get("avs.ramd_min")
"""RAMD minimum (revenu annuel moyen determinant). Rente = min si salaire <= RAMD_MIN."""

AVS_RAMD_MAX: float = _get("avs.ramd_max")
"""RAMD maximum. Rente = max si salaire >= RAMD_MAX (LAVS art. 34, echelle 44)."""

AVS_RENTE_MAX_ANNUELLE: float = _get("avs.max_annual_pension")
"""Rente AVS maximale annuelle (12 mois, sans 13eme rente)."""

AVS_COTISATION_SALARIE: float = _get("avs.contribution_rate_employee")
"""Taux de cotisation AVS part salarie: 5.3% (total 10.6% avec part employeur)."""

AVS_COTISATION_TOTAL: float = _get("avs.contribution_rate_total")
"""Taux de cotisation AVS total (salarie + employeur): 10.6%."""

AVS_DUREE_COTISATION_COMPLETE: int = int(_get("avs.full_contribution_years"))
"""Nombre d'annees de cotisation pour une rente complete (LAVS art. 29ter)."""

AVS_AGE_REFERENCE_HOMME: int = int(_get("avs.reference_age_men"))
"""Age de reference AVS pour les hommes."""

AVS_AGE_REFERENCE_FEMME: int = int(_get("avs.reference_age_women"))
"""Age de reference AVS pour les femmes (depuis reforme AVS 21)."""

AVS_REDUCTION_ANTICIPATION: float = _get("avs.anticipation_reduction")
"""Reduction par annee d'anticipation de la rente AVS: 6.8% (LAVS art. 40)."""

AVS_SUPPLEMENT_AJOURNEMENT: Dict[int, float] = _get_avs_deferral_supplements()
"""Supplement de rente par annee d'ajournement (LAVS art. 39)."""

AVS_FRANCHISE_RETRAITE_MENSUELLE: float = _get("avs.retiree_franchise_monthly")
"""Franchise AVS pour retraites actifs, mensuelle (LAVS art. 4)."""

AVS_FRANCHISE_RETRAITE_ANNUELLE: float = _get("avs.retiree_franchise_annual")
"""Franchise AVS pour retraites actifs, annuelle."""

AVS_SURVIVOR_FACTOR: float = _get("avs.survivor_factor")
"""Facteur rente de survivant (80% de la rente du defunt)."""

# 13eme rente AVS (initiative populaire adoptee en mars 2024)
# Versement: une fois par an en decembre, a partir de decembre 2026.
# Montant = 1/12 de la somme annuelle des rentes vieillesse versees.
# En pratique: rente annuelle effective = rente mensuelle x 13.
# Uniquement rentes de vieillesse (pas AI, pas survivants, pas enfants).
# N'affecte PAS les prestations complementaires (PC).
# Base legale: LAVS art. 34 (nouveau), art. constitutionnel 112 al. 4bis.

AVS_13EME_RENTE_ACTIVE: bool = bool(_get("avs.13th_pension_active"))
"""13eme rente AVS active. True des 2026 (premier versement decembre 2026)."""

AVS_13EME_RENTE_ANNEE_DEBUT: int = int(_get("avs.13th_pension_start_year"))
"""Annee du premier versement de la 13eme rente AVS."""

AVS_NOMBRE_RENTES_PAR_AN: int = 13
"""Nombre de rentes mensuelles par an (12 standard + 1 treizieme)."""

AVS_13EME_RENTE_FACTOR: float = _get("avs.13th_pension_factor")
"""Facteur multiplicateur pour convertir la rente annuelle 12 mois en 13 mois.
Rente annuelle effective = rente mensuelle x 12 x AVS_13EME_RENTE_FACTOR
                         = rente mensuelle x 13."""

# AVS volontaire (expatries)
AVS_VOLONTAIRE_COTISATION_MIN: float = _get("avs.voluntary_contribution_min")
"""Cotisation annuelle minimale AVS volontaire (LAVS art. 2)."""

AVS_VOLONTAIRE_COTISATION_MAX: float = _get("avs.voluntary_contribution_max")
"""Cotisation annuelle maximale AVS volontaire."""


# ══════════════════════════════════════════════════════════════════════════════
# AI — Assurance-invalidite
# Base legale: LAI
# ══════════════════════════════════════════════════════════════════════════════

AI_COTISATION_SALARIE: float = _get("ai.contribution_rate_employee")
"""Taux de cotisation AI part salarie: 0.7% (total 1.4%)."""

AI_COTISATION_TOTAL: float = _get("ai.contribution_rate_total")
"""Taux de cotisation AI total: 1.4%."""

AI_RENTE_ENTIERE: float = _get("ai.full_pension_monthly")
"""Rente AI entiere mensuelle (= rente AVS max). Degre invalidite >= 70%."""

AI_RENTE_DEMI: float = AI_RENTE_ENTIERE * 0.5
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

APG_COTISATION_SALARIE: float = _get("apg.contribution_rate_employee")
"""Taux de cotisation APG part salarie: 0.25% (total 0.5%)."""

APG_COTISATION_TOTAL: float = _get("apg.contribution_rate_total")
"""Taux de cotisation APG total: 0.5%."""

APG_MATERNITE_JOURS: int = int(_get("apg.maternity_days"))
"""Duree du conge maternite: 98 jours = 14 semaines (LAPG art. 16d)."""

APG_MATERNITE_TAUX: float = _get("apg.maternity_rate")
"""Taux d'indemnite de maternite: 80% du salaire (LAPG art. 16f)."""

APG_PATERNITE_JOURS: int = int(_get("apg.paternity_days"))
"""Duree du conge paternite: 10 jours (LAPG art. 16i)."""


# ══════════════════════════════════════════════════════════════════════════════
# AC — Assurance-chomage
# Base legale: LACI
# ══════════════════════════════════════════════════════════════════════════════

AC_PLAFOND_SALAIRE_ASSURE: float = _get("ac.max_insured_salary")
"""Plafond du salaire assure AC (LACI art. 3)."""

AC_COTISATION_SALARIE: float = _get("ac.contribution_rate_employee")
"""Taux de cotisation AC part salarie: 1.1% (total 2.2%)."""

AC_COTISATION_TOTAL: float = _get("ac.contribution_rate_total")
"""Taux de cotisation AC total: 2.2%."""

AC_COTISATION_SOLIDARITE_SALARIE: float = _get("ac.solidarity_rate_employee")
"""Cotisation de solidarite AC part salarie: 0.5% (au-dessus du plafond)."""

AC_COTISATION_SOLIDARITE_TOTAL: float = _get("ac.solidarity_rate_total")
"""Cotisation de solidarite AC total: 1.0%."""

AC_INDEMNITE_TAUX: float = _get("ac.benefit_rate_standard")
"""Taux d'indemnite chomage standard: 70% (LACI art. 22)."""

AC_INDEMNITE_TAUX_CHARGE_FAMILLE: float = _get("ac.benefit_rate_family")
"""Taux d'indemnite chomage avec charges de famille: 80%."""


# ══════════════════════════════════════════════════════════════════════════════
# Pilier 3a — Prevoyance individuelle liee
# Base legale: OPP3 art. 7
# ══════════════════════════════════════════════════════════════════════════════

PILIER_3A_PLAFOND_AVEC_LPP: float = _get("pillar3a.max_with_lpp")
"""Plafond annuel 3a pour salaries affilies a la LPP (petit 3a)."""

PILIER_3A_PLAFOND_SANS_LPP: float = _get("pillar3a.max_without_lpp")
"""Plafond annuel 3a pour independants sans LPP (grand 3a = 20% du revenu, max 36'288)."""

PILIER_3A_TAUX_REVENU_SANS_LPP: float = _get("pillar3a.income_rate_without_lpp")
"""Part du revenu determinant pour le grand 3a: 20%."""


# ══════════════════════════════════════════════════════════════════════════════
# Impot sur retrait de capital (2e/3e pilier) — Taux de base par canton
# Sources: Administrations fiscales cantonales, TaxWare
# ══════════════════════════════════════════════════════════════════════════════

TAUX_IMPOT_RETRAIT_CAPITAL: Dict[str, float] = _get_cantonal_rates()
"""Taux de base de l'impot sur le retrait de capital par canton (LIFD + cantonal + communal)."""

RETRAIT_CAPITAL_TRANCHES: List[Tuple[float, float, float]] = _get_capital_tranches()
"""Tranches progressives pour l'impot sur retrait de capital (multiplicateur)."""

MARRIED_CAPITAL_TAX_DISCOUNT: float = _get("capital_tax.married_discount")
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

EPL_MONTANT_MINIMUM: float = _get("lpp.epl_minimum")
"""Montant minimum pour un retrait EPL (OPP2 art. 5)."""

EPL_BLOCAGE_RACHAT_ANNEES: int = int(_get("lpp.epl_buyback_lock_years"))
"""Delai de blocage des rachats LPP apres un retrait EPL (LPP art. 79b al. 3)."""

# ══════════════════════════════════════════════════════════════════════════════
# Hypotheque — Pratique bancaire suisse (ASB / FINMA)
# ══════════════════════════════════════════════════════════════════════════════

HYPOTHEQUE_TAUX_THEORIQUE: float = _get("mortgage.theoretical_rate")
"""Taux d'interet theorique pour le calcul de capacite (5%)."""

HYPOTHEQUE_TAUX_AMORTISSEMENT: float = _get("mortgage.amortization_rate")
"""Taux d'amortissement annuel minimum (1%)."""

HYPOTHEQUE_TAUX_FRAIS_ACCESSOIRES: float = _get("mortgage.maintenance_rate")
"""Taux de frais accessoires annuels (entretien, assurance) (1%)."""

HYPOTHEQUE_TAUX_CHARGES_TOTAL: float = 0.07
"""Taux de charges theoriques combines (5% + 1% + 1% = 7%)."""

HYPOTHEQUE_RATIO_CHARGES_MAX: float = _get("mortgage.max_charge_ratio")
"""Ratio maximal des charges par rapport au revenu brut (regle du 1/3)."""

HYPOTHEQUE_FONDS_PROPRES_MIN: float = _get("mortgage.min_equity")
"""Part minimale de fonds propres (20% du prix d'achat)."""

HYPOTHEQUE_PART_2E_PILIER_MAX: float = _get("mortgage.max_2nd_pillar")
"""Part maximale du 2e pilier dans les fonds propres (10% du prix d'achat)."""


LPP_CONVERSION_RATE_COMPLEMENTAIRE: float = _get("lpp.conversion_rate_complementaire")
"""Taux de conversion blended pour caisses complementaires (~60% oblig. a 6.8% + ~40% suroblig. a ~4.3%)."""

TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT: float = _get("capital_tax.default_rate")
"""Taux par defaut de l'impot sur le retrait de capital (fallback quand le canton est inconnu)."""


# ══════════════════════════════════════════════════════════════════════════════
# LAMal — Assurance-maladie obligatoire
# Base legale: LAMal art. 62-64
# ══════════════════════════════════════════════════════════════════════════════

LAMAL_QUOTE_PART_RATE: float = _get("lamal.copay_rate")
"""Quote-part: 10% des frais au-dessus de la franchise (LAMal art. 64)."""

LAMAL_QUOTE_PART_CAP_ADULT: float = _get("lamal.copay_cap_adult")
"""Quote-part maximale annuelle adultes >= 26 ans (LAMal art. 64 al. 2)."""

LAMAL_QUOTE_PART_CAP_CHILD: float = _get("lamal.copay_cap_child")
"""Quote-part maximale annuelle enfants < 18 ans (LAMal art. 64 al. 4)."""


AVS_COTISATION_MIN_INDEPENDANT: float = _get("avs.min_contribution_independent")
"""Cotisation AVS minimale annuelle pour independants (LAVS art. 8)."""

AVS_SEUIL_REVENU_MIN_INDEPENDANT: float = _get("avs.independent_min_income_threshold")
"""Seuil de revenu en dessous duquel la cotisation minimale s'applique (LAVS art. 8).
En dessous de ce seuil, l'independant paie la cotisation minimale forfaitaire."""

AVS_BAREME_DEGRESSIF_PLAFOND: float = 58_800.0
"""Plafond du bareme degressif AVS independants (LAVS art. 8).
Au-dessus de ce montant, le taux plein de 10.6% s'applique.
Note: le bareme detaille AVS_BAREME_INDEPENDANT utilise 60'500 comme seuil
du taux plein. Cette constante est conservee pour compatibilite."""

# AVS_RENTE_MAX_ANNUELLE already defined above as _get("avs.max_annual_pension")

AVS_BAREME_INDEPENDANT: List[Tuple[float, float, float]] = [
    (0,       10_100,  0.05371),
    (10_100,  17_600,  0.05828),
    (17_600,  22_200,  0.06542),
    (22_200,  27_200,  0.07158),
    (27_200,  32_300,  0.07773),
    (32_300,  37_800,  0.08386),
    (37_800,  43_200,  0.09002),
    (43_200,  48_800,  0.09610),
    (48_800,  54_300,  0.10222),
    (54_300,  60_500,  0.10413),
    (60_500,  float('inf'), 0.10600),
]
"""Bareme degressif AVS/AI/APG pour independants (LAVS art. 8, RAVS art. 21-23).

Chaque tranche applique un taux unique sur la totalite du revenu (pas marginal).
Valeurs 2025/2026. Le taux final (10.6%) correspond au taux plein AVS/AI/APG.
"""


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
