"""
Pydantic schemas for the Sociological Segments module.

Sprint S12, Chantier 6: Gender gap, frontaliers, independants.

API convention: camelCase field names.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum


# ===========================================================================
# Enums
# ===========================================================================

class PaysFrontalier(str, Enum):
    """Supported cross-border countries."""
    FR = "FR"
    DE = "DE"
    IT = "IT"
    AT = "AT"
    LI = "LI"


class PermisFrontalier(str, Enum):
    """Cross-border work permit types."""
    G = "G"


class EtatCivil(str, Enum):
    """Civil status."""
    celibataire = "celibataire"
    marie = "marie"
    divorce = "divorce"
    veuf = "veuf"


# ===========================================================================
# Gender Gap Schemas
# ===========================================================================

class GenderGapRequest(BaseModel):
    """Request for gender gap pension analysis."""

    tauxActivite: float = Field(
        ..., description="Activity rate (0-100%)", ge=0, le=100
    )
    age: int = Field(
        ..., description="Current age", ge=18, le=120
    )
    revenuAnnuel: float = Field(
        ..., description="Annual gross salary at current activity rate (CHF)", ge=0, le=10_000_000
    )
    salaireCoordonne: float = Field(
        0.0,
        description="Coordinated salary from LPP certificate (CHF)",
        ge=0,
    )
    avoirLpp: float = Field(
        0.0, description="Current LPP capital (CHF)", ge=0
    )
    anneesCotisation: int = Field(
        0, description="Years already contributed to LPP", ge=0
    )
    canton: str = Field(
        "GE", description="Canton of work (2-letter code)", max_length=2
    )


class RecommandationResponse(BaseModel):
    """A single recommendation."""
    id: str
    titre: str
    description: str
    source: str
    priorite: str


class GenderGapResponse(BaseModel):
    """Response for gender gap pension analysis."""

    lacuneAnnuelleChf: float = Field(
        ..., description="Annual pension gap (CHF)"
    )
    lacuneCumuleeChf: float = Field(
        ..., description="Cumulated pension gap over ~20 years retirement (CHF)"
    )
    renteEstimeePleinTemps: float = Field(
        ..., description="Estimated annual pension at 100% activity (CHF)"
    )
    renteEstimeeActuelle: float = Field(
        ..., description="Estimated annual pension at current activity rate (CHF)"
    )
    impactCoordination: float = Field(
        ..., description="Impact of non-prorated coordination deduction (CHF)"
    )
    recommandations: List[RecommandationResponse]
    statistiques: List[str]
    alerts: List[str]
    disclaimer: str


# ===========================================================================
# Frontalier Schemas
# ===========================================================================

class FrontalierRequest(BaseModel):
    """Request for cross-border worker analysis."""

    paysResidence: PaysFrontalier = Field(
        ..., description="Country of residence"
    )
    permis: PermisFrontalier = Field(
        PermisFrontalier.G, description="Work permit type"
    )
    cantonTravail: str = Field(
        ..., description="Canton of work (2-letter code)", max_length=2
    )
    revenuBrut: float = Field(
        ..., description="Gross annual salary (CHF)", ge=0, le=10_000_000
    )
    a3a: bool = Field(
        False, description="Currently has a 3a account"
    )
    aLpp: bool = Field(
        True, description="Currently affiliated to LPP"
    )
    etatCivil: EtatCivil = Field(
        EtatCivil.celibataire, description="Civil status"
    )
    nombreEnfants: int = Field(
        0, description="Number of children", ge=0, le=20
    )
    partRevenuSuisse: float = Field(
        1.0,
        description="Share of income from Switzerland (0.0-1.0)",
        ge=0.0,
        le=1.0,
    )


class ChecklistItemResponse(BaseModel):
    """A single checklist item."""
    item: str
    statut: str
    source: str


class FrontalierResponse(BaseModel):
    """Response for cross-border worker analysis."""

    regimeFiscal: str
    droit3a: bool
    droit3aDetail: str
    regimeLpp: str
    regimeAvs: str
    alertes: List[str]
    recommandations: List[RecommandationResponse]
    checklist: List[ChecklistItemResponse]
    specificites: List[str]
    disclaimer: str


# ===========================================================================
# Independant Schemas
# ===========================================================================

class IndependantRequest(BaseModel):
    """Request for self-employed worker analysis."""

    revenuNet: float = Field(
        ..., description="Annual net income from self-employment (CHF)", ge=0, le=10_000_000
    )
    age: int = Field(
        ..., description="Current age", ge=18, le=120
    )
    aLppVolontaire: bool = Field(
        False, description="Has voluntary LPP affiliation"
    )
    a3a: bool = Field(
        False, description="Has a 3a account"
    )
    aIjm: bool = Field(
        False, description="Has income protection insurance (IJM)"
    )
    aLaa: bool = Field(
        False, description="Has accident insurance (LAA)"
    )
    canton: str = Field(
        "GE", description="Canton (2-letter code)", max_length=2
    )


class LacuneCouvertureResponse(BaseModel):
    """A coverage gap."""
    type: str
    titre: str
    description: str
    severite: str
    source: str


class UrgenceResponse(BaseModel):
    """An urgent action item."""
    id: str
    titre: str
    description: str
    coutEstimeAnnuel: Optional[float] = None
    source: str
    priorite: str


class IndependantChecklistItemResponse(BaseModel):
    """A checklist item for self-employed."""
    item: str
    statut: str
    source: str
    montantEstime: Optional[float] = None
    plafond: Optional[float] = None


class IndependantResponse(BaseModel):
    """Response for self-employed worker analysis."""

    cotisationsAvs: float = Field(
        ..., description="Estimated annual AVS contributions (CHF)"
    )
    plafond3aGrand: float = Field(
        ..., description="Maximum 3a contribution (CHF)"
    )
    coutProtectionTotale: float = Field(
        ..., description="Estimated total annual protection cost (CHF)"
    )
    lacunesCouverture: List[LacuneCouvertureResponse]
    recommandations: List[RecommandationResponse]
    urgences: List[UrgenceResponse]
    checklist: List[IndependantChecklistItemResponse]
    disclaimer: str
