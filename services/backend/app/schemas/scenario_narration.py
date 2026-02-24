"""
Pydantic v2 schemas for Scenario Narration + Annual Refresh — Sprint S37.

API convention: camelCase field names via alias_generator, ConfigDict.

Endpoints:
    POST /api/v1/scenario/narrate       -> ScenarioNarrationResponse
    POST /api/v1/scenario/refresh-check -> AnnualRefreshResponse

Sources:
    - LSFin art. 3 (information financiere)
    - LPP art. 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
"""

from datetime import date
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base model with camelCase aliases
# ===========================================================================


class ScenarioBaseModel(BaseModel):
    """Base model for all S37 scenario schemas."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )


# ===========================================================================
# Request schemas
# ===========================================================================


class ScenarioInputSchema(ScenarioBaseModel):
    """A single scenario input (from ForecasterService)."""

    label: str = Field(..., description="Label: prudent, base, optimiste")
    annual_return: float = Field(
        ..., description="Rendement annuel hypothetique (ex: 0.01, 0.045, 0.07)"
    )
    capital_final: float = Field(
        ..., ge=0, description="Capital estime a la retraite (CHF)"
    )
    monthly_income: float = Field(
        ..., ge=0, description="Revenu mensuel estime a la retraite (CHF)"
    )
    replacement_ratio: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Taux de remplacement (0.0-1.0)",
    )


class ScenarioNarrationRequest(ScenarioBaseModel):
    """Request for narrating retirement scenarios."""

    scenarios: List[ScenarioInputSchema] = Field(
        ..., min_length=1, max_length=5, description="Scenarios a narrer (1-5)"
    )
    first_name: str = Field(
        default="utilisateur", description="Prenom de l'utilisateur"
    )
    age: int = Field(default=30, ge=18, le=99, description="Age actuel")


class RefreshCheckRequest(ScenarioBaseModel):
    """Request for annual refresh detection."""

    last_major_update: date = Field(
        ..., description="Date de la derniere mise a jour majeure du profil"
    )
    current_salary: float = Field(
        default=0.0, ge=0, description="Salaire annuel brut actuel (CHF)"
    )
    current_lpp: float = Field(
        default=0.0, ge=0, description="Avoir LPP actuel (CHF)"
    )
    current_3a: float = Field(
        default=0.0, ge=0, description="Solde 3a actuel (CHF)"
    )
    risk_profile: str = Field(
        default="modere",
        description="Profil de risque: conservateur, modere, dynamique",
    )


# ===========================================================================
# Response schemas
# ===========================================================================


class NarratedScenarioResponse(ScenarioBaseModel):
    """A single narrated scenario in the response."""

    label: str = Field(..., description="Label du scenario")
    narrative: str = Field(
        ..., description="Texte narratif educatif (max 150 mots)"
    )
    annual_return_pct: float = Field(
        ..., description="Rendement annuel en % (ex: 1.0, 4.5, 7.0)"
    )
    capital_final: float = Field(
        ..., description="Capital estime a la retraite (CHF)"
    )
    monthly_income: float = Field(
        ..., description="Revenu mensuel estime (CHF)"
    )


class ScenarioNarrationResponse(ScenarioBaseModel):
    """Response for scenario narration endpoint."""

    scenarios: List[NarratedScenarioResponse] = Field(
        ..., description="Scenarios narres"
    )
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )
    uncertainty_mentioned: bool = Field(
        default=True, description="L'incertitude est mentionnee dans chaque scenario"
    )


class RefreshQuestionResponse(ScenarioBaseModel):
    """A single refresh question in the response."""

    key: str = Field(..., description="Cle technique de la question")
    label: str = Field(..., description="Texte de la question (francais)")
    question_type: str = Field(
        ..., description="Type: slider, yes_no, select, text"
    )
    current_value: Optional[str] = Field(
        default=None, description="Valeur pre-remplie"
    )
    options: List[str] = Field(
        default_factory=list, description="Options pour le type select"
    )


class AnnualRefreshResponse(ScenarioBaseModel):
    """Response for annual refresh check endpoint."""

    refresh_needed: bool = Field(
        ..., description="True si le profil est obsolete (> 11 mois)"
    )
    months_since_update: int = Field(
        ..., description="Nombre de mois depuis la derniere mise a jour"
    )
    questions: List[RefreshQuestionResponse] = Field(
        ..., description="7 questions de mise a jour"
    )
    disclaimer: str = Field(..., description="Avertissement legal")
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )
