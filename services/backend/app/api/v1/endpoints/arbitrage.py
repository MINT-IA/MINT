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

from fastapi import APIRouter, HTTPException

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
def arbitrage_rente_vs_capital(request: RenteVsCapitalRequest) -> RenteVsCapitalResponse:
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
            capital_lpp_total=request.capital_lpp_total,
            capital_obligatoire=request.capital_obligatoire,
            capital_surobligatoire=request.capital_surobligatoire,
            rente_annuelle_proposee=request.rente_annuelle_proposee,
            taux_conversion_obligatoire=(
                request.taux_conversion_obligatoire
                if request.taux_conversion_obligatoire is not None
                else 0.068
            ),
            taux_conversion_surobligatoire=(
                request.taux_conversion_surobligatoire
                if request.taux_conversion_surobligatoire is not None
                else 0.05
            ),
            canton=(
                request.canton.upper()
                if request.canton is not None
                else "VD"
            ),
            age_retraite=(
                request.age_retraite
                if request.age_retraite is not None
                else 65
            ),
            taux_retrait=(
                request.taux_retrait
                if request.taux_retrait is not None
                else 0.04
            ),
            rendement_capital=(
                request.rendement_capital
                if request.rendement_capital is not None
                else 0.03
            ),
            inflation=(
                request.inflation
                if request.inflation is not None
                else 0.02
            ),
            horizon=(
                request.horizon
                if request.horizon is not None
                else 25
            ),
            is_married=(
                request.is_married
                if request.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, RenteVsCapitalResponse)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/allocation-annuelle", response_model=AllocationAnnuelleResponse)
def arbitrage_allocation_annuelle(
    request: AllocationAnnuelleRequest,
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
            montant_disponible=request.montant_disponible,
            taux_marginal=request.taux_marginal,
            a3a_maxed=(
                request.a3a_maxed
                if request.a3a_maxed is not None
                else False
            ),
            potentiel_rachat_lpp=(
                request.potentiel_rachat_lpp
                if request.potentiel_rachat_lpp is not None
                else 0
            ),
            is_property_owner=(
                request.is_property_owner
                if request.is_property_owner is not None
                else False
            ),
            taux_hypothecaire=(
                request.taux_hypothecaire
                if request.taux_hypothecaire is not None
                else 0.015
            ),
            annees_avant_retraite=(
                request.annees_avant_retraite
                if request.annees_avant_retraite is not None
                else 20
            ),
            rendement_3a=(
                request.rendement_3a
                if request.rendement_3a is not None
                else 0.02
            ),
            rendement_lpp=(
                request.rendement_lpp
                if request.rendement_lpp is not None
                else 0.0125
            ),
            rendement_marche=(
                request.rendement_marche
                if request.rendement_marche is not None
                else 0.04
            ),
            canton=(
                request.canton.upper()
                if request.canton is not None
                else "VD"
            ),
        )

        return _result_to_response(result, AllocationAnnuelleResponse)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/location-vs-propriete", response_model=LocationVsProprieteResponse)
def arbitrage_location_vs_propriete(
    request: LocationVsProprieteRequest,
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
            capital_disponible=request.capital_disponible,
            loyer_mensuel_actuel=request.loyer_mensuel_actuel,
            prix_bien=request.prix_bien,
            canton=(
                request.canton.upper()
                if request.canton is not None
                else "VD"
            ),
            horizon_annees=(
                request.horizon_annees
                if request.horizon_annees is not None
                else 20
            ),
            rendement_marche=(
                request.rendement_marche
                if request.rendement_marche is not None
                else 0.04
            ),
            appreciation_immo=(
                request.appreciation_immo
                if request.appreciation_immo is not None
                else 0.015
            ),
            taux_hypotheque=(
                request.taux_hypotheque
                if request.taux_hypotheque is not None
                else 0.02
            ),
            taux_entretien=(
                request.taux_entretien
                if request.taux_entretien is not None
                else 0.01
            ),
            is_married=(
                request.is_married
                if request.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, LocationVsProprieteResponse)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/rachat-vs-marche", response_model=RachatVsMarcheResponse)
def arbitrage_rachat_vs_marche(
    request: RachatVsMarcheRequest,
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
            montant=request.montant,
            taux_marginal=request.taux_marginal,
            annees_avant_retraite=(
                request.annees_avant_retraite
                if request.annees_avant_retraite is not None
                else 20
            ),
            rendement_lpp=(
                request.rendement_lpp
                if request.rendement_lpp is not None
                else 0.0125
            ),
            rendement_marche=(
                request.rendement_marche
                if request.rendement_marche is not None
                else 0.04
            ),
            taux_conversion=(
                request.taux_conversion
                if request.taux_conversion is not None
                else 0.068
            ),
            canton=(
                request.canton.upper()
                if request.canton is not None
                else "VD"
            ),
            is_married=(
                request.is_married
                if request.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, RachatVsMarcheResponse)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/calendrier-retraits", response_model=CalendrierRetraitsResponse)
def arbitrage_calendrier_retraits(
    request: CalendrierRetraitsRequest,
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
            for a in request.assets
        ]

        result = compare_calendrier_retraits(
            assets=assets,
            age_retraite=(
                request.age_retraite
                if request.age_retraite is not None
                else 65
            ),
            canton=(
                request.canton.upper()
                if request.canton is not None
                else "VD"
            ),
            is_married=(
                request.is_married
                if request.is_married is not None
                else False
            ),
        )

        return _result_to_response(result, CalendrierRetraitsResponse)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
