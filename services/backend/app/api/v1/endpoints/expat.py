"""
Expatriation + Frontaliers endpoints — Sprint S23.

POST /api/v1/expat/frontalier/source-tax      — Impot a la source frontalier
POST /api/v1/expat/frontalier/quasi-resident   — Verification quasi-resident
POST /api/v1/expat/frontalier/90-day-rule      — Simulation regle 90 jours
POST /api/v1/expat/frontalier/social-charges   — Comparaison charges sociales
POST /api/v1/expat/frontalier/lamal-option     — Comparaison LAMal vs residence
POST /api/v1/expat/forfait-fiscal              — Simulation forfait fiscal
POST /api/v1/expat/double-taxation             — Analyse double imposition
POST /api/v1/expat/avs-gap                     — Estimation lacunes AVS
POST /api/v1/expat/departure-plan              — Planification de depart
POST /api/v1/expat/tax-comparison              — Comparaison fiscale internationale

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter

from app.schemas.expat import (
    SourceTaxRequest,
    SourceTaxResponse,
    QuasiResidentRequest,
    QuasiResidentResponse,
    NinetyDayRuleRequest,
    NinetyDayRuleResponse,
    SocialChargesRequest,
    SocialChargesResponse,
    LamalOptionRequest,
    LamalOptionResponse,
    ForfaitFiscalRequest,
    ForfaitFiscalResponse,
    DoubleTaxationRequest,
    DoubleTaxationResponse,
    AVSGapRequest,
    AVSGapResponse,
    DeparturePlanRequest,
    DeparturePlanResponse,
    ChecklistItem,
    TaxComparisonRequest,
    TaxComparisonResponse,
)
from app.services.expat.frontalier_service import FrontalierService
from app.services.expat.frontalier_service import DISCLAIMER as FRONTALIER_DISCLAIMER
from app.services.expat.expat_service import ExpatService
from app.services.expat.expat_service import DISCLAIMER as EXPAT_DISCLAIMER


router = APIRouter()


# ---------------------------------------------------------------------------
# Frontalier — Impot a la source
# ---------------------------------------------------------------------------

@router.post("/frontalier/source-tax", response_model=SourceTaxResponse)
@limiter.limit("30/minute")
def calculate_source_tax(request: Request, body: SourceTaxRequest) -> SourceTaxResponse:
    """Calcule l'impot a la source pour un travailleur frontalier.

    Couvre les regimes speciaux GE (quasi-resident) et TI (accord Italie).

    Sources: LIFD art. 83-85, accords bilateraux.
    """
    service = FrontalierService()
    result = service.calculate_source_tax(
        salary=body.salary,
        canton=body.canton,
        marital_status=body.marital_status.value,
        children=body.children,
        church_tax=body.church_tax,
    )
    return SourceTaxResponse(
        salaire_brut=result.salaire_brut,
        canton=result.canton,
        impot_source=result.impot_source,
        taux_effectif=result.taux_effectif,
        impot_ordinaire_estime=result.impot_ordinaire_estime,
        taux_ordinaire_estime=result.taux_ordinaire_estime,
        difference=result.difference,
        regime_special=result.regime_special,
        recommandation=result.recommandation,
        disclaimer=FRONTALIER_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Frontalier — Quasi-resident
# ---------------------------------------------------------------------------

@router.post("/frontalier/quasi-resident", response_model=QuasiResidentResponse)
@limiter.limit("30/minute")
def check_quasi_resident(request: Request, body: QuasiResidentRequest) -> QuasiResidentResponse:
    """Verifie l'eligibilite au statut quasi-resident.

    Si >=90% du revenu mondial est gagne en CH, acces a l'imposition ordinaire.
    Principalement pertinent pour Geneve (LIPP-GE art. 6).

    Sources: LIFD art. 99a, LIPP-GE art. 6.
    """
    service = FrontalierService()
    result = service.check_quasi_resident(
        ch_income=body.ch_income,
        worldwide_income=body.worldwide_income,
        canton=body.canton,
    )
    return QuasiResidentResponse(
        eligible=result.eligible,
        revenu_ch=result.revenu_ch,
        revenu_mondial=result.revenu_mondial,
        ratio_ch=result.ratio_ch,
        seuil_requis=result.seuil_requis,
        economie_potentielle=result.economie_potentielle,
        recommandation=result.recommandation,
        disclaimer=FRONTALIER_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Frontalier — Regle des 90 jours
# ---------------------------------------------------------------------------

@router.post("/frontalier/90-day-rule", response_model=NinetyDayRuleResponse)
@limiter.limit("30/minute")
def simulate_90_day_rule(request: Request, body: NinetyDayRuleRequest) -> NinetyDayRuleResponse:
    """Simule la regle des 90 jours pour le teletravail frontalier.

    Plus de 90 jours de teletravail a l'etranger => imposition bascule.

    Sources: Convention OCDE art. 15, accords bilateraux CH-UE.
    """
    service = FrontalierService()
    result = service.simulate_90_day_rule(
        home_office_days=body.home_office_days,
        commute_days=body.commute_days,
    )
    return NinetyDayRuleResponse(
        jours_teletravail=result.jours_teletravail,
        jours_deplacement_ch=result.jours_deplacement_ch,
        depasse_seuil=result.depasse_seuil,
        pays_imposition=result.pays_imposition,
        risque=result.risque,
        recommandation=result.recommandation,
        disclaimer=FRONTALIER_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Frontalier — Charges sociales
# ---------------------------------------------------------------------------

@router.post("/frontalier/social-charges", response_model=SocialChargesResponse)
@limiter.limit("30/minute")
def compare_social_charges(request: Request, body: SocialChargesRequest) -> SocialChargesResponse:
    """Compare les charges sociales CH vs pays de residence.

    Les frontaliers cotisent toujours en CH (Reglement CE 883/2004).

    Sources: LAVS art. 5, LACI art. 3, LPP art. 8.
    """
    service = FrontalierService()
    result = service.compare_social_charges(
        salary=body.salary,
        country_of_residence=body.country_of_residence.value,
    )
    return SocialChargesResponse(
        salaire_brut=result.salaire_brut,
        pays_residence=result.pays_residence,
        avs_ai_apg_employe=result.avs_ai_apg_employe,
        ac_employe=result.ac_employe,
        ac_solidarite=result.ac_solidarite,
        lpp_employe=result.lpp_employe,
        aanp_employe=result.aanp_employe,
        total_ch_employe=result.total_ch_employe,
        total_ch_employeur=result.total_ch_employeur,
        total_residence_employe=result.total_residence_employe,
        total_residence_employeur=result.total_residence_employeur,
        difference_employe=result.difference_employe,
        recommandation=result.recommandation,
        disclaimer=FRONTALIER_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Frontalier — Option LAMal
# ---------------------------------------------------------------------------

@router.post("/frontalier/lamal-option", response_model=LamalOptionResponse)
@limiter.limit("30/minute")
def estimate_lamal_option(request: Request, body: LamalOptionRequest) -> LamalOptionResponse:
    """Compare l'option LAMal vs assurance du pays de residence.

    Droit d'option pour les frontaliers (LAMal art. 3, OLCP art. 9).

    Sources: LAMal art. 3, 6, OLCP art. 9.
    """
    service = FrontalierService()
    result = service.estimate_lamal_option(
        age=body.age,
        canton=body.canton,
        family_size=body.family_size,
        residence_country=body.residence_country.value,
    )
    return LamalOptionResponse(
        canton=result.canton,
        pays_residence=result.pays_residence,
        prime_lamal_mensuelle=result.prime_lamal_mensuelle,
        prime_lamal_annuelle=result.prime_lamal_annuelle,
        prime_residence_mensuelle=result.prime_residence_mensuelle,
        prime_residence_annuelle=result.prime_residence_annuelle,
        economie_lamal=result.economie_lamal,
        recommandation=result.recommandation,
        disclaimer=FRONTALIER_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Expat — Forfait fiscal
# ---------------------------------------------------------------------------

@router.post("/forfait-fiscal", response_model=ForfaitFiscalResponse)
@limiter.limit("30/minute")
def simulate_forfait_fiscal(request: Request, body: ForfaitFiscalRequest) -> ForfaitFiscalResponse:
    """Simule le forfait fiscal (imposition d'apres la depense).

    Reserve aux non-Suisses sans activite lucrative en CH.
    Aboli dans certains cantons (ZH, SH, AR, AI, BS, BL).

    Sources: LIFD art. 14.
    """
    service = ExpatService()
    result = service.simulate_forfait_fiscal(
        canton=body.canton,
        living_expenses=body.living_expenses,
        actual_income=body.actual_income,
    )
    return ForfaitFiscalResponse(
        canton=result.canton,
        eligible=result.eligible,
        base_forfaitaire=result.base_forfaitaire,
        depenses_reelles=result.depenses_reelles,
        revenu_reel=result.revenu_reel,
        impot_forfait=result.impot_forfait,
        impot_ordinaire=result.impot_ordinaire,
        economie=result.economie,
        conditions=result.conditions,
        recommandation=result.recommandation,
        disclaimer=EXPAT_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Expat — Double imposition
# ---------------------------------------------------------------------------

@router.post("/double-taxation", response_model=DoubleTaxationResponse)
@limiter.limit("30/minute")
def check_double_taxation(request: Request, body: DoubleTaxationRequest) -> DoubleTaxationResponse:
    """Analyse la repartition de l'imposition selon la CDI applicable.

    Conventions de double imposition CH avec les pays partenaires.

    Sources: CDI bilaterales, convention modele OCDE.
    """
    service = ExpatService()
    income_types_values = [t.value for t in body.income_types] if body.income_types else None
    result = service.check_double_taxation(
        residence_country=body.residence_country.value,
        income_types=income_types_values,
    )
    return DoubleTaxationResponse(
        pays_residence=result.pays_residence,
        convention_existe=result.convention_existe,
        date_convention=result.date_convention,
        repartition=result.repartition,
        taux_dividendes_max=result.taux_dividendes_max,
        taux_interets_max=result.taux_interets_max,
        optimisations=result.optimisations,
        recommandation=result.recommandation,
        disclaimer=EXPAT_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Expat — Lacunes AVS
# ---------------------------------------------------------------------------

@router.post("/avs-gap", response_model=AVSGapResponse)
@limiter.limit("30/minute")
def estimate_avs_gap(request: Request, body: AVSGapRequest) -> AVSGapResponse:
    """Estime la reduction de rente AVS due aux annees a l'etranger.

    Chaque annee manquante reduit la rente proportionnellement.

    Sources: LAVS art. 29ter, 34.
    """
    service = ExpatService()
    result = service.estimate_avs_gap(
        years_abroad=body.years_abroad,
        years_in_ch=body.years_in_ch,
    )
    return AVSGapResponse(
        annees_cotisation_ch=result.annees_cotisation_ch,
        annees_a_letranger=result.annees_a_letranger,
        annees_totales=result.annees_totales,
        annees_manquantes=result.annees_manquantes,
        rente_estimee_mensuelle=result.rente_estimee_mensuelle,
        rente_max_mensuelle=result.rente_max_mensuelle,
        reduction_mensuelle=result.reduction_mensuelle,
        reduction_annuelle=result.reduction_annuelle,
        cotisation_volontaire_possible=result.cotisation_volontaire_possible,
        cotisation_min=result.cotisation_min,
        cotisation_max=result.cotisation_max,
        recommandation=result.recommandation,
        disclaimer=EXPAT_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Expat — Planification de depart
# ---------------------------------------------------------------------------

@router.post("/departure-plan", response_model=DeparturePlanResponse)
@limiter.limit("30/minute")
def plan_departure(request: Request, body: DeparturePlanRequest) -> DeparturePlanResponse:
    """Planifie le depart de Suisse avec les impacts financiers.

    Checklist complete, timing optimal, impot sur le capital de prevoyance.

    Sources: LIFD art. 38, 42, LFLP art. 2, OPP3 art. 3.
    """
    service = ExpatService()
    result = service.plan_departure(
        departure_date=body.departure_date,
        canton=body.canton,
        pillar_3a_balance=body.pillar_3a_balance,
        lpp_balance=body.lpp_balance,
    )
    checklist_items = [
        ChecklistItem(
            priorite=item["priorite"],
            action=item["action"],
            delai=item["delai"],
        )
        for item in result.checklist
    ]
    return DeparturePlanResponse(
        date_depart=result.date_depart,
        canton=result.canton,
        pillar_3a_balance=result.pillar_3a_balance,
        lpp_balance=result.lpp_balance,
        impot_capital_3a=result.impot_capital_3a,
        impot_capital_lpp=result.impot_capital_lpp,
        delai_retrait_3a=result.delai_retrait_3a,
        checklist=checklist_items,
        timing_optimal=result.timing_optimal,
        recommandation=result.recommandation,
        disclaimer=EXPAT_DISCLAIMER,
        sources=result.sources,
    )


# ---------------------------------------------------------------------------
# Expat — Comparaison fiscale internationale
# ---------------------------------------------------------------------------

@router.post("/tax-comparison", response_model=TaxComparisonResponse)
@limiter.limit("30/minute")
def compare_tax_burden(request: Request, body: TaxComparisonRequest) -> TaxComparisonResponse:
    """Compare la charge fiscale totale CH vs pays de destination.

    Inclut impots + charges sociales pour une vue globale.
    Note : la Suisse n'a PAS d'exit tax.

    Sources: LIFD, LAVS, LACI, legislations etrangeres.
    """
    service = ExpatService()
    result = service.compare_tax_burden(
        salary=body.salary,
        canton=body.canton,
        target_country=body.target_country.value,
    )
    return TaxComparisonResponse(
        salaire_brut=result.salaire_brut,
        canton=result.canton,
        pays_cible=result.pays_cible,
        impot_ch=result.impot_ch,
        charges_sociales_ch=result.charges_sociales_ch,
        total_ch=result.total_ch,
        net_ch=result.net_ch,
        impot_cible=result.impot_cible,
        charges_sociales_cible=result.charges_sociales_cible,
        total_cible=result.total_cible,
        net_cible=result.net_cible,
        difference_nette=result.difference_nette,
        exit_tax_note=result.exit_tax_note,
        recommandation=result.recommandation,
        disclaimer=EXPAT_DISCLAIMER,
        sources=result.sources,
    )
