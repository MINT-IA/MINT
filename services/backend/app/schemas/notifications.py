"""
Pydantic v2 schemas for the Notifications & Milestones module (Sprint S36).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - CalendarNotificationRequest / CalendarNotificationsResponse
    - EventNotificationRequest / EventNotificationsResponse
    - MilestoneCheckRequest / MilestoneCheckResponse
    - ScheduledNotificationResponse / MilestoneResponse

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LSFin art. 3 (obligation d'information)
"""

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================


class NotifBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Request schemas
# ===========================================================================


class CalendarNotificationRequest(NotifBaseModel):
    """Requete pour generer les notifications calendaires."""

    tax_saving_3a: float = Field(
        default=0.0,
        ge=0.0,
        description="Economie fiscale estimee en versant le plafond 3a (CHF)",
    )
    today: Optional[date] = Field(
        default=None,
        description="Date du jour (override pour tests)",
    )


class EventNotificationRequest(NotifBaseModel):
    """Requete pour generer les notifications evenementielles."""

    fri_delta: float = Field(
        default=0.0,
        description="Variation du score FRI depuis le dernier check-in",
    )
    profile_updated: bool = Field(
        default=False,
        description="Le profil a-t-il ete mis a jour ?",
    )
    check_in_completed: bool = Field(
        default=False,
        description="Un check-in vient-il d'etre complete ?",
    )


class MilestoneCheckRequest(NotifBaseModel):
    """Requete pour detecter les milestones franchis."""

    current_snapshot: dict = Field(
        default_factory=dict,
        description="Snapshot financier actuel",
    )
    previous_snapshot: dict = Field(
        default_factory=dict,
        description="Snapshot financier precedent (vide si premier)",
    )
    check_in_streak: int = Field(
        default=0,
        ge=0,
        description="Nombre de check-ins consecutifs",
    )
    arbitrage_count: int = Field(
        default=0,
        ge=0,
        description="Nombre d'arbitrages completes",
    )


# ===========================================================================
# Response schemas
# ===========================================================================


class ScheduledNotificationResponse(NotifBaseModel):
    """Une notification planifiee."""

    category: str = Field(..., description="Categorie de la notification")
    tier: str = Field(..., description="Tier de la notification (calendar, event, byok)")
    title: str = Field(..., description="Titre (max 60 car.)")
    body: str = Field(..., description="Corps du message (max 200 car.)")
    deeplink: str = Field(..., description="Lien profond (ex: /3a, /dashboard)")
    scheduled_date: date = Field(..., description="Date planifiee")
    personal_number: str = Field(..., description="Nombre personnel inclus (audit)")
    time_reference: str = Field(..., description="Reference temporelle incluse (audit)")


class MilestoneResponse(NotifBaseModel):
    """Un milestone detecte."""

    milestone_type: str = Field(..., description="Type de milestone")
    celebration_text: str = Field(..., description="Texte de celebration (factuel)")
    concrete_value: str = Field(..., description="Valeur concrete de l'accomplissement")
    detected_at: datetime = Field(..., description="Date de detection")


class CalendarNotificationsResponse(NotifBaseModel):
    """Reponse contenant les notifications calendaires."""

    notifications: List[ScheduledNotificationResponse] = Field(
        ..., description="Liste des notifications calendaires"
    )
    count: int = Field(..., description="Nombre de notifications generees")
    disclaimer: str = Field(
        default="Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin).",
        description="Disclaimer legal",
    )
    sources: List[str] = Field(
        default=["OPP3 art. 7", "LSFin art. 3"],
        description="References legales",
    )


class EventNotificationsResponse(NotifBaseModel):
    """Reponse contenant les notifications evenementielles."""

    notifications: List[ScheduledNotificationResponse] = Field(
        ..., description="Liste des notifications evenementielles"
    )
    count: int = Field(..., description="Nombre de notifications generees")
    disclaimer: str = Field(
        default="Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin).",
        description="Disclaimer legal",
    )
    sources: List[str] = Field(
        default=["LSFin art. 3"],
        description="References legales",
    )


class MilestoneCheckResponse(NotifBaseModel):
    """Reponse contenant les milestones detectes."""

    new_milestones: List[MilestoneResponse] = Field(
        ..., description="Liste des milestones nouvellement franchis"
    )
    count: int = Field(..., description="Nombre de milestones detectes")
    disclaimer: str = Field(
        default="Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin).",
        description="Disclaimer legal",
    )
    sources: List[str] = Field(
        default=["LSFin art. 3"],
        description="References legales",
    )
