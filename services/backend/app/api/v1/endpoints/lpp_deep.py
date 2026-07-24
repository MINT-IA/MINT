"""
LPP Deep Dive endpoints — Chantier 4: "Comprendre mon 2e pilier".

POST /api/v1/lpp-deep/rachat-echelonne   — Stepped buyback simulation
POST /api/v1/lpp-deep/libre-passage      — Vested benefits advisor
POST /api/v1/lpp-deep/epl                — Home ownership (EPL) simulation

Sprint S15 — Chantier 4: LPP approfondi.
All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Depends, Request

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
from app.schemas.lpp_deep import (
    RachatEchelonneRequest,
    RachatEchelonneResponse,
    RachatAnnuelEntryResponse,
    LibrePassageRequest,
    LibrePassageResponse,
    ActionItemResponse,
    AlerteResponse,
    RecommandationResponse,
    EPLRequest,
    EPLResponse,
    ImpactPrestationsResponse,
)
from app.services.lpp_deep.rachat_echelonne_service import RachatEchelonneService
from app.services.lpp_deep.libre_passage_service import LibrePassageService
from app.services.lpp_deep.epl_service import EPLService


router = APIRouter()

# Shared service instances
_rachat_service = RachatEchelonneService()
_libre_passage_service = LibrePassageService()
_epl_service = EPLService()


# ---------------------------------------------------------------------------
# Rachat Echelonne
# ---------------------------------------------------------------------------

_RACHAT_ECHELONNE_HINT_FR = (
    "Pour estimer ton rachat LPP échelonné, j'ai besoin de ton canton "
    "et de ton revenu imposable annuel. Tu peux me les partager ?"
)


@router.post("/rachat-echelonne", response_model=RachatEchelonneResponse)
@limiter.limit("30/minute")
def simulate_rachat_echelonne(
    request: Request,
    body: RachatEchelonneRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> RachatEchelonneResponse:
    """Simulate a stepped LPP buyback to optimize tax savings.

    Compares buying back in a single year (bloc) vs spreading over N years.
    The stepped approach typically saves more due to progressive taxation.

    Grounded via D-CE-06 + D-CE-07 : canton, revenuImposable, avoirActuel
    are read from `_user.profile.data` when not in body. Missing canton or
    revenuImposable triggers 422 with the D-CE-08 `CoachToolIncomplete`
    envelope when strict mode is enabled — closes the sev-3 incident class
    where `TAUX_MARGINAUX_PAR_CANTON[None]` would otherwise raise KeyError
    → 500 (threat T-mint-calc-02-03 DoS mitigation).

    Sources: LPP art. 79b, LIFD art. 33 al. 1 let. d, OPP2 art. 60a.
    """
    resolved = _resolve_defaults(profile_data, body, RachatEchelonneRequest)
    missing = _required_profile_fields_missing(resolved, RachatEchelonneRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_RACHAT_ECHELONNE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/lpp-deep/rachat-echelonne",
        )
    emit_calc_invoke_metric(
        kind="rachat_echelonne",
        resolved=resolved,
        schema_class=RachatEchelonneRequest,
    )

    result = _rachat_service.simulate(
        avoir_actuel=float(resolved["avoirActuel"]),
        rachat_max=float(resolved["rachatMax"]),
        revenu_imposable=float(resolved["revenuImposable"]),
        taux_marginal_estime=resolved["tauxMarginalEstime"],
        canton=str(resolved["canton"]),
        horizon_rachat_annees=int(resolved["horizonRachatAnnees"]),
    )

    return RachatEchelonneResponse(
        plan=[
            RachatAnnuelEntryResponse(
                annee=entry.annee,
                montantRachat=entry.montant_rachat,
                revenuImposableAvant=entry.revenu_imposable_avant,
                revenuImposableApres=entry.revenu_imposable_apres,
                tauxMarginalAvant=entry.taux_marginal_avant,
                tauxMarginalApres=entry.taux_marginal_apres,
                economieFiscale=entry.economie_fiscale,
                coutNet=entry.cout_net,
            )
            for entry in result.plan
        ],
        horizonAnnees=result.horizon_annees,
        totalRachat=result.total_rachat,
        totalEconomieFiscale=result.total_economie_fiscale,
        totalCoutNet=result.total_cout_net,
        blocEconomieFiscale=result.bloc_economie_fiscale,
        blocCoutNet=result.bloc_cout_net,
        economieVsBloc=result.economie_vs_bloc,
        economieVsBlocPct=result.economie_vs_bloc_pct,
        canton=result.canton,
        blocageEplFin=result.blocage_epl_fin,
        alerts=result.alerts,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Libre Passage
# ---------------------------------------------------------------------------

@router.post("/libre-passage", response_model=LibrePassageResponse)
@limiter.limit("30/minute")
def analyze_libre_passage(
    request: Request,
    body: LibrePassageRequest,
) -> LibrePassageResponse:
    """Analyze a libre passage (vested benefits) situation.

    Provides a checklist, alerts, and recommendations based on the user's
    situation (job change, departure from Switzerland, cessation of activity).

    Sources: LFLP art. 2-4, LPP art. 25e-25f, OLP art. 8-10.
    """
    result = _libre_passage_service.analyze(
        statut=body.statut.value,
        avoir_libre_passage=body.avoirLibrePassage,
        age=body.age,
        a_nouveau_employeur=body.aNouvelEmployeur,
        delai_jours=body.delaiJours,
        destination=body.destination.value if body.destination else None,
        avoir_obligatoire=body.avoirObligatoire,
        avoir_surobligatoire=body.avoirSurobligatoire,
    )

    return LibrePassageResponse(
        statut=result.statut,
        checklist=[
            ActionItemResponse(
                description=item.description,
                delai=item.delai,
                priorite=item.priorite,
                sourceLegale=item.source_legale,
            )
            for item in result.checklist
        ],
        alertes=[
            AlerteResponse(
                niveau=alerte.niveau,
                message=alerte.message,
                sourceLegale=alerte.source_legale,
            )
            for alerte in result.alertes
        ],
        recommandations=[
            RecommandationResponse(
                titre=rec.titre,
                description=rec.description,
                sourceLegale=rec.source_legale,
            )
            for rec in result.recommandations
        ],
        peutRetirerCapital=result.peut_retirer_capital,
        montantRetirable=result.montant_retirable,
        montantBloque=result.montant_bloque,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# EPL (Encouragement a la propriete du logement)
# ---------------------------------------------------------------------------

_EPL_HINT_FR = (
    "Pour simuler le retrait EPL, j'ai besoin de ton canton — "
    "l'impôt sur le retrait dépend du barème cantonal. Tu peux me le partager ?"
)


@router.post("/epl", response_model=EPLResponse)
@limiter.limit("30/minute")
def simulate_epl(
    request: Request,
    body: EPLRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> EPLResponse:
    """Simulate an EPL (home ownership encouragement) withdrawal from LPP.

    Calculates the maximum withdrawable amount, tax impact, and critically
    the impact on death and disability benefits.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 15). Missing profile.canton
    triggers a 422 with the D-CE-08 `CoachToolIncomplete` envelope when
    strict mode is enabled.

    Sources: LPP art. 30a-30g, OPP2 art. 5-5f, LPP art. 79b al. 3.
    """
    resolved = _resolve_defaults(profile_data, body, EPLRequest)
    missing = _required_profile_fields_missing(resolved, EPLRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_EPL_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/lpp-deep/epl",
        )
    emit_calc_invoke_metric(
        kind="epl",
        resolved=resolved,
        schema_class=EPLRequest,
    )

    result = _epl_service.simulate(
        avoir_lpp_total=resolved["avoirLppTotal"],
        avoir_obligatoire=resolved["avoirObligatoire"],
        avoir_surobligatoire=resolved["avoirSurobligatoire"],
        age=resolved["age"],
        montant_retrait_souhaite=resolved["montantRetraitSouhaite"],
        a_rachete_recemment=resolved["aRacheteRecemment"],
        annees_depuis_dernier_rachat=resolved["anneesDernierRachat"],
        avoir_a_50_ans=resolved["avoirA50Ans"],
        canton=str(resolved["canton"]),
        is_married=bool(resolved["is_married"]),
    )

    return EPLResponse(
        montantRetirableMax=result.montant_retirable_max,
        montantDemande=result.montant_demande,
        montantEffectif=result.montant_effectif,
        respecteMinimum=result.respecte_minimum,
        age=result.age,
        regleAge50Appliquee=result.regle_age_50_appliquee,
        avoirA50Ans=result.avoir_a_50_ans,
        impotRetraitEstime=result.impot_retrait_estime,
        canton=result.canton,
        tauxImpotRetrait=result.taux_impot_retrait,
        impactPrestations=ImpactPrestationsResponse(
            renteInvaliditeReductionPct=result.impact_prestations.rente_invalidite_reduction_pct,
            capitalDecesReductionPct=result.impact_prestations.capital_deces_reduction_pct,
            renteInvaliditeReductionChf=result.impact_prestations.rente_invalidite_reduction_chf,
            capitalDecesReductionChf=result.impact_prestations.capital_deces_reduction_chf,
            message=result.impact_prestations.message,
        ),
        blocageRachat=result.blocage_rachat,
        anneesDernierRachat=result.annees_depuis_rachat,
        anneesRestantesBlocage=result.annees_restantes_blocage,
        checklist=result.checklist,
        alertes=result.alertes,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )
