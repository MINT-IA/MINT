"""
Fiscal (cantonal tax comparator) endpoints — Sprint S20.

POST /api/v1/fiscal/estimate   — Estimate tax for a profile in a specific canton
POST /api/v1/fiscal/compare    — Rank all 26 cantons by tax burden
POST /api/v1/fiscal/move       — Simulate tax savings from moving between cantons

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, HTTPException, Request

from app.core.rate_limit import limiter
from app.schemas.fiscal import (
    TaxEstimateRequest,
    TaxEstimateResponse,
    CantonComparisonRequest,
    CantonComparisonResponse,
    CantonRankingItem,
    MoveSimulationRequest,
    MoveSimulationResponse,
)
from app.services.fiscal.cantonal_comparator import (
    CantonalComparator,
    DISCLAIMER,
    SOURCES,
)


router = APIRouter()


# ---------------------------------------------------------------------------
# Estimate tax for a profile in a specific canton
# ---------------------------------------------------------------------------

@router.post("/estimate", response_model=TaxEstimateResponse)
@limiter.limit("30/minute")
def estimate_tax(request: Request, body: TaxEstimateRequest) -> TaxEstimateResponse:
    """Estimate tax for a profile in a specific canton.

    Returns federal + cantonal/communal breakdown based on simplified
    effective rates from the Administration federale des contributions.

    Sources: LIFD art. 36, LHID art. 1, Charge fiscale 2024.
    """
    comparator = CantonalComparator()

    try:
        estimate = comparator.estimate_tax(
            income=body.revenu_brut,
            canton=body.canton,
            civil_status=body.etat_civil,
            children=body.nombre_enfants,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    return TaxEstimateResponse(
        canton=estimate.canton,
        canton_nom=estimate.canton_name,
        revenu_imposable=estimate.revenu_imposable,
        impot_federal=estimate.impot_federal,
        impot_cantonal_communal=estimate.impot_cantonal_communal,
        charge_totale=estimate.charge_totale,
        taux_effectif=estimate.taux_effectif,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )


# ---------------------------------------------------------------------------
# Compare all 26 cantons
# ---------------------------------------------------------------------------

@router.post("/compare", response_model=CantonComparisonResponse)
@limiter.limit("30/minute")
def compare_cantons(request: Request, body: CantonComparisonRequest) -> CantonComparisonResponse:
    """Rank all 26 cantons by tax burden for a given profile.

    Returns a sorted list from cheapest to most expensive canton,
    with the ecart max and a chiffre choc.

    Sources: LIFD art. 36, LHID art. 1, Charge fiscale 2024.
    """
    comparator = CantonalComparator()

    rankings = comparator.compare_all_cantons(
        income=body.revenu_brut,
        civil_status=body.etat_civil,
        children=body.nombre_enfants,
    )

    # Build response items
    classement = [
        CantonRankingItem(
            rang=r.rang,
            canton=r.canton,
            canton_nom=r.canton_name,
            charge_totale=r.charge_totale,
            taux_effectif=r.taux_effectif,
            difference_vs_premier=r.difference_vs_cheapest,
        )
        for r in rankings
    ]

    ecart_max = rankings[-1].difference_vs_cheapest if rankings else 0.0

    # Build chiffre choc
    if rankings:
        cheapest = rankings[0]
        most_expensive = rankings[-1]
        chiffre_choc = (
            f"A revenu egal, tu paies {ecart_max:,.0f} CHF de plus par an "
            f"a {most_expensive.canton_name} qu'a {cheapest.canton_name}. "
            f"C'est {ecart_max / 12:,.0f} CHF/mois de difference."
        )
    else:
        chiffre_choc = "Aucune donnee disponible."

    return CantonComparisonResponse(
        classement=classement,
        ecart_max=ecart_max,
        chiffre_choc=chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )


# ---------------------------------------------------------------------------
# Simulate a cantonal move
# ---------------------------------------------------------------------------

@router.post("/move", response_model=MoveSimulationResponse)
@limiter.limit("30/minute")
def simulate_move(request: Request, body: MoveSimulationRequest) -> MoveSimulationResponse:
    """Simulate tax savings from moving between cantons.

    Returns annual, monthly, and 10-year cumulative savings,
    plus a checklist and alerts for the move.

    Sources: LIFD art. 36, LHID art. 1, Charge fiscale 2024.
    """
    comparator = CantonalComparator()

    try:
        simulation = comparator.simulate_move(
            income=body.revenu_brut,
            canton_from=body.canton_depart,
            canton_to=body.canton_arrivee,
            civil_status=body.etat_civil,
            children=body.nombre_enfants,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    return MoveSimulationResponse(
        canton_depart=simulation.canton_depart,
        canton_depart_nom=simulation.canton_depart_nom,
        canton_arrivee=simulation.canton_arrivee,
        canton_arrivee_nom=simulation.canton_arrivee_nom,
        charge_depart=simulation.charge_depart,
        charge_arrivee=simulation.charge_arrivee,
        economie_annuelle=simulation.economie_annuelle,
        economie_mensuelle=simulation.economie_mensuelle,
        economie_10_ans=simulation.economie_10_ans,
        chiffre_choc=simulation.chiffre_choc,
        alertes=simulation.alertes,
        checklist=simulation.checklist,
        disclaimer=simulation.disclaimer,
        sources=simulation.sources,
    )
