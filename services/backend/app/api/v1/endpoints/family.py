"""
Family life events endpoints — Sprint S22.

POST /api/v1/family/mariage/compare       — Comparaison fiscale celibataire vs marie
POST /api/v1/family/mariage/regime        — Simulation regime matrimonial
POST /api/v1/family/mariage/survivant     — Estimation rente de survivant
POST /api/v1/family/mariage/checklist     — Checklist mariage personnalisee
POST /api/v1/family/naissance/conge       — Calcul APG conge parental
POST /api/v1/family/naissance/allocations — Allocations familiales cantonales
POST /api/v1/family/naissance/impact-fiscal — Impact fiscal des enfants
POST /api/v1/family/naissance/career-gap  — Impact interruption de carriere
POST /api/v1/family/naissance/checklist   — Checklist naissance personnalisee
POST /api/v1/family/concubinage/compare   — Comparaison mariage vs concubinage
POST /api/v1/family/concubinage/succession — Mecanisme successoral (non chiffre)
GET  /api/v1/family/concubinage/checklist — Checklist concubinage

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
from app.schemas.family import (
    MariageFiscalRequest,
    MariageFiscalResponse,
    RegimeMatrimonialRequest,
    RegimeMatrimonialResponse,
    SurvivorBenefitsRequest,
    SurvivorBenefitsResponse,
    ChecklistMariageRequest,
    ChecklistMariageResponse,
    CongeParentalRequest,
    CongeParentalResponse,
    AllocationsFamilialesRequest,
    AllocationsFamilialesResponse,
    ImpactFiscalEnfantRequest,
    ImpactFiscalEnfantResponse,
    CareerGapRequest,
    CareerGapResponse,
    ChecklistNaissanceRequest,
    ChecklistNaissanceResponse,
    ConcubinageCompareRequest,
    ConcubinageCompareResponse,
    ComparisonItemSchema,
    SuccessionRequest,
    SuccessionResponse,
    ChecklistConcubinageResponse,
)
from app.services.family.mariage_service import MariageService
from app.services.family.naissance_service import NaissanceService
from app.services.family.concubinage_service import ConcubinageService


_CONCUBINAGE_SUCCESSION_HINT_FR = (
    "Pour situer ta succession en concubinage, j'ai besoin de ton canton — "
    "le traitement fiscal d'un·e concubin·e varie considérablement d'un "
    "canton à l'autre. Tu peux me le partager ?"
)


_MARIAGE_COMPARE_HINT_FR = (
    "Pour comparer ta fiscalité célibataire vs mariée, j'ai besoin de ton "
    "canton — les barèmes varient considérablement. Tu peux me le partager ?"
)


_NAISSANCE_ALLOCATIONS_HINT_FR = (
    "Pour estimer les allocations familiales, j'ai besoin de ton canton — "
    "les montants varient considérablement entre cantons. "
    "Tu peux me le partager ?"
)


_CONCUBINAGE_COMPARE_HINT_FR = (
    "Pour comparer mariage et concubinage, j'ai besoin de ton canton — "
    "la fiscalité et la succession varient selon le canton. "
    "Tu peux me le partager ?"
)


router = APIRouter()

DISCLAIMER = (
    "Estimations educatives simplifiees. Ne constitue pas un conseil "
    "fiscal ou juridique (LSFin/LLCA). Consulte un ou une specialiste."
)


# ---------------------------------------------------------------------------
# Mariage — Comparaison fiscale
# ---------------------------------------------------------------------------

@router.post("/mariage/compare", response_model=MariageFiscalResponse)
@limiter.limit("30/minute")
def compare_mariage_fiscal(
    request: Request,
    body: MariageFiscalRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> MariageFiscalResponse:
    """Compare l'impot en tant que 2 celibataires vs couple marie.

    Montre la 'penalite' ou le 'bonus' du mariage selon les revenus.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 19 — silent ZH default
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Sources: LIFD art. 9, 33, 35, 36.
    """
    resolved = _resolve_defaults(profile_data, body, MariageFiscalRequest)
    missing = _required_profile_fields_missing(resolved, MariageFiscalRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_MARIAGE_COMPARE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/family/mariage/compare",
        )
    emit_calc_invoke_metric(
        kind="mariage_compare",
        resolved=resolved,
        schema_class=MariageFiscalRequest,
    )

    service = MariageService()
    result = service.compare_fiscal_impact(
        revenu_1=resolved["revenu_1"],
        revenu_2=resolved["revenu_2"],
        canton=str(resolved["canton"]),
        enfants=resolved["enfants"],
    )
    return MariageFiscalResponse(
        impot_celibataires_total=result.impot_celibataires_total,
        impot_maries_total=result.impot_maries_total,
        difference=result.difference,
        est_penalite_mariage=result.est_penalite_mariage,
        detail_celibataire_1=result.detail_celibataire_1,
        detail_celibataire_2=result.detail_celibataire_2,
        revenus_cumules=result.revenus_cumules,
        deductions_mariage=result.deductions_mariage,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Mariage — Regime matrimonial
# ---------------------------------------------------------------------------

@router.post("/mariage/regime", response_model=RegimeMatrimonialResponse)
@limiter.limit("30/minute")
def simulate_regime(request: Request, body: RegimeMatrimonialRequest) -> RegimeMatrimonialResponse:
    """Simule la repartition du patrimoine selon le regime matrimonial choisi.

    Regimes: participation aux acquets, separation de biens, communaute de biens.

    Sources: CC art. 181, 221, 247.
    """
    service = MariageService()
    result = service.simulate_regime_matrimonial(
        patrimoine_1=body.patrimoine_1,
        patrimoine_2=body.patrimoine_2,
        regime=body.regime.value,
    )
    return RegimeMatrimonialResponse(
        regime=result.regime,
        description=result.description,
        part_conjoint_1=result.part_conjoint_1,
        part_conjoint_2=result.part_conjoint_2,
        patrimoine_total=result.patrimoine_total,
        explication=result.explication,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Mariage — Rente de survivant
# ---------------------------------------------------------------------------

@router.post("/mariage/survivant", response_model=SurvivorBenefitsResponse)
@limiter.limit("30/minute")
def estimate_survivant(request: Request, body: SurvivorBenefitsRequest) -> SurvivorBenefitsResponse:
    """Estime les rentes de survivant en cas de deces du conjoint.

    AVS = 80% de la rente du defunt, LPP = 60% de la rente assuree.

    Sources: LAVS art. 24, LPP art. 19.
    """
    service = MariageService()
    result = service.estimate_survivor_benefits(
        rente_lpp=body.rente_lpp,
        rente_avs=body.rente_avs,
    )
    return SurvivorBenefitsResponse(
        rente_survivant_avs_mensuelle=result.rente_survivant_avs_mensuelle,
        rente_survivant_avs_annuelle=result.rente_survivant_avs_annuelle,
        rente_survivant_lpp_mensuelle=result.rente_survivant_lpp_mensuelle,
        rente_survivant_lpp_annuelle=result.rente_survivant_lpp_annuelle,
        total_survivant_mensuel=result.total_survivant_mensuel,
        total_survivant_annuel=result.total_survivant_annuel,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Mariage — Checklist
# ---------------------------------------------------------------------------

@router.post("/mariage/checklist", response_model=ChecklistMariageResponse)
@limiter.limit("30/minute")
def checklist_mariage(request: Request, body: ChecklistMariageRequest) -> ChecklistMariageResponse:
    """Retourne une checklist actionable personnalisee pour les futurs maries.

    Actions classees par priorite (haute, moyenne, basse), personnalisees
    selon la situation (3a, LPP, propriete, canton).

    Sources: CC art. 159-251, LIFD art. 9, LPP art. 19-20.
    """
    service = MariageService()
    result = service.checklist_mariage(
        has_3a=body.has_3a,
        has_lpp=body.has_lpp,
        has_property=body.has_property,
        canton=body.canton,
    )
    return ChecklistMariageResponse(
        items=result.items,
        priorite_haute=result.priorite_haute,
        priorite_moyenne=result.priorite_moyenne,
        priorite_basse=result.priorite_basse,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Naissance — Conge parental
# ---------------------------------------------------------------------------

@router.post("/naissance/conge", response_model=CongeParentalResponse)
@limiter.limit("30/minute")
def simulate_conge(request: Request, body: CongeParentalRequest) -> CongeParentalResponse:
    """Calcule les APG maternite ou paternite.

    Maternite: 14 semaines, 80%, max CHF 220/jour.
    Paternite: 2 semaines, 80%, max CHF 220/jour.

    Sources: LAPG art. 16d-16l.
    """
    service = NaissanceService()
    result = service.simulate_conge_parental(
        salaire_mensuel=body.salaire_mensuel,
        is_mother=body.is_mother,
    )
    return CongeParentalResponse(
        type_conge=result.type_conge,
        duree_semaines=result.duree_semaines,
        duree_jours=result.duree_jours,
        salaire_journalier=result.salaire_journalier,
        apg_journalier=result.apg_journalier,
        apg_total=result.apg_total,
        perte_revenu=result.perte_revenu,
        est_plafonne=result.est_plafonne,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Naissance — Allocations familiales
# ---------------------------------------------------------------------------

@router.post("/naissance/allocations", response_model=AllocationsFamilialesResponse)
@limiter.limit("30/minute")
def estimate_allocations(
    request: Request,
    body: AllocationsFamilialesRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> AllocationsFamilialesResponse:
    """Estime les allocations familiales cantonales.

    Allocation enfant: CHF 215-330/mois, formation par canton (OFAS/BSV 2026).

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 18 sev-2 — canton-indexed
    allocations). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Sources: LAFam art. 3.
    """
    resolved = _resolve_defaults(profile_data, body, AllocationsFamilialesRequest)
    missing = _required_profile_fields_missing(resolved, AllocationsFamilialesRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_NAISSANCE_ALLOCATIONS_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/family/naissance/allocations",
        )
    emit_calc_invoke_metric(
        kind="naissance_allocations",
        resolved=resolved,
        schema_class=AllocationsFamilialesRequest,
    )

    service = NaissanceService()
    result = service.estimate_allocations(
        canton=str(resolved["canton"]),
        nb_enfants=resolved["nb_enfants"],
        ages_enfants=resolved["ages_enfants"],
    )
    return AllocationsFamilialesResponse(
        canton=result.canton,
        nb_enfants=result.nb_enfants,
        allocation_mensuelle_par_enfant=result.allocation_mensuelle_par_enfant,
        total_mensuel=result.total_mensuel,
        total_annuel=result.total_annuel,
        detail=result.detail,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Naissance — Impact fiscal enfant
# ---------------------------------------------------------------------------

@router.post("/naissance/impact-fiscal", response_model=ImpactFiscalEnfantResponse)
@limiter.limit("30/minute")
def impact_fiscal_enfant(request: Request, body: ImpactFiscalEnfantRequest) -> ImpactFiscalEnfantResponse:
    """Calcule l'economie fiscale liee aux enfants.

    Deduction par enfant: CHF 6'800. Frais de garde: max CHF 25'800.

    Sources: LIFD art. 35 al. 1 let. a, art. 33 al. 3.
    """
    service = NaissanceService()
    result = service.calculate_impact_fiscal_enfant(
        revenu_imposable=body.revenu_imposable,
        taux_marginal=body.taux_marginal,
        nb_enfants=body.nb_enfants,
        frais_garde=body.frais_garde,
    )
    return ImpactFiscalEnfantResponse(
        nb_enfants=result.nb_enfants,
        deduction_enfants=result.deduction_enfants,
        deduction_frais_garde=result.deduction_frais_garde,
        deduction_totale=result.deduction_totale,
        economie_impot_estimee=result.economie_impot_estimee,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Naissance — Career gap
# ---------------------------------------------------------------------------

@router.post("/naissance/career-gap", response_model=CareerGapResponse)
@limiter.limit("30/minute")
def project_career_gap(request: Request, body: CareerGapRequest) -> CareerGapResponse:
    """Projette l'impact d'une interruption de carriere sur LPP et 3a.

    Calcule les bonifications LPP manquees et les versements 3a non effectues.

    Sources: LPP art. 8, 16, OPP2.
    """
    service = NaissanceService()
    result = service.project_career_gap(
        salaire_annuel=body.salaire_annuel,
        duree_interruption_mois=body.duree_interruption_mois,
        age=body.age,
    )
    return CareerGapResponse(
        duree_interruption_mois=result.duree_interruption_mois,
        salaire_annuel=result.salaire_annuel,
        perte_lpp_annuelle=result.perte_lpp_annuelle,
        perte_lpp_totale=result.perte_lpp_totale,
        perte_3a_annuelle=result.perte_3a_annuelle,
        perte_3a_totale=result.perte_3a_totale,
        perte_revenu_totale=result.perte_revenu_totale,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Naissance — Checklist
# ---------------------------------------------------------------------------

@router.post("/naissance/checklist", response_model=ChecklistNaissanceResponse)
@limiter.limit("30/minute")
def checklist_naissance(request: Request, body: ChecklistNaissanceRequest) -> ChecklistNaissanceResponse:
    """Retourne une checklist actionable personnalisee pour les futurs parents.

    Actions classees par priorite (haute, moyenne, basse), personnalisees
    selon la situation (etat civil, canton, 3a, LPP).

    Sources: CC art. 252, LAPG art. 16b-16l, LAFam art. 3, LAMal art. 3.
    """
    service = NaissanceService()
    result = service.checklist_naissance(
        civil_status=body.civil_status,
        canton=body.canton,
        has_3a=body.has_3a,
        has_lpp=body.has_lpp,
    )
    return ChecklistNaissanceResponse(
        items=result.items,
        priorite_haute=result.priorite_haute,
        priorite_moyenne=result.priorite_moyenne,
        priorite_basse=result.priorite_basse,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Concubinage — Comparaison complete
# ---------------------------------------------------------------------------

@router.post("/concubinage/compare", response_model=ConcubinageCompareResponse)
@limiter.limit("30/minute")
def compare_concubinage(
    request: Request,
    body: ConcubinageCompareRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> ConcubinageCompareResponse:
    """Compare mariage vs concubinage : fiscal, prevoyance, succession, protection.

    Analyse complete sur 6 domaines avec scores de protection.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 22 — silent ZH default
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Sources: LIFD, LAVS, LPP, CC.
    """
    resolved = _resolve_defaults(profile_data, body, ConcubinageCompareRequest)
    missing = _required_profile_fields_missing(resolved, ConcubinageCompareRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_CONCUBINAGE_COMPARE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/family/concubinage/compare",
        )
    emit_calc_invoke_metric(
        kind="concubinage_compare",
        resolved=resolved,
        schema_class=ConcubinageCompareRequest,
    )

    service = ConcubinageService()
    result = service.compare_mariage_vs_concubinage(
        revenu_1=resolved["revenu_1"],
        revenu_2=resolved["revenu_2"],
        canton=str(resolved["canton"]),
        enfants=resolved["enfants"],
    )
    comparaisons_schema = [
        ComparisonItemSchema(
            domaine=c.domaine,
            mariage=c.mariage,
            concubinage=c.concubinage,
            avantage=c.avantage,
        )
        for c in result.comparaisons
    ]
    return ConcubinageCompareResponse(
        comparaisons=comparaisons_schema,
        score_protection_mariage=result.score_protection_mariage,
        score_protection_concubinage=result.score_protection_concubinage,
        impot_celibataires_total=result.impot_celibataires_total,
        impot_maries_total=result.impot_maries_total,
        difference_fiscale=result.difference_fiscale,
        synthese=result.synthese,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Concubinage — Succession
# ---------------------------------------------------------------------------

@router.post("/concubinage/succession", response_model=SuccessionResponse)
@limiter.limit("30/minute")
def compare_succession(
    request: Request,
    body: SuccessionRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> SuccessionResponse:
    """Enonce le mecanisme successoral du concubinage, sans le chiffrer.

    Le conjoint survivant est exonere d'impot successoral dans TOUS les
    cantons — par la loi fiscale cantonale, pas par le Code civil. Le concubin
    releve du taux dit 'des tiers'. Ni ce taux ni le montant ne sont rendus :
    ils dependent de la commune, de la franchise, de la part reellement recue
    et de la duree de vie commune, qu'aucun taux plat ne represente.

    Le `patrimoine` n'est plus demande : il alimentait un `patrimoine x taux`
    qui supposait que 100 % du patrimoine pouvait revenir au ou a la
    partenaire, ce que la revision du droit successoral au 1.1.2023 dement.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body. Missing profile.canton triggers a 422 with
    the D-CE-08 `CoachToolIncomplete` envelope when
    `PROFILE_GROUNDING_STRICT_MODE=true`.

    Sources: lois fiscales cantonales sur les successions, CC art. 457 ss,
    CC art. 470-471.
    """
    resolved = _resolve_defaults(profile_data, body, SuccessionRequest)
    missing = _required_profile_fields_missing(resolved, SuccessionRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_CONCUBINAGE_SUCCESSION_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/family/concubinage/succession",
        )
    emit_calc_invoke_metric(
        kind="concubinage_succession",
        resolved=resolved,
        schema_class=SuccessionRequest,
    )

    service = ConcubinageService()
    result = service.compare_succession_concubin_vs_conjoint(
        canton=str(resolved["canton"]),
    )
    return SuccessionResponse(
        canton=result.canton,
        regle_transmission=result.regle_transmission,
        charge_concubin=result.charge_concubin,
        facteurs_determinants=result.facteurs_determinants,
        premier_eclairage=result.premier_eclairage,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Concubinage — Checklist
# ---------------------------------------------------------------------------

@router.get("/concubinage/checklist", response_model=ChecklistConcubinageResponse)
@limiter.limit("30/minute")
def checklist_concubinage(request: Request) -> ChecklistConcubinageResponse:
    """Retourne une checklist actionable pour les concubins.

    Actions classees par priorite (haute, moyenne, basse).

    Sources: CC, LPP, CO.
    """
    service = ConcubinageService()
    result = service.checklist_concubinage()
    return ChecklistConcubinageResponse(
        items=result.items,
        priorite_haute=result.priorite_haute,
        priorite_moyenne=result.priorite_moyenne,
        priorite_basse=result.priorite_basse,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )
