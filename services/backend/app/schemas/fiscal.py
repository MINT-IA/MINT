"""
Pydantic v2 schemas for the Fiscal (cantonal tax comparator) module.

Sprint S20 — Fiscalite cantonale — Comparateur 26 cantons.
API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - Tax estimation for a given profile in a specific canton
    - 26-canton ranking by tax burden
    - Move simulation (savings from changing canton)
"""

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List


# ===========================================================================
# Tax Estimate Schemas
# ===========================================================================

class TaxEstimateRequest(BaseModel):
    """Request for tax estimation in a specific canton."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenu_brut: float = Field(
        ..., gt=0, description="Revenu brut annuel (CHF)"
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres, ex: ZH, GE, VD)"
    )
    etat_civil: str = Field(
        default="celibataire",
        description="Etat civil: celibataire ou marie"
    )
    nombre_enfants: int = Field(
        default=0, ge=0, le=20,
        description="Nombre d'enfants a charge"
    )


class TaxEstimateResponse(BaseModel):
    """Response for tax estimation in a specific canton."""

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
    revenu_imposable: float = Field(
        ..., description="Revenu imposable estime (CHF)"
    )
    impot_federal: float = Field(
        ..., description="Impot federal direct estime (CHF)"
    )
    impot_cantonal_communal: float = Field(
        ..., description="Impot cantonal et communal estime (CHF)"
    )
    charge_totale: float = Field(
        ..., description="Charge fiscale totale estimee (CHF)"
    )
    taux_effectif: float = Field(
        ..., description="Taux effectif d'imposition (%)"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales et statistiques"
    )


# ===========================================================================
# Canton Comparison Schemas
# ===========================================================================

class CantonRankingItem(BaseModel):
    """A single canton in the ranked comparison."""

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
    charge_totale: float = Field(
        ..., description="Charge fiscale totale estimee (CHF)"
    )
    taux_effectif: float = Field(
        ..., description="Taux effectif d'imposition (%)"
    )
    difference_vs_premier: float = Field(
        ..., description="Difference avec le canton le moins cher (CHF)"
    )


class CantonComparisonRequest(BaseModel):
    """Request for 26-canton tax comparison."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenu_brut: float = Field(
        ..., gt=0, description="Revenu brut annuel (CHF)"
    )
    etat_civil: str = Field(
        default="celibataire",
        description="Etat civil: celibataire ou marie"
    )
    nombre_enfants: int = Field(
        default=0, ge=0, le=20,
        description="Nombre d'enfants a charge"
    )


class CantonComparisonResponse(BaseModel):
    """Response for 26-canton tax comparison."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    classement: List[CantonRankingItem] = Field(
        default_factory=list,
        description="Classement des 26 cantons par charge fiscale"
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
# Move Simulation Schemas
# ===========================================================================

class MoveSimulationRequest(BaseModel):
    """Request for cantonal move simulation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenu_brut: float = Field(
        ..., gt=0, description="Revenu brut annuel (CHF)"
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
    nombre_enfants: int = Field(
        default=0, ge=0, le=20,
        description="Nombre d'enfants a charge"
    )


class MoveSimulationResponse(BaseModel):
    """Response for cantonal move simulation."""

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
    charge_depart: float = Field(
        ..., description="Charge fiscale dans le canton de depart (CHF)"
    )
    charge_arrivee: float = Field(
        ..., description="Charge fiscale dans le canton d'arrivee (CHF)"
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
    checklist: List[str] = Field(
        default_factory=list, description="Checklist de demenagement fiscal"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales et statistiques"
    )
