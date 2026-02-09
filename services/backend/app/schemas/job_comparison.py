"""
Pydantic schemas for the Job Change / LPP Plan Comparator.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum


class DeductionType(str, Enum):
    fixed = "fixed"
    proportional = "proportional"


class LPPPlanInput(BaseModel):
    """Input model for a single job's LPP plan data."""

    salaireBrut: float = Field(..., description="Gross annual salary (CHF)", gt=0)
    salaireAssure: Optional[float] = Field(
        None, description="Insured salary if known (CHF)", ge=0
    )
    deductionCoordination: float = Field(
        25725.0, description="Coordination deduction (CHF)"
    )
    deductionCoordinationType: DeductionType = Field(
        DeductionType.fixed, description="Type of coordination deduction"
    )

    # Contributions
    tauxCotisationEmploye: float = Field(
        0.0, description="Employee contribution rate (%)", ge=0
    )
    tauxCotisationEmployeur: float = Field(
        0.0, description="Employer contribution rate (%)", ge=0
    )
    partEmployeurPct: float = Field(
        50.0, description="Employer share of total contributions (%)", ge=50, le=100
    )

    # Capital & conversion
    avoirVieillesse: float = Field(
        0.0, description="Current old-age savings (CHF)", ge=0
    )
    tauxConversionObligatoire: float = Field(
        6.8, description="Mandatory conversion rate (%)", ge=0
    )
    tauxConversionSurobligatoire: Optional[float] = Field(
        None, description="Super-mandatory conversion rate (%)", ge=0
    )
    tauxConversionEnveloppe: Optional[float] = Field(
        None, description="Envelope conversion rate (%)", ge=0
    )

    # Risk coverage
    renteInvaliditePct: float = Field(
        0.0, description="Disability pension as % of insured salary", ge=0
    )
    capitalDeces: float = Field(0.0, description="Death capital (CHF)", ge=0)

    # Buyback
    rachatMaximum: float = Field(
        0.0, description="Maximum buyback amount (CHF)", ge=0
    )

    # Other benefits
    hasIjm: bool = Field(True, description="Has collective daily sickness benefit")
    ijmTaux: float = Field(80.0, description="IJM rate (%)", ge=0, le=100)
    ijmDureeJours: int = Field(720, description="IJM duration (days)", ge=0)


class JobComparisonRequest(BaseModel):
    """Request model for comparing two jobs."""

    currentPlan: LPPPlanInput = Field(..., description="Current job's LPP plan data")
    newPlan: LPPPlanInput = Field(..., description="New job offer's LPP plan data")
    age: int = Field(..., description="Worker's current age", ge=18, le=70)
    yearsToRetirement: Optional[int] = Field(
        None, description="Override years to retirement", ge=0
    )


class ComparisonAxis(BaseModel):
    """A single comparison axis between current and new plan."""

    name: str = Field(..., description="Axis name (e.g. 'Salaire net')")
    currentValue: float = Field(..., description="Current plan value")
    newValue: float = Field(..., description="New plan value")
    delta: float = Field(..., description="Difference (new - current)")
    unit: str = Field("CHF", description="Unit of measurement")
    isPositive: bool = Field(
        ..., description="Whether the delta is favorable for the worker"
    )


class JobComparisonResponse(BaseModel):
    """Full comparison result with 7 axes, verdict, alerts, and checklist."""

    # 7 comparison axes
    axes: List[ComparisonAxis] = Field(
        ..., description="Comparison axes (salary, contributions, capital, pension, death, disability, buyback)"
    )

    # Net salary
    salaireNetActuel: float
    salaireNetNouveau: float
    deltaSalaireNet: float

    # Contributions
    cotisationEmployeActuel: float
    cotisationEmployeNouveau: float
    deltaCotisation: float

    # Capital projection
    capitalRetraiteActuel: float
    capitalRetraiteNouveau: float
    deltaCapital: float

    # Monthly pension
    renteMensuelleActuel: float
    renteMensuelleNouveau: float
    deltaRente: float

    # Risk coverage
    couvertureDecesActuel: float
    couvertureDecesNouveau: float
    deltaDeces: float

    couvertureInvaliditeActuel: float
    couvertureInvaliditeNouveau: float
    deltaInvalidite: float

    # Buyback
    rachatMaxActuel: float
    rachatMaxNouveau: float
    deltaRachat: float

    # IJM
    hasIjmActuel: bool
    hasIjmNouveau: bool

    # Verdict
    verdict: str = Field(
        ..., description="Overall verdict: actuel_meilleur, nouveau_meilleur, comparable"
    )
    verdictDetails: str = Field(..., description="Human-readable explanation")
    annualPensionDelta: float = Field(
        ..., description="Annual pension difference (CHF)"
    )
    lifetimePensionDelta: float = Field(
        ..., description="Pension difference over 20 years of retirement (CHF)"
    )

    # Alerts and checklist
    alerts: List[str] = Field(default_factory=list, description="Warning messages")
    checklist: List[str] = Field(
        default_factory=list, description="Before-you-sign action items"
    )


class ChecklistItem(BaseModel):
    """A single checklist item for the 'before you sign' template."""

    label: str = Field(..., description="Checklist item description")
    category: str = Field(
        ..., description="Category (prevoyance, risque, administratif, fiscal)"
    )
    priority: str = Field(..., description="Priority: haute, moyenne, basse")


class ChecklistResponse(BaseModel):
    """Template checklist for job change due diligence."""

    items: List[ChecklistItem] = Field(..., description="Checklist items")
    disclaimer: str = Field(
        ..., description="Legal disclaimer"
    )
