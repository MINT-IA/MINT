"""
Pydantic v2 schemas for the Reengagement + Consent module (Sprint S40).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - ReengagementRequest / ReengagementResponse — personalized messages
    - ConsentDashboardResponse — consent toggles with nLPD detail
    - ByokDetailResponse — exact fields sent/never-sent to LLM

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LPD art. 6 (principes de traitement)
    - nLPD art. 5 let. f (profilage)
    - LSFin art. 3 (information financiere)
"""

from datetime import date
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================


class ReengagementBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Request schemas
# ===========================================================================


class ReengagementRequest(ReengagementBaseModel):
    """Request body for POST /reengagement/messages."""

    today: Optional[date] = Field(
        default=None,
        description="Date du jour (override pour tests)",
    )
    canton: str = Field(
        default="VD",
        description="Canton de residence (2 lettres)",
    )
    tax_saving_3a: float = Field(
        default=0.0,
        ge=0.0,
        description="Economie fiscale estimee en versant le plafond 3a (CHF)",
    )
    fri_total: float = Field(
        default=0.0,
        ge=0.0,
        le=100.0,
        description="Score FRI actuel (0-100)",
    )
    fri_delta: float = Field(
        default=0.0,
        description="Variation du score FRI depuis le dernier trimestre",
    )
    replacement_ratio: float = Field(
        default=0.0,
        ge=0.0,
        description="Ratio de remplacement projete (0-1+)",
    )


class ConsentUpdateRequest(ReengagementBaseModel):
    """Request body for PATCH /reengagement/consent/{user_id}."""

    consent_type: str = Field(
        ..., description="Type de consentement (byok_data_sharing, snapshot_storage, notifications)",
    )
    enabled: bool = Field(
        ..., description="Activer (true) ou desactiver (false)",
    )


# ===========================================================================
# Response schemas
# ===========================================================================


class ReengagementMessageResponse(ReengagementBaseModel):
    """A single personalized reengagement message."""

    trigger: str = Field(..., description="Type de declencheur calendaire")
    title: str = Field(..., description="Titre (max 60 car.)")
    body: str = Field(..., description="Corps du message avec nombre personnel")
    deeplink: str = Field(..., description="Lien profond (ex: /3a, /fiscal)")
    personal_number: str = Field(
        ..., description="Nombre personnel inclus (CHF ou %)"
    )
    time_constraint: str = Field(
        ..., description="Contrainte temporelle (deadline ou fenetre)"
    )
    month: int = Field(..., ge=1, le=12, description="Mois du declencheur")


class ReengagementResponse(ReengagementBaseModel):
    """Response for POST /reengagement/messages."""

    messages: List[ReengagementMessageResponse] = Field(
        ..., description="Messages de reengagement personnalises"
    )
    count: int = Field(..., description="Nombre de messages generes")
    disclaimer: str = Field(
        default=(
            "Outil educatif simplifie. Ne constitue pas un conseil "
            "financier (LSFin)."
        ),
        description="Mention legale obligatoire",
    )
    sources: List[str] = Field(
        default=[
            "OPP3 art. 7 (plafond 3a)",
            "LPD art. 6 (principes de traitement)",
            "LSFin art. 3 (information financiere)",
        ],
        description="References legales",
    )


# ===========================================================================
# Consent schemas
# ===========================================================================


class ConsentStateResponse(ReengagementBaseModel):
    """State of a single consent toggle."""

    consent_type: str = Field(..., description="Type de consentement")
    enabled: bool = Field(..., description="Active ou non")
    label: str = Field(..., description="Description (francais)")
    detail: str = Field(..., description="Ce qui est partage/stocke")
    never_sent: str = Field(..., description="Ce qui n'est JAMAIS partage")
    revocable: bool = Field(
        default=True, description="Revocable a tout moment"
    )


class ConsentDashboardResponse(ReengagementBaseModel):
    """Full consent dashboard with all 3 toggles."""

    consents: List[ConsentStateResponse] = Field(
        ..., description="Les 3 consentements independants"
    )
    disclaimer: str = Field(..., description="Mention nLPD")
    sources: List[str] = Field(..., description="References legales")


class ByokDetailResponse(ReengagementBaseModel):
    """Detail of exactly which fields are sent to LLM provider."""

    sent_fields: List[str] = Field(
        ..., description="Champs envoyes au fournisseur LLM"
    )
    never_sent_fields: List[str] = Field(
        ..., description="Champs JAMAIS envoyes"
    )
    disclaimer: str = Field(..., description="Mention legale obligatoire")
    sources: List[str] = Field(..., description="References legales")
