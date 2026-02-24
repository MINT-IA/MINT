"""
Allocation Annuelle Comparison — Pure function for annual allocation arbitrage.

Sprint S32 — Arbitrage Phase 1.

Compares up to 4 options for allocating available savings:
- Option 1: 3a (tax-deductible pillar 3a contribution)
- Option 2: Rachat LPP (voluntary LPP buyback)
- Option 3: Amortissement indirect (indirect mortgage amortization via 3a)
- Option 4: Investissement libre (free investment, always available)

All constants are imported from app.constants.social_insurance (NEVER hardcoded).

Sources:
    - OPP3 art. 7 (plafond 3a: 7'258 CHF avec LPP)
    - LPP art. 79b (rachat LPP, blocage 3 ans)
    - LIFD art. 33 (deductions fiscales)
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
    PILIER_3A_PLAFOND_AVEC_LPP,
    LPP_TAUX_INTERET_MIN,
    TAUX_IMPOT_RETRAIT_CAPITAL,
    MARRIED_CAPITAL_TAX_DISCOUNT,
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
    "OPP3 art. 7 (plafond 3a: 7'258 CHF avec LPP)",
    "LPP art. 79b (rachat volontaire, blocage 3 ans)",
    "LIFD art. 33 (deductions fiscales prevoyance)",
    "LIFD art. 38 (imposition du capital de prevoyance)",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _build_3a_option(
    montant: float,
    taux_marginal: float,
    annees: int,
    rendement_3a: float,
    canton: str,
) -> TrajectoireOption:
    """Build Option 1: Pillar 3a contribution trajectory.

    Annual contribution capped at PILIER_3A_PLAFOND_AVEC_LPP (7'258 CHF).
    Tax saving each year = contribution * taux_marginal.
    Growth compounded. At retirement: taxed at capital withdrawal rate.
    """
    contribution = min(montant, PILIER_3A_PLAFOND_AVEC_LPP)
    trajectory: List[YearlySnapshot] = []

    capital_3a = 0.0
    cumulative_tax_saving = 0.0

    for i in range(annees):
        # Annual contribution
        capital_3a += contribution
        # Growth on total
        growth = capital_3a * rendement_3a
        capital_3a += growth
        # Tax saving
        annual_tax_saving = contribution * taux_marginal
        cumulative_tax_saving += annual_tax_saving

        trajectory.append(YearlySnapshot(
            year=i + 1,
            net_patrimony=round(capital_3a + cumulative_tax_saving, 2),
            annual_cashflow=round(contribution, 2),
            cumulative_tax_delta=round(-cumulative_tax_saving, 2),  # negative = saving
        ))

    # Tax at withdrawal
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    withdrawal_tax = calculate_progressive_capital_tax(capital_3a, base_rate)
    net_capital = capital_3a - withdrawal_tax
    terminal_value = net_capital + cumulative_tax_saving
    total_tax_impact = withdrawal_tax - cumulative_tax_saving  # net tax effect

    return TrajectoireOption(
        id="3a",
        label="Pilier 3a (prevoyance liee)",
        trajectory=trajectory,
        terminal_value=round(terminal_value, 2),
        cumulative_tax_impact=round(total_tax_impact, 2),
    )


def _build_rachat_lpp_option(
    montant: float,
    potentiel_rachat: float,
    taux_marginal: float,
    annees: int,
    rendement_lpp: float,
    canton: str,
) -> TrajectoireOption:
    """Build Option 2: Rachat LPP (voluntary buyback) trajectory.

    Annual buyback capped at potentiel_rachat.
    Tax saving each year = buyback * taux_marginal.
    Growth at caisse rate (default 1.25%).
    Blocage: LPP art. 79b al. 3 -- cannot withdraw for 3 years after buyback.
    """
    annual_buyback = min(montant, potentiel_rachat)
    # Spread over years: cap total at potentiel_rachat
    remaining_potentiel = potentiel_rachat
    trajectory: List[YearlySnapshot] = []

    capital_lpp = 0.0
    cumulative_tax_saving = 0.0

    for i in range(annees):
        # Annual buyback (capped by remaining potential)
        this_year_buyback = min(annual_buyback, remaining_potentiel)
        remaining_potentiel -= this_year_buyback

        capital_lpp += this_year_buyback
        # Growth on total
        growth = capital_lpp * rendement_lpp
        capital_lpp += growth
        # Tax saving
        annual_tax_saving = this_year_buyback * taux_marginal
        cumulative_tax_saving += annual_tax_saving

        trajectory.append(YearlySnapshot(
            year=i + 1,
            net_patrimony=round(capital_lpp + cumulative_tax_saving, 2),
            annual_cashflow=round(this_year_buyback, 2),
            cumulative_tax_delta=round(-cumulative_tax_saving, 2),
        ))

    # At retirement: capital can be converted to rente or withdrawn
    # For comparison: assume capital withdrawal (like 3a)
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    withdrawal_tax = calculate_progressive_capital_tax(capital_lpp, base_rate)
    net_capital = capital_lpp - withdrawal_tax
    terminal_value = net_capital + cumulative_tax_saving
    total_tax_impact = withdrawal_tax - cumulative_tax_saving

    return TrajectoireOption(
        id="rachat_lpp",
        label="Rachat LPP (prevoyance professionnelle)",
        trajectory=trajectory,
        terminal_value=round(terminal_value, 2),
        cumulative_tax_impact=round(total_tax_impact, 2),
    )


def _build_amortissement_indirect_option(
    montant: float,
    taux_marginal: float,
    annees: int,
    taux_hypothecaire: float,
    rendement_3a: float,
    canton: str,
) -> TrajectoireOption:
    """Build Option 3: Amortissement indirect (indirect mortgage amortization).

    Montant goes to 3a earmarked for mortgage repayment.
    Tax saving: taux_marginal * montant (3a deduction + maintained mortgage interest deduction).
    Net benefit = tax saving from 3a + maintained interest deduction - opportunity cost.
    """
    contribution = min(montant, PILIER_3A_PLAFOND_AVEC_LPP)
    trajectory: List[YearlySnapshot] = []

    capital_3a = 0.0
    cumulative_tax_saving = 0.0

    for i in range(annees):
        capital_3a += contribution
        growth = capital_3a * rendement_3a
        capital_3a += growth

        # Tax saving from 3a deduction
        tax_saving_3a = contribution * taux_marginal
        # Additional benefit: maintained mortgage interest deduction
        # Interest on the "not-amortized" portion stays deductible
        interest_deduction_benefit = contribution * taux_hypothecaire * taux_marginal
        total_annual_saving = tax_saving_3a + interest_deduction_benefit
        cumulative_tax_saving += total_annual_saving

        trajectory.append(YearlySnapshot(
            year=i + 1,
            net_patrimony=round(capital_3a + cumulative_tax_saving, 2),
            annual_cashflow=round(contribution, 2),
            cumulative_tax_delta=round(-cumulative_tax_saving, 2),
        ))

    # At retirement: 3a used to repay mortgage (capital withdrawal tax applies)
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    withdrawal_tax = calculate_progressive_capital_tax(capital_3a, base_rate)
    net_capital = capital_3a - withdrawal_tax
    terminal_value = net_capital + cumulative_tax_saving
    total_tax_impact = withdrawal_tax - cumulative_tax_saving

    return TrajectoireOption(
        id="amort_indirect",
        label="Amortissement indirect (3a pour hypotheque)",
        trajectory=trajectory,
        terminal_value=round(terminal_value, 2),
        cumulative_tax_impact=round(total_tax_impact, 2),
    )


def _build_investissement_libre_option(
    montant: float,
    annees: int,
    rendement_marche: float,
    canton: str,
) -> TrajectoireOption:
    """Build Option 4: Investissement libre (free investment).

    No tax deduction. Full liquidity. Growth at market return.
    Wealth tax applies annually (~0.3-0.5%).
    """
    # Approximate wealth tax rate
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    wealth_tax_rate = base_rate * 0.05  # Very rough proxy: ~0.2-0.4%
    wealth_tax_rate = max(0.002, min(wealth_tax_rate, 0.005))

    trajectory: List[YearlySnapshot] = []
    capital = 0.0
    cumulative_tax = 0.0

    for i in range(annees):
        capital += montant
        growth = capital * rendement_marche
        capital += growth
        # Annual wealth tax
        annual_wealth_tax = capital * wealth_tax_rate
        capital -= annual_wealth_tax
        cumulative_tax += annual_wealth_tax

        trajectory.append(YearlySnapshot(
            year=i + 1,
            net_patrimony=round(capital, 2),
            annual_cashflow=round(montant, 2),
            cumulative_tax_delta=round(cumulative_tax, 2),
        ))

    return TrajectoireOption(
        id="invest_libre",
        label="Investissement libre (placement non lie)",
        trajectory=trajectory,
        terminal_value=round(capital, 2),
        cumulative_tax_impact=round(cumulative_tax, 2),
    )


def _build_hypotheses(
    montant: float,
    taux_marginal: float,
    annees: int,
    rendement_3a: float,
    rendement_lpp: float,
    rendement_marche: float,
    taux_hypothecaire: float,
    canton: str,
    a3a_maxed: bool,
    potentiel_rachat_lpp: float,
    is_property_owner: bool,
) -> List[str]:
    """Build the complete list of hypotheses used in the simulation."""
    hypotheses = [
        f"Montant disponible annuel: {montant:,.0f} CHF",
        f"Taux marginal d'imposition estime: {taux_marginal * 100:.1f}%",
        f"Horizon: {annees} ans avant la retraite",
        f"Rendement 3a: {rendement_3a * 100:.1f}%/an",
        f"Rendement LPP (caisse): {rendement_lpp * 100:.2f}%/an",
        f"Rendement marche libre: {rendement_marche * 100:.1f}%/an",
        f"Canton de domicile fiscal: {canton}",
        f"3a deja verse au maximum: {'oui' if a3a_maxed else 'non'}",
        f"Potentiel de rachat LPP: {potentiel_rachat_lpp:,.0f} CHF",
        f"Proprietaire: {'oui' if is_property_owner else 'non'}",
    ]
    if is_property_owner:
        hypotheses.append(
            f"Taux hypothecaire: {taux_hypothecaire * 100:.2f}%"
        )
    hypotheses.extend([
        "LPP art. 79b al. 3: blocage de 3 ans apres un rachat LPP "
        "(pas de retrait en capital dans les 3 ans suivant un rachat)",
        "L'impot sur la fortune est estime de maniere simplifiee",
        "Les rendements passes ne presagent pas des rendements futurs",
    ])
    return hypotheses


# ═══════════════════════════════════════════════════════════════════════════════
# Main function
# ═══════════════════════════════════════════════════════════════════════════════

def compare_allocation_annuelle(
    montant_disponible: float,
    taux_marginal: float,
    a3a_maxed: bool = False,
    potentiel_rachat_lpp: float = 0,
    is_property_owner: bool = False,
    taux_hypothecaire: float = 0.015,
    annees_avant_retraite: int = 20,
    rendement_3a: float = 0.02,
    rendement_lpp: float = 0.0125,
    rendement_marche: float = 0.04,
    canton: str = "VD",
) -> ArbitrageResult:
    """Compare allocation strategies for available annual savings.

    Returns UP TO 4 options depending on eligibility:
    - 3a: only if a3a_maxed is False
    - Rachat LPP: only if potentiel_rachat_lpp > 0
    - Amortissement indirect: only if is_property_owner is True
    - Investissement libre: always available

    NEVER ranks options. Uses educational, non-prescriptive language.

    Args:
        montant_disponible: Amount available for allocation (CHF/year).
        taux_marginal: Marginal tax rate (0.0 - 0.50).
        a3a_maxed: Whether 3a is already fully contributed this year.
        potentiel_rachat_lpp: Available LPP buyback potential (CHF).
        is_property_owner: Whether the user owns property.
        taux_hypothecaire: Current mortgage rate (default 1.5%).
        annees_avant_retraite: Years before retirement (default 20).
        rendement_3a: Expected 3a return (default 2%).
        rendement_lpp: Expected LPP caisse return (default 1.25%).
        rendement_marche: Expected free market return (default 4%).
        canton: Canton code for tax estimation (default VD).

    Returns:
        ArbitrageResult with eligible options, sensitivity, and compliance.
    """
    # Validate canton
    canton = canton.upper()
    if canton not in TAUX_IMPOT_RETRAIT_CAPITAL:
        canton = "VD"

    options: List[TrajectoireOption] = []

    # Option 1: 3a (only if not maxed)
    if not a3a_maxed and montant_disponible > 0:
        options.append(_build_3a_option(
            montant=montant_disponible,
            taux_marginal=taux_marginal,
            annees=annees_avant_retraite,
            rendement_3a=rendement_3a,
            canton=canton,
        ))

    # Option 2: Rachat LPP (only if potential > 0)
    if potentiel_rachat_lpp > 0 and montant_disponible > 0:
        options.append(_build_rachat_lpp_option(
            montant=montant_disponible,
            potentiel_rachat=potentiel_rachat_lpp,
            taux_marginal=taux_marginal,
            annees=annees_avant_retraite,
            rendement_lpp=rendement_lpp,
            canton=canton,
        ))

    # Option 3: Amortissement indirect (only if property owner)
    if is_property_owner and montant_disponible > 0:
        options.append(_build_amortissement_indirect_option(
            montant=montant_disponible,
            taux_marginal=taux_marginal,
            annees=annees_avant_retraite,
            taux_hypothecaire=taux_hypothecaire,
            rendement_3a=rendement_3a,
            canton=canton,
        ))

    # Option 4: Investissement libre (always available)
    options.append(_build_investissement_libre_option(
        montant=montant_disponible,
        annees=annees_avant_retraite,
        rendement_marche=rendement_marche,
        canton=canton,
    ))

    # Breakeven: compare 3a vs invest libre if both present
    breakeven_year = -1
    option_3a = next((o for o in options if o.id == "3a"), None)
    option_libre = next((o for o in options if o.id == "invest_libre"), None)
    if option_3a and option_libre:
        # Find when invest libre overtakes 3a
        min_len = min(len(option_3a.trajectory), len(option_libre.trajectory))
        if min_len > 1:
            prev_diff = (option_3a.trajectory[0].net_patrimony
                         - option_libre.trajectory[0].net_patrimony)
            for i in range(1, min_len):
                curr_diff = (option_3a.trajectory[i].net_patrimony
                             - option_libre.trajectory[i].net_patrimony)
                if prev_diff * curr_diff < 0:
                    breakeven_year = option_3a.trajectory[i].year
                    break
                prev_diff = curr_diff

    # Chiffre choc
    if option_3a and option_libre:
        delta = abs(option_3a.terminal_value - option_libre.terminal_value)
        if option_3a.terminal_value > option_libre.terminal_value:
            chiffre_choc = (
                f"Dans ce scenario simule sur {annees_avant_retraite} ans, "
                f"le 3a pourrait representer {delta:,.0f} CHF de plus que "
                f"l'investissement libre grace a l'avantage fiscal."
            )
        else:
            chiffre_choc = (
                f"Dans ce scenario simule sur {annees_avant_retraite} ans, "
                f"l'investissement libre pourrait representer {delta:,.0f} CHF de plus "
                f"que le 3a grace au rendement de marche."
            )
    else:
        chiffre_choc = (
            f"Dans ce scenario simule, avec {montant_disponible:,.0f} CHF/an "
            f"sur {annees_avant_retraite} ans, chaque strategie presente un "
            f"profil risque/rendement different."
        )

    # Display summary
    display_summary = (
        f"Dans ce scenario simule, avec {montant_disponible:,.0f} CHF disponibles par an "
        f"sur {annees_avant_retraite} ans, {len(options)} strategie(s) sont comparees."
    )

    # Hypotheses
    hypotheses = _build_hypotheses(
        montant=montant_disponible,
        taux_marginal=taux_marginal,
        annees=annees_avant_retraite,
        rendement_3a=rendement_3a,
        rendement_lpp=rendement_lpp,
        rendement_marche=rendement_marche,
        taux_hypothecaire=taux_hypothecaire,
        canton=canton,
        a3a_maxed=a3a_maxed,
        potentiel_rachat_lpp=potentiel_rachat_lpp,
        is_property_owner=is_property_owner,
    )

    # Sensitivity: impact of rendement_marche +/- 1%
    option_libre_plus = _build_investissement_libre_option(
        montant=montant_disponible,
        annees=annees_avant_retraite,
        rendement_marche=rendement_marche + 0.01,
        canton=canton,
    )
    option_libre_minus = _build_investissement_libre_option(
        montant=montant_disponible,
        annees=annees_avant_retraite,
        rendement_marche=rendement_marche - 0.01,
        canton=canton,
    )
    sensitivity = {
        "rendement_marche": round(
            option_libre_plus.terminal_value - option_libre_minus.terminal_value, 2
        ),
    }

    # Confidence score
    confidence_score = 65.0  # Default with standard inputs

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
