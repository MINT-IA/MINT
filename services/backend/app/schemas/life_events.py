"""
Pydantic schemas for Life Events simulators (Divorce + Succession).

Sprint S10: Divorce Financial Simulator + Succession Simulator.
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from enum import Enum


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class RegimeMatrimonial(str, Enum):
    participation_acquets = "participation_acquets"
    communaute_biens = "communaute_biens"
    separation_biens = "separation_biens"


class EtatCivil(str, Enum):
    marie = "marie"
    celibataire = "celibataire"
    divorce = "divorce"
    veuf = "veuf"
    concubin = "concubin"


# ---------------------------------------------------------------------------
# Divorce Schemas
# ---------------------------------------------------------------------------

class DivorceSimulationRequest(BaseModel):
    """Request model for divorce financial simulation."""

    dureeMarriageAnnees: int = Field(
        ..., description="Marriage duration in years", ge=0
    )
    regimeMatrimonial: RegimeMatrimonial = Field(
        RegimeMatrimonial.participation_acquets,
        description="Matrimonial property regime",
    )
    nombreEnfants: int = Field(
        0, description="Number of children", ge=0
    )
    revenuAnnuelConjoint1: float = Field(
        ..., description="Annual income of spouse 1 (CHF)", ge=0
    )
    revenuAnnuelConjoint2: float = Field(
        ..., description="Annual income of spouse 2 (CHF)", ge=0
    )
    lppConjoint1PendantMariage: float = Field(
        0.0, description="LPP accumulated during marriage by spouse 1 (CHF)", ge=0
    )
    lppConjoint2PendantMariage: float = Field(
        0.0, description="LPP accumulated during marriage by spouse 2 (CHF)", ge=0
    )
    avoirs3aConjoint1: float = Field(
        0.0, description="3a pillar savings of spouse 1 (CHF)", ge=0
    )
    avoirs3aConjoint2: float = Field(
        0.0, description="3a pillar savings of spouse 2 (CHF)", ge=0
    )
    fortuneCommune: float = Field(
        0.0, description="Common fortune (real estate, savings) in CHF", ge=0
    )
    detteCommune: float = Field(
        0.0, description="Common debt (mortgage, credits) in CHF", ge=0
    )
    canton: str = Field(
        "GE", description="Canton of residence (2-letter code)", max_length=2
    )


class DivorceSimulationResponse(BaseModel):
    """Response model for divorce financial simulation."""

    partageLpp: dict = Field(..., description="LPP splitting details")
    splittingAvs: dict = Field(..., description="AVS splitting explanation")
    partage3a: dict = Field(..., description="3a pillar splitting")
    partageFortune: dict = Field(..., description="Fortune splitting")
    impactFiscalAvant: dict = Field(..., description="Tax before divorce (joint)")
    impactFiscalApres: dict = Field(..., description="Tax after divorce (individual)")
    pensionAlimentaireEstimee: float = Field(
        ..., description="Estimated monthly alimony (CHF/month)"
    )
    checklist: List[str] = Field(default_factory=list, description="Action items")
    alerts: List[str] = Field(default_factory=list, description="Warning messages")
    disclaimer: str = Field(..., description="Legal disclaimer")


# ---------------------------------------------------------------------------
# Succession Schemas
# ---------------------------------------------------------------------------

class SuccessionSimulationRequest(BaseModel):
    """Request model for succession simulation."""

    fortuneTotale: float = Field(
        ..., description="Total estate value (CHF)", ge=0
    )
    etatCivil: EtatCivil = Field(
        ..., description="Civil status"
    )
    aConjoint: bool = Field(
        False, description="Has surviving spouse/registered partner"
    )
    nombreEnfants: int = Field(
        0, description="Number of children", ge=0
    )
    aParentsVivants: bool = Field(
        False, description="Has living parents"
    )
    aFratrie: bool = Field(
        False, description="Has siblings"
    )
    aConcubin: bool = Field(
        False, description="Has unmarried partner (concubin)"
    )
    aTestament: bool = Field(
        False, description="Has a will/testament"
    )
    quotiteDisponibleTestament: Optional[Dict[str, float]] = Field(
        None,
        description="Allocation of quotite disponible per beneficiary (fraction 0-1)",
    )
    avoirs3a: float = Field(
        0.0, description="3a pillar assets (CHF)", ge=0
    )
    capitalDecesLpp: float = Field(
        0.0, description="LPP death capital (CHF)", ge=0
    )
    canton: str = Field(
        "GE", description="Canton for tax rates (2-letter code)", max_length=2
    )


class SuccessionSimulationResponse(BaseModel):
    """Response model for succession simulation."""

    repartitionLegale: dict = Field(
        ..., description="Legal inheritance distribution"
    )
    repartitionAvecTestament: dict = Field(
        ..., description="Distribution with will"
    )
    reservesHereditaires: dict = Field(
        ..., description="Mandatory reserves per heir"
    )
    quotiteDisponible: float = Field(
        ..., description="Freely disposable share (CHF)"
    )
    fiscalite: dict = Field(
        ..., description="Succession tax details by heir"
    )
    ordre3aOpp3: List[str] = Field(
        ..., description="OPP3 art. 2 beneficiary order"
    )
    alerteConcubin: str = Field(
        "", description="Concubin-specific warning"
    )
    checklist: List[str] = Field(default_factory=list, description="Action items")
    alerts: List[str] = Field(default_factory=list, description="Warning messages")
    disclaimer: str = Field(..., description="Legal disclaimer")


# ---------------------------------------------------------------------------
# Checklist Schemas (shared)
# ---------------------------------------------------------------------------

class LifeEventChecklistItem(BaseModel):
    """A single checklist item for life events."""

    label: str = Field(..., description="Checklist item description")
    category: str = Field(
        ..., description="Category (juridique, fiscal, prevoyance, administratif)"
    )
    priority: str = Field(..., description="Priority: haute, moyenne, basse")


class LifeEventChecklistResponse(BaseModel):
    """Template checklist for life event planning."""

    items: List[LifeEventChecklistItem] = Field(..., description="Checklist items")
    disclaimer: str = Field(..., description="Legal disclaimer")
