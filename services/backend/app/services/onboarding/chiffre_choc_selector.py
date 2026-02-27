"""
Chiffre Choc Selector — Pick the ONE most impactful number for onboarding.

Sprint S31 — Onboarding Redesign.

Given a MinimalProfileResult, selects the single chiffre choc that will
have the most impact on the user. Priority order:
1. Liquidity crisis (months_liquidity < 2)
2. Retirement gap (estimated_replacement_ratio < 0.55)
3. Tax saving opportunity (existing_3a == 0 AND tax_saving_3a > 1500)
4. Default: retirement gap (always applicable)

All text is in French, informal "tu", educational tone.

NEVER uses banned terms:
    "garanti", "certain", "assure", "sans risque",
    "optimal", "meilleur", "parfait", "conseiller",
    "tu devrais", "tu dois"

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

from app.services.onboarding.onboarding_models import (
    ChiffreChoc,
    MinimalProfileResult,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Compliance constants
# ═══════════════════════════════════════════════════════════════════════════════

_DISCLAIMER = (
    "Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). "
    "Consulte un\u00b7e spécialiste pour une analyse personnalisée."
)

_SOURCES_RETIREMENT = [
    "LAVS art. 21-29 (rente AVS)",
    "LPP art. 15-16 (bonifications vieillesse)",
]

_SOURCES_TAX = [
    "OPP3 art. 7 (plafond 3a: 7'258 CHF)",
    "LIFD art. 33 (déduction 3a du revenu imposable)",
]

_SOURCES_LIQUIDITY = [
    "Recommandation générale: 3-6 mois de charges en réserve",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Category builders
# ═══════════════════════════════════════════════════════════════════════════════

def _build_liquidity_choc(profile: MinimalProfileResult) -> ChiffreChoc:
    """Build chiffre choc for liquidity crisis (< 2 months runway)."""
    months = profile.months_liquidity
    monthly_expenses = profile.estimated_monthly_expenses

    display_text = (
        f"Ta réserve financière couvre environ {months:.1f} mois de charges. "
        f"Avec ~CHF {monthly_expenses:,.0f} de dépenses mensuelles estimées, "
        f"un imprévu pourrait vite devenir problématique."
    )
    explanation_text = (
        "Les spécialistes recommandent de conserver 3 à 6 mois de charges "
        "en épargne de précaution. En dessous de 2 mois, la marge de "
        "manœuvre est très réduite face à une perte d'emploi, une maladie "
        "ou une réparation urgente."
    )
    action_text = "Découvre comment constituer ta réserve de précaution pas à pas \u2192"

    return ChiffreChoc(
        category="liquidity",
        primary_number=round(months, 1),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES_LIQUIDITY),
        confidence_score=profile.confidence_score,
    )


def _build_retirement_gap_choc(profile: MinimalProfileResult) -> ChiffreChoc:
    """Build chiffre choc for retirement gap."""
    monthly_retirement = profile.estimated_monthly_retirement
    monthly_expenses = profile.estimated_monthly_expenses
    gap = max(0, monthly_expenses - monthly_retirement)

    display_text = (
        f"À la retraite, ton revenu mensuel estimé serait de "
        f"CHF {monthly_retirement:,.0f}. Aujourd'hui, tu dépenses "
        f"probablement ~CHF {monthly_expenses:,.0f} par mois."
    )

    if gap > 0:
        explanation_text = (
            f"Cela représente un écart d'environ CHF {gap:,.0f} par mois. "
            f"L'AVS et la LPP couvrent en moyenne 60% du dernier salaire. "
            f"Le 3e pilier et l'épargne libre permettent de combler ce gap."
        )
    else:
        explanation_text = (
            "Tes revenus projetés à la retraite semblent couvrir tes charges "
            "estimées. Toutefois, cette projection est basée sur des estimations "
            "simplifiées. Enrichis ton profil pour une analyse plus précise."
        )

    action_text = "Simule l'impact d'un 3e pilier sur ta situation \u2192"

    return ChiffreChoc(
        category="retirement_gap",
        primary_number=round(gap, 0),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES_RETIREMENT),
        confidence_score=profile.confidence_score,
    )


def _build_tax_saving_choc(profile: MinimalProfileResult) -> ChiffreChoc:
    """Build chiffre choc for tax saving opportunity via 3a."""
    tax_saving = profile.tax_saving_3a

    display_text = (
        f"En ouvrant un 3e pilier, tu pourrais économiser environ "
        f"CHF {tax_saving:,.0f} d'impôts chaque année."
    )
    explanation_text = (
        "Le versement au 3e pilier est déductible du revenu imposable. "
        "Avec un plafond de CHF 7'258 par an (salarié·e affilié·e LPP), "
        "l'économie fiscale dépend de ton taux marginal d'imposition."
    )
    action_text = "Explore les options 3a et leur impact fiscal \u2192"

    return ChiffreChoc(
        category="tax_saving",
        primary_number=round(tax_saving, 0),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES_TAX),
        confidence_score=profile.confidence_score,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Main selector
# ═══════════════════════════════════════════════════════════════════════════════

def select_chiffre_choc(profile: MinimalProfileResult) -> ChiffreChoc:
    """Select the single most impactful chiffre choc for the user.

    Priority order (select FIRST match):
    1. Liquidity crisis: months_liquidity < 2
    2. Retirement gap: estimated_replacement_ratio < 0.55
    3. Tax saving: existing_3a == 0 AND tax_saving_3a > 1500
    4. Default fallback: retirement_gap (always applicable)

    Args:
        profile: The computed MinimalProfileResult.

    Returns:
        A single ChiffreChoc with category, display text, and compliance fields.
    """
    # Priority 1: Liquidity crisis
    if profile.months_liquidity < 2.0:
        return _build_liquidity_choc(profile)

    # Priority 2: Retirement gap
    if profile.estimated_replacement_ratio < 0.55:
        return _build_retirement_gap_choc(profile)

    # Priority 3: Tax saving opportunity
    # Check if user has no 3a AND the tax saving is significant
    has_no_3a = profile.existing_3a <= 0.0
    if has_no_3a and profile.tax_saving_3a > 1500:
        return _build_tax_saving_choc(profile)

    # Default fallback: retirement gap
    return _build_retirement_gap_choc(profile)
