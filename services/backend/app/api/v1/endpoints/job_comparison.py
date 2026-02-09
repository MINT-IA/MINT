"""
Job Change / LPP Plan Comparator endpoint.

POST /api/v1/job-comparison/compare — compare two jobs
GET  /api/v1/job-comparison/checklist — get the "before you sign" checklist template
"""

from fastapi import APIRouter
from app.schemas.job_comparison import (
    JobComparisonRequest,
    JobComparisonResponse,
    ComparisonAxis,
    ChecklistItem,
    ChecklistResponse,
)
from app.services.job_comparator import JobComparator, LPPPlanData

router = APIRouter()

_comparator = JobComparator()


def _input_to_plan(plan_input) -> LPPPlanData:
    """Convert Pydantic LPPPlanInput to dataclass LPPPlanData."""
    return LPPPlanData(
        salaire_brut=plan_input.salaireBrut,
        salaire_assure=plan_input.salaireAssure,
        deduction_coordination=plan_input.deductionCoordination,
        deduction_coordination_type=plan_input.deductionCoordinationType.value,
        taux_cotisation_employe=plan_input.tauxCotisationEmploye,
        taux_cotisation_employeur=plan_input.tauxCotisationEmployeur,
        part_employeur_pct=plan_input.partEmployeurPct,
        avoir_vieillesse=plan_input.avoirVieillesse,
        taux_conversion_obligatoire=plan_input.tauxConversionObligatoire,
        taux_conversion_surobligatoire=plan_input.tauxConversionSurobligatoire,
        taux_conversion_enveloppe=plan_input.tauxConversionEnveloppe,
        rente_invalidite_pct=plan_input.renteInvaliditePct,
        capital_deces=plan_input.capitalDeces,
        rachat_maximum=plan_input.rachatMaximum,
        has_ijm=plan_input.hasIjm,
        ijm_taux=plan_input.ijmTaux,
        ijm_duree_jours=plan_input.ijmDureeJours,
    )


@router.post("/compare", response_model=JobComparisonResponse)
def compare_jobs(request: JobComparisonRequest) -> JobComparisonResponse:
    """Compare two jobs focusing on the 'invisible salary' (LPP).

    This stateless endpoint performs no data storage — all computation
    is done on the fly from the provided inputs.
    """
    current = _input_to_plan(request.currentPlan)
    new = _input_to_plan(request.newPlan)

    result = _comparator.compare(
        current=current,
        new=new,
        age=request.age,
        years_to_retirement=request.yearsToRetirement,
    )

    # Build comparison axes
    axes = [
        ComparisonAxis(
            name="Salaire net annuel",
            currentValue=result.salaire_net_actuel,
            newValue=result.salaire_net_nouveau,
            delta=result.delta_salaire_net,
            unit="CHF/an",
            isPositive=result.delta_salaire_net >= 0,
        ),
        ComparisonAxis(
            name="Cotisation employe",
            currentValue=result.cotisation_employe_actuel,
            newValue=result.cotisation_employe_nouveau,
            delta=result.delta_cotisation,
            unit="CHF/an",
            isPositive=result.delta_cotisation <= 0,  # Lower is better for employee
        ),
        ComparisonAxis(
            name="Capital retraite projete",
            currentValue=result.capital_retraite_actuel,
            newValue=result.capital_retraite_nouveau,
            delta=result.delta_capital,
            unit="CHF",
            isPositive=result.delta_capital >= 0,
        ),
        ComparisonAxis(
            name="Rente mensuelle",
            currentValue=result.rente_mensuelle_actuel,
            newValue=result.rente_mensuelle_nouveau,
            delta=result.delta_rente,
            unit="CHF/mois",
            isPositive=result.delta_rente >= 0,
        ),
        ComparisonAxis(
            name="Capital deces",
            currentValue=result.couverture_deces_actuel,
            newValue=result.couverture_deces_nouveau,
            delta=result.delta_deces,
            unit="CHF",
            isPositive=result.delta_deces >= 0,
        ),
        ComparisonAxis(
            name="Couverture invalidite",
            currentValue=result.couverture_invalidite_actuel,
            newValue=result.couverture_invalidite_nouveau,
            delta=result.delta_invalidite,
            unit="CHF/an",
            isPositive=result.delta_invalidite >= 0,
        ),
        ComparisonAxis(
            name="Rachat maximum",
            currentValue=result.rachat_max_actuel,
            newValue=result.rachat_max_nouveau,
            delta=result.delta_rachat,
            unit="CHF",
            isPositive=result.delta_rachat >= 0,
        ),
    ]

    return JobComparisonResponse(
        axes=axes,
        salaireNetActuel=result.salaire_net_actuel,
        salaireNetNouveau=result.salaire_net_nouveau,
        deltaSalaireNet=result.delta_salaire_net,
        cotisationEmployeActuel=result.cotisation_employe_actuel,
        cotisationEmployeNouveau=result.cotisation_employe_nouveau,
        deltaCotisation=result.delta_cotisation,
        capitalRetraiteActuel=result.capital_retraite_actuel,
        capitalRetraiteNouveau=result.capital_retraite_nouveau,
        deltaCapital=result.delta_capital,
        renteMensuelleActuel=result.rente_mensuelle_actuel,
        renteMensuelleNouveau=result.rente_mensuelle_nouveau,
        deltaRente=result.delta_rente,
        couvertureDecesActuel=result.couverture_deces_actuel,
        couvertureDecesNouveau=result.couverture_deces_nouveau,
        deltaDeces=result.delta_deces,
        couvertureInvaliditeActuel=result.couverture_invalidite_actuel,
        couvertureInvaliditeNouveau=result.couverture_invalidite_nouveau,
        deltaInvalidite=result.delta_invalidite,
        rachatMaxActuel=result.rachat_max_actuel,
        rachatMaxNouveau=result.rachat_max_nouveau,
        deltaRachat=result.delta_rachat,
        hasIjmActuel=result.has_ijm_actuel,
        hasIjmNouveau=result.has_ijm_nouveau,
        verdict=result.verdict,
        verdictDetails=result.verdict_details,
        annualPensionDelta=result.annual_pension_delta,
        lifetimePensionDelta=result.lifetime_pension_delta,
        alerts=result.alerts,
        checklist=result.checklist,
    )


