"""
Segments sociologiques endpoints.

Sprint S12, Chantier 6:
- POST /api/v1/segments/gender-gap/simulate
- POST /api/v1/segments/frontalier/simulate
- POST /api/v1/segments/independant/simulate

All endpoints are stateless — no data storage.
"""

from fastapi import APIRouter

from app.schemas.segments import (
    GenderGapRequest,
    GenderGapResponse,
    RecommandationResponse,
    FrontalierRequest,
    FrontalierResponse,
    ChecklistItemResponse,
    IndependantRequest,
    IndependantResponse,
    LacuneCouvertureResponse,
    UrgenceResponse,
    IndependantChecklistItemResponse,
)
from app.services.gender_gap_service import GenderGapService, GenderGapInput
from app.services.frontalier_service import FrontalierService, FrontalierInput
from app.services.independant_service import IndependantService, IndependantInput

router = APIRouter()

_gender_gap_service = GenderGapService()
_frontalier_service = FrontalierService()
_independant_service = IndependantService()


# ---------------------------------------------------------------------------
# Gender Gap
# ---------------------------------------------------------------------------

@router.post("/gender-gap/simulate", response_model=GenderGapResponse)
def simulate_gender_gap(request: GenderGapRequest) -> GenderGapResponse:
    """Simulate LPP pension gap due to part-time work.

    Compares projected pension at current activity rate vs full-time.
    Stateless — no data storage.
    """
    input_data = GenderGapInput(
        taux_activite=request.tauxActivite,
        age=request.age,
        revenu_annuel=request.revenuAnnuel,
        salaire_coordonne=request.salaireCoordonne,
        avoir_lpp=request.avoirLpp,
        annees_cotisation=request.anneesCotisation,
        canton=request.canton,
    )

    result = _gender_gap_service.analyze(input_data)

    return GenderGapResponse(
        lacuneAnnuelleChf=result.lacune_annuelle_chf,
        lacuneCumuleeChf=result.lacune_cumulee_chf,
        renteEstimeePleinTemps=result.rente_estimee_plein_temps,
        renteEstimeeActuelle=result.rente_estimee_actuelle,
        impactCoordination=result.impact_coordination,
        recommandations=[
            RecommandationResponse(**r) for r in result.recommandations
        ],
        statistiques=result.statistiques,
        alerts=result.alerts,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Frontalier
# ---------------------------------------------------------------------------

@router.post("/frontalier/simulate", response_model=FrontalierResponse)
def simulate_frontalier(request: FrontalierRequest) -> FrontalierResponse:
    """Analyze cross-border worker situation by country of residence.

    Covers fiscal regime, 3a rights, LPP/AVS coordination.
    Stateless — no data storage.
    """
    input_data = FrontalierInput(
        pays_residence=request.paysResidence.value,
        permis=request.permis.value,
        canton_travail=request.cantonTravail,
        revenu_brut=request.revenuBrut,
        a_3a=request.a3a,
        a_lpp=request.aLpp,
        etat_civil=request.etatCivil.value,
        nombre_enfants=request.nombreEnfants,
        part_revenu_suisse=request.partRevenuSuisse,
    )

    result = _frontalier_service.analyze(input_data)

    return FrontalierResponse(
        regimeFiscal=result.regime_fiscal,
        droit3a=result.droit_3a,
        droit3aDetail=result.droit_3a_detail,
        regimeLpp=result.regime_lpp,
        regimeAvs=result.regime_avs,
        alertes=result.alertes,
        recommandations=[
            RecommandationResponse(**r) for r in result.recommandations
        ],
        checklist=[
            ChecklistItemResponse(**c) for c in result.checklist
        ],
        specificites=result.specificites,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Independant
# ---------------------------------------------------------------------------

@router.post("/independant/simulate", response_model=IndependantResponse)
def simulate_independant(request: IndependantRequest) -> IndependantResponse:
    """Analyze self-employed worker coverage and contributions.

    Covers AVS, 3a plafond, coverage gaps, protection costs.
    Stateless — no data storage.
    """
    input_data = IndependantInput(
        revenu_net=request.revenuNet,
        age=request.age,
        a_lpp_volontaire=request.aLppVolontaire,
        a_3a=request.a3a,
        a_ijm=request.aIjm,
        a_laa=request.aLaa,
        canton=request.canton,
    )

    result = _independant_service.analyze(input_data)

    return IndependantResponse(
        cotisationsAvs=result.cotisations_avs,
        plafond3aGrand=result.plafond_3a_grand,
        coutProtectionTotale=result.cout_protection_totale,
        lacunesCouverture=[
            LacuneCouvertureResponse(**lc) for lc in result.lacunes_couverture
        ],
        recommandations=[
            RecommandationResponse(**r) for r in result.recommandations
        ],
        urgences=[
            UrgenceResponse(
                id=u["id"],
                titre=u["titre"],
                description=u["description"],
                coutEstimeAnnuel=u.get("cout_estime_annuel"),
                source=u["source"],
                priorite=u["priorite"],
            )
            for u in result.urgences
        ],
        checklist=[
            IndependantChecklistItemResponse(
                item=c["item"],
                statut=c["statut"],
                source=c["source"],
                montantEstime=c.get("montant_estime"),
                plafond=c.get("plafond"),
            )
            for c in result.checklist
        ],
        disclaimer=result.disclaimer,
    )
