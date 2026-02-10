"""
Family life events endpoints — Sprint S22.

POST /api/v1/family/mariage/compare     — Comparaison fiscale celibataire vs marie
POST /api/v1/family/mariage/regime      — Simulation regime matrimonial
POST /api/v1/family/mariage/survivant   — Estimation rente de survivant
POST /api/v1/family/naissance/conge     — Calcul APG conge parental
POST /api/v1/family/naissance/allocations — Allocations familiales cantonales
POST /api/v1/family/naissance/impact-fiscal — Impact fiscal des enfants
POST /api/v1/family/naissance/career-gap — Impact interruption de carriere
POST /api/v1/family/concubinage/compare — Comparaison mariage vs concubinage
POST /api/v1/family/concubinage/succession — Impot de succession compare
GET  /api/v1/family/concubinage/checklist — Checklist concubinage

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter

from app.schemas.family import (
    MariageFiscalRequest,
    MariageFiscalResponse,
    RegimeMatrimonialRequest,
    RegimeMatrimonialResponse,
    SurvivorBenefitsRequest,
    SurvivorBenefitsResponse,
    CongeParentalRequest,
    CongeParentalResponse,
    AllocationsFamilialesRequest,
    AllocationsFamilialesResponse,
    ImpactFiscalEnfantRequest,
    ImpactFiscalEnfantResponse,
    CareerGapRequest,
    CareerGapResponse,
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
def compare_mariage_fiscal(request: MariageFiscalRequest) -> MariageFiscalResponse:
    """Compare l'impot en tant que 2 celibataires vs couple marie.

    Montre la 'penalite' ou le 'bonus' du mariage selon les revenus.

    Sources: LIFD art. 9, 33, 35, 36.
    """
    service = MariageService()
    result = service.compare_fiscal_impact(
        revenu_1=request.revenu_1,
        revenu_2=request.revenu_2,
        canton=request.canton,
        enfants=request.enfants,
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
def simulate_regime(request: RegimeMatrimonialRequest) -> RegimeMatrimonialResponse:
    """Simule la repartition du patrimoine selon le regime matrimonial choisi.

    Regimes: participation aux acquets, separation de biens, communaute de biens.

    Sources: CC art. 181, 221, 247.
    """
    service = MariageService()
    result = service.simulate_regime_matrimonial(
        patrimoine_1=request.patrimoine_1,
        patrimoine_2=request.patrimoine_2,
        regime=request.regime.value,
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
def estimate_survivant(request: SurvivorBenefitsRequest) -> SurvivorBenefitsResponse:
    """Estime les rentes de survivant en cas de deces du conjoint.

    AVS = 80% de la rente du defunt, LPP = 60% de la rente assuree.

    Sources: LAVS art. 24, LPP art. 19.
    """
    service = MariageService()
    result = service.estimate_survivor_benefits(
        rente_lpp=request.rente_lpp,
        rente_avs=request.rente_avs,
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
# Naissance — Conge parental
# ---------------------------------------------------------------------------

@router.post("/naissance/conge", response_model=CongeParentalResponse)
def simulate_conge(request: CongeParentalRequest) -> CongeParentalResponse:
    """Calcule les APG maternite ou paternite.

    Maternite: 14 semaines, 80%, max CHF 220/jour.
    Paternite: 2 semaines, 80%, max CHF 220/jour.

    Sources: LAPG art. 16d-16l.
    """
    service = NaissanceService()
    result = service.simulate_conge_parental(
        salaire_mensuel=request.salaire_mensuel,
        is_mother=request.is_mother,
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
def estimate_allocations(request: AllocationsFamilialesRequest) -> AllocationsFamilialesResponse:
    """Estime les allocations familiales cantonales.

    Allocation enfant: CHF 200-300/mois, allocation formation: +CHF 50/mois.

    Sources: LAFam art. 3.
    """
    service = NaissanceService()
    result = service.estimate_allocations(
        canton=request.canton,
        nb_enfants=request.nb_enfants,
        ages_enfants=request.ages_enfants,
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
def impact_fiscal_enfant(request: ImpactFiscalEnfantRequest) -> ImpactFiscalEnfantResponse:
    """Calcule l'economie fiscale liee aux enfants.

    Deduction par enfant: CHF 6'700. Frais de garde: max CHF 25'500.

    Sources: LIFD art. 35, 33.
    """
    service = NaissanceService()
    result = service.calculate_impact_fiscal_enfant(
        revenu_imposable=request.revenu_imposable,
        taux_marginal=request.taux_marginal,
        nb_enfants=request.nb_enfants,
        frais_garde=request.frais_garde,
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
def project_career_gap(request: CareerGapRequest) -> CareerGapResponse:
    """Projette l'impact d'une interruption de carriere sur LPP et 3a.

    Calcule les bonifications LPP manquees et les versements 3a non effectues.

    Sources: LPP art. 8, 16, OPP2.
    """
    service = NaissanceService()
    result = service.project_career_gap(
        salaire_annuel=request.salaire_annuel,
        duree_interruption_mois=request.duree_interruption_mois,
        age=request.age,
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
# Concubinage — Comparaison complete
# ---------------------------------------------------------------------------

@router.post("/concubinage/compare", response_model=ConcubinageCompareResponse)
def compare_concubinage(request: ConcubinageCompareRequest) -> ConcubinageCompareResponse:
    """Compare mariage vs concubinage : fiscal, prevoyance, succession, protection.

    Analyse complete sur 6 domaines avec scores de protection.

    Sources: LIFD, LAVS, LPP, CC.
    """
    service = ConcubinageService()
    result = service.compare_mariage_vs_concubinage(
        revenu_1=request.revenu_1,
        revenu_2=request.revenu_2,
        canton=request.canton,
        enfants=request.enfants,
        patrimoine=request.patrimoine,
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
def compare_succession(request: SuccessionRequest) -> SuccessionResponse:
    """Compare l'impot de succession conjoint vs concubin.

    Le conjoint est exonere dans la plupart des cantons. Le concubin
    est impose au taux 'tiers' (10-25% selon le canton).

    Sources: Lois cantonales successions, CC art. 457-466.
    """
    service = ConcubinageService()
    result = service.estimate_inheritance_tax(
        patrimoine=request.patrimoine,
        canton=request.canton,
        is_married=request.is_married,
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
def checklist_concubinage() -> ChecklistConcubinageResponse:
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
