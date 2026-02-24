"""
Calendrier de Retraits — Pure function for withdrawal scheduling arbitrage.

Sprint S33 — Arbitrage Phase 2.

THE HIGHEST WOW-NUMBER MODULE: compares withdrawing all retirement assets
in the same year vs optimally staggering them across years for massive
tax savings (often CHF 15'000 - 40'000+).

Compares 2 options:
- Option A: Everything withdrawn the same year (high progressive tax)
- Option B: Optimally staggered withdrawals (each year taxed separately)

MUST use calculate_progressive_capital_tax() from app.constants.social_insurance.

Sources:
    - LIFD art. 38 (imposition separee du capital)
    - OPP3 art. 3 (retrait 3a des 59/60 ans)
    - LPP art. 13 (retraite anticipee des 58 ans)

Rules:
    - NEVER rank options. Use "Dans ce scenario simule..." language
    - hypotheses must list ALL assumptions
    - disclaimer ALWAYS present mentioning "outil educatif", "LSFin"
    - NEVER use banned terms: "garanti", "certain", "assure", "sans risque",
      "optimal", "meilleur", "parfait", "conseiller"
"""

from dataclasses import dataclass
from typing import List, Dict, Optional

from app.constants.social_insurance import (
    TAUX_IMPOT_RETRAIT_CAPITAL,
    MARRIED_CAPITAL_TAX_DISCOUNT,
    calculate_progressive_capital_tax,
)

