"""
Mortgage & Real Estate endpoints — Sprint S17.

POST /api/v1/mortgage/affordability     — Affordability check (Tragbarkeitsrechnung)
POST /api/v1/mortgage/saron-vs-fixed    — SARON vs fixed rate comparison
POST /api/v1/mortgage/imputed-rental    — Imputed rental value (Eigenmietwert)
POST /api/v1/mortgage/amortization      — Direct vs indirect amortization
POST /api/v1/mortgage/epl-combined      — Combined EPL (3a + LPP) for equity

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Depends, Request

from app.core.auth import require_current_user
from app.core.profile_resolver import (
    _required_profile_fields_missing,
    _resolve_defaults,
    emit_calc_invoke_metric,
    get_profile_filled,
    raise_incomplete_as_422,
)
from app.core.rate_limit import limiter
from app.models.user import User
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

_AFFORDABILITY_HINT_FR = (
    "Pour estimer ta capacité d'achat, j'ai besoin de ton canton, "
    "de ton revenu brut annuel et de ton épargne disponible. "
    "Tu peux me les partager ?"
)


@router.post("/affordability", response_model=MortgageAffordabilityResponse)
@limiter.limit("30/minute")
def calculate_affordability(
    request: Request,
    body: MortgageAffordabilityRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> MortgageAffordabilityResponse:
    """Calculate mortgage affordability (Tragbarkeitsrechnung).

    Checks whether the household can afford a given property based on
    Swiss lending rules: 20% equity, 33% income ratio, 5% theoretical rate.

    Grounded via D-CE-06 + D-CE-07 : canton, revenu_brut_annuel,
    epargne_disponible, avoir_3a, avoir_lpp are read from `_user.profile`
    when not supplied in the body. The 5% theoretical rate is a regulatory
    constant (FINMA art. 28 / HYPOTHEQUE_TAUX_THEORIQUE) and is NEVER
    user-overridable. Missing required profile fields trigger 422 with the
    D-CE-08 `CoachToolIncomplete` envelope when strict mode is enabled.

    Sources: Circulaire FINMA 2017/5; directives ASB.
    """
    resolved = _resolve_defaults(profile_data, body, MortgageAffordabilityRequest)
    missing = _required_profile_fields_missing(resolved, MortgageAffordabilityRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_AFFORDABILITY_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/mortgage/affordability",
        )
    emit_calc_invoke_metric(
        kind="affordability",
        resolved=resolved,
        schema_class=MortgageAffordabilityRequest,
    )

    result = _affordability_service.calculate_affordability(
        revenu_brut_annuel=float(resolved["revenuBrutAnnuel"]),
        epargne_disponible=float(resolved["epargneDisponible"]),
        avoir_3a=float(resolved["avoir3a"] or 0),
        avoir_lpp=float(resolved["avoirLpp"] or 0),
        prix_achat=float(resolved["prixAchat"] or 0),
        canton=str(resolved["canton"]),
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

_IMPUTED_RENTAL_HINT_FR = (
    "Pour calculer la valeur locative imposable, j'ai besoin de ton canton — "
    "les barèmes varient considérablement. Tu peux me le partager ?"
)


_AMORTIZATION_HINT_FR = (
    "Pour comparer amortissement direct et indirect, j'ai besoin de ton canton — "
    "l'avantage fiscal dépend du barème cantonal. Tu peux me le partager ?"
)


_EPL_COMBINED_HINT_FR = (
    "Pour calculer ton apport combiné 3a + LPP, j'ai besoin de ton canton — "
    "l'impôt sur le retrait varie selon le canton. Tu peux me le partager ?"
)


@router.post("/imputed-rental", response_model=ImputedRentalResponse)
@limiter.limit("30/minute")
def calculate_imputed_rental(
    request: Request,
    body: ImputedRentalRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> ImputedRentalResponse:
    """Calculate imputed rental value (Eigenmietwert) and tax impact.

    Swiss homeowners must declare the imputed rental value as income,
    but can deduct mortgage interest, maintenance, and insurance.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 9). Missing profile.canton
    triggers a 422 with the D-CE-08 `CoachToolIncomplete` envelope when
    strict mode is enabled.

    Sources: LIFD art. 21 al. 1 let. b; LIFD art. 32; LIFD art. 33.
    """
    resolved = _resolve_defaults(profile_data, body, ImputedRentalRequest)
    missing = _required_profile_fields_missing(resolved, ImputedRentalRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_IMPUTED_RENTAL_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/mortgage/imputed-rental",
        )
    emit_calc_invoke_metric(
        kind="imputed_rental",
        resolved=resolved,
        schema_class=ImputedRentalRequest,
    )

    result = _imputed_rental_service.calculate(
        valeur_venale=resolved["valeurVenale"],
        canton=str(resolved["canton"]),
        interets_hypothecaires_annuels=resolved["interetsHypothecairesAnnuels"],
        frais_entretien_annuels=resolved["fraisEntretienAnnuels"],
        prime_assurance_batiment=resolved["primeAssuranceBatiment"],
        age_bien_ans=resolved["ageBienAns"],
        taux_marginal_imposition=resolved["tauxMarginalImposition"],
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
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> AmortizationComparisonResponse:
    """Compare direct vs indirect mortgage amortization.

    Direct: reduce debt -> lower interest -> lower deductions.
    Indirect: contribute to pledged 3a -> constant debt + 3a growth + max deductions.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 10 — silent ZH default
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Sources: OPP3 art. 1; LIFD art. 33; pratique bancaire suisse.
    """
    resolved = _resolve_defaults(profile_data, body, AmortizationComparisonRequest)
    missing = _required_profile_fields_missing(resolved, AmortizationComparisonRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_AMORTIZATION_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/mortgage/amortization",
        )
    emit_calc_invoke_metric(
        kind="amortization",
        resolved=resolved,
        schema_class=AmortizationComparisonRequest,
    )

    result = _amortization_service.compare(
        montant_hypothecaire=resolved["montantHypothecaire"],
        taux_interet=resolved["tauxInteret"],
        duree_ans=resolved["dureeAns"],
        versement_annuel_amortissement=resolved["versementAnnuelAmortissement"],
        taux_marginal_imposition=resolved["tauxMarginalImposition"],
        rendement_3a=resolved["rendement3a"],
        canton=str(resolved["canton"]),
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
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> EplCombinedResponse:
    """Calculate combined EPL equity (3a + LPP) for housing purchase.

    Combines cash, 3a withdrawal, and LPP EPL to calculate total
    available equity. Recommends optimal sourcing order.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 11 — silent ZH default
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Sources: OPP3 art. 1; LPP art. 30a-30g; LPP art. 79b al. 3.
    """
    resolved = _resolve_defaults(profile_data, body, EplCombinedRequest)
    missing = _required_profile_fields_missing(resolved, EplCombinedRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_EPL_COMBINED_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/mortgage/epl-combined",
        )
    emit_calc_invoke_metric(
        kind="epl_combined",
        resolved=resolved,
        schema_class=EplCombinedRequest,
    )

    result = _epl_combined_service.calculate(
        avoir_3a=resolved["avoir3a"],
        avoir_lpp_total=resolved["avoirLppTotal"],
        avoir_obligatoire=resolved["avoirObligatoire"],
        avoir_surobligatoire=resolved["avoirSurobligatoire"],
        age=resolved["age"],
        canton=str(resolved["canton"]),
        epargne_cash=resolved["epargneCash"],
        prix_cible=resolved["prixCible"],
        a_rachete_recemment=resolved["aRacheteRecemment"],
        annees_depuis_dernier_rachat=resolved["anneesDernierRachat"],
        avoir_lpp_a_50_ans=resolved["avoirLppA50Ans"],
        is_married=bool(resolved["is_married"]),
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
