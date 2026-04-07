"""
Mortgage & Real Estate endpoints — Sprint S17.

POST /api/v1/mortgage/affordability     — Affordability check (Tragbarkeitsrechnung)
POST /api/v1/mortgage/saron-vs-fixed    — SARON vs fixed rate comparison
POST /api/v1/mortgage/imputed-rental    — Imputed rental value (Eigenmietwert)
POST /api/v1/mortgage/amortization      — Direct vs indirect amortization
POST /api/v1/mortgage/epl-combined      — Combined EPL (3a + LPP) for equity

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter
from app.schemas.mortgage import (
    MortgageAffordabilityRequest,
    MortgageAffordabilityResponse,
    PremierEclairageResponse,
    DecompositionChargesResponse,
    SaronVsFixedRequest,
    SaronVsFixedResponse,
    GrapheEntryResponse,
    ScenarioResultResponse,
    ImputedRentalRequest,
    ImputedRentalResponse,
    AmortizationComparisonRequest,
    AmortizationComparisonResponse,
    AmortDirectResponse,
    AmortIndirectResponse,
    AmortGrapheEntryResponse,
    EplCombinedRequest,
    EplCombinedResponse,
    DetailFondsPropresMixResponse,
)
from app.services.mortgage.affordability_service import AffordabilityService
from app.services.mortgage.saron_vs_fixed_service import SaronVsFixedService
from app.services.mortgage.imputed_rental_service import ImputedRentalService
from app.services.mortgage.amortization_service import AmortizationService
from app.services.mortgage.epl_combined_service import EplCombinedService


router = APIRouter()

# Shared service instances
_affordability_service = AffordabilityService()
_saron_vs_fixed_service = SaronVsFixedService()
_imputed_rental_service = ImputedRentalService()
_amortization_service = AmortizationService()
_epl_combined_service = EplCombinedService()


# ---------------------------------------------------------------------------
# Affordability
# ---------------------------------------------------------------------------

@router.post("/affordability", response_model=MortgageAffordabilityResponse)
@limiter.limit("30/minute")
def calculate_affordability(
    request: Request,
    body: MortgageAffordabilityRequest,
) -> MortgageAffordabilityResponse:
    """Calculate mortgage affordability (Tragbarkeitsrechnung).

    Checks whether the household can afford a given property based on
    Swiss lending rules: 20% equity, 33% income ratio, 5% theoretical rate.

    Sources: Circulaire FINMA 2017/5; directives ASB.
    """
    result = _affordability_service.calculate_affordability(
        revenu_brut_annuel=body.revenuBrutAnnuel,
        epargne_disponible=body.epargneDisponible,
        avoir_3a=body.avoir3a,
        avoir_lpp=body.avoirLpp,
        prix_achat=body.prixAchat,
        canton=body.canton,
    )

    return MortgageAffordabilityResponse(
        prixMaxAccessible=result.prix_max_accessible,
        fondsPropresTotalNet=result.fonds_propres_total,
        fondsPropresSuffisants=result.fonds_propres_suffisants,
        detailFondsPropres=result.detail_fonds_propres,
        chargesMensuellesTheoriques=result.charges_mensuelles_theoriques,
        ratioCharges=result.ratio_charges,
        capaciteOk=result.capacite_ok,
        decompositionCharges=DecompositionChargesResponse(
            interets=result.decomposition_charges.interets,
            amortissement=result.decomposition_charges.amortissement,
            fraisAccessoires=result.decomposition_charges.frais_accessoires,
        ),
        montantHypothecaire=result.montant_hypothecaire,
        prixAchat=result.prix_achat,
        revenuBrutAnnuel=result.revenu_brut_annuel,
        canton=result.canton,
        premierEclairage=PremierEclairageResponse(
            montant=result.premier_eclairage.montant,
            texte=result.premier_eclairage.texte,
        ),
        checklist=result.checklist,
        alertes=result.alertes,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# SARON vs Fixed
# ---------------------------------------------------------------------------

@router.post("/saron-vs-fixed", response_model=SaronVsFixedResponse)
@limiter.limit("30/minute")
def compare_saron_vs_fixed(
    request: Request,
    body: SaronVsFixedRequest,
) -> SaronVsFixedResponse:
    """Compare SARON vs fixed-rate mortgage costs.

    Simulates total interest cost for a fixed-rate mortgage and three
    SARON scenarios (stable, rising, falling) over the chosen duration.

    Sources: Conventions bancaires suisses; SIX Swiss Exchange (SARON).
    """
    result = _saron_vs_fixed_service.compare(
        montant_hypothecaire=body.montantHypothecaire,
        duree_ans=body.dureeAns,
        taux_saron_actuel=body.tauxSaronActuel,
        marge_banque=body.margeBanque,
        taux_fixe=body.tauxFixe,
    )

    return SaronVsFixedResponse(
        tauxFixe=result.taux_fixe,
        coutTotalFixe=result.cout_total_fixe,
        mensualiteFixe=result.mensualite_fixe,
        scenarios=[
            ScenarioResultResponse(
                nom=s.nom,
                label=s.label,
                coutTotalInterets=s.cout_total_interets,
                mensualiteMoyenne=s.mensualite_moyenne,
                mensualiteMin=s.mensualite_min,
                mensualiteMax=s.mensualite_max,
                differenceVsFixe=s.difference_vs_fixe,
                grapheData=[
                    GrapheEntryResponse(
                        annee=g.annee,
                        mensualiteFixe=g.mensualite_fixe,
                        mensualiteSaron=g.mensualite_saron,
                    )
                    for g in s.graphe_data
                ],
            )
            for s in result.scenarios
        ],
        meilleurScenario=result.meilleur_scenario,
        economieMax=result.economie_max,
        montantHypothecaire=result.montant_hypothecaire,
        dureeAns=result.duree_ans,
        tauxSaronActuel=result.taux_saron_actuel,
        margeBanque=result.marge_banque,
        premierEclairage=PremierEclairageResponse(
            montant=result.premier_eclairage.montant,
            texte=result.premier_eclairage.texte,
        ),
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Imputed Rental Value
# ---------------------------------------------------------------------------

@router.post("/imputed-rental", response_model=ImputedRentalResponse)
@limiter.limit("30/minute")
def calculate_imputed_rental(
    request: Request,
    body: ImputedRentalRequest,
) -> ImputedRentalResponse:
    """Calculate imputed rental value (Eigenmietwert) and tax impact.

    Swiss homeowners must declare the imputed rental value as income,
    but can deduct mortgage interest, maintenance, and insurance.

    Sources: LIFD art. 21 al. 1 let. b; LIFD art. 32; LIFD art. 33.
    """
    result = _imputed_rental_service.calculate(
        valeur_venale=body.valeurVenale,
        canton=body.canton,
        interets_hypothecaires_annuels=body.interetsHypothecairesAnnuels,
        frais_entretien_annuels=body.fraisEntretienAnnuels,
        prime_assurance_batiment=body.primeAssuranceBatiment,
        age_bien_ans=body.ageBienAns,
        taux_marginal_imposition=body.tauxMarginalImposition,
    )

    return ImputedRentalResponse(
        valeurLocative=result.valeur_locative,
        tauxValeurLocative=result.taux_valeur_locative,
        deductionInterets=result.deduction_interets,
        deductionEntretien=result.deduction_entretien,
        deductionAssurance=result.deduction_assurance,
        deductionsTotal=result.deductions_total,
        impactRevenuImposable=result.impact_revenu_imposable,
        impactFiscalNet=result.impact_fiscal_net,
        estAvantageFiscal=result.est_avantage_fiscal,
        forfaitEntretienApplicable=result.forfait_entretien_applicable,
        forfaitEntretienMontant=result.forfait_entretien_montant,
        recommandationForfaitVsReel=result.recommandation_forfait_vs_reel,
        valeurVenale=result.valeur_venale,
        canton=result.canton,
        ageBienAns=result.age_bien_ans,
        tauxMarginalImposition=result.taux_marginal_imposition,
        premierEclairage=PremierEclairageResponse(
            montant=result.premier_eclairage.montant,
            texte=result.premier_eclairage.texte,
        ),
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# Amortization Comparison
# ---------------------------------------------------------------------------

@router.post("/amortization", response_model=AmortizationComparisonResponse)
@limiter.limit("30/minute")
def compare_amortization(
    request: Request,
    body: AmortizationComparisonRequest,
) -> AmortizationComparisonResponse:
    """Compare direct vs indirect mortgage amortization.

    Direct: reduce debt -> lower interest -> lower deductions.
    Indirect: contribute to pledged 3a -> constant debt + 3a growth + max deductions.

    Sources: OPP3 art. 1; LIFD art. 33; pratique bancaire suisse.
    """
    result = _amortization_service.compare(
        montant_hypothecaire=body.montantHypothecaire,
        taux_interet=body.tauxInteret,
        duree_ans=body.dureeAns,
        versement_annuel_amortissement=body.versementAnnuelAmortissement,
        taux_marginal_imposition=body.tauxMarginalImposition,
        rendement_3a=body.rendement3a,
        canton=body.canton,
    )

    return AmortizationComparisonResponse(
        direct=AmortDirectResponse(
            detteFinale=result.direct.dette_finale,
            interetsPayesTotal=result.direct.interets_payes_total,
            deductionFiscaleCumulee=result.direct.deduction_fiscale_cumulee,
            coutNetTotal=result.direct.cout_net_total,
        ),
        indirect=AmortIndirectResponse(
            detteFinale=result.indirect.dette_finale,
            interetsPayesTotal=result.indirect.interets_payes_total,
            deductionFiscaleCumulee=result.indirect.deduction_fiscale_cumulee,
            capital3aCumule=result.indirect.capital_3a_cumule,
            coutNetTotal=result.indirect.cout_net_total,
        ),
        differenceNette=result.difference_nette,
        methodeAvantageuse=result.methode_avantageuse,
        grapheData=[
            AmortGrapheEntryResponse(
                annee=g.annee,
                detteDirect=g.dette_direct,
                detteIndirect=g.dette_indirect,
                capital3a=g.capital_3a,
                coutCumuleDirect=g.cout_cumule_direct,
                coutCumuleIndirect=g.cout_cumule_indirect,
            )
            for g in result.graphe_data
        ],
        montantHypothecaire=result.montant_hypothecaire,
        tauxInteret=result.taux_interet,
        dureeAns=result.duree_ans,
        versementAnnuel=result.versement_annuel,
        tauxMarginalImposition=result.taux_marginal_imposition,
        rendement3a=result.rendement_3a,
        canton=result.canton,
        premierEclairage=PremierEclairageResponse(
            montant=result.premier_eclairage.montant,
            texte=result.premier_eclairage.texte,
        ),
        sources=result.sources,
        disclaimer=result.disclaimer,
    )


# ---------------------------------------------------------------------------
# EPL Combined
# ---------------------------------------------------------------------------

@router.post("/epl-combined", response_model=EplCombinedResponse)
@limiter.limit("30/minute")
def calculate_epl_combined(
    request: Request,
    body: EplCombinedRequest,
) -> EplCombinedResponse:
    """Calculate combined EPL equity (3a + LPP) for housing purchase.

    Combines cash, 3a withdrawal, and LPP EPL to calculate total
    available equity. Recommends optimal sourcing order.

    Sources: OPP3 art. 1; LPP art. 30a-30g; LPP art. 79b al. 3.
    """
    result = _epl_combined_service.calculate(
        avoir_3a=body.avoir3a,
        avoir_lpp_total=body.avoirLppTotal,
        avoir_obligatoire=body.avoirObligatoire,
        avoir_surobligatoire=body.avoirSurobligatoire,
        age=body.age,
        canton=body.canton,
        epargne_cash=body.epargneCash,
        prix_cible=body.prixCible,
        a_rachete_recemment=body.aRacheteRecemment,
        annees_depuis_dernier_rachat=body.anneesDernierRachat,
        avoir_lpp_a_50_ans=body.avoirLppA50Ans,
    )

    return EplCombinedResponse(
        totalFondsPropres=result.total_fonds_propres,
        detail=DetailFondsPropresMixResponse(
            cash=result.detail.cash,
            retrait3a=result.detail.retrait_3a,
            retraitLpp=result.detail.retrait_lpp,
            impot3a=result.detail.impot_3a,
            impotLpp=result.detail.impot_lpp,
            net3a=result.detail.net_3a,
            netLpp=result.detail.net_lpp,
            totalBrut=result.detail.total_brut,
            totalNet=result.detail.total_net,
        ),
        prixCible=result.prix_cible,
        pourcentagePrixCouvert=result.pourcentage_prix_couvert,
        mixOptimal=result.mix_optimal,
        premierEclairage=PremierEclairageResponse(
            montant=result.premier_eclairage.montant,
            texte=result.premier_eclairage.texte,
        ),
        alertes=result.alertes,
        sources=result.sources,
        disclaimer=result.disclaimer,
    )