from app.services.arbitrage.arbitrage_models import (
    YearlySnapshot,
    TrajectoireOption,
    ArbitrageResult,
    compute_terminal_spread,
    add_tornado_sensitivity,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Compliance constants
# ═══════════════════════════════════════════════════════════════════════════════

_DISCLAIMER = (
    "Outil educatif simplifie. Ne constitue pas un conseil financier "
    "personnalise au sens de la LSFin. Les projections reposent sur des "
    "hypotheses simplifiees. Consulte un\u00b7e specialiste pour une analyse "
    "adaptee a ta situation."
)

_SOURCES = [
    "LIFD art. 38 (imposition separee du capital de prevoyance)",
    "OPP3 art. 3 (retrait 3a des 59/60 ans)",
    "LPP art. 13 (retraite anticipee des 58 ans)",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Data model
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class RetirementAsset:
    """A retirement asset eligible for withdrawal.

    Attributes:
        type: Asset type ("3a", "lpp", "libre_passage").
        amount: Current value (CHF).
        earliest_withdrawal_age: Earliest age for withdrawal.
            3a: 59 for women, 60 for men.
            LPP: 58-65.
            Libre passage: depends on situation.
    """
    type: str
    amount: float
    earliest_withdrawal_age: int


# ═══════════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _get_base_rate(canton: str, is_married: bool) -> float:
    """Get the capital tax base rate for a canton, with married discount."""
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    if is_married:
        base_rate *= MARRIED_CAPITAL_TAX_DISCOUNT
    return base_rate


def _build_same_year_option(
    assets: List[RetirementAsset],
    age_retraite: int,
    canton: str,
    is_married: bool,
    base_rate_override: Optional[float] = None,
) -> TrajectoireOption:
    """Build Option A: Everything withdrawn the same year.

    All assets are withdrawn at retirement age.
    Total capital is taxed as a single lump sum (progressive brackets hit hard).
    """
    total_capital = sum(a.amount for a in assets)
    base_rate = (
        base_rate_override
        if base_rate_override is not None
        else _get_base_rate(canton, is_married)
    )
    total_tax = calculate_progressive_capital_tax(total_capital, base_rate)
    net_after_tax = total_capital - total_tax

    # Single-year trajectory
    trajectory = [
        YearlySnapshot(
            year=age_retraite,
            net_patrimony=round(net_after_tax, 2),
            annual_cashflow=round(net_after_tax, 2),
            cumulative_tax_delta=round(total_tax, 2),
        )
    ]

    return TrajectoireOption(
        id="same_year",
        label="Retrait total la meme annee",
        trajectory=trajectory,
        terminal_value=round(net_after_tax, 2),
        cumulative_tax_impact=round(total_tax, 2),
    )


def _build_staggered_option(
    assets: List[RetirementAsset],
    age_retraite: int,
    canton: str,
    is_married: bool,
    base_rate_override: Optional[float] = None,
) -> TrajectoireOption:
    """Build Option B: Optimally staggered withdrawals.

    Sort assets by earliest_withdrawal_age.
    Each withdrawal is taxed separately at lower progressive brackets.
    """
    if not assets:
        return TrajectoireOption(
            id="staggered",
            label="Retraits echelonnes",
            trajectory=[],
            terminal_value=0.0,
            cumulative_tax_impact=0.0,
        )

    # Sort by earliest withdrawal age (ascending)
    sorted_assets = sorted(assets, key=lambda a: a.earliest_withdrawal_age)

    # Assign withdrawal years: spread across available years
    # If multiple assets have the same earliest_withdrawal_age, spread them
    base_rate = (
        base_rate_override
        if base_rate_override is not None
        else _get_base_rate(canton, is_married)
    )
    trajectory: List[YearlySnapshot] = []
    cumulative_net = 0.0
    cumulative_tax = 0.0

    # Build withdrawal schedule
    schedule: List[tuple] = []  # (year, asset_type, amount)

    # Assign each asset to a distinct year when possible
    used_years = set()
    for asset in sorted_assets:
        # Find the earliest available year
        year = max(asset.earliest_withdrawal_age, min(used_years) if used_years else asset.earliest_withdrawal_age)
        # Try the natural withdrawal age first
        candidate = asset.earliest_withdrawal_age
        while candidate in used_years and candidate <= age_retraite:
            candidate += 1
        # If all years up to retirement are taken, use retirement age
        if candidate > age_retraite:
            candidate = age_retraite
        used_years.add(candidate)
        schedule.append((candidate, asset.type, asset.amount))

    # Sort schedule by year
    schedule.sort(key=lambda x: x[0])

    # Group by year (in case multiple assets end up same year)
    year_groups: Dict[int, float] = {}
    year_labels: Dict[int, List[str]] = {}
    for year, asset_type, amount in schedule:
        year_groups[year] = year_groups.get(year, 0.0) + amount
        if year not in year_labels:
            year_labels[year] = []
        year_labels[year].append(asset_type)

    # Build trajectory year by year
    for year in sorted(year_groups.keys()):
        amount = year_groups[year]
        tax = calculate_progressive_capital_tax(amount, base_rate)
        net = amount - tax
        cumulative_net += net
        cumulative_tax += tax

        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(cumulative_net, 2),
            annual_cashflow=round(net, 2),
            cumulative_tax_delta=round(cumulative_tax, 2),
        ))

    return TrajectoireOption(
        id="staggered",
        label="Retraits echelonnes sur plusieurs annees",
        trajectory=trajectory,
        terminal_value=round(cumulative_net, 2),
        cumulative_tax_impact=round(cumulative_tax, 2),
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Main function
# ═══════════════════════════════════════════════════════════════════════════════

def compare_calendrier_retraits(
    assets: List[RetirementAsset],
    age_retraite: int = 65,
    canton: str = "VD",
    is_married: bool = False,
) -> ArbitrageResult:
    """Compare same-year vs staggered capital withdrawals.

    ALWAYS returns 2 options:
    - Option A: Everything withdrawn the same year (progressive brackets)
    - Option B: Optimally staggered withdrawals (each taxed separately)

    NEVER ranks options. Uses educational, non-prescriptive language.

    Args:
        assets: List of RetirementAsset (3a, lpp, libre_passage).
        age_retraite: Retirement age (default 65).
        canton: Canton code for tax estimation (default VD).
        is_married: Married status for tax splitting (default False).

    Returns:
        ArbitrageResult with 2 options, breakeven, sensitivity, and compliance.
    """
    # Validate canton
    canton = canton.upper()
    if canton not in TAUX_IMPOT_RETRAIT_CAPITAL:
        canton = "VD"

    # Filter out zero-amount assets
    valid_assets = [a for a in assets if a.amount > 0]

    # Build 2 options
    option_a = _build_same_year_option(
        assets=valid_assets,
        age_retraite=age_retraite,
        canton=canton,
        is_married=is_married,
    )

    option_b = _build_staggered_option(
        assets=valid_assets,
        age_retraite=age_retraite,
        canton=canton,
        is_married=is_married,
    )

    options = [option_a, option_b]

    # Breakeven: staggered is always cheaper or equal, so -1
    breakeven_year = -1

    # Chiffre choc: THE key number — tax saved by staggering
    tax_same_year = option_a.cumulative_tax_impact
    tax_staggered = option_b.cumulative_tax_impact
    delta_tax = tax_same_year - tax_staggered
    delta_net = option_b.terminal_value - option_a.terminal_value

    total_capital = sum(a.amount for a in valid_assets)
    if delta_tax > 0:
        chiffre_choc = (
            f"Dans ce scenario simule, echelonner les retraits pourrait "
            f"permettre d'economiser {delta_tax:,.0f} CHF d'impots "
            f"sur un capital total de {total_capital:,.0f} CHF — "
            f"soit {delta_net:,.0f} CHF de plus en patrimoine net."
        )
    else:
        chiffre_choc = (
            f"Dans ce scenario simule, l'echelonnement des retraits "
            f"ne presente pas d'avantage fiscal significatif pour un "
            f"capital total de {total_capital:,.0f} CHF."
        )

    # Display summary
    n_assets = len(valid_assets)
    display_summary = (
        f"Dans ce scenario simule, avec {n_assets} avoir(s) de prevoyance "
        f"totalisant {total_capital:,.0f} CHF, l'echelonnement des retraits "
        f"sur plusieurs annees fiscales peut reduire significativement "
        f"l'impact de la progressivite de l'impot."
    )

    # Build withdrawal schedule description for hypotheses
    schedule_desc = []
    sorted_assets = sorted(valid_assets, key=lambda a: a.earliest_withdrawal_age)
    for a in sorted_assets:
        schedule_desc.append(
            f"{a.type}: {a.amount:,.0f} CHF (retrait possible des {a.earliest_withdrawal_age} ans)"
        )

    # Hypotheses
    situation = "marie\u00b7e" if is_married else "celibataire"
    hypotheses = [
        f"Capital total: {total_capital:,.0f} CHF repartis sur {n_assets} avoir(s)",
        *schedule_desc,
        f"Age de retraite: {age_retraite} ans",
        f"Canton de domicile fiscal: {canton}",
        f"Situation familiale: {situation}",
        f"Impot retrait same-year: {tax_same_year:,.0f} CHF",
        f"Impot retraits echelonnes: {tax_staggered:,.0f} CHF",
        "Chaque retrait est impose separement (LIFD art. 38)",
        "Les montants sont en valeur actuelle (pas d'indexation)",
    ]

    # Sensitivity
    base_spread = compute_terminal_spread(options)
    sensitivity: Dict[str, float] = {}

    base_rate_current = _get_base_rate(canton, is_married)

    def _spread_variant(
        *,
        capital_scale: float = 1.0,
        age_variant: int = age_retraite,
        base_rate_variant: float = base_rate_current,
    ) -> float:
        scaled_assets = [
            RetirementAsset(
                type=a.type,
                amount=max(0.0, a.amount * capital_scale),
                earliest_withdrawal_age=a.earliest_withdrawal_age,
            )
            for a in assets
        ]
        variant_same_year = _build_same_year_option(
            scaled_assets,
            age_variant,
            canton,
            is_married,
            base_rate_override=base_rate_variant,
        )
        variant_staggered = _build_staggered_option(
            scaled_assets,
            age_variant,
            canton,
            is_married,
            base_rate_override=base_rate_variant,
        )
        return compute_terminal_spread([variant_same_year, variant_staggered])

    # Keep legacy key expected by tests and reporting.
    base_rate_vd = TAUX_IMPOT_RETRAIT_CAPITAL.get("VD", 0.08)
    base_rate_zg = TAUX_IMPOT_RETRAIT_CAPITAL.get("ZG", 0.035)
    tax_vd = calculate_progressive_capital_tax(total_capital, base_rate_vd)
    tax_zg = calculate_progressive_capital_tax(total_capital, base_rate_zg)
    sensitivity["canton_impact_VD_vs_ZG"] = round(tax_vd - tax_zg, 2)

    rate_low = max(0.0, base_rate_current - 0.01)
    rate_high = base_rate_current + 0.01
    add_tornado_sensitivity(
        sensitivity,
        "taux_impot_capital",
        base_value=base_spread,
        low_value=_spread_variant(base_rate_variant=rate_low),
        high_value=_spread_variant(base_rate_variant=rate_high),
        assumption_low=rate_low,
        assumption_high=rate_high,
    )

    age_low = max(58, age_retraite - 2)
    age_high = min(70, age_retraite + 2)
    add_tornado_sensitivity(
        sensitivity,
        "age_retraite",
        base_value=base_spread,
        low_value=_spread_variant(age_variant=age_low),
        high_value=_spread_variant(age_variant=age_high),
        assumption_low=float(age_low),
        assumption_high=float(age_high),
    )

    cap_low = total_capital * 0.90
    cap_high = total_capital * 1.10
    add_tornado_sensitivity(
        sensitivity,
        "capital_total",
        base_value=base_spread,
        low_value=_spread_variant(capital_scale=0.90),
        high_value=_spread_variant(capital_scale=1.10),
        assumption_low=cap_low,
        assumption_high=cap_high,
    )

    # Confidence score: high when concrete amounts provided
    confidence_score = 80.0 if valid_assets else 0.0

    return ArbitrageResult(
        options=options,
        breakeven_year=breakeven_year,
        chiffre_choc=chiffre_choc,
        display_summary=display_summary,
        hypotheses=hypotheses,
        disclaimer=_DISCLAIMER,
        sources=list(_SOURCES),
        confidence_score=confidence_score,
        sensitivity=sensitivity,
    )
