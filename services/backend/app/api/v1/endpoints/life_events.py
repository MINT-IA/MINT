"""
Life Events endpoints: Divorce Financial Simulator + Succession Simulator.

POST /api/v1/life-events/divorce/simulate     — Divorce financial simulation
POST /api/v1/life-events/succession/simulate  — Succession simulation
GET  /api/v1/life-events/divorce/checklist    — Divorce checklist template
GET  /api/v1/life-events/succession/checklist — Succession checklist template

Sprint S10.
"""

from fastapi import APIRouter
from app.schemas.life_events import (
    DivorceSimulationRequest,
    DivorceSimulationResponse,
    SuccessionSimulationRequest,
    SuccessionSimulationResponse,
    LifeEventChecklistItem,
    LifeEventChecklistResponse,
)
from app.services.divorce_simulator import DivorceSimulator, DivorceInput
from app.services.succession_simulator import SuccessionSimulator, SuccessionInput

router = APIRouter()

_divorce_sim = DivorceSimulator()
_succession_sim = SuccessionSimulator()


# ---------------------------------------------------------------------------
# Divorce endpoints
# ---------------------------------------------------------------------------

@router.post("/divorce/simulate", response_model=DivorceSimulationResponse)
def simulate_divorce(request: DivorceSimulationRequest) -> DivorceSimulationResponse:
    """Simulate financial impact of a divorce under Swiss law.

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    input_data = DivorceInput(
        duree_mariage_annees=request.dureeMarriageAnnees,
        regime_matrimonial=request.regimeMatrimonial.value,
        nombre_enfants=request.nombreEnfants,
        revenu_annuel_conjoint_1=request.revenuAnnuelConjoint1,
        revenu_annuel_conjoint_2=request.revenuAnnuelConjoint2,
        lpp_conjoint_1_pendant_mariage=request.lppConjoint1PendantMariage,
        lpp_conjoint_2_pendant_mariage=request.lppConjoint2PendantMariage,
        avoirs_3a_conjoint_1=request.avoirs3aConjoint1,
        avoirs_3a_conjoint_2=request.avoirs3aConjoint2,
        fortune_commune=request.fortuneCommune,
        dette_commune=request.detteCommune,
        canton=request.canton,
    )

    result = _divorce_sim.simulate(input_data)

    return DivorceSimulationResponse(
        partageLpp=result.partage_lpp,
        splittingAvs=result.splitting_avs,
        partage3a=result.partage_3a,
        partageFortune=result.partage_fortune,
        impactFiscalAvant=result.impact_fiscal_avant,
        impactFiscalApres=result.impact_fiscal_apres,
        pensionAlimentaireEstimee=result.pension_alimentaire_estimee,
        checklist=result.checklist,
        alerts=result.alerts,
        disclaimer=result.disclaimer,
    )


@router.get("/divorce/checklist", response_model=LifeEventChecklistResponse)
def get_divorce_checklist() -> LifeEventChecklistResponse:
    """Get template checklist for divorce planning.

    Static template — no personal data required.
    """
    items = [
        LifeEventChecklistItem(
            label="Obtenir un extrait du compte individuel AVS.",
            category="administratif",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Demander les certificats de prevoyance LPP des deux conjoints.",
            category="prevoyance",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Consulter un avocat specialise en droit de la famille.",
            category="juridique",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Verifier le regime matrimonial (contrat de mariage ou regime legal).",
            category="juridique",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Faire evaluer les biens immobiliers par un expert independant.",
            category="juridique",
            priority="moyenne",
        ),
        LifeEventChecklistItem(
            label="Rassembler les justificatifs de fortune (comptes bancaires, titres, 3a).",
            category="administratif",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Preparer un budget post-divorce pour chaque conjoint.",
            category="fiscal",
            priority="moyenne",
        ),
        LifeEventChecklistItem(
            label="Anticiper l'impact fiscal du passage a l'imposition individuelle.",
            category="fiscal",
            priority="moyenne",
        ),
        LifeEventChecklistItem(
            label="Mettre a jour les beneficiaires des assurances-vie et du 3a.",
            category="prevoyance",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Separer les comptes bancaires joints.",
            category="administratif",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Si enfants: preparer un plan de garde et de contributions d'entretien.",
            category="juridique",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Clarifier la repartition des dettes communes (hypotheque, credits).",
            category="juridique",
            priority="moyenne",
        ),
    ]

    return LifeEventChecklistResponse(
        items=items,
        disclaimer=(
            "Cette checklist est fournie a titre informatif et educatif. "
            "Elle ne constitue pas un conseil juridique. "
            "Consultez un avocat specialise en droit de la famille."
        ),
    )


# ---------------------------------------------------------------------------
# Succession endpoints
# ---------------------------------------------------------------------------

@router.post("/succession/simulate", response_model=SuccessionSimulationResponse)
def simulate_succession(
    request: SuccessionSimulationRequest,
) -> SuccessionSimulationResponse:
    """Simulate inheritance distribution under Swiss law (2023 revision).

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    input_data = SuccessionInput(
        fortune_totale=request.fortuneTotale,
        etat_civil=request.etatCivil.value,
        a_conjoint=request.aConjoint,
        nombre_enfants=request.nombreEnfants,
        a_parents_vivants=request.aParentsVivants,
        a_fratrie=request.aFratrie,
        a_concubin=request.aConcubin,
        a_testament=request.aTestament,
        quotite_disponible_testament=request.quotiteDisponibleTestament,
        avoirs_3a=request.avoirs3a,
        capital_deces_lpp=request.capitalDecesLpp,
        canton=request.canton,
    )

    result = _succession_sim.simulate(input_data)

    return SuccessionSimulationResponse(
        repartitionLegale=result.repartition_legale,
        repartitionAvecTestament=result.repartition_avec_testament,
        reservesHereditaires=result.reserves_hereditaires,
        quotiteDisponible=result.quotite_disponible,
        fiscalite=result.fiscalite,
        ordre3aOpp3=result.ordre_3a_opp3,
        alerteConcubin=result.alerte_concubin,
        checklist=result.checklist,
        alerts=result.alerts,
        disclaimer=result.disclaimer,
    )


