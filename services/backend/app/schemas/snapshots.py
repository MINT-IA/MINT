"""
Pydantic v2 schemas for the Snapshots module (Sprint S33).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - CreateSnapshotRequest / SnapshotResponse
    - SnapshotListResponse
    - DeleteSnapshotsResponse
    - EvolutionPointSchema / EvolutionResponse

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================

class SnapshotBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Request schemas
# ===========================================================================

class CreateSnapshotRequest(SnapshotBaseModel):
    """Requete pour creer un snapshot financier."""

    user_id: str = Field(
        ..., min_length=1,
        description="Identifiant de l'utilisateur",
    )
    trigger: str = Field(
        ...,
        description="Declencheur: 'quarterly', 'life_event', 'profile_update', 'check_in'",
    )
    profile_data: Dict[str, Any] = Field(
        default_factory=dict,
        description="Donnees du profil (age, gross_income, canton, etc.)",
    )


# ===========================================================================
# Response schemas
# ===========================================================================

class SnapshotResponse(SnapshotBaseModel):
    """Un snapshot financier."""

    id: str = Field(..., description="UUID du snapshot")
    user_id: str = Field(..., description="Identifiant de l'utilisateur")
    created_at: str = Field(..., description="Date de creation (ISO 8601)")
    trigger: str = Field(..., description="Declencheur du snapshot")
    model_version: str = Field(..., description="Version du modele")
    # Core inputs
    age: int = Field(0, description="Age au moment du snapshot")
    gross_income: float = Field(0.0, description="Revenu brut annuel (CHF)")
    canton: str = Field("VD", description="Canton de domicile fiscal")
    archetype: str = Field("swiss_native", description="Archetype financier")
    household_type: str = Field("single", description="Type de menage")
    # Key outputs
    replacement_ratio: float = Field(0.0, description="Taux de remplacement (0-1)")
    months_liquidity: float = Field(0.0, description="Mois de reserve de liquidite")
    tax_saving_potential: float = Field(0.0, description="Potentiel d'economie fiscale (CHF)")
    confidence_score: float = Field(0.0, description="Score de confiance (0-100)")
    enrichment_count: int = Field(0, description="Nombre d'enrichissements completes")
    # FRI scores
    fri_total: float = Field(0.0, description="FRI total (0-100)")
    fri_l: float = Field(0.0, description="FRI Liquidite (0-100)")
    fri_f: float = Field(0.0, description="FRI Fiscalite (0-100)")
    fri_r: float = Field(0.0, description="FRI Retraite (0-100)")
    fri_s: float = Field(0.0, description="FRI Securite (0-100)")


class SnapshotListResponse(SnapshotBaseModel):
    """Liste de snapshots."""

    snapshots: List[SnapshotResponse] = Field(
        ..., description="Liste des snapshots (plus recent en premier)"
    )
    count: int = Field(..., description="Nombre de snapshots retournes")


class DeleteSnapshotsResponse(SnapshotBaseModel):
    """Resultat de la suppression de snapshots."""

    deleted_count: int = Field(
        ..., description="Nombre de snapshots supprimes"
    )
    message: str = Field(
        ..., description="Message de confirmation"
    )


class EvolutionPointSchema(SnapshotBaseModel):
    """Un point de donnee dans la serie temporelle."""

    date: str = Field(..., description="Date (ISO 8601)")
    value: float = Field(..., description="Valeur de la metrique")
    trigger: str = Field(..., description="Declencheur du snapshot")


class EvolutionResponse(SnapshotBaseModel):
    """Serie temporelle d'une metrique financiere."""

    field: str = Field(..., description="Nom de la metrique")
    data_points: List[EvolutionPointSchema] = Field(
        ..., description="Points de donnee (plus ancien en premier)"
    )
    count: int = Field(..., description="Nombre de points")
