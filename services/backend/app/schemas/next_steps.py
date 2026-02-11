"""
Pydantic v2 schemas for the Next Steps recommendation service.

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - NextStepsRequest: user profile input for recommendations
    - NextStepItem: a single recommended next step
    - NextStepsResponse: list of up to 5 prioritized steps + compliance
"""

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List


# ===========================================================================
# Base config
# ===========================================================================

class NextStepsBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Request
# ===========================================================================

class NextStepsRequest(NextStepsBaseModel):
    """Requete pour les recommendations de prochaines etapes."""

    age: int = Field(
        ..., ge=16, le=100,
        description="Age de l'utilisateur",
    )
    civil_status: str = Field(
        ...,
        description="Etat civil: single, married, divorced, widowed, registered_partnership, concubinage",
    )
    children_count: int = Field(
        ..., ge=0,
        description="Nombre d'enfants a charge",
    )
    employment_status: str = Field(
        ...,
        description="Statut professionnel: employee, independent, unemployed, inactive",
    )
    monthly_net_income: float = Field(
        ..., ge=0,
        description="Revenu mensuel net (CHF)",
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres, ex: ZH, VD, GE)",
    )
    has_3a: bool = Field(
        default=False,
        description="Possede un 3e pilier a",
    )
    has_pension_fund: bool = Field(
        default=False,
        description="Affilie a une caisse de pension LPP",
    )
    has_debt: bool = Field(
        default=False,
        description="A des dettes (credit conso, leasing, etc.)",
    )
    has_real_estate: bool = Field(
        default=False,
        description="Proprietaire immobilier",
    )
    has_investments: bool = Field(
        default=False,
        description="Possede des placements (valeurs mobilieres, etc.)",
    )


# ===========================================================================
# Response items
# ===========================================================================

class NextStepItem(NextStepsBaseModel):
    """Une etape recommandee parmi les 18 evenements de vie."""

    life_event: str = Field(
        ..., description="Type d'evenement de vie (ex: debtCrisis, retirement, firstJob)",
    )
    title: str = Field(
        ..., description="Titre de la recommandation en francais",
    )
    reason: str = Field(
        ..., description="Explication de la pertinence pour l'utilisateur",
    )
    priority: int = Field(
        ..., ge=1, le=5,
        description="Priorite (1 = la plus haute, 5 = la plus basse)",
    )
    route: str = Field(
        ..., description="Route GoRouter (ex: /check/debt, /retirement)",
    )
    icon_name: str = Field(
        ..., description="Nom de l'icone Material (ex: warning, elderly, home)",
    )


# ===========================================================================
# Response
# ===========================================================================

class NextStepsResponse(NextStepsBaseModel):
    """Resultat avec la liste des prochaines etapes recommandees."""

    steps: List[NextStepItem] = Field(
        ..., description="Liste de 1 a 5 etapes recommandees, triees par priorite",
    )
    disclaimer: str = Field(
        ..., description="Disclaimer legal (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )
