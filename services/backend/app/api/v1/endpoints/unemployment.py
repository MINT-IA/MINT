"""
Unemployment (LACI) endpoints — Sprint S19: Chomage (LACI) + Premier emploi.

POST /api/v1/unemployment/calculate       — Calculate unemployment benefits
GET  /api/v1/unemployment/checklist       — Get generic checklist + timeline
GET  /api/v1/unemployment/orp-link/{canton} — Get cantonal ORP link

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter, Depends

from app.core.auth import require_current_user
from app.core.profile_resolver import (
    _required_profile_fields_missing,
    _resolve_defaults,
    emit_calc_invoke_metric,
    get_profile_filled,
    raise_incomplete_as_422,
)
from app.models.user import User
from app.schemas.unemployment import (
    UnemploymentBenefitsRequest,
    UnemploymentBenefitsResponse,
    UnemploymentChecklistResponse,
    OrpLinkResponse,
    TimelineStep,
)
from app.services.unemployment.calculator import (
    UnemploymentCalculator,
    get_orp_link,
    get_unemployment_checklist,
)


_UNEMPLOYMENT_HINT_FR = (
    "Pour estimer tes indemnités chômage, j'ai besoin de ton canton — "
    "le supplément cantonal varie selon le canton. Tu peux me le partager ?"
)


router = APIRouter()


# ---------------------------------------------------------------------------
# Calculate unemployment benefits
# ---------------------------------------------------------------------------

@router.post("/calculate", response_model=UnemploymentBenefitsResponse)
def calculate_unemployment_benefits(
    request: UnemploymentBenefitsRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> UnemploymentBenefitsResponse:
    """Calculate LACI unemployment benefits.

    Computes daily/monthly indemnities, duration, eligibility status,
    and provides a timeline + checklist for post-job-loss actions.

    Grounded via D-CE-06 + D-CE-07 : `canton` is read from `_user.profile`
    when not supplied in the body (W0 audit row 37 — silent ZH default
    closed). Missing profile.canton triggers a 422 with the D-CE-08
    `CoachToolIncomplete` envelope when strict mode is enabled.

    Sources: LACI art. 8, 13, 22, 23, 27. OAC art. 37.
    """
    resolved = _resolve_defaults(profile_data, request, UnemploymentBenefitsRequest)
    missing = _required_profile_fields_missing(resolved, UnemploymentBenefitsRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=_UNEMPLOYMENT_HINT_FR,
            resolved_body=resolved,
            endpoint="/api/v1/unemployment/calculate",
        )
    emit_calc_invoke_metric(
        kind="unemployment_calculate",
        resolved=resolved,
        schema_class=UnemploymentBenefitsRequest,
    )

    calculator = UnemploymentCalculator()
    result = calculator.calculate(
        gain_assure_mensuel=resolved["gain_assure_mensuel"],
        age=resolved["age"],
        annees_cotisation=resolved["annees_cotisation"],
        has_children=resolved["has_children"],
        has_disability=resolved["has_disability"],
        canton=str(resolved["canton"]),
        date_licenciement=resolved["date_licenciement"],
    )

    # Convert timeline dicts to TimelineStep models
    timeline_steps = [
        TimelineStep(**step) for step in result.get("timeline", [])
    ]

    return UnemploymentBenefitsResponse(
        taux_indemnite=result["taux_indemnite"],
        gain_assure_retenu=result["gain_assure_retenu"],
        indemnite_journaliere=result["indemnite_journaliere"],
        indemnite_mensuelle=result["indemnite_mensuelle"],
        nombre_indemnites=result["nombre_indemnites"],
        duree_mois=result["duree_mois"],
        delai_carence_jours=result["delai_carence_jours"],
        eligible=result["eligible"],
        raison_non_eligible=result.get("raison_non_eligible"),
        timeline=timeline_steps,
        checklist=result.get("checklist", []),
        alertes=result.get("alertes", []),
        premier_eclairage=result["premier_eclairage"],
        disclaimer=result["disclaimer"],
        sources=result["sources"],
    )


# ---------------------------------------------------------------------------
# Generic checklist + timeline
# ---------------------------------------------------------------------------

@router.get("/checklist", response_model=UnemploymentChecklistResponse)
def unemployment_checklist() -> UnemploymentChecklistResponse:
    """Get the generic unemployment checklist and timeline.

    Useful for displaying information even before a specific calculation.
    """
    data = get_unemployment_checklist()
    timeline_steps = [TimelineStep(**step) for step in data.get("timeline", [])]
    return UnemploymentChecklistResponse(
        checklist=data.get("checklist", []),
        timeline=timeline_steps,
    )


# ---------------------------------------------------------------------------
# ORP link by canton
# ---------------------------------------------------------------------------

@router.get("/orp-link/{canton}", response_model=OrpLinkResponse)
def orp_link(canton: str) -> OrpLinkResponse:
    """Get the ORP (Office regional de placement) link for a given canton.

    Returns the cantonal employment office URL. Falls back to arbeit.swiss
    for unknown cantons.
    """
    data = get_orp_link(canton)
    return OrpLinkResponse(canton=data["canton"], url=data["url"])
