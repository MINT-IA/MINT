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
from app.core.profile_resolver import (
    _required_profile_fields_missing,
    _resolve_defaults,
    emit_calc_invoke_metric,
    get_profile_filled,
    raise_incomplete_as_422,
)
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

RENTE_VS_CAPITAL_CALCULATION_VERSION = "backend-l2-rente-vs-capital-v1"


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
        premier_eclairage=result.premier_eclairage,
        display_summary=result.display_summary,
        hypotheses=result.hypotheses,
        disclaimer=result.disclaimer,
        sources=result.sources,
        confidence_score=result.confidence_score,
        sensitivity=result.sensitivity,
    )


def _rente_vs_capital_receipt_lines() -> list[str]:
    return [
        "Origine du calcul : comparaison backend L2",
        f"Version du calcul : {RENTE_VS_CAPITAL_CALCULATION_VERSION}",
        "Statut du calcul : complet",
        "Champs manquants : aucun",
    ]


@router.post("/rente-vs-capital", response_model=RenteVsCapitalResponse)
@limiter.limit("10/minute")
def arbitrage_rente_vs_capital(
    request: Request,
    body: RenteVsCapitalRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> RenteVsCapitalResponse:
    """Compare rente viagere vs retrait en capital vs mixte.

    Simule 3 options pour la prevoyance LPP a la retraite:
    - Option A: Rente viagere integrale
    - Option B: Retrait en capital integral (+ SWR)
    - Option C: Mixte (obligatoire en rente, surobligatoire en capital)

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 2 — silent VD fallback
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when `PROFILE_GROUNDING_STRICT_MODE=true` ;
    otherwise a warning is logged and the legacy hardcoded-default branch
    resumes (non-strict graceful Flutter rollout).

    Returns:
        RenteVsCapitalResponse avec 3 trajectoires, breakeven, sensibilite,
        disclaimer et sources legales.
    """
    resolved = _resolve_defaults(profile_data, body, RenteVsCapitalRequest)
    missing = _required_profile_fields_missing(resolved, RenteVsCapitalRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_RENTE_VS_CAPITAL_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/arbitrage/rente-vs-capital",
        )
    emit_calc_invoke_metric(
        kind="rente_vs_capital",
        resolved=resolved,
        schema_class=RenteVsCapitalRequest,
    )

    try:
        result = compare_rente_vs_capital(
            capital_lpp_total=resolved["capital_lpp_total"],
            capital_obligatoire=resolved["capital_obligatoire"],
            capital_surobligatoire=resolved["capital_surobligatoire"],
            rente_annuelle_proposee=resolved["rente_annuelle_proposee"],
            taux_conversion_obligatoire=(
                resolved["taux_conversion_obligatoire"]
                if resolved["taux_conversion_obligatoire"] is not None
                else 0.068
            ),
            taux_conversion_surobligatoire=(
                resolved["taux_conversion_surobligatoire"]
                if resolved["taux_conversion_surobligatoire"] is not None
                else 0.05
            ),
            canton=str(resolved["canton"]).upper(),
            age_retraite=(
                resolved["age_retraite"]
                if resolved["age_retraite"] is not None
                else 65
            ),
            taux_retrait=(
                resolved["taux_retrait"]
                if resolved["taux_retrait"] is not None
                else 0.04
            ),
            rendement_capital=(
                resolved["rendement_capital"]
                if resolved["rendement_capital"] is not None
                else 0.03
            ),
            inflation=(
                resolved["inflation"]
                if resolved["inflation"] is not None
                else 0.02
            ),
            horizon=(
                resolved["horizon"]
                if resolved["horizon"] is not None
                else 25
            ),
            is_married=(
                resolved["is_married"]
                if resolved["is_married"] is not None
                else False
            ),
        )

        response = _result_to_response(result, RenteVsCapitalResponse)
        response.calculation_version = RENTE_VS_CAPITAL_CALCULATION_VERSION
        response.missing_fields = []
        response.receipt_lines = _rente_vs_capital_receipt_lines()
        return response

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")


_ALLOCATION_ANNUELLE_HINT_FR = (
    "Pour estimer ton allocation annuelle, j'ai besoin de ton canton, "
    "de savoir si tu es propriétaire et de ton taux hypothécaire actuel. "
    "Tu peux me les partager ?"
)


_LOCATION_VS_PROPRIETE_HINT_FR = (
    "Pour comparer location et propriété, j'ai besoin de ton canton "
    "de domicile fiscal. Tu peux me le partager ?"
)


_RENTE_VS_CAPITAL_HINT_FR = (
    "Pour comparer rente et capital LPP, j'ai besoin de ton canton — "
    "les taux d'imposition varient considérablement. Tu peux me le partager ?"
)


_RACHAT_VS_MARCHE_HINT_FR = (
    "Pour comparer rachat LPP et investissement libre, j'ai besoin de ton "
    "canton — l'économie fiscale dépend du barème cantonal. "
    "Tu peux me le partager ?"
)


_CALENDRIER_RETRAITS_HINT_FR = (
    "Pour comparer un retrait groupé et un retrait échelonné, j'ai besoin "
    "de ton canton — la progressivité fiscale change tout. "
    "Tu peux me le partager ?"
)


@router.post("/allocation-annuelle", response_model=AllocationAnnuelleResponse)
@limiter.limit("10/minute")
def arbitrage_allocation_annuelle(
    request: Request,
    body: AllocationAnnuelleRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> AllocationAnnuelleResponse:
    """Compare les strategies d'allocation annuelle de l'epargne.

    Simule jusqu'a 4 options selon l'eligibilite:
    - 3a (si pas encore verse au max)
    - Rachat LPP (si potentiel de rachat > 0)
    - Amortissement indirect (si proprietaire)
    - Investissement libre (toujours disponible)

    Grounded via D-CE-06 + D-CE-07 : canton, is_property_owner,
    taux_hypothecaire and rendement_3a are read from `_user.profile` when
    not supplied in the body (no silent hardcoded VD/False/1.5%/2%
    fallback). Missing required profile fields trigger a 422 with the
    D-CE-08 `CoachToolIncomplete` envelope when
    `PROFILE_GROUNDING_STRICT_MODE=true` ; otherwise a warning is logged
    and the legacy hardcoded-defaults branch resumes (non-strict
    graceful Flutter rollout).

    Returns:
        AllocationAnnuelleResponse avec trajectoires, breakeven, sensibilite,
        disclaimer et sources legales.
    """
    resolved = _resolve_defaults(profile_data, body, AllocationAnnuelleRequest)
    missing = _required_profile_fields_missing(resolved, AllocationAnnuelleRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_ALLOCATION_ANNUELLE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/arbitrage/allocation-annuelle",
        )
    emit_calc_invoke_metric(
        kind="allocation_annuelle",
        resolved=resolved,
        schema_class=AllocationAnnuelleRequest,
    )

    try:
        result = compare_allocation_annuelle(
            montant_disponible=resolved["montant_disponible"],
            taux_marginal=resolved["taux_marginal"],
            a3a_maxed=(
                resolved["a3a_maxed"]
                if resolved["a3a_maxed"] is not None
                else False
            ),
            potentiel_rachat_lpp=(
                resolved["potentiel_rachat_lpp"]
                if resolved["potentiel_rachat_lpp"] is not None
                else 0
            ),
            is_property_owner=bool(resolved["is_property_owner"]),
            taux_hypothecaire=float(resolved["taux_hypothecaire"]),
            annees_avant_retraite=(
                resolved["annees_avant_retraite"]
                if resolved["annees_avant_retraite"] is not None
                else 20
            ),
            rendement_3a=float(resolved["rendement_3a"]),
            rendement_lpp=(
                resolved["rendement_lpp"]
                if resolved["rendement_lpp"] is not None
                else 0.0125
            ),
            rendement_marche=(
                resolved["rendement_marche"]
                if resolved["rendement_marche"] is not None
                else 0.04
            ),
            canton=str(resolved["canton"]).upper(),
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
    profile_data: dict = Depends(get_profile_filled),
) -> LocationVsProprieteResponse:
    """Compare continuer a louer vs acheter un bien immobilier.

    Simule 2 options:
    - Option A: Continuer a louer + investir le capital sur le marche
    - Option B: Acheter le bien avec hypotheque

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 3 sev-2 fix — legacy default
    "VD" produced wrong rent vs property economic comparison for non-VD
    users). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when `PROFILE_GROUNDING_STRICT_MODE=true` ;
    otherwise a warning is logged and the legacy hardcoded-default branch
    resumes (non-strict graceful Flutter rollout).

    Returns:
        LocationVsProprieteResponse avec 2 trajectoires, breakeven, sensibilite,
        disclaimer et sources legales (CO, LIFD, FINMA).
    """
    resolved = _resolve_defaults(profile_data, body, LocationVsProprieteRequest)
    missing = _required_profile_fields_missing(resolved, LocationVsProprieteRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_LOCATION_VS_PROPRIETE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/arbitrage/location-vs-propriete",
        )
    emit_calc_invoke_metric(
        kind="location_vs_propriete",
        resolved=resolved,
        schema_class=LocationVsProprieteRequest,
    )

    try:
        result = compare_location_vs_propriete(
            capital_disponible=resolved["capital_disponible"],
            loyer_mensuel_actuel=resolved["loyer_mensuel_actuel"],
            prix_bien=resolved["prix_bien"],
            canton=str(resolved["canton"]).upper(),
            horizon_annees=(
                resolved["horizon_annees"]
                if resolved["horizon_annees"] is not None
                else 20
            ),
            rendement_marche=(
                resolved["rendement_marche"]
                if resolved["rendement_marche"] is not None
                else 0.04
            ),
            appreciation_immo=(
                resolved["appreciation_immo"]
                if resolved["appreciation_immo"] is not None
                else 0.015
            ),
            taux_hypotheque=(
                resolved["taux_hypotheque"]
                if resolved["taux_hypotheque"] is not None
                else 0.02
            ),
            taux_entretien=(
                resolved["taux_entretien"]
                if resolved["taux_entretien"] is not None
                else 0.01
            ),
            is_married=(
                resolved["is_married"]
                if resolved["is_married"] is not None
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
    profile_data: dict = Depends(get_profile_filled),
) -> RachatVsMarcheResponse:
    """Compare rachat LPP vs investissement libre.

    Simule 2 options:
    - Option A: Rachat LPP (deduction fiscale + croissance en caisse)
    - Option B: Investissement libre (liquidite totale + rendement marche)

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 4 — silent VD fallback
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Returns:
        RachatVsMarcheResponse avec 2 trajectoires, breakeven, sensibilite,
        disclaimer et sources legales (LPP, LIFD, OPP2).
    """
    resolved = _resolve_defaults(profile_data, body, RachatVsMarcheRequest)
    missing = _required_profile_fields_missing(resolved, RachatVsMarcheRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_RACHAT_VS_MARCHE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/arbitrage/rachat-vs-marche",
        )
    emit_calc_invoke_metric(
        kind="rachat_vs_marche",
        resolved=resolved,
        schema_class=RachatVsMarcheRequest,
    )

    try:
        result = compare_rachat_vs_marche(
            montant=resolved["montant"],
            taux_marginal=resolved["taux_marginal"],
            annees_avant_retraite=(
                resolved["annees_avant_retraite"]
                if resolved["annees_avant_retraite"] is not None
                else 20
            ),
            rendement_lpp=(
                resolved["rendement_lpp"]
                if resolved["rendement_lpp"] is not None
                else 0.0125
            ),
            rendement_marche=(
                resolved["rendement_marche"]
                if resolved["rendement_marche"] is not None
                else 0.04
            ),
            taux_conversion=(
                resolved["taux_conversion"]
                if resolved["taux_conversion"] is not None
                else 0.068
            ),
            canton=str(resolved["canton"]).upper(),
            is_married=(
                resolved["is_married"]
                if resolved["is_married"] is not None
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
    profile_data: dict = Depends(get_profile_filled),
) -> CalendrierRetraitsResponse:
    """Compare retrait total la meme annee vs retraits echelonnes.

    Simule 2 options:
    - Option A: Tout retirer la meme annee (progressivite maximale)
    - Option B: Echelonner les retraits sur plusieurs annees fiscales

    Le premier éclairage montre l'economie fiscale potentielle, souvent
    CHF 15'000 a 40'000+ pour des capitaux importants.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 5 — silent VD fallback
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Returns:
        CalendrierRetraitsResponse avec 2 trajectoires, premier éclairage,
        disclaimer et sources legales (LIFD art. 38, OPP3, LPP).
    """
    resolved = _resolve_defaults(profile_data, body, CalendrierRetraitsRequest)
    missing = _required_profile_fields_missing(resolved, CalendrierRetraitsRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_CALENDRIER_RETRAITS_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/arbitrage/calendrier-retraits",
        )
    emit_calc_invoke_metric(
        kind="calendrier_retraits",
        resolved=resolved,
        schema_class=CalendrierRetraitsRequest,
    )

    try:
        # Convert schema assets to service dataclass
        assets = [
            RetirementAsset(
                type=a.type,
                amount=a.amount,
                earliest_withdrawal_age=a.earliest_withdrawal_age,
            )
            for a in resolved["assets"]
        ]

        result = compare_calendrier_retraits(
            assets=assets,
            age_retraite=(
                resolved["age_retraite"]
                if resolved["age_retraite"] is not None
                else 65
            ),
            canton=str(resolved["canton"]).upper(),
            is_married=(
                resolved["is_married"]
                if resolved["is_married"] is not None
                else False
            ),
        )

        return _result_to_response(result, CalendrierRetraitsResponse)

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")
