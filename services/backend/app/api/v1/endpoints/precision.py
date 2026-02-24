"""
Precision endpoints — Sprint S41: Guided Precision Entry.

GET  /api/v1/precision/help/{field_name} — aide contextuelle par champ
POST /api/v1/precision/validate          — validation croisee du profil
POST /api/v1/precision/smart-defaults    — estimations contextuelles
POST /api/v1/precision/prompts           — demandes de precision contextuelles

All endpoints are stateless (no data storage). Pure computation on the fly.

Sources:
    - LPP art. 7, 8, 15-16 (prevoyance professionnelle)
    - LAVS art. 29ter, 34 (duree cotisation, rente)
    - OPP3 art. 7 (plafond 3a)
    - LIFD art. 38 (imposition du capital)
"""

from fastapi import APIRouter, HTTPException

from app.schemas.precision import (
    FieldHelpResponse,
    CrossValidationRequest,
    CrossValidationResponse,
    CrossValidationAlertSchema,
    SmartDefaultRequest,
    SmartDefaultResponse,
    SmartDefaultSchema,
    PrecisionPromptRequest,
    PrecisionPromptResponse,
    PrecisionPromptSchema,
)
from app.services.precision import (
    get_field_help,
    cross_validate,
    compute_smart_defaults,
    get_precision_prompts,
)

router = APIRouter()

# ═══════════════════════════════════════════════════════════════════════════════
# Compliance constants
# ═══════════════════════════════════════════════════════════════════════════════

_DISCLAIMER = (
    "Cet outil est educatif et ne constitue pas un conseil financier, "
    "fiscal ou juridique personnalise. Les estimations sont indicatives. "
    "Consulte un·e specialiste pour ta situation personnelle (LSFin art. 3)."
)

_SOURCES = [
    "LPP art. 7 (seuil d'entree: 22'680 CHF)",
    "LPP art. 8 (deduction de coordination: 26'460 CHF)",
    "LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)",
    "LAVS art. 29ter (duree cotisation complete: 44 ans)",
    "LAVS art. 34 (rente maximale: 2'520 CHF/mois)",
    "OPP3 art. 7 (plafond 3a: 7'258 CHF / 36'288 CHF)",
    "LIFD art. 38 (imposition du capital de prevoyance)",
]


# ═══════════════════════════════════════════════════════════════════════════════
# GET /help/{field_name}
# ═══════════════════════════════════════════════════════════════════════════════


