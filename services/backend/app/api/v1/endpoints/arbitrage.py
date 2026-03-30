"""
Arbitrage endpoints — Sprint S32-S33: Arbitrage Phase 1 + 2.

POST /api/v1/arbitrage/rente-vs-capital        — compare rente vs capital vs mixed
POST /api/v1/arbitrage/allocation-annuelle     — compare 3a, rachat LPP, amort indirect, invest libre
POST /api/v1/arbitrage/location-vs-propriete   — compare renting vs buying (Sprint S33)
POST /api/v1/arbitrage/rachat-vs-marche        — compare LPP buyback vs market (Sprint S33)
POST /api/v1/arbitrage/calendrier-retraits     — compare same-year vs staggered withdrawals (Sprint S33)

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources:
    - LPP art. 14 (taux de conversion minimum)
    - LPP art. 37 (choix rente/capital)
    - LPP art. 79b (rachat LPP, blocage 3 ans)
    - LIFD art. 22 (imposition des rentes)
    - LIFD art. 38 (imposition du capital de prevoyance)
    - OPP3 art. 7 (plafond 3a)
    - CO art. 253ss (bail)
    - FINMA Tragbarkeitsrechnung
"""

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.user import User
from app.schemas.arbitrage import (
    RenteVsCapitalRequest,
    RenteVsCapitalResponse,
    AllocationAnnuelleRequest,
    AllocationAnnuelleResponse,
    LocationVsProprieteRequest,
    LocationVsProprieteResponse,
    RachatVsMarcheRequest,
    RachatVsMarcheResponse,
    CalendrierRetraitsRequest,
    CalendrierRetraitsResponse,
    YearlySnapshotSchema,
    TrajectoireOptionSchema,
)
from app.services.arbitrage import (
    compare_rente_vs_capital,
    compare_allocation_annuelle,
    compare_location_vs_propriete,
    compare_rachat_vs_marche,
    compare_calendrier_retraits,
    RetirementAsset,
)

router = APIRouter()


def _option_to_schema(option) -> TrajectoireOptionSchema:
    """Convert service TrajectoireOption dataclass to Pydantic schema."""
    return TrajectoireOptionSchema(
        id=option.id,
        label=option.label,
        trajectory=[
            YearlySnapshotSchema(
                year=s.year,
                net_patrimony=s.net_patrimony,
                annual_cashflow=s.annual_cashflow,
                cumulative_tax_delta=s.cumulative_tax_delta,
            )
            for s in option.trajectory
        ],
        terminal_value=option.terminal_value,
        cumulative_tax_impact=option.cumulative_tax_impact,
    )


def _result_to_response(result, response_class):
    """Convert ArbitrageResult dataclass to a Pydantic response schema."""
    return response_class(
        options=[_option_to_schema(o) for o in result.options],
        breakeven_year=result.breakeven_year,
        chiffre_choc=result.chiffre_choc,
        display_summary=result.display_summary,
        hypotheses=result.hypotheses,
        disclaimer=result.disclaimer,
        sources=result.sources,
        confidence_score=result.confidence_score,
        sensitivity=result.sensitivity,
    )


