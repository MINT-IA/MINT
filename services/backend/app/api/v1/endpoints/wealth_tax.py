"""
Wealth Tax + Church Tax endpoints — Sprint S22+ (Chantier 1).

POST /api/v1/fiscal/wealth-tax/estimate  — Estimate wealth tax for one canton
POST /api/v1/fiscal/wealth-tax/compare   — Compare wealth tax across all cantons
POST /api/v1/fiscal/wealth-tax/move      — Simulate wealth tax impact of moving
POST /api/v1/fiscal/wealth-tax/church    — Estimate church tax for one canton

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources: LHID art. 14, modele simplifie MINT (recalibrage ESTV en cours, ADR 2026-07-28), lois fiscales cantonales.
"""

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import require_current_user
from app.core.profile_resolver import (
    _required_profile_fields_missing,
    _resolve_defaults,
    emit_calc_invoke_metric,
    get_profile_filled,
    raise_incomplete_as_422,
)
from app.core.rate_limit import limiter
from app.models.user import User
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


_WEALTH_TAX_ESTIMATE_HINT_FR = (
    "Pour estimer ton impôt sur la fortune, j'ai besoin de ton canton. "
    "Tu peux me le partager ?"
)


# ---------------------------------------------------------------------------
# Estimate wealth tax for a profile in a specific canton
# ---------------------------------------------------------------------------

@router.post("/estimate", response_model=WealthTaxEstimateResponse)
@limiter.limit("30/minute")
def estimate_wealth_tax(
    request: Request,
    body: WealthTaxEstimateRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> WealthTaxEstimateResponse:
    """Estimate wealth tax for a given fortune in a specific canton.

    Returns the fortune imposable (after exemption) and the estimated
    annual wealth tax based on simplified effective rates.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (no silent hardcoded fallback). Missing
    required profile field triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when `PROFILE_GROUNDING_STRICT_MODE=true` ;
    otherwise a warning is logged and the legacy hardcoded-defaults branch
    resumes (non-strict graceful Flutter rollout).

    Sources: LHID art. 14, modele simplifie MINT (recalibrage ESTV en cours).
    """
    resolved = _resolve_defaults(profile_data, body, WealthTaxEstimateRequest)
    missing = _required_profile_fields_missing(resolved, WealthTaxEstimateRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_WEALTH_TAX_ESTIMATE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/fiscal/wealth-tax/estimate",
        )
    emit_calc_invoke_metric(
        kind="wealth_tax_estimate",
        resolved=resolved,
        schema_class=WealthTaxEstimateRequest,
    )

    service = WealthTaxService()

    try:
        estimate = service.estimate_wealth_tax(
            fortune=resolved["fortune_nette"],
            canton=resolved["canton"],
            civil_status=resolved["etat_civil"],
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
        premier_eclairage=estimate.premier_eclairage,
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
    with the ecart max and a premier éclairage.

    Sources: LHID art. 14, modele simplifie MINT (recalibrage ESTV en cours).
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

    # Build premier éclairage
    if rankings and ecart_max > 0:
        cheapest = rankings[0]
        most_expensive = rankings[-1]
        premier_eclairage = (
            f"A fortune egale, tu paies {ecart_max:,.0f} CHF de plus par an "
            f"d'impot sur la fortune a {most_expensive.canton_name} "
            f"qu'a {cheapest.canton_name}."
        )
    else:
        premier_eclairage = "Aucune donnee disponible."

    return WealthTaxComparisonResponse(
        classement=classement,
        ecart_max=ecart_max,
        premier_eclairage=premier_eclairage,
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

    Sources: LHID art. 14, modele simplifie MINT (recalibrage ESTV en cours).
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
        premier_eclairage=simulation.premier_eclairage,
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
        premier_eclairage=estimate.premier_eclairage,
        disclaimer=estimate.disclaimer,
        sources=estimate.sources,
    )
