"""
Life Events endpoints: Divorce, Succession, Donation, Housing Sale.

POST /api/v1/life-events/divorce/simulate        — Divorce financial simulation
POST /api/v1/life-events/succession/simulate     — Succession simulation
POST /api/v1/life-events/donation/simulate       — Donation simulation
POST /api/v1/life-events/housing-sale/simulate   — Housing sale simulation
GET  /api/v1/life-events/divorce/checklist       — Divorce checklist template
GET  /api/v1/life-events/succession/checklist    — Succession checklist template

Sprint S10 + W15 (donation + housing sale wiring).
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
from app.schemas.life_events import (
    DivorceSimulationRequest,
    DivorceSimulationResponse,
    SuccessionSimulationRequest,
    SuccessionSimulationResponse,
    LifeEventChecklistItem,
    LifeEventChecklistResponse,
    DonationSimulationRequest,
    DonationSimulationResponse,
    HousingSaleSimulationRequest,
    HousingSaleSimulationResponse,
)
from app.services.divorce_simulator import DivorceSimulator, DivorceInput
from app.services.succession_simulator import SuccessionSimulator, SuccessionInput
from app.services.donation_service import DonationService, DonationInput
from app.services.housing_sale_service import HousingSaleService, HousingSaleInput


_SUCCESSION_SIMULATE_HINT_FR = (
    "Pour estimer les frais de succession, j'ai besoin de ton canton — "
    "les taux varient considérablement. Tu peux me le partager ?"
)


_DIVORCE_SIMULATE_HINT_FR = (
    "Pour simuler l'impact financier d'un divorce, j'ai besoin de ton "
    "canton — la fiscalité et le partage varient considérablement. "
    "Tu peux me le partager ?"
)


_DONATION_SIMULATE_HINT_FR = (
    "Pour simuler ta donation, j'ai besoin de ton canton — "
    "les taux d'imposition des donations varient considérablement entre "
    "cantons. Tu peux me le partager ?"
)


router = APIRouter()

_divorce_sim = DivorceSimulator()
_succession_sim = SuccessionSimulator()
_donation_svc = DonationService()
_housing_sale_svc = HousingSaleService()


# ---------------------------------------------------------------------------
# Divorce endpoints
# ---------------------------------------------------------------------------

@router.post("/divorce/simulate", response_model=DivorceSimulationResponse)
def simulate_divorce(
    request: DivorceSimulationRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> DivorceSimulationResponse:
    """Simulate financial impact of a divorce under Swiss law.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 25 — silent GE default
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    resolved = _resolve_defaults(profile_data, request, DivorceSimulationRequest)
    missing = _required_profile_fields_missing(resolved, DivorceSimulationRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_DIVORCE_SIMULATE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/life-events/divorce/simulate",
        )
    emit_calc_invoke_metric(
        kind="divorce_simulate",
        resolved=resolved,
        schema_class=DivorceSimulationRequest,
    )

    # Enum-preservation defensive extraction
    regime_value = resolved["regimeMatrimonial"]
    if hasattr(regime_value, "value"):
        regime_value = regime_value.value

    input_data = DivorceInput(
        duree_mariage_annees=resolved["dureeMarriageAnnees"],
        regime_matrimonial=regime_value,
        nombre_enfants=resolved["nombreEnfants"],
        revenu_annuel_conjoint_1=resolved["revenuAnnuelConjoint1"],
        revenu_annuel_conjoint_2=resolved["revenuAnnuelConjoint2"],
        lpp_conjoint_1_pendant_mariage=resolved["lppConjoint1PendantMariage"],
        lpp_conjoint_2_pendant_mariage=resolved["lppConjoint2PendantMariage"],
        avoirs_3a_conjoint_1=resolved["avoirs3aConjoint1"],
        avoirs_3a_conjoint_2=resolved["avoirs3aConjoint2"],
        fortune_commune=resolved["fortuneCommune"],
        dette_commune=resolved["detteCommune"],
        canton=str(resolved["canton"]),
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
    body: SuccessionSimulationRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> SuccessionSimulationResponse:
    """Simulate inheritance distribution under Swiss law (2023 revision).

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 26 sev-3 fix — legacy default
    "GE" silently leaked canton-specific tax rates for non-GE users). Missing
    profile.canton triggers a 422 with the D-CE-08 `CoachToolIncomplete`
    envelope when `PROFILE_GROUNDING_STRICT_MODE=true` ; otherwise a warning
    is logged and the legacy hardcoded-default branch resumes.

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    resolved = _resolve_defaults(profile_data, body, SuccessionSimulationRequest)
    missing = _required_profile_fields_missing(resolved, SuccessionSimulationRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_SUCCESSION_SIMULATE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/life-events/succession/simulate",
        )
    emit_calc_invoke_metric(
        kind="succession_simulate",
        resolved=resolved,
        schema_class=SuccessionSimulationRequest,
    )

    # Pydantic v2 alias_generator is NOT used on this schema (camelCase comes
    # from raw field names), so resolved keys are camelCase (e.g. `fortuneTotale`).
    # The enum `etatCivil` is still a SuccessionSimulationRequest field object
    # when sourced from body ; resolved preserves the value as-is.
    etat_civil_value = resolved["etatCivil"]
    if hasattr(etat_civil_value, "value"):
        etat_civil_value = etat_civil_value.value

    input_data = SuccessionInput(
        fortune_totale=resolved["fortuneTotale"],
        etat_civil=etat_civil_value,
        a_conjoint=resolved["aConjoint"],
        nombre_enfants=resolved["nombreEnfants"],
        a_parents_vivants=resolved["aParentsVivants"],
        a_fratrie=resolved["aFratrie"],
        a_concubin=resolved["aConcubin"],
        a_testament=resolved["aTestament"],
        quotite_disponible_testament=resolved["quotiteDisponibleTestament"],
        avoirs_3a=resolved["avoirs3a"],
        capital_deces_lpp=resolved["capitalDecesLpp"],
        canton=resolved["canton"],
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


# ---------------------------------------------------------------------------
# Donation endpoints
# ---------------------------------------------------------------------------

@router.post("/donation/simulate", response_model=DonationSimulationResponse)
@limiter.limit("10/minute")
def simulate_donation(
    request: Request,
    body: DonationSimulationRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> DonationSimulationResponse:
    """Simulate tax impact of a donation (CC art. 239-252).

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row — donation_service silent
    GE default closed). Missing profile.canton triggers a 422 with the
    D-CE-08 `CoachToolIncomplete` envelope when strict mode is enabled.

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    resolved = _resolve_defaults(profile_data, body, DonationSimulationRequest)
    missing = _required_profile_fields_missing(resolved, DonationSimulationRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_DONATION_SIMULATE_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/life-events/donation/simulate",
        )
    emit_calc_invoke_metric(
        kind="donation_simulate",
        resolved=resolved,
        schema_class=DonationSimulationRequest,
    )

    input_data = DonationInput(
        montant=resolved["montant"],
        donateur_age=resolved["donateurAge"],
        lien_parente=resolved["lienParente"],
        canton=str(resolved["canton"]),
        type_donation=resolved["typeDonation"],
        valeur_immobiliere=resolved["valeurImmobiliere"],
        avancement_hoirie=resolved["avancementHoirie"],
        nb_enfants=resolved["nbEnfants"],
        fortune_totale_donateur=resolved["fortuneTotaleDonateur"],
        regime_matrimonial=resolved["regimeMatrimonial"],
        has_spouse=resolved["hasSpouse"],
        has_parents=resolved["hasParents"],
    )

    result = _donation_svc.calculate(input_data)

    return DonationSimulationResponse(
        montantDonation=result.montant_donation,
        verdictFiscal=result.verdict_fiscal,
        reserveHereditaireTotale=result.reserve_hereditaire_totale,
        quotiteDisponible=result.quotite_disponible,
        donationDepasseQuotite=result.donation_depasse_quotite,
        montantDepassement=result.montant_depassement,
        impactSuccession=result.impact_succession,
        checklist=result.checklist,
        alerts=result.alerts,
        disclaimer=result.disclaimer,
        sources=result.sources,
        premierEclairage=result.premier_eclairage,
    )


