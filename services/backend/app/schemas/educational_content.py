"""
Pydantic v2 schemas for the Educational Content service.

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - InsertContentResponse: a single educational insert
    - InsertListResponse: list of educational inserts
"""

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List


# ===========================================================================
# Base config
# ===========================================================================

class EducationalBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Response items
# ===========================================================================

class InsertContentResponse(EducationalBaseModel):
    """Contenu educatif d'un insert du wizard."""

    question_id: str = Field(
        ..., description="Identifiant unique de la question wizard (ex: q_has_3a)",
    )
    title: str = Field(
        ..., description="Titre de l'insert en francais",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc: un nombre marquant avec explication",
    )
    learning_goals: List[str] = Field(
        ..., description="Objectifs d'apprentissage pour l'utilisateur",
    )
    disclaimer: str = Field(
        ..., description="Disclaimer legal (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )
    action_label: str = Field(
        ..., description="Libelle du bouton d'action (call-to-action)",
    )
    action_route: str = Field(
        ..., description="Route GoRouter pour l'action (ex: /simulators/3a-growth)",
    )
    phase: str = Field(
        ..., description="Phase du wizard (ex: Niveau 0, Niveau 1, Niveau 2)",
    )
    safe_mode: str = Field(
        ..., description="Comportement en safe mode (description)",
    )


# ===========================================================================
# Response wrapper
# ===========================================================================

class InsertListResponse(EducationalBaseModel):
    """Liste d'inserts educatifs."""

    inserts: List[InsertContentResponse] = Field(
        ..., description="Liste des inserts educatifs",
    )
    count: int = Field(
        ..., description="Nombre total d'inserts retournes",
    )
