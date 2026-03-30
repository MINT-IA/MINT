"""
Assurances endpoints.

POST /api/v1/assurances/lamal/optimize — LAMal franchise optimizer
POST /api/v1/assurances/coverage/check — Coverage checklist

Sprint S13, Chantier 7: Assurances completes.
"""

from fastapi import APIRouter, Depends, Request

from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.user import User
from app.schemas.assurances import (
    LamalFranchiseRequest,
    LamalFranchiseResponse,
    FranchiseComparisonResponse,
    BreakEvenResponse,
    RecommandationResponse,
    CoverageCheckRequest,
    CoverageCheckResponse,
    ChecklistItemResponse,
)
from app.services.lamal_franchise_service import (
    LamalFranchiseOptimizer,
    LamalFranchiseInput,
)
from app.services.coverage_checklist_service import (
    CoverageChecklistService,
    CoverageCheckInput,
)

router = APIRouter()

_franchise_optimizer = LamalFranchiseOptimizer()
_coverage_service = CoverageChecklistService()


@router.post("/lamal/optimize", response_model=LamalFranchiseResponse)
def optimize_franchise(request: LamalFranchiseRequest, _user: User = Depends(require_current_user)) -> LamalFranchiseResponse:
    """Optimize LAMal franchise based on health expenses and premium.

    This stateless endpoint performs no data storage -- all computation
    is done on the fly from the provided inputs.
    """
    input_data = LamalFranchiseInput(
        prime_mensuelle_base=request.primeMensuelleBase,
        depenses_sante_annuelles=request.depensesSanteAnnuelles,
        age_category=request.ageCategory.value,
    )

    result = _franchise_optimizer.optimize(input_data)

    # Map service result to response schema
    comparaison = [
        FranchiseComparisonResponse(
            franchise=entry["franchise"],
            primeAnnuelle=entry["prime_annuelle"],
            franchiseEffective=entry["franchise_effective"],
            quotePart=entry["quote_part"],
            coutTotal=entry["cout_total"],
            economieVsRef=entry["economie_vs_ref"],
        )
        for entry in result.comparaison
    ]

    break_even_points = [
        BreakEvenResponse(
            franchiseBasse=bp["franchise_basse"],
            franchiseHaute=bp["franchise_haute"],
            seuilDepenses=bp["seuil_depenses"],
        )
        for bp in result.break_even_points
    ]

    recommandations = [
        RecommandationResponse(
            id=rec["id"],
            titre=rec["titre"],
            description=rec["description"],
            source=rec["source"],
            priorite=rec["priorite"],
        )
        for rec in result.recommandations
    ]

    return LamalFranchiseResponse(
        comparaison=comparaison,
        franchiseOptimale=result.franchise_optimale,
        breakEvenPoints=break_even_points,
        recommandations=recommandations,
        alerteDelai=result.alerte_delai,
        disclaimer=result.disclaimer,
    )


@router.post("/coverage/check", response_model=CoverageCheckResponse)
def check_coverage(request: CoverageCheckRequest, _user: User = Depends(require_current_user)) -> CoverageCheckResponse:
    """Evaluate insurance coverage and generate personalized checklist.

    This stateless endpoint performs no data storage -- all computation
    is done on the fly from the provided inputs.
    """
    input_data = CoverageCheckInput(
        statut_professionnel=request.statutProfessionnel.value,
        a_hypotheque=request.aHypotheque,
        a_famille=request.aFamille,
        est_locataire=request.estLocataire,
        voyages_frequents=request.voyagesFrequents,
        a_ijm_collective=request.aIjmCollective,
        a_laa=request.aLaa,
        a_rc_privee=request.aRcPrivee,
        a_menage=request.aMenage,
        a_protection_juridique=request.aProtectionJuridique,
        a_assurance_voyage=request.aAssuranceVoyage,
        a_assurance_deces=request.aAssuranceDeces,
        canton=request.canton,
    )

    result = _coverage_service.evaluate(input_data)

    # Map service result to response schema
    checklist = [
        ChecklistItemResponse(
            id=item["id"],
            categorie=item["categorie"],
            titre=item["titre"],
            description=item["description"],
            urgence=item["urgence"],
            statut=item["statut"],
            coutEstimeAnnuel=item.get("cout_estime_annuel"),
            source=item["source"],
        )
        for item in result.checklist
    ]

    recommandations = [
        RecommandationResponse(
            id=rec["id"],
            titre=rec["titre"],
            description=rec["description"],
            source=rec["source"],
            priorite=rec["priorite"],
        )
        for rec in result.recommandations
    ]

    return CoverageCheckResponse(
        checklist=checklist,
        scoreCouverture=result.score_couverture,
        lacunesCritiques=result.lacunes_critiques,
        recommandations=recommandations,
        disclaimer=result.disclaimer,
    )