@router.get("/succession/checklist", response_model=LifeEventChecklistResponse)
def get_succession_checklist() -> LifeEventChecklistResponse:
    """Get template checklist for succession planning.

    Static template — no personal data required.
    """
    items = [
        LifeEventChecklistItem(
            label="Faire un inventaire complet de vos avoirs (fortune, immobilier, 2e et 3e piliers).",
            category="administratif",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Consulter un notaire pour rediger ou mettre a jour votre testament.",
            category="juridique",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Verifier les clauses beneficiaires de vos assurances-vie et du 3a.",
            category="prevoyance",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Evaluer les droits de succession dans votre canton.",
            category="fiscal",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Informer vos proches de l'existence et de l'emplacement de votre testament.",
            category="administratif",
            priority="moyenne",
        ),
        LifeEventChecklistItem(
            label="Si enfants mineurs: designer un tuteur dans votre testament.",
            category="juridique",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Si concubin: rediger un testament attribuant la quotite disponible.",
            category="juridique",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Evaluer l'option de l'usufruit au conjoint survivant (CC art. 473).",
            category="juridique",
            priority="moyenne",
        ),
        LifeEventChecklistItem(
            label="Verifier les beneficiaires du 2e pilier (capital deces LPP).",
            category="prevoyance",
            priority="haute",
        ),
        LifeEventChecklistItem(
            label="Mettre a jour votre planification en cas de changement d'etat civil.",
            category="administratif",
            priority="moyenne",
        ),
        LifeEventChecklistItem(
            label="Envisager un pacte successoral pour les situations complexes.",
            category="juridique",
            priority="basse",
        ),
        LifeEventChecklistItem(
            label="Evaluer les donations de son vivant et leur rapport a la succession.",
            category="fiscal",
            priority="basse",
        ),
    ]

    return LifeEventChecklistResponse(
        items=items,
        disclaimer=(
            "Cette checklist est fournie a titre informatif et educatif. "
            "Elle ne constitue pas un conseil juridique ou fiscal. "
            "Consultez un notaire ou un avocat specialise en droit successoral."
        ),
    )
