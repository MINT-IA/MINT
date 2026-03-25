"""
Pillar 3a Deep Dive endpoints — Gap G1: "3a Deep".

POST /api/v1/3a-deep/staggered-withdrawal   — Multi-account staggered withdrawal
POST /api/v1/3a-deep/real-return             — Real return with tax savings
POST /api/v1/3a-deep/compare-providers       — Fintech vs bank vs insurance

Sprint S16 — Gap G1: 3a Deep.
All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter
from app.schemas.pillar_3a_deep import (
    StaggeredWithdrawalRequest,
    StaggeredWithdrawalResponse,
    YearlyWithdrawalEntryResponse,
    RealReturnRequest,
    RealReturnResponse,
    ProviderCompareRequest,
    ProviderCompareResponse,
    ProviderProjectionResponse,
)
from app.services.pillar_3a_deep.multi_account_service import MultiAccountService
from app.services.pillar_3a_deep.real_return_service import RealReturnService
from app.services.pillar_3a_deep.provider_comparator_service import ProviderComparatorService


router = APIRouter()

# Shared service instances
_multi_account_service = MultiAccountService()
_real_return_service = RealReturnService()
_provider_comparator_service = ProviderComparatorService()


# ---------------------------------------------------------------------------
# Staggered Withdrawal
# ---------------------------------------------------------------------------

@router.post("/staggered-withdrawal", response_model=StaggeredWithdrawalResponse)
@limiter.limit("30/minute")
def simulate_staggered_withdrawal(
    request: Request,
    body: StaggeredWithdrawalRequest,
) -> StaggeredWithdrawalResponse:
    """Simulate staggered vs bloc 3a withdrawal for tax optimization.

    Compares withdrawing all 3a capital in one year vs splitting across
    multiple accounts withdrawn over N years. Staggering typically saves
    significant taxes due to progressive capital withdrawal taxation.

    Sources: OPP3 art. 1, 3; LIFD art. 33 al. 1 let. e, art. 38.
    """
    result = _multi_account_service.simulate_staggered_withdrawal(
        avoir_total=body.avoirTotal,
        nb_comptes=body.nbComptes,
        canton=body.canton,
        revenu_imposable=body.revenuImposable,
        age_retrait_debut=body.ageRetraitDebut,
        age_retrait_fin=body.ageRetraitFin,
    )

    return StaggeredWithdrawalResponse(
        blocTax=result.bloc_tax,
        blocTauxEffectif=result.bloc_taux_effectif,
        staggeredTax=result.staggered_tax,
        staggeredTauxEffectif=result.staggered_taux_effectif,
        economy=result.economy,
        economyPct=result.economy_pct,
        optimalAccounts=result.optimal_accounts,
        yearlyPlan=[
            YearlyWithdrawalEntryResponse(
                annee=entry.annee,
                age=entry.age,
                montantRetrait=entry.montant_retrait,
                tauxImposition=entry.taux_imposition,
                impot=entry.impot,
                netRecu=entry.net_recu,
            )
            for entry in result.yearly_plan
        ],
        avoirTotal=result.avoir_total,
        nbComptes=result.nb_comptes,
        canton=result.canton,
        chiffreChoc=result.chiffre_choc,
        alerts=result.alerts,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Real Return
# ---------------------------------------------------------------------------

@router.post("/real-return", response_model=RealReturnResponse)
@limiter.limit("30/minute")
def calculate_real_return(
    request: Request,
    body: RealReturnRequest,
) -> RealReturnResponse:
    """Calculate the real return of a 3a investment including tax savings.

    Accounts for gross return, management fees, inflation, and the annual
    tax deduction (versement x taux_marginal). Compares with a regular
    savings account.

    Sources: LIFD art. 33 al. 1 let. e; OPP3 art. 1.
    """
    result = _real_return_service.calculate_real_return(
        versement_annuel=body.versementAnnuel,
        taux_marginal=body.tauxMarginal,
        rendement_brut=body.rendementBrut,
        frais_gestion=body.fraisGestion,
        duree_annees=body.dureeAnnees,
        inflation=body.inflation,
    )

    return RealReturnResponse(
        versementAnnuel=result.versement_annuel,
        totalVerse=result.total_verse,
        capitalFinal3a=result.capital_final_3a,
        rendementNetAnnuel=result.rendement_net_annuel,
        totalEconomiesFiscales=result.total_economies_fiscales,
        rendementReelAnnualise=result.rendement_reel_annualise,
        rendementBrut=result.rendement_brut,
        fraisGestion=result.frais_gestion,
        inflation=result.inflation,
        capitalFinalEpargne=result.capital_final_epargne,
        rendementEpargne=result.rendement_epargne,
        avantage3aVsEpargne=result.avantage_3a_vs_epargne,
        dureeAnnees=result.duree_annees,
        tauxMarginal=result.taux_marginal,
        chiffreChoc=result.chiffre_choc,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Provider Comparator
# ---------------------------------------------------------------------------

@router.post("/compare-providers", response_model=ProviderCompareResponse)
@limiter.limit("30/minute")
def compare_providers(
    request: Request,
    body: ProviderCompareRequest,
) -> ProviderCompareResponse:
    """Compare 3a providers (fintech, bank, insurance).

    Shows projected capital for each provider type based on publicly
    available fee and return data. Does NOT recommend a specific provider.

    Sources: OPP3; LIFD art. 33 al. 1 let. e; public fee schedules.
    """
    result = _provider_comparator_service.compare_providers(
        age=body.age,
        versement_annuel=body.versementAnnuel,
        duree=body.duree,
        profil_risque=body.profilRisque,
    )

    return ProviderCompareResponse(
        projections=[
            ProviderProjectionResponse(
                nom=p.nom,
                typeProvider=p.type_provider,
                rendementBrut=p.rendement_brut,
                fraisGestion=p.frais_gestion,
                rendementNet=p.rendement_net,
                capitalFinal=p.capital_final,
                totalVerse=p.total_verse,
                gainNet=p.gain_net,
                engagementAnnees=p.engagement_annees,
                note=p.note,
                warning=p.warning,
            )
            for p in result.projections
        ],
        meilleurCapital=result.meilleur_capital,
        pireCapital=result.pire_capital,
        differenceMax=result.difference_max,
        age=result.age,
        versementAnnuel=result.versement_annuel,
        duree=result.duree,
        profilRisque=result.profil_risque,
        chiffreChoc=result.chiffre_choc,
        baseLegale=result.base_legale,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )
