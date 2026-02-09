"""
Debt Prevention endpoints — Gap G6: "Prevention dette".

POST /api/v1/debt/ratio              — Debt ratio assessment
POST /api/v1/debt/repayment-plan     — Repayment planning
GET  /api/v1/debt/resources/{canton}  — Professional help resources

Sprint S16 — Gap G6: Prevention dette.
All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter

from app.schemas.debt_prevention import (
    DebtRatioRequest,
    DebtRatioResponse,
    RepaymentPlanRequest,
    RepaymentPlanResponse,
    MonthlyEntryResponse,
    DebtPayoffEntryResponse,
    HelpResourceResponse,
    HelpResourcesResponse,
)
from app.services.debt_prevention.debt_ratio_service import DebtRatioService
from app.services.debt_prevention.repayment_service import RepaymentService
from app.services.debt_prevention.resources_service import ResourcesService


router = APIRouter()

# Shared service instances
_debt_ratio_service = DebtRatioService()
_repayment_service = RepaymentService()
_resources_service = ResourcesService()


# ---------------------------------------------------------------------------
# Debt Ratio
# ---------------------------------------------------------------------------

@router.post("/ratio", response_model=DebtRatioResponse)
def calculate_debt_ratio(
    request: DebtRatioRequest,
) -> DebtRatioResponse:
    """Calculate the debt-to-income ratio and assess risk level.

    Thresholds: < 15% green, 15-30% orange, > 30% red.
    Also calculates the minimum vital insaisissable (LP art. 93).

    Sources: LP art. 93; SchKG.
    """
    result = _debt_ratio_service.calculate_debt_ratio(
        revenus_mensuels=request.revenusMensuels,
        charges_dette_mensuelles=request.chargesDetteMensuelles,
        loyer=request.loyer,
        autres_charges_fixes=request.autresChargesFixes,
        situation_familiale=request.situationFamiliale,
        nb_enfants=request.nbEnfants,
    )

    return DebtRatioResponse(
        ratioEndettement=result.ratio_endettement,
        ratioPct=result.ratio_pct,
        niveauRisque=result.niveau_risque,
        revenusMensuels=result.revenus_mensuels,
        chargesDetteMensuelles=result.charges_dette_mensuelles,
        loyer=result.loyer,
        autresChargesFixes=result.autres_charges_fixes,
        totalChargesFixes=result.total_charges_fixes,
        disponibleMensuel=result.disponible_mensuel,
        minimumVital=result.minimum_vital,
        margeVsMinimumVital=result.marge_vs_minimum_vital,
        enDessousMinimumVital=result.en_dessous_minimum_vital,
        chiffreChoc=result.chiffre_choc,
        recommandations=result.recommandations,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Repayment Plan
# ---------------------------------------------------------------------------

@router.post("/repayment-plan", response_model=RepaymentPlanResponse)
def plan_repayment(
    request: RepaymentPlanRequest,
) -> RepaymentPlanResponse:
    """Plan debt repayment using avalanche or snowball strategy.

    Avalanche: highest rate first (mathematically optimal).
    Snowball (boule_de_neige): smallest balance first (psychologically motivating).

    Sources: LCD; LP art. 93.
    """
    dettes_dicts = [
        {
            "nom": d.nom,
            "montant": d.montant,
            "taux": d.taux,
            "mensualite_min": d.mensualiteMin,
        }
        for d in request.dettes
    ]

    result = _repayment_service.plan_repayment(
        dettes=dettes_dicts,
        budget_mensuel_remboursement=request.budgetMensuelRemboursement,
        strategie=request.strategie,
    )

    return RepaymentPlanResponse(
        strategie=result.strategie,
        dureeMois=result.duree_mois,
        totalInterets=result.total_interets,
        totalRembourse=result.total_rembourse,
        planMensuel=[
            MonthlyEntryResponse(
                mois=entry.mois,
                detteNom=entry.dette_nom,
                paiement=entry.paiement,
                dontInterets=entry.dont_interets,
                dontCapital=entry.dont_capital,
                soldeRestant=entry.solde_restant,
            )
            for entry in result.plan_mensuel
        ],
        payoffs=[
            DebtPayoffEntryResponse(
                nom=p.nom,
                moisLiberation=p.mois_liberation,
                totalInterets=p.total_interets,
                montantInitial=p.montant_initial,
            )
            for p in result.payoffs
        ],
        budgetMensuel=result.budget_mensuel,
        nbDettes=result.nb_dettes,
        chiffreChoc=result.chiffre_choc,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

@router.get("/resources/{canton}", response_model=HelpResourcesResponse)
def get_help_resources(
    canton: str,
    situation: str = "prevention",
) -> HelpResourcesResponse:
    """Get professional help resources for debt counseling.

    All resources are public, free, and confidential.
    Available for all 26 cantons.

    Sources: Dettes Conseils Suisse; Caritas; LP art. 93.
    """
    result = _resources_service.get_help_resources(
        canton=canton,
        situation=situation,
    )

    return HelpResourcesResponse(
        resources=[
            HelpResourceResponse(
                nom=r.nom,
                description=r.description,
                url=r.url,
                telephone=r.telephone,
                canton=r.canton,
                gratuit=r.gratuit,
                confidentiel=r.confidentiel,
                typeAide=r.type_aide,
            )
            for r in result.resources
        ],
        canton=result.canton,
        situation=result.situation,
        chiffreChoc=result.chiffre_choc,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )
