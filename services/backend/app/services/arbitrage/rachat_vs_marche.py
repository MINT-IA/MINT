"""
Rachat LPP vs Investissement Libre — Pure function for buyback vs market arbitrage.

Sprint S33 — Arbitrage Phase 2.

Compares 2 options:
- Option A: Rachat LPP (voluntary buyback with tax deduction)
- Option B: Investissement libre (free market investment)

All constants are imported from app.constants.social_insurance (NEVER hardcoded).

Sources:
    - LPP art. 79b (rachat volontaire)
    - LPP art. 79b al. 3 (blocage 3 ans apres rachat)
    - LIFD art. 33 (deduction fiscale des rachats)
    - OPP2 art. 60a (conditions de rachat)

Rules:
    - NEVER rank options. Use "Dans ce scenario simule..." language
    - hypotheses must list ALL assumptions
    - disclaimer ALWAYS present mentioning "outil educatif", "LSFin"
    - NEVER use banned terms: "garanti", "certain", "assure", "sans risque",
      "optimal", "meilleur", "parfait", "conseiller"
"""

from typing import List, Dict

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
    "LPP art. 79b (rachat volontaire)",
    "LPP art. 79b al. 3 (blocage 3 ans apres rachat)",
    "LIFD art. 33 (deduction fiscale des rachats)",
    "OPP2 art. 60a (conditions de rachat)",
]

# Wealth tax approximation
_WEALTH_TAX_RATE = 0.003  # ~0.3%/year on free investments


# ═══════════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _get_capital_tax(capital: float, canton: str, is_married: bool) -> float:
    """Calculate progressive capital withdrawal tax.

    Uses the centralized calculate_progressive_capital_tax from constants.
    """
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    if is_married:
        base_rate *= MARRIED_CAPITAL_TAX_DISCOUNT
    return calculate_progressive_capital_tax(capital, base_rate)


def _build_rachat_option(
    montant: float,
    taux_marginal: float,
    annees_avant_retraite: int,
    rendement_lpp: float,
    taux_conversion: float,
    canton: str,
    is_married: bool,
) -> TrajectoireOption:
    """Build Option A: Rachat LPP.

    Tax saving at buyback. Capital grows at caisse rate.
    At retirement: capital withdrawal taxed at progressive rate.
    Blocage 3 ans after buyback.
    """
    trajectory: List[YearlySnapshot] = []

    # Immediate tax saving from buyback
    tax_saving = montant * taux_marginal

    # Capital grows in LPP at caisse rate
    capital = montant
    cumulative_tax_delta = -tax_saving  # Negative = money saved

    for year in range(1, annees_avant_retraite + 1):
        capital *= (1 + rendement_lpp)

        # At retirement (last year): withdrawal tax
        if year == annees_avant_retraite:
            withdrawal_tax = _get_capital_tax(capital, canton, is_married)
            net_capital = capital - withdrawal_tax
            cumulative_tax_delta += withdrawal_tax
        else:
            net_capital = capital
            withdrawal_tax = 0.0

        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(net_capital, 2),
            annual_cashflow=round(capital * rendement_lpp / (1 + rendement_lpp) if year < annees_avant_retraite else -withdrawal_tax, 2),
            cumulative_tax_delta=round(cumulative_tax_delta, 2),
        ))

    # Terminal value = net capital after withdrawal tax + initial tax saving
    terminal = trajectory[-1].net_patrimony + tax_saving if trajectory else 0.0

    return TrajectoireOption(
        id="rachat_lpp",
        label="Rachat LPP (deduction fiscale + croissance en caisse)",
        trajectory=trajectory,
        terminal_value=round(terminal, 2),
        cumulative_tax_impact=round(cumulative_tax_delta, 2),
    )


def _build_marche_option(
    montant: float,
    annees_avant_retraite: int,
    rendement_marche: float,
) -> TrajectoireOption:
    """Build Option B: Investissement libre.

    No tax deduction. Capital grows at market return.
    Wealth tax ~0.3%/year. Full liquidity at all times.
    """
    trajectory: List[YearlySnapshot] = []

    capital = montant
    cumulative_wealth_tax = 0.0

    for year in range(1, annees_avant_retraite + 1):
        # Market growth
        capital *= (1 + rendement_marche)
        # Wealth tax
        wealth_tax = capital * _WEALTH_TAX_RATE
        capital -= wealth_tax
        cumulative_wealth_tax += wealth_tax

        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(capital, 2),
            annual_cashflow=round(capital * rendement_marche / (1 + rendement_marche) - wealth_tax, 2),
            cumulative_tax_delta=round(cumulative_wealth_tax, 2),
        ))

    terminal = trajectory[-1].net_patrimony if trajectory else 0.0

    return TrajectoireOption(
        id="investissement_libre",
        label="Investissement libre (liquidite totale)",
        trajectory=trajectory,
        terminal_value=round(terminal, 2),
        cumulative_tax_impact=round(cumulative_wealth_tax, 2),
    )


