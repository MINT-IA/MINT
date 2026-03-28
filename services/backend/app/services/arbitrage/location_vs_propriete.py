"""
Location vs Propriete Comparison — Pure function for rent vs buy arbitrage.

Sprint S33 — Arbitrage Phase 2.

Compares 2 options:
- Option A: Continue renting + invest capital on the market
- Option B: Buy property with mortgage

All constants are imported from app.constants.social_insurance (NEVER hardcoded).

Sources:
    - CO art. 253ss (bail)
    - LIFD art. 21 (valeur locative)
    - LIFD art. 32 (deductions)
    - FINMA Tragbarkeitsrechnung

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
    "CO art. 253ss (bail)",
    "LIFD art. 21 (valeur locative)",
    "LIFD art. 32 (deductions hypothecaires)",
    "FINMA Tragbarkeitsrechnung (taux theorique 5%)",
]

# FINMA / ASB constants
_FINMA_TAUX_THEORIQUE = 0.05   # 5% theoretical rate for affordability
_FINMA_AMORTISSEMENT = 0.01    # 1%/year amortization
_FINMA_FRAIS_ACCESSOIRES = 0.01  # 1%/year accessory costs
_FINMA_RATIO_CHARGES_MAX = 1 / 3  # Max 1/3 of gross income
_FONDS_PROPRES_MIN = 0.20       # 20% minimum equity


# ═══════════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _estimate_tax_benefit_mortgage(
    mortgage_interest: float,
    maintenance_cost: float,
    canton: str,
    is_married: bool,
) -> float:
    """Estimate tax benefit from mortgage interest and maintenance deductions.

    Mortgage interest and maintenance costs are tax-deductible (LIFD art. 32).
    We estimate the benefit using a proxy income tax rate.

    Args:
        mortgage_interest: Annual mortgage interest paid (CHF).
        maintenance_cost: Annual maintenance costs (CHF).
        canton: Canton code.
        is_married: Whether the person is married.

    Returns:
        Estimated annual tax saving (CHF).
    """
    base_rate = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton.upper(), 0.065)
    # Income tax rate is roughly 3x the capital withdrawal base rate
    income_rate = base_rate * 3.0
    if is_married:
        income_rate *= 0.80  # Splitting benefit
    deductible = mortgage_interest + maintenance_cost
    return round(deductible * income_rate, 2)


def _build_location_option(
    capital_disponible: float,
    loyer_mensuel: float,
    rendement_marche: float,
    horizon: int,
) -> TrajectoireOption:
    """Build Option A: Continue renting + invest capital.

    Capital grows at market return. Rent is paid annually.
    Year-by-year: net patrimony = invested capital * (1+r)^t - cumulative rent.
    """
    trajectory: List[YearlySnapshot] = []
    invested = capital_disponible
    cumulative_rent = 0.0

    for year in range(1, horizon + 1):
        # Capital grows
        invested *= (1 + rendement_marche)
        # Annual rent
        annual_rent = loyer_mensuel * 12
        cumulative_rent += annual_rent
        # Net patrimony = invested capital - cumulative rent paid
        net_patrimony = invested - cumulative_rent
        annual_cashflow = -annual_rent + invested * rendement_marche / (1 + rendement_marche)

        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(net_patrimony, 2),
            annual_cashflow=round(annual_cashflow, 2),
            cumulative_tax_delta=0.0,  # No special tax for renting
        ))

    terminal = trajectory[-1].net_patrimony if trajectory else 0.0
    return TrajectoireOption(
        id="location",
        label="Continuer a louer + investir le capital",
        trajectory=trajectory,
        terminal_value=round(terminal, 2),
        cumulative_tax_impact=round(cumulative_rent, 2),
    )


def _build_propriete_option(
    capital_disponible: float,
    prix_bien: float,
    taux_hypotheque: float,
    taux_entretien: float,
    appreciation_immo: float,
    canton: str,
    is_married: bool,
    horizon: int,
) -> TrajectoireOption:
    """Build Option B: Buy property.

    Down payment: 20% of prix_bien.
    Mortgage: 80% of prix_bien.
    Annual costs: mortgage interest + amortization + maintenance.
    Tax benefit: mortgage interest + maintenance deductible.
    Property value grows at appreciation_immo.
    """
    trajectory: List[YearlySnapshot] = []

    # Down payment
    down_payment = prix_bien * _FONDS_PROPRES_MIN
    mortgage = prix_bien * (1 - _FONDS_PROPRES_MIN)
    # Remaining capital after down payment (could be negative if not enough)
    remaining_cash = capital_disponible - down_payment

    property_value = prix_bien
    cumulative_costs = 0.0
    cumulative_tax_savings = 0.0

    # 2nd rank: from 80% LTV to 65% LTV over max 15 years
    seuil_premier_rang = prix_bien * 0.65
    deuxieme_rang = max(0.0, mortgage - seuil_premier_rang)
    amort_annuel_2nd_rank = deuxieme_rang / 15 if deuxieme_rang > 0 else 0.0

    for year in range(1, horizon + 1):
        # Annual costs
        mortgage_interest = mortgage * taux_hypotheque
        # Amortization: 2nd rank only, over 15 years, then stops
        amortization = amort_annuel_2nd_rank if mortgage > seuil_premier_rang else 0.0
        maintenance = prix_bien * taux_entretien

        # Reduce mortgage by amortization (floor at 1st rank level)
        mortgage = max(seuil_premier_rang, mortgage - amortization)

        # Total annual cost
        annual_cost = mortgage_interest + amortization + maintenance

        # Tax benefit from deductions
        tax_benefit = _estimate_tax_benefit_mortgage(
            mortgage_interest, maintenance, canton, is_married
        )

        net_annual_cost = annual_cost - tax_benefit
        cumulative_costs += net_annual_cost
        cumulative_tax_savings += tax_benefit

        # Property appreciation
        property_value *= (1 + appreciation_immo)

        # Remaining cash could also grow (if any left after down payment)
        if remaining_cash > 0:
            remaining_cash *= 1.0  # No growth assumed (opportunity cost)

        # Net patrimony = property value - remaining mortgage - cumulative net costs + remaining cash
        net_patrimony = property_value - mortgage + remaining_cash - cumulative_costs

        trajectory.append(YearlySnapshot(
            year=year,
            net_patrimony=round(net_patrimony, 2),
            annual_cashflow=round(-net_annual_cost, 2),
            cumulative_tax_delta=round(-cumulative_tax_savings, 2),
        ))

    terminal = trajectory[-1].net_patrimony if trajectory else 0.0
    return TrajectoireOption(
        id="propriete",
        label="Acheter le bien immobilier",
        trajectory=trajectory,
        terminal_value=round(terminal, 2),
        cumulative_tax_impact=round(cumulative_costs, 2),
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

def compare_location_vs_propriete(
    capital_disponible: float,
    loyer_mensuel_actuel: float,
    prix_bien: float,
    canton: str = "VD",
    horizon_annees: int = 20,
    rendement_marche: float = 0.04,
    appreciation_immo: float = 0.015,
    taux_hypotheque: float = 0.02,
    taux_entretien: float = 0.01,
    is_married: bool = False,
) -> ArbitrageResult:
    """Compare renting vs buying for a given property and capital.

    ALWAYS returns 2 options:
    - Option A: Continue renting + invest capital on the market
    - Option B: Buy property with mortgage

    NEVER ranks options. Uses educational, non-prescriptive language.

    Args:
        capital_disponible: Available equity (CHF).
        loyer_mensuel_actuel: Current monthly rent (CHF).
        prix_bien: Property purchase price (CHF).
        canton: Canton code for tax estimation (default VD).
        horizon_annees: Simulation horizon in years (default 20).
        rendement_marche: Market return if renting + investing (default 4%).
        appreciation_immo: Real estate appreciation rate (default 1.5%).
        taux_hypotheque: Real mortgage interest rate (default 2%).
        taux_entretien: Maintenance costs as % of price (default 1%).
        is_married: Married status for tax splitting (default False).

    Returns:
        ArbitrageResult with 2 options, breakeven, sensitivity, and compliance.
    """
    # Validate canton
    canton = canton.upper()
    if canton not in TAUX_IMPOT_RETRAIT_CAPITAL:
        canton = "VD"

    # Ensure non-negative horizon
    horizon_annees = max(1, horizon_annees)

    # Build 2 options
    option_a = _build_location_option(
        capital_disponible=capital_disponible,
        loyer_mensuel=loyer_mensuel_actuel,
        rendement_marche=rendement_marche,
        horizon=horizon_annees,
    )

    option_b = _build_propriete_option(
        capital_disponible=capital_disponible,
        prix_bien=prix_bien,
        taux_hypotheque=taux_hypotheque,
        taux_entretien=taux_entretien,
        appreciation_immo=appreciation_immo,
        canton=canton,
        is_married=is_married,
        horizon=horizon_annees,
    )

    options = [option_a, option_b]

    # Breakeven
    breakeven_year = _calculate_breakeven(option_a, option_b)

    # Chiffre choc
    delta = abs(option_a.terminal_value - option_b.terminal_value)
    if option_b.terminal_value > option_a.terminal_value:
        chiffre_choc = (
            f"Dans ce scenario simule sur {horizon_annees} ans, l'achat "
            f"pourrait representer {delta:,.0f} CHF de plus en patrimoine net "
            f"que la location — mais avec moins de flexibilite."
        )
    else:
        chiffre_choc = (
            f"Dans ce scenario simule sur {horizon_annees} ans, la location + "
            f"investissement pourrait representer {delta:,.0f} CHF de plus en "
            f"patrimoine net que l'achat."
        )

    # Display summary
    display_summary = (
        f"Dans ce scenario simule, sur {horizon_annees} ans, les 2 options "
        f"presentent des profils differents en termes de patrimoine, "
        f"flexibilite et fiscalite."
    )

    # Amortization: 2nd rank from 80% to 65% LTV over 15 years
    initial_mortgage = prix_bien * (1 - _FONDS_PROPRES_MIN)
    seuil_1er_rang = prix_bien * 0.65
    deuxieme_rang_hyp = max(0.0, initial_mortgage - seuil_1er_rang)
    amort_annuel_2nd_rank = deuxieme_rang_hyp / 15 if deuxieme_rang_hyp > 0 else 0.0

    # FINMA affordability check
    annual_theoretical_cost = (
        initial_mortgage * _FINMA_TAUX_THEORIQUE
        + amort_annuel_2nd_rank
        + prix_bien * _FINMA_FRAIS_ACCESSOIRES
    )

    # Hypotheses
    situation = "marie\u00b7e" if is_married else "celibataire"
    hypotheses = [
        f"Capital disponible: {capital_disponible:,.0f} CHF",
        f"Loyer mensuel actuel: {loyer_mensuel_actuel:,.0f} CHF",
        f"Prix du bien: {prix_bien:,.0f} CHF",
        f"Fonds propres: {_FONDS_PROPRES_MIN * 100:.0f}% ({prix_bien * _FONDS_PROPRES_MIN:,.0f} CHF)",
        f"Hypotheque: {(1 - _FONDS_PROPRES_MIN) * 100:.0f}% ({prix_bien * (1 - _FONDS_PROPRES_MIN):,.0f} CHF)",
        f"Taux hypothecaire reel: {taux_hypotheque * 100:.1f}%/an",
        f"Taux theorique FINMA: {_FINMA_TAUX_THEORIQUE * 100:.0f}% (Tragbarkeitsrechnung)",
        f"Amortissement: 2e rang (80% -> 65% LTV) sur 15 ans ({amort_annuel_2nd_rank:,.0f} CHF/an)",
        f"Frais d'entretien: {taux_entretien * 100:.0f}%/an du prix d'achat",
        f"Charges annuelles theoriques: {annual_theoretical_cost:,.0f} CHF (ratio FINMA)",
        f"Rendement marche (scenario location): {rendement_marche * 100:.1f}%/an",
        f"Appreciation immobiliere: {appreciation_immo * 100:.1f}%/an",
        f"Horizon de simulation: {horizon_annees} ans",
        f"Canton de domicile fiscal: {canton}",
        f"Situation familiale: {situation}",
        "Valeur locative non incluse dans cette simulation simplifiee",
        "Frais de notaire et droits de mutation non inclus",
    ]

    base_spread = compute_terminal_spread(options)

    def _spread_variant(
        *,
        variant_loyer_mensuel: float = loyer_mensuel_actuel,
        variant_rendement_marche: float = rendement_marche,
        variant_appreciation_immo: float = appreciation_immo,
        variant_taux_hypotheque: float = taux_hypotheque,
    ) -> float:
        variant_a = _build_location_option(
            capital_disponible=capital_disponible,
            loyer_mensuel=variant_loyer_mensuel,
            rendement_marche=variant_rendement_marche,
            horizon=horizon_annees,
        )
        variant_b = _build_propriete_option(
            capital_disponible=capital_disponible,
            prix_bien=prix_bien,
            taux_hypotheque=variant_taux_hypotheque,
            taux_entretien=taux_entretien,
            appreciation_immo=variant_appreciation_immo,
            canton=canton,
            is_married=is_married,
            horizon=horizon_annees,
        )
        return compute_terminal_spread([variant_a, variant_b])

    sensitivity: Dict[str, float] = {}

    rendement_low = max(0.0, rendement_marche - 0.01)
    rendement_high = rendement_marche + 0.01
    add_tornado_sensitivity(
        sensitivity,
        "rendement_marche",
        base_value=base_spread,
        low_value=_spread_variant(variant_rendement_marche=rendement_low),
        high_value=_spread_variant(variant_rendement_marche=rendement_high),
        assumption_low=rendement_low,
        assumption_high=rendement_high,
    )

    taux_hypo_low = max(0.0, taux_hypotheque - 0.005)
    taux_hypo_high = taux_hypotheque + 0.005
    add_tornado_sensitivity(
        sensitivity,
        "taux_hypothecaire",
        base_value=base_spread,
        low_value=_spread_variant(variant_taux_hypotheque=taux_hypo_low),
        high_value=_spread_variant(variant_taux_hypotheque=taux_hypo_high),
        assumption_low=taux_hypo_low,
        assumption_high=taux_hypo_high,
    )

    appreciation_low = max(0.0, appreciation_immo - 0.005)
    appreciation_high = appreciation_immo + 0.005
    add_tornado_sensitivity(
        sensitivity,
        "appreciation_immo",
        base_value=base_spread,
        low_value=_spread_variant(variant_appreciation_immo=appreciation_low),
        high_value=_spread_variant(variant_appreciation_immo=appreciation_high),
        assumption_low=appreciation_low,
        assumption_high=appreciation_high,
    )

    loyer_low = max(0.0, loyer_mensuel_actuel * 0.90)
    loyer_high = loyer_mensuel_actuel * 1.10
    add_tornado_sensitivity(
        sensitivity,
        "loyer_mensuel",
        base_value=base_spread,
        low_value=_spread_variant(variant_loyer_mensuel=loyer_low),
        high_value=_spread_variant(variant_loyer_mensuel=loyer_high),
        assumption_low=loyer_low,
        assumption_high=loyer_high,
    )

    # Confidence score
    confidence_score = 65.0  # Medium — many assumptions in rent vs buy

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
