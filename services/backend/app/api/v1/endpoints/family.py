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
POST /api/v1/family/concubinage/succession — Impot de succession compare
GET  /api/v1/family/concubinage/checklist — Checklist concubinage

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter
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
def compare_mariage_fiscal(request: Request, body: MariageFiscalRequest) -> MariageFiscalResponse:
    """Compare l'impot en tant que 2 celibataires vs couple marie.

    Montre la 'penalite' ou le 'bonus' du mariage selon les revenus.

    Sources: LIFD art. 9, 33, 35, 36.
    """
    service = MariageService()
    result = service.compare_fiscal_impact(
        revenu_1=body.revenu_1,
        revenu_2=body.revenu_2,
        canton=body.canton,
        enfants=body.enfants,
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
        chiffre_choc=result.chiffre_choc,
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
        chiffre_choc=result.chiffre_choc,
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
        chiffre_choc=result.chiffre_choc,
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
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Naissance — Allocations familiales
# ---------------------------------------------------------------------------

@router.post("/naissance/allocations", response_model=AllocationsFamilialesResponse)
@limiter.limit("30/minute")
def estimate_allocations(request: Request, body: AllocationsFamilialesRequest) -> AllocationsFamilialesResponse:
    """Estime les allocations familiales cantonales.

    Allocation enfant: CHF 200-300/mois, allocation formation: +CHF 50/mois.

    Sources: LAFam art. 3.
    """
    service = NaissanceService()
    result = service.estimate_allocations(
        canton=body.canton,
        nb_enfants=body.nb_enfants,
        ages_enfants=body.ages_enfants,
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

    Deduction par enfant: CHF 6'700. Frais de garde: max CHF 25'500.

    Sources: LIFD art. 35, 33.
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
        chiffre_choc=result.chiffre_choc,
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
        chiffre_choc=result.chiffre_choc,
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
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Concubinage — Comparaison complete
# ---------------------------------------------------------------------------

@router.post("/concubinage/compare", response_model=ConcubinageCompareResponse)
@limiter.limit("30/minute")
def compare_concubinage(request: Request, body: ConcubinageCompareRequest) -> ConcubinageCompareResponse:
    """Compare mariage vs concubinage : fiscal, prevoyance, succession, protection.

    Analyse complete sur 6 domaines avec scores de protection.

    Sources: LIFD, LAVS, LPP, CC.
    """
    service = ConcubinageService()
    result = service.compare_mariage_vs_concubinage(
        revenu_1=body.revenu_1,
        revenu_2=body.revenu_2,
        canton=body.canton,
        enfants=body.enfants,
        patrimoine=body.patrimoine,
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
        impot_succession_conjoint=result.impot_succession_conjoint,
        impot_succession_concubin=result.impot_succession_concubin,
        synthese=result.synthese,
        chiffre_choc=result.chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Concubinage — Succession
# ---------------------------------------------------------------------------

@router.post("/concubinage/succession", response_model=SuccessionResponse)
@limiter.limit("30/minute")
def compare_succession(request: Request, body: SuccessionRequest) -> SuccessionResponse:
    """Compare l'impot de succession conjoint vs concubin.

    Le conjoint est exonere dans la plupart des cantons. Le concubin
    est impose au taux 'tiers' (10-25% selon le canton).

    Sources: Lois cantonales successions, CC art. 457-466.
    """
    service = ConcubinageService()
    result = service.estimate_inheritance_tax(
        patrimoine=body.patrimoine,
        canton=body.canton,
        is_married=body.is_married,
    )
    return SuccessionResponse(
        canton=result.canton,
        patrimoine=result.patrimoine,
        impot_conjoint=result.impot_conjoint,
        impot_concubin=result.impot_concubin,
        difference=result.difference,
        taux_conjoint=result.taux_conjoint,
        taux_concubin=result.taux_concubin,
        chiffre_choc=result.chiffre_choc,
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