def _calculate_breakeven(option_a: TrajectoireOption, option_b: TrajectoireOption) -> int:
    """Find the year when option B overtakes option A (or vice versa).

    Returns the crossover year, or -1 if curves never cross.
    """
    if not option_a.trajectory or not option_b.trajectory:
        return -1

    min_len = min(len(option_a.trajectory), len(option_b.trajectory))
    if min_len == 0:
        return -1

    prev_diff = option_a.trajectory[0].net_patrimony - option_b.trajectory[0].net_patrimony

    for i in range(1, min_len):
        curr_diff = option_a.trajectory[i].net_patrimony - option_b.trajectory[i].net_patrimony
        if prev_diff * curr_diff < 0:
            return option_a.trajectory[i].year
        prev_diff = curr_diff

    return -1


# ═══════════════════════════════════════════════════════════════════════════════
# Main function
# ═══════════════════════════════════════════════════════════════════════════════

def compare_rachat_vs_marche(
    montant: float,
    taux_marginal: float,
    annees_avant_retraite: int = 20,
    rendement_lpp: float = 0.0125,
    rendement_marche: float = 0.04,
    taux_conversion: float = 0.068,
    canton: str = "VD",
    is_married: bool = False,
) -> ArbitrageResult:
    """Compare LPP buyback vs market investment.

    ALWAYS returns 2 options:
    - Option A: Rachat LPP (tax deduction + caisse growth + withdrawal tax)
    - Option B: Investissement libre (market growth + wealth tax)

    NEVER ranks options. Uses educational, non-prescriptive language.

    Args:
        montant: Amount to invest/buyback (CHF).
        taux_marginal: Marginal tax rate (0.0-0.50).
        annees_avant_retraite: Years before retirement (default 20).
        rendement_lpp: LPP interest rate (default 1.25%).
        rendement_marche: Market return (default 4%).
        taux_conversion: LPP conversion rate (default 6.8%).
        canton: Canton code for tax estimation (default VD).
        is_married: Married status for tax splitting (default False).

    Returns:
        ArbitrageResult with 2 options, breakeven, sensitivity, and compliance.
    """
    # Validate canton
    canton = canton.upper()
    if canton not in TAUX_IMPOT_RETRAIT_CAPITAL:
        canton = "VD"

    # Ensure non-negative
    annees_avant_retraite = max(1, annees_avant_retraite)

    # Build 2 options
    option_a = _build_rachat_option(
        montant=montant,
        taux_marginal=taux_marginal,
        annees_avant_retraite=annees_avant_retraite,
        rendement_lpp=rendement_lpp,
        taux_conversion=taux_conversion,
        canton=canton,
        is_married=is_married,
    )

    option_b = _build_marche_option(
        montant=montant,
        annees_avant_retraite=annees_avant_retraite,
        rendement_marche=rendement_marche,
    )

    options = [option_a, option_b]

    # Breakeven
    breakeven_year = _calculate_breakeven(option_a, option_b)

    # Chiffre choc
    delta = abs(option_a.terminal_value - option_b.terminal_value)
    tax_saving = montant * taux_marginal
    if option_a.terminal_value > option_b.terminal_value:
        chiffre_choc = (
            f"Dans ce scenario simule, le rachat LPP pourrait representer "
            f"{delta:,.0f} CHF de plus en patrimoine net apres {annees_avant_retraite} ans, "
            f"grace a une economie fiscale immediate de {tax_saving:,.0f} CHF — "
            f"mais avec un blocage de 3 ans (LPP art. 79b al. 3)."
        )
    else:
        chiffre_choc = (
            f"Dans ce scenario simule, l'investissement libre pourrait "
            f"representer {delta:,.0f} CHF de plus en patrimoine net apres "
            f"{annees_avant_retraite} ans — malgre l'absence de deduction fiscale."
        )

    # Display summary
    display_summary = (
        f"Dans ce scenario simule, sur {annees_avant_retraite} ans, "
        f"le rachat LPP et l'investissement libre presentent des profils "
        f"differents en termes de fiscalite, rendement et liquidite."
    )

    # Hypotheses
    situation = "marie\u00b7e" if is_married else "celibataire"
    hypotheses = [
        f"Montant a investir/racheter: {montant:,.0f} CHF",
        f"Taux marginal d'imposition: {taux_marginal * 100:.1f}%",
        f"Economie fiscale immediate du rachat: {tax_saving:,.0f} CHF",
        f"Rendement LPP en caisse: {rendement_lpp * 100:.2f}%/an",
        f"Rendement marche libre: {rendement_marche * 100:.1f}%/an",
        f"Impot sur la fortune: ~{_WEALTH_TAX_RATE * 100:.1f}%/an (investissement libre)",
        f"Taux de conversion LPP: {taux_conversion * 100:.1f}%",
        f"Annees avant la retraite: {annees_avant_retraite}",
        f"Canton de domicile fiscal: {canton}",
        f"Situation familiale: {situation}",
        "Blocage de 3 ans apres rachat LPP (LPP art. 79b al. 3)",
        "Retrait en capital a la retraite (impot progressif LIFD art. 38)",
        "Les rendements passes ne presagent pas des rendements futurs",
    ]

    base_spread = compute_terminal_spread(options)

    def _spread_variant(
        *,
        variant_taux_marginal: float = taux_marginal,
        variant_annees: int = annees_avant_retraite,
        variant_rendement_lpp: float = rendement_lpp,
        variant_rendement_marche: float = rendement_marche,
    ) -> float:
        variant_a = _build_rachat_option(
            montant=montant,
            taux_marginal=variant_taux_marginal,
            annees_avant_retraite=variant_annees,
            rendement_lpp=variant_rendement_lpp,
            taux_conversion=taux_conversion,
            canton=canton,
            is_married=is_married,
        )
        variant_b = _build_marche_option(
            montant=montant,
            annees_avant_retraite=variant_annees,
            rendement_marche=variant_rendement_marche,
        )
        return compute_terminal_spread([variant_a, variant_b])

    sensitivity: Dict[str, float] = {}

    rendement_marche_low = max(0.0, rendement_marche - 0.01)
    rendement_marche_high = rendement_marche + 0.01
    add_tornado_sensitivity(
        sensitivity,
        "rendement_marche",
        base_value=base_spread,
        low_value=_spread_variant(variant_rendement_marche=rendement_marche_low),
        high_value=_spread_variant(variant_rendement_marche=rendement_marche_high),
        assumption_low=rendement_marche_low,
        assumption_high=rendement_marche_high,
    )

    taux_marginal_low = max(0.0, taux_marginal - 0.02)
    taux_marginal_high = min(0.50, taux_marginal + 0.02)
    add_tornado_sensitivity(
        sensitivity,
        "taux_marginal",
        base_value=base_spread,
        low_value=_spread_variant(variant_taux_marginal=taux_marginal_low),
        high_value=_spread_variant(variant_taux_marginal=taux_marginal_high),
        assumption_low=taux_marginal_low,
        assumption_high=taux_marginal_high,
    )

    rendement_lpp_low = max(0.0, rendement_lpp - 0.005)
    rendement_lpp_high = rendement_lpp + 0.005
    add_tornado_sensitivity(
        sensitivity,
        "rendement_lpp",
        base_value=base_spread,
        low_value=_spread_variant(variant_rendement_lpp=rendement_lpp_low),
        high_value=_spread_variant(variant_rendement_lpp=rendement_lpp_high),
        assumption_low=rendement_lpp_low,
        assumption_high=rendement_lpp_high,
    )

    annees_low = max(1, annees_avant_retraite - 2)
    annees_high = min(40, annees_avant_retraite + 2)
    add_tornado_sensitivity(
        sensitivity,
        "annees_avant_retraite",
        base_value=base_spread,
        low_value=_spread_variant(variant_annees=annees_low),
        high_value=_spread_variant(variant_annees=annees_high),
        assumption_low=float(annees_low),
        assumption_high=float(annees_high),
    )

    # Confidence score
    confidence_score = 70.0

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
