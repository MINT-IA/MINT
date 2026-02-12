"""
Commune tax multiplier endpoints.

GET /api/v1/communes/search?q=Zurich&canton=ZH  — Search communes by name or NPA
GET /api/v1/communes/{npa}                       — Lookup commune by postal code
GET /api/v1/communes/canton/{canton_code}        — List all communes for a canton
GET /api/v1/communes/cheapest?canton=ZH&limit=10 — Cheapest communes ranking

All endpoints are stateless (no data storage). Pure lookup from hardcoded data.

Sources:
    - LHID art. 1 (harmonisation fiscale)
    - LHID art. 2 al. 1 (autonomie communale en matiere fiscale)
"""

from fastapi import APIRouter, HTTPException, Query
from typing import Optional

from app.schemas.commune import (
    CommuneResponse,
    CommuneSearchResponse,
    CommuneListResponse,
    CheapestCommunesResponse,
)
from app.services.fiscal.commune_service import (
    search_communes,
    get_commune_by_npa,
    list_communes_by_canton,
    get_cheapest_communes,
    DISCLAIMER,
    SOURCES,
    CANTON_NAMES,
    COMMUNE_DATA,
)


router = APIRouter()


# ---------------------------------------------------------------------------
# Search communes by name or NPA
# ---------------------------------------------------------------------------

@router.get("/search", response_model=CommuneSearchResponse)
def search_communes_endpoint(
    q: str = Query(..., min_length=1, description="Recherche par nom ou NPA"),
    canton: Optional[str] = Query(None, min_length=2, max_length=2, description="Filtre par canton (ex: ZH)"),
) -> CommuneSearchResponse:
    """Rechercher des communes par nom ou code postal (NPA).

    Exemples:
        - ?q=Zurich
        - ?q=8000
        - ?q=Lausanne&canton=VD

    Sources: LHID art. 1, art. 2 al. 1.
    """
    results = search_communes(query=q, canton=canton)

    commune_responses = [
        CommuneResponse(**r) for r in results
    ]

    return CommuneSearchResponse(
        resultats=commune_responses,
        total=len(commune_responses),
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )


# ---------------------------------------------------------------------------
# List cheapest communes (must be before /{npa} to avoid route conflict)
# ---------------------------------------------------------------------------

@router.get("/cheapest", response_model=CheapestCommunesResponse)
def cheapest_communes_endpoint(
    canton: Optional[str] = Query(None, min_length=2, max_length=2, description="Filtre par canton (ex: ZH)"),
    limit: int = Query(10, ge=1, le=50, description="Nombre de resultats (1-50)"),
) -> CheapestCommunesResponse:
    """Classement des communes les moins cheres fiscalement.

    Retourne les communes avec le multiplicateur le plus bas,
    toutes cantons confondus ou filtre par canton.

    Sources: LHID art. 1, art. 2 al. 1.
    """
    results = get_cheapest_communes(canton=canton, limit=limit)

    commune_responses = [
        CommuneResponse(**r) for r in results
    ]

    # Build chiffre choc
    if len(commune_responses) >= 2:
        cheapest = commune_responses[0]
        most_exp = commune_responses[-1]
        chiffre_choc = (
            f"A commune comparable, le multiplicateur varie de "
            f"{cheapest.multiplier:.2f} ({cheapest.commune}, {cheapest.canton}) "
            f"a {most_exp.multiplier:.2f} ({most_exp.commune}, {most_exp.canton}). "
            f"Ton choix de commune peut faire une vraie difference sur tes impots."
        )
    else:
        chiffre_choc = "Pas assez de donnees pour comparer."

    return CheapestCommunesResponse(
        communes=commune_responses,
        total=len(commune_responses),
        chiffre_choc=chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )


# ---------------------------------------------------------------------------
# List communes by canton
# ---------------------------------------------------------------------------

@router.get("/canton/{canton_code}", response_model=CommuneListResponse)
def list_canton_communes_endpoint(
    canton_code: str,
) -> CommuneListResponse:
    """Lister toutes les communes d'un canton, triees par multiplicateur.

    Le canton le moins cher apparait en premier.

    Sources: LHID art. 1, art. 2 al. 1.
    """
    canton_code = canton_code.upper()

    if canton_code not in COMMUNE_DATA:
        raise HTTPException(
            status_code=404,
            detail=f"Canton inconnu: '{canton_code}'. "
                   f"Codes valides: {', '.join(sorted(COMMUNE_DATA.keys()))}"
        )

    try:
        results = list_communes_by_canton(canton=canton_code)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    commune_responses = [
        CommuneResponse(**r) for r in results
    ]

    # Build chiffre choc
    canton_data = COMMUNE_DATA[canton_code]
    canton_nom = CANTON_NAMES.get(canton_code, canton_code)
    if len(commune_responses) >= 2:
        cheapest = commune_responses[0]
        most_exp = commune_responses[-1]
        ecart = most_exp.multiplier - cheapest.multiplier
        chiffre_choc = (
            f"Dans le canton de {canton_nom}, le multiplicateur varie de "
            f"{cheapest.multiplier:.2f} ({cheapest.commune}) a "
            f"{most_exp.multiplier:.2f} ({most_exp.commune}), "
            f"soit un ecart de {ecart:.2f}. "
            f"Choisir la bonne commune peut reduire significativement tes impots."
        )
    else:
        chiffre_choc = f"Une seule commune repertoriee pour {canton_nom}."

    return CommuneListResponse(
        canton=canton_code,
        canton_nom=canton_nom,
        system=canton_data["system"],
        communes=commune_responses,
        total=len(commune_responses),
        chiffre_choc=chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=list(SOURCES),
    )


# ---------------------------------------------------------------------------
# Lookup commune by NPA
# ---------------------------------------------------------------------------

@router.get("/{npa}", response_model=CommuneResponse)
def get_commune_by_npa_endpoint(
    npa: int,
) -> CommuneResponse:
    """Trouver une commune par son code postal (NPA).

    Exemples: /api/v1/communes/8000 -> Zurich, ZH

    Sources: LHID art. 1, art. 2 al. 1.
    """
    result = get_commune_by_npa(npa)

    if not result.get("commune"):
        raise HTTPException(
            status_code=404,
            detail=f"Aucune commune trouvee pour le NPA {npa}. "
                   f"Verifie le code postal ou essaie la recherche par nom."
        )

    return CommuneResponse(**result)