# ---------------------------------------------------------------------------
# Housing Sale endpoints
# ---------------------------------------------------------------------------

@router.post("/housing-sale/simulate", response_model=HousingSaleSimulationResponse)
@limiter.limit("10/minute")
def simulate_housing_sale(
    request: Request,
    body: HousingSaleSimulationRequest,
    _user: User = Depends(require_current_user),
) -> HousingSaleSimulationResponse:
    """Simulate capital gains tax on property sale (LIFD art. 12).

    Stateless endpoint — no data storage. All computation is done
    on the fly from the provided inputs.
    """
    input_data = HousingSaleInput(
        prix_achat=body.prixAchat,
        prix_vente=body.prixVente,
        annee_achat=body.anneeAchat,
        annee_vente=body.anneeVente,
        investissements_valorisants=body.investissementsValorisants,
        frais_acquisition=body.fraisAcquisition,
        canton=body.canton,
        residence_principale=body.residencePrincipale,
        epl_lpp_utilise=body.eplLppUtilise,
        epl_3a_utilise=body.epl3aUtilise,
        hypotheque_restante=body.hypothequeRestante,
        projet_remploi=body.projetRemploi,
        prix_remploi=body.prixRemploi,
        annees_occupation=body.anneesOccupation,
    )

    result = _housing_sale_svc.calculate(input_data)

    return HousingSaleSimulationResponse(
        plusValueBrute=result.plus_value_brute,
        plusValueImposable=result.plus_value_imposable,
        dureeDetention=result.duree_detention,
        modeleGain=result.modele_gain,
        tauxImpositionPlusValue=result.taux_imposition_plus_value,
        impotPlusValue=result.impot_plus_value,
        remploiReport=result.remploi_report,
        impotEffectif=result.impot_effectif,
        remboursementEplLpp=result.remboursement_epl_lpp,
        remboursementEpl3a=result.remboursement_epl_3a,
        soldeHypotheque=result.solde_hypotheque,
        produitNet=result.produit_net,
        gainImmobilier=result.gain_immobilier,
        checklist=result.checklist,
        alerts=result.alerts,
        disclaimer=result.disclaimer,
        sources=result.sources,
        premierEclairage=result.premier_eclairage,
    )