@router.get("/help/{field_name}", response_model=FieldHelpResponse)
def get_help(field_name: str) -> FieldHelpResponse:
    """Retourne l'aide contextuelle pour un champ financier.

    Fournit pour chaque champ: ou trouver le chiffre exact,
    sur quel document, le nom en allemand, et une estimation de repli.

    Args:
        field_name: Nom du champ (ex: lpp_total, salaire_brut, taux_marginal).

    Returns:
        FieldHelpResponse avec aide contextuelle complete.
    """
    try:
        help_data = get_field_help(field_name)
        return FieldHelpResponse(
            field_name=help_data.field_name,
            where_to_find=help_data.where_to_find,
            document_name=help_data.document_name,
            german_name=help_data.german_name,
            fallback_estimation=help_data.fallback_estimation,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ═══════════════════════════════════════════════════════════════════════════════
# POST /validate
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/validate", response_model=CrossValidationResponse)
def validate_profile(request: CrossValidationRequest) -> CrossValidationResponse:
    """Valide la coherence des donnees du profil.

    Effectue des verifications croisees entre les champs fournis:
    - LPP vs age/salaire
    - Salaire brut vs net
    - 3a vs age
    - LPP vs statut independant
    - Hypotheque vs proprietaire
    - Taux marginal vs revenu

    Returns:
        CrossValidationResponse avec alertes et count.
    """
    # Convert Pydantic model to dict for service (only non-None fields)
    profile = {}
    if request.age is not None:
        profile["age"] = request.age
    if request.salaire_brut is not None:
        profile["salaire_brut"] = request.salaire_brut
    if request.salaire_net is not None:
        profile["salaire_net"] = request.salaire_net
    if request.canton is not None:
        profile["canton"] = request.canton.upper()
    if request.lpp_total is not None:
        profile["lpp_total"] = request.lpp_total
    if request.lpp_obligatoire is not None:
        profile["lpp_obligatoire"] = request.lpp_obligatoire
    if request.pillar_3a_balance is not None:
        profile["pillar_3a_balance"] = request.pillar_3a_balance
    if request.mortgage_remaining is not None:
        profile["mortgage_remaining"] = request.mortgage_remaining
    if request.is_property_owner is not None:
        profile["is_property_owner"] = request.is_property_owner
    if request.is_independant is not None:
        profile["is_independant"] = request.is_independant
    if request.has_lpp is not None:
        profile["has_lpp"] = request.has_lpp
    if request.taux_marginal is not None:
        profile["taux_marginal"] = request.taux_marginal
    if request.monthly_expenses is not None:
        profile["monthly_expenses"] = request.monthly_expenses

    alerts = cross_validate(profile)

    return CrossValidationResponse(
        alerts=[
            CrossValidationAlertSchema(
                field_name=a.field_name,
                severity=a.severity,
                message=a.message,
                suggestion=a.suggestion,
            )
            for a in alerts
        ],
        alert_count=len(alerts),
        disclaimer=_DISCLAIMER,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# POST /smart-defaults
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/smart-defaults", response_model=SmartDefaultResponse)
def get_smart_defaults(request: SmartDefaultRequest) -> SmartDefaultResponse:
    """Calcule des estimations contextuelles pour les champs manquants.

    Prend en compte l'archetype, l'age, le salaire et le canton
    pour fournir des estimations plus precises que des valeurs generiques.

    Returns:
        SmartDefaultResponse avec estimations, disclaimer et sources legales.
    """
    defaults = compute_smart_defaults(
        archetype=request.archetype,
        age=request.age,
        salary=request.salary,
        canton=request.canton.upper(),
    )

    return SmartDefaultResponse(
        defaults=[
            SmartDefaultSchema(
                field_name=d.field_name,
                value=d.value,
                source=d.source,
                confidence=d.confidence,
            )
            for d in defaults
        ],
        disclaimer=_DISCLAIMER,
        sources=_SOURCES,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# POST /prompts
# ═══════════════════════════════════════════════════════════════════════════════


@router.post("/prompts", response_model=PrecisionPromptResponse)
def get_prompts(request: PrecisionPromptRequest) -> PrecisionPromptResponse:
    """Retourne les demandes de precision adaptees au contexte.

    Determine quels champs manquants impactent le plus le resultat
    dans le module consulte, et genere des prompts educatifs.

    Contextes supportes:
    - rente_vs_capital: comparaison rente vs capital LPP
    - tax_optimization: optimisation fiscale (3a, rachat)
    - fri_display: affichage du Financial Resilience Index
    - retirement_projection: projection de retraite
    - mortgage_check: verification hypothecaire

    Returns:
        PrecisionPromptResponse avec prompts, disclaimer et sources legales.
    """
    # Build profile dict from request fields
    profile: dict = {}
    if request.lpp_total is not None:
        profile["lpp_total"] = request.lpp_total
    if request.lpp_obligatoire is not None:
        profile["lpp_obligatoire"] = request.lpp_obligatoire
    if request.taux_marginal is not None:
        profile["taux_marginal"] = request.taux_marginal
    if request.pillar_3a_balance is not None:
        profile["pillar_3a_balance"] = request.pillar_3a_balance
    if request.avs_contribution_years is not None:
        profile["avs_contribution_years"] = request.avs_contribution_years
    if request.monthly_expenses is not None:
        profile["monthly_expenses"] = request.monthly_expenses
    if request.mortgage_remaining is not None:
        profile["mortgage_remaining"] = request.mortgage_remaining

    prompts = get_precision_prompts(
        context=request.context,
        profile=profile,
    )

    return PrecisionPromptResponse(
        prompts=[
            PrecisionPromptSchema(
                trigger=p.trigger,
                field_needed=p.field_needed,
                prompt_text=p.prompt_text,
                impact_text=p.impact_text,
            )
            for p in prompts
        ],
        disclaimer=_DISCLAIMER,
        sources=_SOURCES,
    )
