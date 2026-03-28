"""
Pydantic schemas for the Proactive Coaching module.

Sprint S11: Coaching proactif.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class EmploymentStatus(str, Enum):
    """Coaching-internal French dialect. Profile API uses English ('employee', 'self_employed', 'retired').
    If integrating with Profile API, map: salarie↔employee, independant↔self_employed, retraite↔retired."""
    salarie = "salarie"
    independant = "independant"
    retraite = "retraite"


class EtatCivil(str, Enum):
    celibataire = "celibataire"
    marie = "marie"
    divorce = "divorce"
    veuf = "veuf"


# ---------------------------------------------------------------------------
# Request
# ---------------------------------------------------------------------------

class CoachingProfileRequest(BaseModel):
    """Request model for coaching tip generation."""

    age: int = Field(..., description="User's age", ge=0, le=120)
    canton: str = Field(
        "GE", description="Canton of residence (2-letter code)", max_length=2
    )
    revenuAnnuel: float = Field(
        ..., description="Annual income (CHF)", ge=0
    )
    has3a: bool = Field(False, description="Has a 3rd pillar account")
    montant3a: float = Field(
        0.0, description="Current year 3a contribution (CHF)", ge=0
    )
    hasLpp: bool = Field(False, description="Has a LPP pension fund")
    avoirLpp: float = Field(
        0.0, description="Current LPP savings (CHF)", ge=0
    )
    lacuneLpp: float = Field(
        0.0, description="LPP buyback gap (CHF)", ge=0
    )
    tauxActivite: float = Field(
        100.0, description="Activity rate (0-100%)", ge=0, le=100
    )
    chargesFixesMensuelles: float = Field(
        0.0, description="Monthly fixed expenses (CHF)", ge=0
    )
    epargneDisponible: float = Field(
        0.0, description="Available savings (CHF)", ge=0
    )
    detteTotale: float = Field(
        0.0, description="Total debt (CHF)", ge=0
    )
    hasBudget: bool = Field(False, description="Has a budget set up")
    employmentStatus: EmploymentStatus = Field(
        EmploymentStatus.salarie, description="Employment status"
    )
    etatCivil: EtatCivil = Field(
        EtatCivil.celibataire, description="Civil status"
    )


# ---------------------------------------------------------------------------
# Response
# ---------------------------------------------------------------------------

class CoachingTipResponse(BaseModel):
    """A single coaching tip."""

    id: str = Field(..., description="Tip identifier")
    category: str = Field(..., description="Category (prevoyance, fiscalite, budget)")
    priority: str = Field(..., description="Priority: haute, moyenne, basse")
    title: str = Field(..., description="Tip title")
    message: str = Field(..., description="Tip message")
    action: str = Field(..., description="Recommended action")
    estimatedImpactChf: Optional[float] = Field(
        None, description="Estimated financial impact (CHF)"
    )
    source: str = Field(..., description="Legal source reference")
    icon: str = Field(..., description="Icon name for display")


class CoachingResponse(BaseModel):
    """Response model for coaching tips."""

    tips: List[CoachingTipResponse] = Field(
        default_factory=list, description="List of coaching tips"
    )
    disclaimer: str = Field(
        ..., description="Legal disclaimer"
    )
