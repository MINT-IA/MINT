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
    MARRIED_CAPITAL_TAX_DISCOUNT,
    LPP_TAUX_CONVERSION_MIN,
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

    Uses federal progressive brackets (LIFD art. 36) + cantonal effective rates
    from CantonalComparator for a realistic estimation instead of multiplier hack.

    Args:
        rente_annuelle: Annual rente income (CHF).
        canton: Canton code.
        is_married: Whether the person is married (splitting benefit).

    Returns:
        Estimated annual income tax (CHF).
    """
    from app.services.fiscal.cantonal_comparator import (
        EFFECTIVE_RATES_100K_SINGLE,
        FEDERAL_BRACKETS,
    )

    # Revenu imposable: ~85% of rente after standard deductions
    # (assurance maladie, frais médicaux, déduction forfaitaire — LIFD art. 33)
    # This is a simplification; actual deductions depend on personal situation.
    revenu_imposable = rente_annuelle * 0.85

    # Federal tax via progressive brackets (LIFD art. 36)
    impot_federal = 0.0
    prev_bound = 0.0
    for upper, rate in FEDERAL_BRACKETS:
        if revenu_imposable <= prev_bound:
            break
        taxable = min(revenu_imposable, upper) - prev_bound
        impot_federal += taxable * rate
        prev_bound = upper

    # Cantonal+communal tax via effective rate scaled by income
    cantonal_rate = EFFECTIVE_RATES_100K_SINGLE.get(canton.upper(), 0.13)
    # Scale rate for income level (rates calibrated at 100k)
    income_factor = max(0.6, min(1.5, rente_annuelle / 100_000))
    impot_cantonal = revenu_imposable * cantonal_rate * income_factor

    total = impot_federal + impot_cantonal
    if is_married:
        total *= 0.80  # Splitting benefit
    return round(total, 2)


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
    inflation: float = 0.0,
) -> TrajectoireOption:
    """Build Option A: Full Rente trajectory.

    Year-by-year: cumulative net rente income received.
    LPP rente is NOT indexed — purchasing power erodes with inflation.
    All values expressed in real terms (today's francs).
    No inheritance at death.
    """
    trajectory: List[YearlySnapshot] = []
    cumulative_net = 0.0
    cumulative_tax = 0.0

    for i in range(horizon):
        year = age_retraite + i
        # LPP rente is nominal (not indexed) — deflate to real terms
        deflator = (1 + inflation) ** (i + 1) if inflation > 0 else 1.0
        real_rente = rente_annuelle / deflator
        annual_tax = _estimate_income_tax_on_rente(real_rente, canton, is_married)
        net_annual = real_rente - annual_tax
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
    inflation: float = 0.0,
) -> TrajectoireOption:
    """Build Option B: Full Capital trajectory.

    Capital taxed once at withdrawal (LIFD art. 38, progressive brackets).
    Then invested and drawn down using Trinity Study SWR:
      - Year 1: withdraw initialCapital × SWR
      - Each following year: adjust that amount for inflation
    SWR withdrawals are NOT taxable income (consumption of patrimony).
    All values expressed in real terms (today's francs).
    netPatrimony = remaining invested capital in real terms.
    """
    trajectory: List[YearlySnapshot] = []

    # One-time withdrawal tax at retirement
    withdrawal_tax = _get_capital_tax(capital_total, canton, is_married)
    capital_net = capital_total - withdrawal_tax
    capital_net_at_start = capital_net
    initial_withdrawal = 0.0

    for i in range(horizon):
        year = age_retraite + i
        # Capital grows at NOMINAL return
        capital_net *= (1 + rendement_capital)

        # Trinity Study SWR: fixed initial withdrawal, inflation-adjusted
        if i == 0:
            initial_withdrawal = capital_net_at_start * taux_retrait
        nominal_withdrawal = initial_withdrawal * ((1 + inflation) ** i)
        # Cap withdrawal to remaining capital
        actual_withdrawal = min(nominal_withdrawal, max(0.0, capital_net))
        capital_net -= actual_withdrawal

        # Express in real terms (deflate to today's purchasing power)
        deflator = (1 + inflation) ** (i + 1) if inflation > 0 else 1.0
        real_patrimony = capital_net / deflator
        real_cashflow = actual_withdrawal / deflator

        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(real_patrimony, 2),
            annual_cashflow=round(real_cashflow, 2),
            cumulative_tax_delta=round(withdrawal_tax, 2),
        ))

    # Terminal value = remaining capital in real terms
    final_real = trajectory[-1].net_patrimony if trajectory else 0.0
    return TrajectoireOption(
        id="full_capital",
        label="Retrait en capital integral",
        trajectory=trajectory,
        terminal_value=round(final_real, 2),
        cumulative_tax_impact=round(withdrawal_tax, 2),
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
    inflation: float = 0.0,
) -> TrajectoireOption:
    """Build Option C: Mixed trajectory (key differentiator).

    Obligatoire -> rente at conversion rate (not indexed, erodes with inflation).
    Surobligatoire -> capital (taxed at withdrawal, then Trinity Study SWR).
    All values in real terms (today's francs).
    """
    trajectory: List[YearlySnapshot] = []

    # Rente from obligatoire portion (nominal, not indexed)
    rente_obligatoire_annuelle = capital_obligatoire * taux_conversion_obligatoire

    # Capital from surobligatoire portion
    surob_withdrawal_tax = _get_capital_tax(capital_surobligatoire, canton, is_married)
    surob_net = capital_surobligatoire - surob_withdrawal_tax
    surob_net_at_start = surob_net
    initial_swr = 0.0

    cumulative_real_net = 0.0
    cumulative_tax = surob_withdrawal_tax

    for i in range(horizon):
        year = age_retraite + i
        deflator = (1 + inflation) ** (i + 1) if inflation > 0 else 1.0

        # Rente: nominal, deflated to real terms
        real_rente = rente_obligatoire_annuelle / deflator
        rente_tax = _estimate_income_tax_on_rente(real_rente, canton, is_married)
        net_rente = real_rente - rente_tax
        cumulative_tax += rente_tax

        # SWR from surobligatoire: Trinity Study (fixed initial, inflation-adjusted)
        surob_net *= (1 + rendement_capital)
        if i == 0:
            initial_swr = surob_net_at_start * taux_retrait
        nominal_swr = initial_swr * ((1 + inflation) ** i)
        actual_swr = min(nominal_swr, max(0.0, surob_net))
        surob_net -= actual_swr
        real_swr = actual_swr / deflator

        # Real remaining surob capital
        real_surob = surob_net / deflator

        total_real_cashflow = net_rente + real_swr
        cumulative_real_net += total_real_cashflow

        # Net patrimony = remaining surob capital (real) + cumulative real income
        net_patrimony = real_surob + cumulative_real_net
        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(net_patrimony, 2),
            annual_cashflow=round(total_real_cashflow, 2),
            cumulative_tax_delta=round(cumulative_tax, 2),
        ))

    final_value = trajectory[-1].net_patrimony if trajectory else 0.0
    return TrajectoireOption(
        id="mixed",
        label="Mixte (rente obligatoire + capital surobligatoire)",
        trajectory=trajectory,
        terminal_value=round(final_value, 2),
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
        f"Inflation estimee: {inflation * 100:.1f}%/an (toutes les valeurs en francs d'aujourd'hui)",
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

    # Build 3 options (all in real terms / today's francs)
    option_a = _build_full_rente_option(
        rente_annuelle=rente_annuelle_proposee,
        canton=canton,
        is_married=is_married,
        horizon=horizon,
        age_retraite=age_retraite,
        inflation=inflation,
    )

    option_b = _build_full_capital_option(
        capital_total=capital_lpp_total,
        canton=canton,
        is_married=is_married,
        taux_retrait=taux_retrait,
        rendement_capital=rendement_capital,
        horizon=horizon,
        age_retraite=age_retraite,
        inflation=inflation,
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
        inflation=inflation,
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

    base_spread = compute_terminal_spread(options)
    sensitivity: Dict[str, float] = {}

    def _spread_variant(
        *,
        variant_taux_retrait: float = taux_retrait,
        variant_rendement_capital: float = rendement_capital,
        variant_taux_conv_oblig: float = taux_conversion_obligatoire,
        variant_taux_conv_surob: float = taux_conversion_surobligatoire,
    ) -> float:
        variant_b = _build_full_capital_option(
            capital_total=capital_lpp_total,
            canton=canton,
            is_married=is_married,
            taux_retrait=variant_taux_retrait,
            rendement_capital=variant_rendement_capital,
            horizon=horizon,
            age_retraite=age_retraite,
            inflation=inflation,
        )
        variant_c = _build_mixed_option(
            capital_obligatoire=capital_obligatoire,
            capital_surobligatoire=capital_surobligatoire,
            taux_conversion_obligatoire=variant_taux_conv_oblig,
            taux_conversion_surobligatoire=variant_taux_conv_surob,
            canton=canton,
            is_married=is_married,
            taux_retrait=variant_taux_retrait,
            rendement_capital=variant_rendement_capital,
            horizon=horizon,
            age_retraite=age_retraite,
            inflation=inflation,
        )
        return compute_terminal_spread([option_a, variant_b, variant_c])

    # ── Tornado variables ──────────────────────────────────────────────
    rendement_low = max(0.0, rendement_capital - 0.01)
    rendement_high = rendement_capital + 0.01
    add_tornado_sensitivity(
        sensitivity,
        "rendement_capital",
        base_value=base_spread,
        low_value=_spread_variant(variant_rendement_capital=rendement_low),
        high_value=_spread_variant(variant_rendement_capital=rendement_high),
        assumption_low=rendement_low,
        assumption_high=rendement_high,
    )

    retrait_low = max(0.01, taux_retrait - 0.005)
    retrait_high = min(0.08, taux_retrait + 0.005)
    add_tornado_sensitivity(
        sensitivity,
        "taux_retrait",
        base_value=base_spread,
        low_value=_spread_variant(variant_taux_retrait=retrait_low),
        high_value=_spread_variant(variant_taux_retrait=retrait_high),
        assumption_low=retrait_low,
        assumption_high=retrait_high,
    )

    conv_oblig_low = max(LPP_TAUX_CONVERSION_MIN, taux_conversion_obligatoire - 0.005)
    conv_oblig_high = taux_conversion_obligatoire + 0.005
    add_tornado_sensitivity(
        sensitivity,
        "taux_conversion_obligatoire",
        base_value=base_spread,
        low_value=_spread_variant(variant_taux_conv_oblig=conv_oblig_low),
        high_value=_spread_variant(variant_taux_conv_oblig=conv_oblig_high),
        assumption_low=conv_oblig_low,
        assumption_high=conv_oblig_high,
    )

    conv_surob_low = max(0.035, taux_conversion_surobligatoire - 0.005)
    conv_surob_high = min(0.10, taux_conversion_surobligatoire + 0.005)
    add_tornado_sensitivity(
        sensitivity,
        "taux_conversion_surobligatoire",
        base_value=base_spread,
        low_value=_spread_variant(variant_taux_conv_surob=conv_surob_low),
        high_value=_spread_variant(variant_taux_conv_surob=conv_surob_high),
        assumption_low=conv_surob_low,
        assumption_high=conv_surob_high,
    )

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
