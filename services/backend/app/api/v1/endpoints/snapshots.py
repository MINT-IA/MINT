"""
Snapshots endpoints — Sprint S33: Financial Snapshots.

POST   /api/v1/snapshots                    — Create snapshot
GET    /api/v1/snapshots                    — Get snapshots for authenticated user
DELETE /api/v1/snapshots                    — Delete all snapshots (LPD compliance)
GET    /api/v1/snapshots/evolution           — Get evolution time series

WARNING (V12-3): When no DB session is provided, this service uses an in-memory
fallback dict. Data will NOT survive restart. Feature-gated pending DB migration
(see migrations/004_snapshots.sql). The endpoint layer adds an
X-Storage-Mode: in-memory response header to signal this to clients.

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""


import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response

from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.user import User

from app.schemas.snapshots import (
    CreateSnapshotRequest,
    SnapshotResponse,
    SnapshotListResponse,
    DeleteSnapshotsResponse,
    EvolutionPointSchema,
    EvolutionResponse,
)
from app.services.reengagement.consent_manager import ConsentManager
from app.services.reengagement.reengagement_models import ConsentType
from app.services.snapshots import (
    create_snapshot,
    get_snapshots,
    delete_all_snapshots,
    get_evolution,
)

router = APIRouter()
logger = logging.getLogger(__name__)

# V12-3: WARNING — In-memory storage. Data will not survive restart.
# Feature-gated pending DB migration (see migrations/004_snapshots.sql).
logger.warning(
    "Snapshots: in-memory fallback active — snapshot data will NOT survive "
    "restart. Feature-gated pending DB migration."
)

# V12-3: Header injected on affected endpoints to signal in-memory mode.
_IN_MEMORY_HEADER = ("X-Storage-Mode", "in-memory")


def _snapshot_to_response(snapshot) -> SnapshotResponse:
    """Convert FinancialSnapshot dataclass to Pydantic response."""
    return SnapshotResponse(
        id=snapshot.id,
        user_id=snapshot.user_id,
        created_at=snapshot.created_at,
        trigger=snapshot.trigger,
        model_version=snapshot.model_version,
        age=snapshot.age,
        gross_income=snapshot.gross_income,
        canton=snapshot.canton,
        archetype=snapshot.archetype,
        household_type=snapshot.household_type,
        replacement_ratio=snapshot.replacement_ratio,
        months_liquidity=snapshot.months_liquidity,
        tax_saving_potential=snapshot.tax_saving_potential,
        confidence_score=snapshot.confidence_score,
        enrichment_count=snapshot.enrichment_count,
        fri_total=snapshot.fri_total,
        fri_l=snapshot.fri_l,
        fri_f=snapshot.fri_f,
        fri_r=snapshot.fri_r,
        fri_s=snapshot.fri_s,
    )


@router.post("", response_model=SnapshotResponse)
@limiter.limit("30/minute")
def create_financial_snapshot(request: Request, body: CreateSnapshotRequest, response: Response, current_user: User = Depends(require_current_user)) -> SnapshotResponse:
    """Creer un snapshot financier.

    Capture l'etat financier de l'utilisateur a un moment donne,
    declenche par un check-in trimestriel, un evenement de vie,
    ou une mise a jour du profil.

    Returns:
        SnapshotResponse avec l'identifiant unique du snapshot.
    """
    response.headers[_IN_MEMORY_HEADER[0]] = _IN_MEMORY_HEADER[1]

    # Consent guard: snapshot_storage consent required (nLPD)
    if not ConsentManager.is_consent_given(current_user.id, ConsentType.snapshot_storage):
        raise HTTPException(
            status_code=403,
            detail=(
                "Consentement 'snapshot_storage' requis pour sauvegarder "
                "un snapshot. Active-le dans Profil > Consentements."
            ),
        )

    try:
        snapshot = create_snapshot(
            user_id=current_user.id,
            trigger=body.trigger,
            profile_data=body.profile_data,
        )
        return _snapshot_to_response(snapshot)

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")


@router.get("", response_model=SnapshotListResponse)
@limiter.limit("60/minute")
def get_user_snapshots(
    request: Request,
    response: Response,
    limit: int = Query(default=10, ge=1, le=100, description="Nombre max de snapshots"),
    current_user: User = Depends(require_current_user),
) -> SnapshotListResponse:
    """Recuperer les snapshots de l'utilisateur authentifie.

    Retourne les snapshots les plus recents en premier (ordre chronologique inverse).

    Args:
        limit: Nombre maximum de snapshots a retourner (defaut: 10, max: 100).

    Returns:
        SnapshotListResponse avec la liste des snapshots.
    """
    response.headers[_IN_MEMORY_HEADER[0]] = _IN_MEMORY_HEADER[1]
    snapshots = get_snapshots(user_id=current_user.id, limit=limit)
    return SnapshotListResponse(
        snapshots=[_snapshot_to_response(s) for s in snapshots],
        count=len(snapshots),
    )


@router.delete("", response_model=DeleteSnapshotsResponse)
@limiter.limit("30/minute")
def delete_user_snapshots(request: Request, response: Response, current_user: User = Depends(require_current_user)) -> DeleteSnapshotsResponse:
    """Supprimer tous les snapshots de l'utilisateur authentifie.

    Conformite LPD (Loi sur la protection des donnees) — droit a l'effacement.

    Returns:
        DeleteSnapshotsResponse avec le nombre de snapshots supprimes.
    """
    response.headers[_IN_MEMORY_HEADER[0]] = _IN_MEMORY_HEADER[1]
    count = delete_all_snapshots(user_id=current_user.id)
    return DeleteSnapshotsResponse(
        deleted_count=count,
        message=f"{count} snapshot(s) supprime(s).",
    )


@router.get("/evolution", response_model=EvolutionResponse)
@limiter.limit("60/minute")
def get_user_evolution(
    request: Request,
    response: Response,
    field: str = Query(
        default="replacement_ratio",
        description="Metrique a suivre (replacement_ratio, months_liquidity, etc.)",
    ),
    current_user: User = Depends(require_current_user),
) -> EvolutionResponse:
    """Recuperer la serie temporelle d'une metrique financiere.

    Retourne les points de donnee en ordre chronologique (plus ancien en premier),
    pour visualiser l'evolution dans le temps.

    Args:
        field: Nom de la metrique a suivre.

    Returns:
        EvolutionResponse avec la serie temporelle.
    """
    response.headers[_IN_MEMORY_HEADER[0]] = _IN_MEMORY_HEADER[1]
    try:
        data_points = get_evolution(user_id=current_user.id, field=field)
        return EvolutionResponse(
            field=field,
            data_points=[
                EvolutionPointSchema(
                    date=dp["date"],
                    value=dp["value"],
                    trigger=dp["trigger"],
                )
                for dp in data_points
            ],
            count=len(data_points),
        )

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")