@router.get("/checklist", response_model=ChecklistResponse)
def get_checklist() -> ChecklistResponse:
    """Get the 'before you sign' checklist template for job change due diligence.

    This is a static template — no personal data required.
    """
    items = [
        ChecklistItem(
            label="Demander le certificat de prevoyance (certificat LPP) du nouvel employeur.",
            category="prevoyance",
            priority="haute",
        ),
        ChecklistItem(
            label="Comparer le taux de conversion obligatoire et surobligatoire.",
            category="prevoyance",
            priority="haute",
        ),
        ChecklistItem(
            label="Verifier la part employeur (minimum legal 50%, bons plans: 60-65%).",
            category="prevoyance",
            priority="haute",
        ),
        ChecklistItem(
            label="Verifier la presence d'une IJM collective (perte de gain maladie).",
            category="risque",
            priority="haute",
        ),
        ChecklistItem(
            label="Demander le montant de rachat maximum dans la nouvelle caisse.",
            category="prevoyance",
            priority="moyenne",
        ),
        ChecklistItem(
            label="Verifier les prestations invalidite (rente et exoneration).",
            category="risque",
            priority="haute",
        ),
        ChecklistItem(
            label="Verifier le capital deces et les beneficiaires designes.",
            category="risque",
            priority="moyenne",
        ),
        ChecklistItem(
            label="Organiser le transfert du libre passage vers la nouvelle caisse.",
            category="administratif",
            priority="haute",
        ),
        ChecklistItem(
            label="Verifier la deduction de coordination (fixe vs proportionnelle, important pour temps partiel).",
            category="prevoyance",
            priority="moyenne",
        ),
        ChecklistItem(
            label="Demander le reglement de prevoyance complet de la nouvelle caisse.",
            category="administratif",
            priority="moyenne",
        ),
        ChecklistItem(
            label="Verifier le delai de carence pour les prestations de risque.",
            category="risque",
            priority="moyenne",
        ),
        ChecklistItem(
            label="Verifier l'impact fiscal d'un eventuel rachat dans la nouvelle caisse.",
            category="fiscal",
            priority="basse",
        ),
        ChecklistItem(
            label="Si plan surobligatoire: verifier le salaire assure au-dela du maximum LPP.",
            category="prevoyance",
            priority="moyenne",
        ),
    ]

    return ChecklistResponse(
        items=items,
        disclaimer=(
            "Cette checklist est fournie a titre informatif et educatif. "
            "Elle ne constitue pas un conseil en prevoyance professionnelle "
            "au sens de la LSFin. Consultez un expert LPP pour une analyse personnalisee."
        ),
    )
