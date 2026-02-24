"""
Snapshots endpoints — Sprint S33: Financial Snapshots.

POST   /api/v1/snapshots                    — Create snapshot
GET    /api/v1/snapshots/{user_id}           — Get snapshots for a user
DELETE /api/v1/snapshots/{user_id}           — Delete all snapshots (LPD compliance)
GET    /api/v1/snapshots/{user_id}/evolution — Get evolution time series

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""

from typing import Optional

from fastapi import APIRouter, HTTPException, Query

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
def create_financial_snapshot(request: CreateSnapshotRequest) -> SnapshotResponse:
    """Creer un snapshot financier.

    Capture l'etat financier de l'utilisateur a un moment donne,
    declenche par un check-in trimestriel, un evenement de vie,
    ou une mise a jour du profil.

    Returns:
        SnapshotResponse avec l'identifiant unique du snapshot.
    """
    # Consent guard: snapshot_storage consent required (nLPD)
    if not ConsentManager.is_consent_given(request.user_id, ConsentType.snapshot_storage):
        raise HTTPException(
            status_code=403,
            detail=(
                "Consentement 'snapshot_storage' requis pour sauvegarder "
                "un snapshot. Active-le dans Profil > Consentements."
            ),
        )

    try:
        snapshot = create_snapshot(
            user_id=request.user_id,
            trigger=request.trigger,
            profile_data=request.profile_data,
        )
        return _snapshot_to_response(snapshot)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{user_id}", response_model=SnapshotListResponse)
def get_user_snapshots(
    user_id: str,
    limit: int = Query(default=10, ge=1, le=100, description="Nombre max de snapshots"),
) -> SnapshotListResponse:
    """Recuperer les snapshots d'un utilisateur.

    Retourne les snapshots les plus recents en premier (ordre chronologique inverse).

    Args:
        user_id: Identifiant de l'utilisateur.
        limit: Nombre maximum de snapshots a retourner (defaut: 10, max: 100).

    Returns:
        SnapshotListResponse avec la liste des snapshots.
    """
    snapshots = get_snapshots(user_id=user_id, limit=limit)
    return SnapshotListResponse(
        snapshots=[_snapshot_to_response(s) for s in snapshots],
        count=len(snapshots),
    )


@router.delete("/{user_id}", response_model=DeleteSnapshotsResponse)
def delete_user_snapshots(user_id: str) -> DeleteSnapshotsResponse:
    """Supprimer tous les snapshots d'un utilisateur.

    Conformite LPD (Loi sur la protection des donnees) — droit a l'effacement.

    Args:
        user_id: Identifiant de l'utilisateur.

    Returns:
        DeleteSnapshotsResponse avec le nombre de snapshots supprimes.
    """
    count = delete_all_snapshots(user_id=user_id)
    return DeleteSnapshotsResponse(
        deleted_count=count,
        message=f"{count} snapshot(s) supprime(s) pour l'utilisateur {user_id}.",
    )


@router.get("/{user_id}/evolution", response_model=EvolutionResponse)
def get_user_evolution(
    user_id: str,
    field: str = Query(
        default="replacement_ratio",
        description="Metrique a suivre (replacement_ratio, months_liquidity, etc.)",
    ),
) -> EvolutionResponse:
    """Recuperer la serie temporelle d'une metrique financiere.

    Retourne les points de donnee en ordre chronologique (plus ancien en premier),
    pour visualiser l'evolution dans le temps.

    Args:
        user_id: Identifiant de l'utilisateur.
        field: Nom de la metrique a suivre.

    Returns:
        EvolutionResponse avec la serie temporelle.
    """
    try:
        data_points = get_evolution(user_id=user_id, field=field)
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

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
