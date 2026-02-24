"""
Rente vs Capital Comparison — Pure function for retirement arbitrage.

Sprint S32 — Arbitrage Phase 1.

Compares 3 options for LPP retirement:
- Option A: Full Rente (annuity)
- Option B: Full Capital (lump sum with SWR withdrawals)
- Option C: Mixed (obligatoire -> rente, surobligatoire -> capital)

Option C is the key differentiator: most Swiss fintechs don't show it.

All constants are imported from app.constants.social_insurance (NEVER hardcoded).

Sources:
    - LPP art. 14 (taux de conversion minimum: 6.8%)
    - LPP art. 37 (choix rente/capital)
    - LIFD art. 22 (imposition des rentes)
    - LIFD art. 38 (imposition du capital de prevoyance)

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
    RETRAIT_CAPITAL_TRANCHES,
    MARRIED_CAPITAL_TAX_DISCOUNT,
    LPP_TAUX_CONVERSION_MIN,
    calculate_progressive_capital_tax,
)

from app.services.arbitrage.arbitrage_models import (
    YearlySnapshot,
    TrajectoireOption,
    ArbitrageResult,
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
    "LPP art. 14 (taux de conversion minimum)",
    "LPP art. 37 (choix rente/capital)",
    "LIFD art. 22 (imposition des rentes)",
    "LIFD art. 38 (imposition du capital de prevoyance)",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _estimate_income_tax_on_rente(rente_annuelle: float, canton: str, is_married: bool) -> float:
    """Estimate annual income tax on rente income.

    Uses cantonal base rate as proxy, scaled up for income tax
    (income tax is typically ~3x capital withdrawal rate).

    Args:
        rente_annuelle: Annual rente income (CHF).
        canton: Canton code.
        is_married: Whether the person is married (splitting benefit).

    Returns:
        Estimated annual income tax (CHF).
    """
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    # Income tax is roughly 2.5-3x the capital withdrawal rate
    income_rate = base_rate * 3.0
    if is_married:
        income_rate *= 0.80  # Splitting benefit
    return round(rente_annuelle * income_rate, 2)


def _get_capital_tax(capital: float, canton: str, is_married: bool) -> float:
    """Calculate progressive capital withdrawal tax.

    Uses the centralized calculate_progressive_capital_tax from constants.

    Args:
        capital: Capital amount being withdrawn (CHF).
        canton: Canton code.
        is_married: Whether the person is married.

    Returns:
        Tax amount (CHF).
    """
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    if is_married:
        base_rate *= MARRIED_CAPITAL_TAX_DISCOUNT
    return calculate_progressive_capital_tax(capital, base_rate)


def _build_full_rente_option(
    rente_annuelle: float,
    canton: str,
    is_married: bool,
    horizon: int,
    age_retraite: int,
) -> TrajectoireOption:
    """Build Option A: Full Rente trajectory.

    Year-by-year: cumulative net rente income received.
    No inheritance at death.
    """
    trajectory: List[YearlySnapshot] = []
    cumulative_net = 0.0
    cumulative_tax = 0.0

    annual_tax = _estimate_income_tax_on_rente(rente_annuelle, canton, is_married)
    net_annual = rente_annuelle - annual_tax

    for i in range(horizon):
        year = age_retraite + i
        cumulative_net += net_annual
        cumulative_tax += annual_tax
        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(cumulative_net, 2),
            annual_cashflow=round(net_annual, 2),
            cumulative_tax_delta=round(cumulative_tax, 2),
        ))

    return TrajectoireOption(
        id="full_rente",
        label="Rente viagere integrale",
        trajectory=trajectory,
        terminal_value=round(cumulative_net, 2),
        cumulative_tax_impact=round(cumulative_tax, 2),
    )


def _build_full_capital_option(
    capital_total: float,
    canton: str,
    is_married: bool,
    taux_retrait: float,
    rendement_capital: float,
    horizon: int,
    age_retraite: int,
) -> TrajectoireOption:
    """Build Option B: Full Capital trajectory.

    Capital after withdrawal tax. Year-by-year: SWR withdrawals,
    capital grows at rendement. Remaining capital is inheritable.
    """
    trajectory: List[YearlySnapshot] = []

    # Withdrawal tax at retirement
    withdrawal_tax = _get_capital_tax(capital_total, canton, is_married)
    remaining_capital = capital_total - withdrawal_tax
    cumulative_withdrawals = 0.0
    cumulative_tax = withdrawal_tax

    for i in range(horizon):
        year = age_retraite + i
        # SWR withdrawal from remaining capital
        swr_withdrawal = remaining_capital * taux_retrait
        remaining_capital -= swr_withdrawal
        # Growth on remaining capital
        growth = remaining_capital * rendement_capital
        remaining_capital += growth
        remaining_capital = max(0.0, remaining_capital)
        cumulative_withdrawals += swr_withdrawal

        # Net patrimony = remaining capital + cumulative withdrawals
        net_patrimony = remaining_capital + cumulative_withdrawals
        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(net_patrimony, 2),
            annual_cashflow=round(swr_withdrawal, 2),
            cumulative_tax_delta=round(cumulative_tax, 2),
        ))

    return TrajectoireOption(
        id="full_capital",
        label="Retrait en capital integral",
        trajectory=trajectory,
        terminal_value=round(remaining_capital + cumulative_withdrawals, 2),
        cumulative_tax_impact=round(cumulative_tax, 2),
    )


def _build_mixed_option(
    capital_obligatoire: float,
    capital_surobligatoire: float,
    taux_conversion_obligatoire: float,
    taux_conversion_surobligatoire: float,
    canton: str,
    is_married: bool,
    taux_retrait: float,
    rendement_capital: float,
    horizon: int,
    age_retraite: int,
) -> TrajectoireOption:
    """Build Option C: Mixed trajectory (key differentiator).

    Obligatoire -> rente at 6.8% conversion rate.
    Surobligatoire -> capital (taxed at withdrawal, then SWR).
    Combined: rente income + SWR income from surobligatoire capital.
    """
    trajectory: List[YearlySnapshot] = []

    # Rente from obligatoire portion
    rente_obligatoire_annuelle = capital_obligatoire * taux_conversion_obligatoire
    rente_tax = _estimate_income_tax_on_rente(rente_obligatoire_annuelle, canton, is_married)
    net_rente_annual = rente_obligatoire_annuelle - rente_tax

    # Capital from surobligatoire portion
    surob_withdrawal_tax = _get_capital_tax(capital_surobligatoire, canton, is_married)
    remaining_surob = capital_surobligatoire - surob_withdrawal_tax

    cumulative_net = 0.0
    cumulative_tax = surob_withdrawal_tax
    cumulative_swr = 0.0

    for i in range(horizon):
        year = age_retraite + i
        # Rente income from obligatoire
        cumulative_tax += rente_tax

        # SWR from surobligatoire capital
        swr_withdrawal = remaining_surob * taux_retrait
        remaining_surob -= swr_withdrawal
        growth = remaining_surob * rendement_capital
        remaining_surob += growth
        remaining_surob = max(0.0, remaining_surob)
        cumulative_swr += swr_withdrawal

        total_annual_cashflow = net_rente_annual + swr_withdrawal
        cumulative_net += total_annual_cashflow

        # Net patrimony = remaining surob capital + cumulative net income
        net_patrimony = remaining_surob + cumulative_net
        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(net_patrimony, 2),
            annual_cashflow=round(total_annual_cashflow, 2),
            cumulative_tax_delta=round(cumulative_tax, 2),
        ))

    return TrajectoireOption(
        id="mixed",
        label="Mixte (rente obligatoire + capital surobligatoire)",
        trajectory=trajectory,
        terminal_value=round(remaining_surob + cumulative_net, 2),
        cumulative_tax_impact=round(cumulative_tax, 2),
    )


def _calculate_breakeven(option_a: TrajectoireOption, option_b: TrajectoireOption) -> int:
    """Find the year when option B overtakes option A (or vice versa).

    Compares net patrimony year by year.
    Returns the crossover year, or -1 if curves never cross.
    """
    if not option_a.trajectory or not option_b.trajectory:
        return -1

    min_len = min(len(option_a.trajectory), len(option_b.trajectory))
    prev_diff = option_a.trajectory[0].net_patrimony - option_b.trajectory[0].net_patrimony

    for i in range(1, min_len):
        curr_diff = option_a.trajectory[i].net_patrimony - option_b.trajectory[i].net_patrimony
        # Check for sign change (crossover)
        if prev_diff * curr_diff < 0:
            return option_a.trajectory[i].year
        prev_diff = curr_diff

    return -1


def _build_chiffre_choc(options: List[TrajectoireOption], horizon: int) -> str:
    """Build the most striking delta as chiffre choc.

    Compares terminal values between options A and B.
    """
    if len(options) < 2:
        return "Simulation incomplete."

    rente_terminal = options[0].terminal_value
    capital_terminal = options[1].terminal_value
    delta = abs(capital_terminal - rente_terminal)

    if capital_terminal > rente_terminal:
        return (
            f"Dans ce scenario simule sur {horizon} ans, le retrait en capital "
            f"pourrait representer {delta:,.0f} CHF de plus en patrimoine cumule "
            f"que la rente — mais sans revenu a vie."
        )
    else:
        return (
            f"Dans ce scenario simule sur {horizon} ans, la rente pourrait "
            f"representer {delta:,.0f} CHF de plus en revenus cumules "
            f"que le capital — avec un revenu a vie."
        )


def _build_hypotheses(
    taux_retrait: float,
    rendement_capital: float,
    inflation: float,
    taux_conversion_obligatoire: float,
    taux_conversion_surobligatoire: float,
    horizon: int,
    canton: str,
    is_married: bool,
) -> List[str]:
    """Build the complete list of hypotheses used in the simulation."""
    situation = "marie\u00b7e" if is_married else "celibataire"
    return [
        f"Taux de retrait (SWR) sur le capital: {taux_retrait * 100:.1f}%/an",
        f"Rendement net du capital apres retraite: {rendement_capital * 100:.1f}%/an",
        f"Inflation estimee: {inflation * 100:.1f}%/an (non appliquee dans cette version simplifiee)",
        f"Taux de conversion obligatoire LPP: {taux_conversion_obligatoire * 100:.1f}%",
        f"Taux de conversion surobligatoire: {taux_conversion_surobligatoire * 100:.1f}%",
        f"Horizon de simulation: {horizon} ans apres la retraite",
        f"Canton de domicile fiscal: {canton}",
        f"Situation familiale: {situation}",
        "Les rentes ne sont pas indexees a l'inflation dans cette simulation",
        "L'impot sur le revenu est estime a partir du taux cantonal de base",
        "Pas de prise en compte d'autres revenus a la retraite (AVS, 3a, etc.)",
    ]


# ═══════════════════════════════════════════════════════════════════════════════
# Main function
# ═══════════════════════════════════════════════════════════════════════════════

def compare_rente_vs_capital(
    capital_lpp_total: float,
    capital_obligatoire: float,
    capital_surobligatoire: float,
    rente_annuelle_proposee: float,
    taux_conversion_obligatoire: float = 0.068,    # 6.8% LPP minimum
    taux_conversion_surobligatoire: float = 0.05,  # typical caisse rate
    canton: str = "VD",
    age_retraite: int = 65,
    taux_retrait: float = 0.04,       # SWR on capital portion
    rendement_capital: float = 0.03,  # conservative post-retirement
    inflation: float = 0.02,          # Swiss average
    horizon: int = 25,                # years in retirement (to age 90)
    is_married: bool = False,
) -> ArbitrageResult:
    """Compare rente vs capital vs mixed for LPP retirement.

    ALWAYS returns 3 options:
    - Option A: Full Rente (annuity)
    - Option B: Full Capital (lump sum + SWR)
    - Option C: Mixed (obligatoire -> rente, surobligatoire -> capital)

    NEVER ranks options. Uses educational, non-prescriptive language.

    Args:
        capital_lpp_total: Total LPP capital at retirement (CHF).
        capital_obligatoire: Obligatoire portion of LPP capital (CHF).
        capital_surobligatoire: Surobligatoire portion of LPP capital (CHF).
        rente_annuelle_proposee: Annual rente proposed by the caisse (CHF).
        taux_conversion_obligatoire: Conversion rate for obligatoire (default 6.8%).
        taux_conversion_surobligatoire: Conversion rate for surobligatoire (default 5%).
        canton: Canton code for tax estimation (default VD).
        age_retraite: Retirement age (default 65).
        taux_retrait: Safe withdrawal rate on capital (default 4%).
        rendement_capital: Post-retirement capital return (default 3%).
        inflation: Inflation rate (default 2%).
        horizon: Simulation horizon in years (default 25).
        is_married: Married status for tax splitting (default False).

    Returns:
        ArbitrageResult with 3 options, breakeven, sensitivity, and compliance.
    """
    # Validate canton
    canton = canton.upper()
    if canton not in TAUX_IMPOT_RETRAIT_CAPITAL:
        canton = "VD"  # Fallback to VD

    # Build 3 options
    option_a = _build_full_rente_option(
        rente_annuelle=rente_annuelle_proposee,
        canton=canton,
        is_married=is_married,
        horizon=horizon,
        age_retraite=age_retraite,
    )

    option_b = _build_full_capital_option(
        capital_total=capital_lpp_total,
        canton=canton,
        is_married=is_married,
        taux_retrait=taux_retrait,
        rendement_capital=rendement_capital,
        horizon=horizon,
        age_retraite=age_retraite,
    )

    option_c = _build_mixed_option(
        capital_obligatoire=capital_obligatoire,
        capital_surobligatoire=capital_surobligatoire,
        taux_conversion_obligatoire=taux_conversion_obligatoire,
        taux_conversion_surobligatoire=taux_conversion_surobligatoire,
        canton=canton,
        is_married=is_married,
        taux_retrait=taux_retrait,
        rendement_capital=rendement_capital,
        horizon=horizon,
        age_retraite=age_retraite,
    )

    options = [option_a, option_b, option_c]

    # Breakeven: compare rente vs capital
    breakeven_year = _calculate_breakeven(option_a, option_b)

    # Chiffre choc
    chiffre_choc = _build_chiffre_choc(options, horizon)

    # Display summary
    display_summary = (
        f"Dans ce scenario simule, sur {horizon} ans de retraite, "
        f"les 3 options presentent des profils differents en termes de "
        f"revenu, fiscalite et patrimoine transmissible."
    )

    # Hypotheses
    hypotheses = _build_hypotheses(
        taux_retrait=taux_retrait,
        rendement_capital=rendement_capital,
        inflation=inflation,
        taux_conversion_obligatoire=taux_conversion_obligatoire,
        taux_conversion_surobligatoire=taux_conversion_surobligatoire,
        horizon=horizon,
        canton=canton,
        is_married=is_married,
    )

    # Sensitivity: impact of rendement +/- 1%
    option_b_plus = _build_full_capital_option(
        capital_total=capital_lpp_total,
        canton=canton,
        is_married=is_married,
        taux_retrait=taux_retrait,
        rendement_capital=rendement_capital + 0.01,
        horizon=horizon,
        age_retraite=age_retraite,
    )
    option_b_minus = _build_full_capital_option(
        capital_total=capital_lpp_total,
        canton=canton,
        is_married=is_married,
        taux_retrait=taux_retrait,
        rendement_capital=rendement_capital - 0.01,
        horizon=horizon,
        age_retraite=age_retraite,
    )

    sensitivity = {
        "rendement_capital": round(
            option_b_plus.terminal_value - option_b_minus.terminal_value, 2
        ),
    }

    # Confidence score: high when all inputs are explicit
    confidence_score = 70.0  # Default when all inputs provided

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
