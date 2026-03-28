"""
Chiffre Choc Selector V2 — intention × lifecycle × confidence × available data.

Sprint S57 — ChiffreChoc V2.

Given a MinimalProfileResult and optional stress_type, selects the single
chiffre choc that will have the most impact on the user.

Selection hierarchy:
0. Critical archetype alerts (indep no LPP, expat low AVS)
1. Liquidity crisis (real data or severe)
2. Stress-aligned selection (if stress_type declared, data supports it)
3. Universal priorities (retirement gap, tax saving)
   — gated by lifecycle relevance and data confidence
4. Lifecycle-aware fallback (age-driven, always valid)

Confidence gating:
- If key data is estimated → confidence_mode = "pedagogical"
- If based on provided data or pure math → confidence_mode = "factual"

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

import math
from typing import Optional

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

_SOURCES_COMPOUND = [
    "Calcul mathématique: intérêts composés à 3% nominal",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Phase 0: Archetype alerts (aligned with Flutter _selectByArchetype)
# ═══════════════════════════════════════════════════════════════════════════════

def _select_by_archetype(profile: MinimalProfileResult) -> Optional[ChiffreChoc]:
    """Archetype-specific chiffre choc (highest priority when applicable).

    Aligned with Flutter ChiffreChocSelector._selectByArchetype.
    """
    # Independent without LPP: massive retirement gap alert
    if (profile.archetype == "independent_no_lpp"
        or (profile.estimated_replacement_ratio < 0.30
            and profile.projected_lpp_monthly <= 0
            and profile.gross_annual_salary > 0)):
        gap = max(0, profile.estimated_monthly_expenses - profile.estimated_monthly_retirement)
        lpp_estimated = "existing_lpp" in profile.estimated_fields
        return ChiffreChoc(
            category="retirement_gap",
            primary_number=round(gap, 0),
            display_text=(
                f"En tant qu'indépendant·e sans LPP, seule l'AVS te couvre. "
                f"Il te manquerait CHF {gap:,.0f} chaque mois à la retraite."
            ),
            explanation_text=(
                "Le 3e pilier (max CHF 36'288/an) et "
                "une LPP facultative peuvent combler cet écart."
            ),
            action_text="Découvre tes options de prévoyance \u2192",
            disclaimer=_DISCLAIMER,
            sources=list(_SOURCES_RETIREMENT),
            confidence_score=profile.confidence_score,
            confidence_mode="pedagogical" if lpp_estimated else "factual",
        )

    # Non-Swiss expat: AVS gap warning
    if (profile.archetype in ("expat_eu", "expat_non_eu")
            and profile.projected_avs_monthly < 1500):
        avs = profile.projected_avs_monthly
        is_eu = profile.archetype == "expat_eu"
        explanation = (
            "Tes années de cotisation en Europe comptent aussi grâce aux "
            "accords bilatéraux. Vérifie ta rente avec ton relevé CI."
            if is_eu else
            "Ta rente pourrait être réduite par des lacunes de cotisation. "
            "Demande ton relevé CI à ta caisse de compensation."
        )
        return ChiffreChoc(
            category="retirement_gap",
            primary_number=round(avs, 0),
            display_text=f"Ta rente AVS estimée: CHF {avs:,.0f}/mois.",
            explanation_text=explanation,
            action_text="Vérifie tes droits AVS \u2192",
            disclaimer=_DISCLAIMER,
            sources=list(_SOURCES_RETIREMENT),
            confidence_score=profile.confidence_score,
            confidence_mode="pedagogical",
        )

    return None


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

    savings_estimated = "current_savings" in profile.estimated_fields
    mode = "pedagogical" if savings_estimated else "factual"

    return ChiffreChoc(
        category="liquidity",
        primary_number=round(months, 1),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES_LIQUIDITY),
        confidence_score=profile.confidence_score,
        confidence_mode=mode,
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

    lpp_estimated = "existing_lpp" in profile.estimated_fields
    mode = "pedagogical" if lpp_estimated else "factual"

    return ChiffreChoc(
        category="retirement_gap",
        primary_number=round(gap, 0),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES_RETIREMENT),
        confidence_score=profile.confidence_score,
        confidence_mode=mode,
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
        confidence_mode="factual",  # Derived from salary + canton, both provided
    )


def _build_retirement_income_choc(profile: MinimalProfileResult) -> ChiffreChoc:
    """Build chiffre choc showing retirement income (positive framing)."""
    monthly_retirement = profile.estimated_monthly_retirement
    ratio_pct = round(profile.estimated_replacement_ratio * 100)

    display_text = (
        f"Avec l'AVS et la LPP, tu pourrais recevoir environ "
        f"CHF {monthly_retirement:,.0f} par mois à la retraite, "
        f"soit {ratio_pct}% de ton salaire actuel."
    )
    explanation_text = (
        "Ce taux de remplacement est dans la moyenne suisse. "
        "Le 3e pilier et l'épargne libre peuvent améliorer ta situation."
    )
    action_text = "Simule ta retraite en détail \u2192"

    lpp_estimated = "existing_lpp" in profile.estimated_fields
    mode = "pedagogical" if lpp_estimated else "factual"

    return ChiffreChoc(
        category="retirement_income",
        primary_number=round(monthly_retirement, 0),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES_RETIREMENT),
        confidence_score=profile.confidence_score,
        confidence_mode=mode,
    )


def _build_compound_growth_choc(profile: MinimalProfileResult) -> ChiffreChoc:
    """Build compound growth choc for young users. Pure math, always factual."""
    age = profile.age  # A10 fix: no hasattr fallback — field is always present
    years = 65 - age
    monthly_contrib = 200.0
    annual_rate = 0.03
    monthly_rate = annual_rate / 12
    total_months = years * 12

    future_value = monthly_contrib * ((math.pow(1 + monthly_rate, total_months) - 1) / monthly_rate)

    reference_age = 35
    years_at_35 = 65 - reference_age
    months_at_35 = years_at_35 * 12
    future_at_35 = monthly_contrib * ((math.pow(1 + monthly_rate, months_at_35) - 1) / monthly_rate)

    advantage = future_value - future_at_35

    display_text = (
        f"200 CHF/mois dès maintenant = CHF {advantage:,.0f} de plus à 65 ans "
        f"qu'en commençant à 35."
    )
    explanation_text = (
        "Le temps est ton plus grand atout. Chaque année de cotisation supplémentaire "
        "profite des intérêts composés — ton argent travaille pour toi pendant "
        f"que tu vis ta vie. Sur {years} ans, même 200 CHF/mois font une différence majeure."
    )
    action_text = "Découvre combien ton 3a pourrait te rapporter \u2192"

    return ChiffreChoc(
        category="compound_growth",
        primary_number=round(advantage, 0),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES_COMPOUND),
        confidence_score=profile.confidence_score,
        confidence_mode="factual",  # Pure math
    )


def _build_hourly_rate_choc(profile: MinimalProfileResult) -> ChiffreChoc:
    """Build hourly rate choc. Uses gross_annual_salary (provided), always factual.

    A2/A3 fix: uses profile.gross_annual_salary directly, NOT retirement proxy.
    """
    gross_annual = profile.gross_annual_salary
    working_hours_per_year = 2088.0
    net_annual = gross_annual * 0.75
    hourly_net = net_annual / working_hours_per_year if working_hours_per_year > 0 else 0

    rent_estimate = profile.estimated_monthly_expenses * 0.30
    rent_hours = round(rent_estimate / hourly_net) if hourly_net > 0 else 0

    display_text = (
        f"Après charges sociales et impôts, tu gagnes environ "
        f"CHF {hourly_net:.0f} de l'heure."
    )
    explanation_text = (
        f"Ton loyer te coûte ~{rent_hours} heures de travail par mois. "
        f"Savoir ce que tu gagnes vraiment par heure aide à évaluer "
        f"chaque dépense en temps de vie, pas seulement en francs."
    )
    action_text = "Explore ton budget en détail \u2192"

    return ChiffreChoc(
        category="hourly_rate",
        primary_number=round(hourly_net, 0),
        display_text=display_text,
        explanation_text=explanation_text,
        action_text=action_text,
        disclaimer=_DISCLAIMER,
        sources=[],
        confidence_score=profile.confidence_score,
        confidence_mode="factual",  # Pure math from provided salary
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Stress-aligned selection
# ═══════════════════════════════════════════════════════════════════════════════

def _select_by_stress(
    stress_type: str, profile: MinimalProfileResult
) -> Optional[ChiffreChoc]:
    """Try to produce a chiffre choc aligned with user's declared intention.

    A3 fix: uses profile.gross_annual_salary for salary guard, not retirement proxy.
    """
    if stress_type == "stress_budget":
        # Budget: show hourly rate (pure math from salary — always factual)
        if profile.gross_annual_salary > 0:
            return _build_hourly_rate_choc(profile)
        return None

    if stress_type == "stress_impots":
        if profile.tax_saving_3a > 500:
            return _build_tax_saving_choc(profile)
        return None

    if stress_type == "stress_retraite":
        if profile.gross_annual_salary > 0:
            if profile.estimated_replacement_ratio < 0.55:
                return _build_retirement_gap_choc(profile)
            # Ratio OK → show retirement income (positive framing, not gap)
            return _build_retirement_income_choc(profile)
        return None

    # stress_patrimoine, stress_couple: no data at onboarding → fall through
    return None


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle-aware fallback
# ═══════════════════════════════════════════════════════════════════════════════

def _select_by_lifecycle(profile: MinimalProfileResult) -> ChiffreChoc:
    """Lifecycle-aware fallback when no stress/priority matched."""
    age = profile.age

    if age < 28:
        return _build_compound_growth_choc(profile)

    if age < 38:
        if profile.existing_3a <= 0 and profile.tax_saving_3a > 1500:
            return _build_tax_saving_choc(profile)
        return _build_compound_growth_choc(profile)

    # 38+: retirement is relevant
    if profile.estimated_replacement_ratio < 0.55:
        return _build_retirement_gap_choc(profile)

    return _build_retirement_income_choc(profile)


# ═══════════════════════════════════════════════════════════════════════════════
# Main selector
# ═══════════════════════════════════════════════════════════════════════════════

def select_chiffre_choc(
    profile: MinimalProfileResult,
    stress_type: Optional[str] = None,
) -> ChiffreChoc:
    """Select the single most impactful chiffre choc for the user.

    V2: selection = intention × lifecycle × confidence × available data.

    Args:
        profile: The computed MinimalProfileResult.
        stress_type: Optional user intention ('stress_retraite', 'stress_budget', etc.)

    Returns:
        A single ChiffreChoc with category, display text, confidence_mode,
        and compliance fields.
    """
    # Phase 0: Archetype-specific alerts (A1 fix — was missing)
    archetype_choc = _select_by_archetype(profile)
    if archetype_choc is not None:
        return archetype_choc

    # Phase 1: Liquidity crisis — only if savings data is real or crisis is severe
    savings_estimated = "current_savings" in profile.estimated_fields
    if profile.months_liquidity < 2.0:
        if not savings_estimated or profile.months_liquidity < 1.0:
            return _build_liquidity_choc(profile)

    # Phase 2: Stress-aligned selection
    if stress_type and stress_type != "stress_general":
        stress_choc = _select_by_stress(stress_type, profile)
        if stress_choc is not None:
            return stress_choc

    # Phase 3: Universal priorities (gated by lifecycle)
    age = profile.age

    # Retirement gap: relevant from age 30+
    if age >= 30 and profile.estimated_replacement_ratio < 0.55:
        return _build_retirement_gap_choc(profile)

    # Tax saving 3a
    has_no_3a = profile.existing_3a <= 0.0
    if has_no_3a and profile.tax_saving_3a > 1500:
        return _build_tax_saving_choc(profile)

    # Phase 4: Lifecycle-aware fallback
    return _select_by_lifecycle(profile)
