"""
Unemployment (LACI) endpoints — Sprint S19: Chomage (LACI) + Premier emploi.

POST /api/v1/unemployment/calculate       — Calculate unemployment benefits
GET  /api/v1/unemployment/checklist       — Get generic checklist + timeline
GET  /api/v1/unemployment/orp-link/{canton} — Get cantonal ORP link

All endpoints are stateless (no data storage). Pure computation on the fly.
"""

from fastapi import APIRouter

from app.schemas.unemployment import (
    UnemploymentBenefitsRequest,
    UnemploymentBenefitsResponse,
    TimelineStep,
)
from app.services.unemployment.calculator import (
    UnemploymentCalculator,
    get_orp_link,
    get_unemployment_checklist,
)


router = APIRouter()


# ---------------------------------------------------------------------------
# Calculate unemployment benefits
# ---------------------------------------------------------------------------

@router.post("/calculate", response_model=UnemploymentBenefitsResponse)
def calculate_unemployment_benefits(
    request: UnemploymentBenefitsRequest,
) -> UnemploymentBenefitsResponse:
    """Calculate LACI unemployment benefits.

    Computes daily/monthly indemnities, duration, eligibility status,
    and provides a timeline + checklist for post-job-loss actions.

    Sources: LACI art. 8, 13, 22, 23, 27. OAC art. 37.
    """
    calculator = UnemploymentCalculator()
    result = calculator.calculate(
        gain_assure_mensuel=request.gain_assure_mensuel,
        age=request.age,
        annees_cotisation=request.annees_cotisation,
        has_children=request.has_children,
        has_disability=request.has_disability,
        canton=request.canton,
        date_licenciement=request.date_licenciement,
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
        chiffre_choc=result["chiffre_choc"],
        disclaimer=result["disclaimer"],
        sources=result["sources"],
    )


# ---------------------------------------------------------------------------
# Generic checklist + timeline
# ---------------------------------------------------------------------------

@router.get("/checklist")
def unemployment_checklist():
    """Get the generic unemployment checklist and timeline.

    Useful for displaying information even before a specific calculation.
    """
    return get_unemployment_checklist()


# ---------------------------------------------------------------------------
# ORP link by canton
# ---------------------------------------------------------------------------

@router.get("/orp-link/{canton}")
def orp_link(canton: str):
    """Get the ORP (Office regional de placement) link for a given canton.

    Returns the cantonal employment office URL. Falls back to arbeit.swiss
    for unknown cantons.
    """
    return get_orp_link(canton)
