"""
Independants endpoints — Sprint S18: Module Independants complet.

POST /api/v1/independants/avs-cotisations      — AVS contribution calculator
POST /api/v1/independants/ijm-simulation       — IJM (income loss) simulator
POST /api/v1/independants/3a-independant       — Enhanced 3a calculator
POST /api/v1/independants/dividende-vs-salaire — Dividend/salary optimizer
POST /api/v1/independants/lpp-volontaire       — Voluntary LPP simulator

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter
from app.schemas.independants import (
    AvsCotisationsRequest,
    AvsCotisationsResponse,
    IjmRequest,
    IjmResponse,
    Pillar3aIndepRequest,
    Pillar3aIndepResponse,
    DividendeVsSalaireRequest,
    DividendeVsSalaireResponse,
    GrapheDataPointResponse,
    LppVolontaireRequest,
    LppVolontaireResponse,
)
from app.services.independants.avs_cotisations_service import calculer_cotisation_avs
from app.services.independants.ijm_service import simuler_ijm
from app.services.independants.pillar_3a_indep_service import calculer_3a_independant
from app.services.independants.dividende_vs_salaire_service import simuler_dividende_vs_salaire
from app.services.independants.lpp_volontaire_service import simuler_lpp_volontaire


router = APIRouter()


# ---------------------------------------------------------------------------
# AVS Cotisations
# ---------------------------------------------------------------------------

@router.post("/avs-cotisations", response_model=AvsCotisationsResponse)
@limiter.limit("30/minute")
def compute_avs_cotisations(
    request: Request,
    body: AvsCotisationsRequest,
) -> AvsCotisationsResponse:
    """Calculate AVS/AI/APG contributions for a self-employed worker.

    Uses the progressive rate scale (bareme degressif) from RAVS art. 21.
    Compares with what an employee would pay on the same income.

    Sources: LAVS art. 8-9, RAVS art. 21-23.
    """
    result = calculer_cotisation_avs(
        revenu_net_activite=body.revenu_net_activite,
    )

    return AvsCotisationsResponse(
        cotisation_avs_ai_apg=result.cotisation_avs_ai_apg,
        taux_effectif=result.taux_effectif,
        comparaison_salarie=result.comparaison_salarie,
        difference_vs_salarie=result.difference_vs_salarie,
        premier_eclairage=result.premier_eclairage,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# IJM Simulation
# ---------------------------------------------------------------------------

@router.post("/ijm-simulation", response_model=IjmResponse)
@limiter.limit("30/minute")
def simulate_ijm(
    request: Request,
    body: IjmRequest,
) -> IjmResponse:
    """Simulate IJM (income loss insurance) for a self-employed worker.

    Estimates daily allowance, monthly/annual premium, and income lost
    during the waiting period without coverage.

    Sources: LAMal art. 67-77, CO art. 324a, LCA.
    """
    result = simuler_ijm(
        revenu_mensuel=body.revenu_mensuel,
        age=body.age,
        delai_carence=body.delai_carence,
    )

    return IjmResponse(
        indemnite_journaliere=result.indemnite_journaliere,
        prime_mensuelle=result.prime_mensuelle,
        prime_annuelle=result.prime_annuelle,
        cout_sans_couverture=result.cout_sans_couverture,
        premier_eclairage=result.premier_eclairage,
        alertes=result.alertes,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# 3a Independant
# ---------------------------------------------------------------------------

@router.post("/3a-independant", response_model=Pillar3aIndepResponse)
@limiter.limit("30/minute")
def compute_3a_independant(
    request: Request,
    body: Pillar3aIndepRequest,
) -> Pillar3aIndepResponse:
    """Calculate enhanced 3a limit and tax savings for a self-employed worker.

    Self-employed WITHOUT LPP benefit from the "grand 3a": 20% of net income,
    max 36'288 CHF/year.

    Sources: OPP3 art. 7, LPP art. 4, LIFD art. 33 al. 1 let. e.
    """
    result = calculer_3a_independant(
        revenu_net=body.revenu_net,
        affilie_lpp=body.affilie_lpp,
        taux_marginal_imposition=body.taux_marginal_imposition,
        canton=body.canton,
    )

    return Pillar3aIndepResponse(
        plafond_applicable=result.plafond_applicable,
        economie_fiscale=result.economie_fiscale,
        comparaison_salarie=result.comparaison_salarie,
        avantage_independant=result.avantage_independant,
        premier_eclairage=result.premier_eclairage,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Dividende vs Salaire
# ---------------------------------------------------------------------------

@router.post("/dividende-vs-salaire", response_model=DividendeVsSalaireResponse)
@limiter.limit("30/minute")
def simulate_dividende_vs_salaire(
    request: Request,
    body: DividendeVsSalaireRequest,
) -> DividendeVsSalaireResponse:
    """Simulate dividend vs salary optimization for SA/Sarl directors.

    Compares total fiscal and social charge across different salary/dividend
    splits. Warns about requalification risk.

    Sources: LIFD art. 20, LIFD art. 17-18, LAVS art. 14.
    """
    result = simuler_dividende_vs_salaire(
        benefice_disponible=body.benefice_disponible,
        part_salaire=body.part_salaire,
        taux_marginal=body.taux_marginal,
        canton=body.canton,
    )

    return DividendeVsSalaireResponse(
        charge_totale_salaire=result.charge_totale_salaire,
        charge_totale_dividende=result.charge_totale_dividende,
        charge_totale_tout_dividende=result.charge_totale_tout_dividende,
        split_optimal_indicatif=result.split_optimal_indicatif,
        economies=result.economies,
        alerte_requalification=result.alerte_requalification,
        graphe_data=[
            GrapheDataPointResponse(
                split_salaire=dp.split_salaire,
                charge_totale=dp.charge_totale,
            )
            for dp in result.graphe_data
        ],
        premier_eclairage=result.premier_eclairage,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# LPP Volontaire
# ---------------------------------------------------------------------------

@router.post("/lpp-volontaire", response_model=LppVolontaireResponse)
@limiter.limit("30/minute")
def simulate_lpp_volontaire(
    request: Request,
    body: LppVolontaireRequest,
) -> LppVolontaireResponse:
    """Simulate voluntary LPP affiliation for a self-employed worker.

    Calculates coordinated salary, annual contribution, tax savings,
    and shows the retirement capital gap without LPP.

    Sources: LPP art. 4, 44, 46, 16, 8. LIFD art. 33 al. 1 let. d.
    """
    result = simuler_lpp_volontaire(
        revenu_net=body.revenu_net,
        age=body.age,
        taux_marginal=body.taux_marginal,
    )

    return LppVolontaireResponse(
        salaire_coordonne=result.salaire_coordonne,
        cotisation_annuelle=result.cotisation_annuelle,
        economie_fiscale=result.economie_fiscale,
        comparaison_sans_lpp=result.comparaison_sans_lpp,
        taux_bonification=result.taux_bonification,
        premier_eclairage=result.premier_eclairage,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )
