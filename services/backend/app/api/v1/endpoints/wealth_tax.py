"""
Wealth Tax + Church Tax endpoints — Sprint S22+ (Chantier 1).

POST /api/v1/fiscal/wealth-tax/estimate  — Estimate wealth tax for one canton
POST /api/v1/fiscal/wealth-tax/compare   — Compare wealth tax across all cantons
POST /api/v1/fiscal/wealth-tax/move      — Simulate wealth tax impact of moving
POST /api/v1/fiscal/wealth-tax/church    — Estimate church tax for one canton

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources: LHID art. 14, OFS Charge Fiscale 2024, lois fiscales cantonales.
"""

from fastapi import APIRouter, HTTPException, Request

from app.core.rate_limit import limiter
from app.schemas.wealth_tax import (
    WealthTaxEstimateRequest,
    WealthTaxEstimateResponse,
    WealthTaxComparisonRequest,
    WealthTaxComparisonResponse,
    WealthTaxRankingItem,
    WealthTaxMoveRequest,
    WealthTaxMoveResponse,
    ChurchTaxEstimateRequest,
    ChurchTaxEstimateResponse,
)
from app.services.fiscal.wealth_tax_service import (
    WealthTaxService,
    DISCLAIMER as WEALTH_DISCLAIMER,
    SOURCES as WEALTH_SOURCES,
)
from app.services.fiscal.church_tax_service import (
    ChurchTaxService,
)


router = APIRouter()


# ---------------------------------------------------------------------------
# Estimate wealth tax for a profile in a specific canton
# ---------------------------------------------------------------------------

@router.post("/estimate", response_model=WealthTaxEstimateResponse)
@limiter.limit("30/minute")
def estimate_wealth_tax(request: Request, body: WealthTaxEstimateRequest) -> WealthTaxEstimateResponse:
    """Estimate wealth tax for a given fortune in a specific canton.

    Returns the fortune imposable (after exemption) and the estimated
    annual wealth tax based on simplified effective rates.

    Sources: LHID art. 14, OFS Charge Fiscale 2024.
    """
    service = WealthTaxService()

    try:
        estimate = service.estimate_wealth_tax(
            fortune=body.fortune_nette,
            canton=body.canton,
            civil_status=body.etat_civil,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    return WealthTaxEstimateResponse(
        canton=estimate.canton,
        canton_nom=estimate.canton_name,
        fortune_nette=estimate.fortune_nette,
        fortune_imposable=estimate.fortune_imposable,
        impot_fortune=estimate.impot_fortune,
        taux_effectif_permille=estimate.taux_effectif_permille,
        chiffre_choc=estimate.chiffre_choc,
        disclaimer=estimate.disclaimer,
        sources=estimate.sources,
    )


# ---------------------------------------------------------------------------
# Compare all 26 cantons by wealth tax
# ---------------------------------------------------------------------------

@router.post("/compare", response_model=WealthTaxComparisonResponse)
@limiter.limit("30/minute")
def compare_wealth_tax(request: Request, body: WealthTaxComparisonRequest) -> WealthTaxComparisonResponse:
    """Rank all 26 cantons by wealth tax burden for a given fortune.

    Returns a sorted list from cheapest to most expensive canton,
    with the ecart max and a chiffre choc.

    Sources: LHID art. 14, OFS Charge Fiscale 2024.
    """
    service = WealthTaxService()

    try:
        rankings = service.compare_all_cantons(
            fortune=body.fortune_nette,
            civil_status=body.etat_civil,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    # Build response items
    classement = [
        WealthTaxRankingItem(
            rang=r.rang,
            canton=r.canton,
            canton_nom=r.canton_name,
            impot_fortune=r.impot_fortune,
            taux_effectif_permille=r.taux_effectif_permille,
            difference_vs_premier=r.difference_vs_cheapest,
        )
        for r in rankings
    ]

    ecart_max = rankings[-1].difference_vs_cheapest if rankings else 0.0

    # Build chiffre choc
    if rankings and ecart_max > 0:
        cheapest = rankings[0]
        most_expensive = rankings[-1]
        chiffre_choc = (
            f"A fortune egale, tu paies {ecart_max:,.0f} CHF de plus par an "
            f"d'impot sur la fortune a {most_expensive.canton_name} "
            f"qu'a {cheapest.canton_name}."
        )
    else:
        chiffre_choc = "Aucune donnee disponible."

    return WealthTaxComparisonResponse(
        classement=classement,
        ecart_max=ecart_max,
        chiffre_choc=chiffre_choc,
        disclaimer=WEALTH_DISCLAIMER,
        sources=list(WEALTH_SOURCES),
    )


# ---------------------------------------------------------------------------
# Simulate a wealth tax move
# ---------------------------------------------------------------------------

@router.post("/move", response_model=WealthTaxMoveResponse)
@limiter.limit("30/minute")
def simulate_wealth_tax_move(request: Request, body: WealthTaxMoveRequest) -> WealthTaxMoveResponse:
    """Simulate wealth tax savings from moving between cantons.

    Returns annual, monthly, and 10-year cumulative savings
    on wealth tax from a cantonal move.

    Sources: LHID art. 14, OFS Charge Fiscale 2024.
    """
    service = WealthTaxService()

    try:
        simulation = service.simulate_move_wealth(
            fortune=body.fortune_nette,
            canton_from=body.canton_depart,
            canton_to=body.canton_arrivee,
            civil_status=body.etat_civil,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    return WealthTaxMoveResponse(
        canton_depart=simulation.canton_depart,
        canton_depart_nom=simulation.canton_depart_nom,
        canton_arrivee=simulation.canton_arrivee,
        canton_arrivee_nom=simulation.canton_arrivee_nom,
        impot_depart=simulation.impot_depart,
        impot_arrivee=simulation.impot_arrivee,
        economie_annuelle=simulation.economie_annuelle,
        economie_mensuelle=simulation.economie_mensuelle,
        economie_10_ans=simulation.economie_10_ans,
        chiffre_choc=simulation.chiffre_choc,
        alertes=simulation.alertes,
        disclaimer=simulation.disclaimer,
        sources=simulation.sources,
    )


# ---------------------------------------------------------------------------
# Estimate church tax
# ---------------------------------------------------------------------------

@router.post("/church", response_model=ChurchTaxEstimateResponse)
@limiter.limit("30/minute")
def estimate_church_tax(request: Request, body: ChurchTaxEstimateRequest) -> ChurchTaxEstimateResponse:
    """Estimate church tax for a given cantonal tax in a specific canton.

    Church tax is calculated as a percentage of the cantonal income tax.
    In some cantons (TI, VD, NE, GE), it is voluntary or already included.

    Sources: LHID art. 1, lois fiscales cantonales, RSM Switzerland.
    """
    service = ChurchTaxService()

    try:
        estimate = service.estimate_church_tax(
            cantonal_tax=body.impot_cantonal,
            canton=body.canton,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    return ChurchTaxEstimateResponse(
        canton=estimate.canton,
        canton_nom=estimate.canton_name,
        is_mandatory=estimate.is_mandatory,
        church_tax_rate=estimate.church_tax_rate,
        impot_cantonal_base=estimate.impot_cantonal_base,
        impot_eglise=estimate.impot_eglise,
        chiffre_choc=estimate.chiffre_choc,
        disclaimer=estimate.disclaimer,
        sources=estimate.sources,
    )
