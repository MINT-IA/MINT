"""
Educational Content endpoints — contenu pedagogique pour les inserts du wizard.

GET  /api/v1/educational-content/         — liste tous les inserts educatifs
GET  /api/v1/educational-content/{question_id} — retourne un insert par question_id
GET  /api/v1/educational-content/phase/{phase} — retourne les inserts par phase

Sert le contenu educatif (chiffre choc, objectifs d'apprentissage, disclaimer,
sources legales) pour chaque question du wizard MINT.

All endpoints are stateless (no data storage). Pure read from in-memory data.
"""

from fastapi import APIRouter, HTTPException, Request

from app.core.rate_limit import limiter

from app.schemas.educational_content import (
    InsertContentResponse,
    InsertListResponse,
)
from app.services.educational_content_service import EducationalContentService

router = APIRouter()

# Service instance (stateless, safe to reuse)
_service = EducationalContentService()


def _to_response(insert) -> InsertContentResponse:
    """Convert a service InsertContent dataclass to a Pydantic response."""
    return InsertContentResponse(
        question_id=insert.question_id,
        title=insert.title,
        chiffre_choc=insert.chiffre_choc,
        learning_goals=insert.learning_goals,
        disclaimer=insert.disclaimer,
        sources=insert.sources,
        action_label=insert.action_label,
        action_route=insert.action_route,
        phase=insert.phase,
        safe_mode=insert.safe_mode,
    )


@router.get("/phase/{phase}", response_model=InsertListResponse)
@limiter.limit("60/minute")
def get_inserts_by_phase(
    request: Request, phase: str) -> InsertListResponse:
    """Retourne tous les inserts educatifs pour une phase donnee.

    Args:
        phase: Phase du wizard (ex: "Niveau 0", "Niveau 1", "Niveau 2").

    Returns:
        InsertListResponse avec la liste filtree des inserts.
    """
    inserts = _service.get_inserts_by_phase(phase)
    items = [_to_response(i) for i in inserts]
    return InsertListResponse(inserts=items, count=len(items))


@router.get("", response_model=InsertListResponse)
@limiter.limit("60/minute")
def list_all_inserts(
    request: Request) -> InsertListResponse:
    """Retourne tous les inserts educatifs disponibles.

    Returns:
        InsertListResponse avec la liste complete des 16 inserts.
    """
    inserts = _service.get_all_inserts()
    items = [_to_response(i) for i in inserts]
    return InsertListResponse(inserts=items, count=len(items))


@router.get("/{question_id}", response_model=InsertContentResponse)
@limiter.limit("60/minute")
def get_insert(
    request: Request, question_id: str) -> InsertContentResponse:
    """Retourne un insert educatif par son identifiant de question.

    Args:
        question_id: Identifiant de la question wizard (ex: "q_has_3a").

    Returns:
        InsertContentResponse ou 404 si non trouve.
    """
    insert = _service.get_insert(question_id)
    if insert is None:
        raise HTTPException(
            status_code=404,
            detail=f"Insert non trouve pour question_id: {question_id}",
        )
    return _to_response(insert)
