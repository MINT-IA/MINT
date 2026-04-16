"""
Pydantic v2 schemas for the Wealth Tax + Church Tax module.

Sprint S22+ — Chantier 1: Impot sur la fortune + impot ecclesiastique.
API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - Wealth tax estimation for a given fortune in a specific canton
    - 26-canton wealth tax ranking
    - Wealth tax move simulation
    - Church tax estimation
"""

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List


# ===========================================================================
# Wealth Tax Estimate Schemas
# ===========================================================================

class WealthTaxEstimateRequest(BaseModel):
    """Request for wealth tax estimation in a specific canton."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    fortune_nette: float = Field(
        ..., ge=0, description="Fortune nette (CHF)"
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres, ex: ZH, GE, VD)"
    )
    etat_civil: str = Field(
        default="celibataire",
        description="Etat civil: celibataire ou marie"
    )


class WealthTaxEstimateResponse(BaseModel):
    """Response for wealth tax estimation in a specific canton."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    canton: str = Field(
        ..., description="Code canton"
    )
    canton_nom: str = Field(
        ..., description="Nom complet du canton en francais"
    )
    fortune_nette: float = Field(
        ..., description="Fortune nette declaree (CHF)"
    )
    fortune_imposable: float = Field(
        ..., description="Fortune imposable apres exoneration (CHF)"
    )
    impot_fortune: float = Field(
        ..., description="Impot sur la fortune estime (CHF/an)"
    )
    taux_effectif_permille: float = Field(
        ..., description="Taux effectif en pour mille"
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


# ===========================================================================
# Wealth Tax Comparison Schemas
# ===========================================================================

class WealthTaxRankingItem(BaseModel):
    """A single canton in the ranked comparison by wealth tax."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    rang: int = Field(
        ..., description="Rang dans le classement (1 = moins cher)"
    )
    canton: str = Field(
        ..., description="Code canton"
    )
    canton_nom: str = Field(
        ..., description="Nom complet du canton en francais"
    )
    impot_fortune: float = Field(
        ..., description="Impot sur la fortune estime (CHF/an)"
    )
    taux_effectif_permille: float = Field(
        ..., description="Taux effectif en pour mille"
    )
    difference_vs_premier: float = Field(
        ..., description="Difference avec le canton le moins cher (CHF)"
    )


class WealthTaxComparisonRequest(BaseModel):
    """Request for 26-canton wealth tax comparison."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    fortune_nette: float = Field(
        ..., ge=0, description="Fortune nette (CHF)"
    )
    etat_civil: str = Field(
        default="celibataire",
        description="Etat civil: celibataire ou marie"
    )


class WealthTaxComparisonResponse(BaseModel):
    """Response for 26-canton wealth tax comparison."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    classement: List[WealthTaxRankingItem] = Field(
        default_factory=list,
        description="Classement des 26 cantons par impot sur la fortune"
    )
    ecart_max: float = Field(
        ..., description="Ecart entre le canton le moins cher et le plus cher (CHF)"
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


# ===========================================================================
# Wealth Tax Move Simulation Schemas
# ===========================================================================

class WealthTaxMoveRequest(BaseModel):
    """Request for wealth tax move simulation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    fortune_nette: float = Field(
        ..., ge=0, description="Fortune nette (CHF)"
    )
    canton_depart: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton de depart (2 lettres)"
    )
    canton_arrivee: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton d'arrivee (2 lettres)"
    )
    etat_civil: str = Field(
        default="celibataire",
        description="Etat civil: celibataire ou marie"
    )


class WealthTaxMoveResponse(BaseModel):
    """Response for wealth tax move simulation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    canton_depart: str = Field(
        ..., description="Code canton de depart"
    )
    canton_depart_nom: str = Field(
        ..., description="Nom du canton de depart"
    )
    canton_arrivee: str = Field(
        ..., description="Code canton d'arrivee"
    )
    canton_arrivee_nom: str = Field(
        ..., description="Nom du canton d'arrivee"
    )
    impot_depart: float = Field(
        ..., description="Impot sur la fortune dans le canton de depart (CHF)"
    )
    impot_arrivee: float = Field(
        ..., description="Impot sur la fortune dans le canton d'arrivee (CHF)"
    )
    economie_annuelle: float = Field(
        ..., description="Economie annuelle estimee (CHF, positif = economie)"
    )
    economie_mensuelle: float = Field(
        ..., description="Economie mensuelle estimee (CHF)"
    )
    economie_10_ans: float = Field(
        ..., description="Economie cumulee sur 10 ans (CHF)"
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    alertes: List[str] = Field(
        default_factory=list, description="Alertes et avertissements"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales et statistiques"
    )


# ===========================================================================
# Church Tax Schemas
# ===========================================================================

class ChurchTaxEstimateRequest(BaseModel):
    """Request for church tax estimation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    impot_cantonal: float = Field(
        ..., ge=0, description="Impot cantonal sur le revenu (CHF)"
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres)"
    )


class ChurchTaxEstimateResponse(BaseModel):
    """Response for church tax estimation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    canton: str = Field(
        ..., description="Code canton"
    )
    canton_nom: str = Field(
        ..., description="Nom complet du canton en francais"
    )
    is_mandatory: bool = Field(
        ..., description="True si l'impot ecclesiastique est obligatoire"
    )
    church_tax_rate: float = Field(
        ..., description="Taux d'impot ecclesiastique (fraction de l'impot cantonal)"
    )
    impot_cantonal_base: float = Field(
        ..., description="Impot cantonal utilise comme base (CHF)"
    )
    impot_eglise: float = Field(
        ..., description="Impot ecclesiastique estime (CHF)"
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
