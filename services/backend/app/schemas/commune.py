"""
Pydantic v2 schemas for the Commune multiplier module.

Provides commune-level tax multiplier data for Swiss municipalities.
API convention: camelCase field names via alias_generator, ConfigDict.

Sources:
    - LHID art. 1 (harmonisation fiscale)
    - LHID art. 2 al. 1 (autonomie communale)
    - Publications officielles cantonales 2025
"""

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List


# ===========================================================================
# Commune Response Schemas
# ===========================================================================

class CommuneResponse(BaseModel):
    """A single commune with its tax multiplier."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    canton: str = Field(
        ..., description="Code canton (2 lettres, ex: ZH, GE)"
    )
    canton_nom: str = Field(
        ..., description="Nom du canton en francais"
    )
    commune: str = Field(
        ..., description="Nom de la commune"
    )
    npa: List[int] = Field(
        default_factory=list,
        description="Codes postaux (NPA) de la commune"
    )
    multiplier: float = Field(
        ..., description="Multiplicateur fiscal total (canton + commune)"
    )
    steuerfuss: int = Field(
        ..., description="Steuerfuss / taux communal brut"
    )
    system: str = Field(
        ..., description="Systeme fiscal (steuerfuss_pct, coefficient, centimes_additionnels, etc.)"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales et statistiques"
    )


class CommuneSearchResponse(BaseModel):
    """Response for commune search results."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    resultats: List[CommuneResponse] = Field(
        default_factory=list,
        description="Liste des communes correspondant a la recherche"
    )
    total: int = Field(
        ..., description="Nombre total de resultats"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales et statistiques"
    )


class CommuneListResponse(BaseModel):
    """Response for listing communes by canton."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    canton: str = Field(
        ..., description="Code canton"
    )
    canton_nom: str = Field(
        ..., description="Nom du canton en francais"
    )
    system: str = Field(
        ..., description="Systeme fiscal du canton"
    )
    communes: List[CommuneResponse] = Field(
        default_factory=list,
        description="Liste des communes triees par multiplicateur"
    )
    total: int = Field(
        ..., description="Nombre total de communes"
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales et statistiques"
    )


class CheapestCommunesResponse(BaseModel):
    """Response for cheapest communes ranking."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    communes: List[CommuneResponse] = Field(
        default_factory=list,
        description="Communes triees par multiplicateur croissant"
    )
    total: int = Field(
        ..., description="Nombre de communes retournees"
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales et statistiques"
    )