@router.post("/rente-vs-capital", response_model=RenteVsCapitalResponse)
@limiter.limit("10/minute")
def arbitrage_rente_vs_capital(request: Request, body: RenteVsCapitalRequest, _user: User = Depends(require_current_user)) -> RenteVsCapitalResponse:
    """Compare rente viagere vs retrait en capital vs mixte.

    Simule 3 options pour la prevoyance LPP a la retraite:
    - Option A: Rente viagere integrale
    - Option B: Retrait en capital integral (+ SWR)
    - Option C: Mixte (obligatoire en rente, surobligatoire en capital)

    Returns:
        RenteVsCapitalResponse avec 3 trajectoires, breakeven, sensibilite,
        disclaimer et sources legales.
    """
    try:
        result = compare_rente_vs_capital(
            capital_lpp_total=body.capital_lpp_total,
            capital_obligatoire=body.capital_obligatoire,
            capital_surobligatoire=body.capital_surobligatoire,
            rente_annuelle_proposee=body.rente_annuelle_proposee,
            taux_conversion_obligatoire=(
                body.taux_conversion_obligatoire
                if body.taux_conversion_obligatoire is not None
                else 0.068
            ),
            taux_conversion_surobligatoire=(
                body.taux_conversion_surobligatoire
                if body.taux_conversion_surobligatoire is not None
                else 0.05
            ),
            canton=(
                body.canton.upper()
                if body.canton is not None
                else "VD"
            ),
            age_retraite=(
                body.age_retraite
                if body.age_retraite is not None
                else 65
            ),
            taux_retrait=(
                body.taux_retrait
                if body.taux_retrait is not None
                else 0.04
            ),
            rendement_capital=(
                body.rendement_capital
                if body.rendement_capital is not None
                else 0.03
            ),
            inflation=(
                body.inflation
                if body.inflation is not None
                else 0.02
            ),
            horizon=(
                body.horizon
                if body.horizon is not None
                else 25
            ),
            is_married=(
                body.is_married
                if body.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, RenteVsCapitalResponse)

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")


@router.post("/allocation-annuelle", response_model=AllocationAnnuelleResponse)
@limiter.limit("10/minute")
def arbitrage_allocation_annuelle(
    request: Request,
    body: AllocationAnnuelleRequest,
    _user: User = Depends(require_current_user),
) -> AllocationAnnuelleResponse:
    """Compare les strategies d'allocation annuelle de l'epargne.

    Simule jusqu'a 4 options selon l'eligibilite:
    - 3a (si pas encore verse au max)
    - Rachat LPP (si potentiel de rachat > 0)
    - Amortissement indirect (si proprietaire)
    - Investissement libre (toujours disponible)

    Returns:
        AllocationAnnuelleResponse avec trajectoires, breakeven, sensibilite,
        disclaimer et sources legales.
    """
    try:
        result = compare_allocation_annuelle(
            montant_disponible=body.montant_disponible,
            taux_marginal=body.taux_marginal,
            a3a_maxed=(
                body.a3a_maxed
                if body.a3a_maxed is not None
                else False
            ),
            potentiel_rachat_lpp=(
                body.potentiel_rachat_lpp
                if body.potentiel_rachat_lpp is not None
                else 0
            ),
            is_property_owner=(
                body.is_property_owner
                if body.is_property_owner is not None
                else False
            ),
            taux_hypothecaire=(
                body.taux_hypothecaire
                if body.taux_hypothecaire is not None
                else 0.015
            ),
            annees_avant_retraite=(
                body.annees_avant_retraite
                if body.annees_avant_retraite is not None
                else 20
            ),
            rendement_3a=(
                body.rendement_3a
                if body.rendement_3a is not None
                else 0.02
            ),
            rendement_lpp=(
                body.rendement_lpp
                if body.rendement_lpp is not None
                else 0.0125
            ),
            rendement_marche=(
                body.rendement_marche
                if body.rendement_marche is not None
                else 0.04
            ),
            canton=(
                body.canton.upper()
                if body.canton is not None
                else "VD"
            ),
        )

        return _result_to_response(result, AllocationAnnuelleResponse)

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")


@router.post("/location-vs-propriete", response_model=LocationVsProprieteResponse)
@limiter.limit("10/minute")
def arbitrage_location_vs_propriete(
    request: Request,
    body: LocationVsProprieteRequest,
    _user: User = Depends(require_current_user),
) -> LocationVsProprieteResponse:
    """Compare continuer a louer vs acheter un bien immobilier.

    Simule 2 options:
    - Option A: Continuer a louer + investir le capital sur le marche
    - Option B: Acheter le bien avec hypotheque

    Returns:
        LocationVsProprieteResponse avec 2 trajectoires, breakeven, sensibilite,
        disclaimer et sources legales (CO, LIFD, FINMA).
    """
    try:
        result = compare_location_vs_propriete(
            capital_disponible=body.capital_disponible,
            loyer_mensuel_actuel=body.loyer_mensuel_actuel,
            prix_bien=body.prix_bien,
            canton=(
                body.canton.upper()
                if body.canton is not None
                else "VD"
            ),
            horizon_annees=(
                body.horizon_annees
                if body.horizon_annees is not None
                else 20
            ),
            rendement_marche=(
                body.rendement_marche
                if body.rendement_marche is not None
                else 0.04
            ),
            appreciation_immo=(
                body.appreciation_immo
                if body.appreciation_immo is not None
                else 0.015
            ),
            taux_hypotheque=(
                body.taux_hypotheque
                if body.taux_hypotheque is not None
                else 0.02
            ),
            taux_entretien=(
                body.taux_entretien
                if body.taux_entretien is not None
                else 0.01
            ),
            is_married=(
                body.is_married
                if body.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, LocationVsProprieteResponse)

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")


@router.post("/rachat-vs-marche", response_model=RachatVsMarcheResponse)
@limiter.limit("10/minute")
def arbitrage_rachat_vs_marche(
    request: Request,
    body: RachatVsMarcheRequest,
    _user: User = Depends(require_current_user),
) -> RachatVsMarcheResponse:
    """Compare rachat LPP vs investissement libre.

    Simule 2 options:
    - Option A: Rachat LPP (deduction fiscale + croissance en caisse)
    - Option B: Investissement libre (liquidite totale + rendement marche)

    Returns:
        RachatVsMarcheResponse avec 2 trajectoires, breakeven, sensibilite,
        disclaimer et sources legales (LPP, LIFD, OPP2).
    """
    try:
        result = compare_rachat_vs_marche(
            montant=body.montant,
            taux_marginal=body.taux_marginal,
            annees_avant_retraite=(
                body.annees_avant_retraite
                if body.annees_avant_retraite is not None
                else 20
            ),
            rendement_lpp=(
                body.rendement_lpp
                if body.rendement_lpp is not None
                else 0.0125
            ),
            rendement_marche=(
                body.rendement_marche
                if body.rendement_marche is not None
                else 0.04
            ),
            taux_conversion=(
                body.taux_conversion
                if body.taux_conversion is not None
                else 0.068
            ),
            canton=(
                body.canton.upper()
                if body.canton is not None
                else "VD"
            ),
            is_married=(
                body.is_married
                if body.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, RachatVsMarcheResponse)

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")


@router.post("/calendrier-retraits", response_model=CalendrierRetraitsResponse)
@limiter.limit("10/minute")
def arbitrage_calendrier_retraits(
    request: Request,
    body: CalendrierRetraitsRequest,
    _user: User = Depends(require_current_user),
) -> CalendrierRetraitsResponse:
    """Compare retrait total la meme annee vs retraits echelonnes.

    Simule 2 options:
    - Option A: Tout retirer la meme annee (progressivite maximale)
    - Option B: Echelonner les retraits sur plusieurs annees fiscales

    Le chiffre choc montre l'economie fiscale potentielle, souvent
    CHF 15'000 a 40'000+ pour des capitaux importants.

    Returns:
        CalendrierRetraitsResponse avec 2 trajectoires, chiffre choc,
        disclaimer et sources legales (LIFD art. 38, OPP3, LPP).
    """
    try:
        # Convert schema assets to service dataclass
        assets = [
            RetirementAsset(
                type=a.type,
                amount=a.amount,
                earliest_withdrawal_age=a.earliest_withdrawal_age,
            )
            for a in body.assets
        ]

        result = compare_calendrier_retraits(
            assets=assets,
            age_retraite=(
                body.age_retraite
                if body.age_retraite is not None
                else 65
            ),
            canton=(
                body.canton.upper()
                if body.canton is not None
                else "VD"
            ),
            is_married=(
                body.is_married
                if body.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, CalendrierRetraitsResponse)

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")
