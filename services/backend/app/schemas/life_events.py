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
        0, description="Number of children", ge=0, le=20
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
        0, description="Number of children", ge=0, le=20
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


# ---------------------------------------------------------------------------
# Donation Schemas
# ---------------------------------------------------------------------------

class DonationSimulationRequest(BaseModel):
    """Request model for donation simulation."""

    montant: float = Field(
        ..., description="Donation amount (CHF)", ge=0, le=10_000_000
    )
    donateurAge: int = Field(
        50, description="Donor age", ge=18, le=120
    )
    lienParente: str = Field(
        ..., description="Relationship: conjoint, descendant, parent, fratrie, concubin, tiers"
    )
    canton: str = Field(
        "GE", description="Canton code (2-letter)", min_length=2, max_length=2
    )
    typeDonation: str = Field(
        "especes", description="Type: especes, immobilier, titres"
    )
    valeurImmobiliere: float = Field(
        0.0, description="Property value if real estate (CHF)", ge=0
    )
    avancementHoirie: bool = Field(
        True, description="Advance on inheritance (default for descendants)"
    )
    nbEnfants: int = Field(
        0, description="Number of donor's children", ge=0, le=20
    )
    fortuneTotaleDonateur: float = Field(
        0.0, description="Total estate of donor (CHF)", ge=0
    )
    regimeMatrimonial: str = Field(
        "participation_acquets", description="Matrimonial regime"
    )
    hasSpouse: bool = Field(
        False, description="Whether donor has a spouse"
    )
    hasParents: bool = Field(
        False, description="Whether donor's parents are alive"
    )


class DonationSimulationResponse(BaseModel):
    """Response model for donation simulation."""

    montantDonation: float = Field(..., description="Donation amount (CHF)")
    tauxImposition: float = Field(..., description="Tax rate")
    impotDonation: float = Field(..., description="Tax amount (CHF)")
    reserveHereditaireTotale: float = Field(..., description="Total reserved shares (CHF)")
    quotiteDisponible: float = Field(..., description="Freely disposable share (CHF)")
    donationDepasseQuotite: bool = Field(..., description="Whether donation exceeds quotite")
    montantDepassement: float = Field(..., description="Excess amount (CHF)")
    impactSuccession: str = Field(..., description="Impact on future succession")
    checklist: List[str] = Field(default_factory=list, description="Action items")
    alerts: List[str] = Field(default_factory=list, description="Warning messages")
    disclaimer: str = Field(..., description="Legal disclaimer")
    sources: List[str] = Field(default_factory=list, description="Legal references")
    chiffreChoc: dict = Field(default_factory=dict, description="Impact number")


# ---------------------------------------------------------------------------
# Housing Sale Schemas
# ---------------------------------------------------------------------------

class HousingSaleSimulationRequest(BaseModel):
    """Request model for housing sale simulation."""

    prixAchat: float = Field(
        ..., description="Purchase price (CHF)", ge=0
    )
    prixVente: float = Field(
        ..., description="Sale price (CHF)", ge=0
    )
    anneeAchat: int = Field(
        ..., description="Year of purchase", ge=1900, le=2100
    )
    anneeVente: int = Field(
        2025, description="Year of sale", ge=1900, le=2100
    )
    investissementsValorisants: float = Field(
        0.0, description="Value-adding renovations (CHF)", ge=0
    )
    fraisAcquisition: float = Field(
        0.0, description="Notary fees at purchase (CHF)", ge=0
    )
    canton: str = Field(
        "GE", description="Canton code (2-letter)", min_length=2, max_length=2
    )
    residencePrincipale: bool = Field(
        True, description="Primary residence?"
    )
    eplLppUtilise: float = Field(
        0.0, description="LPP EPL used for purchase (CHF)", ge=0
    )
    epl3aUtilise: float = Field(
        0.0, description="3a EPL used for purchase (CHF)", ge=0
    )
    hypothequeRestante: float = Field(
        0.0, description="Remaining mortgage balance (CHF)", ge=0
    )
    projetRemploi: bool = Field(
        False, description="Plans to buy replacement property within 2 years?"
    )
    prixRemploi: float = Field(
        0.0, description="Price of replacement property (CHF)", ge=0
    )


class HousingSaleSimulationResponse(BaseModel):
    """Response model for housing sale simulation."""

    plusValueBrute: float = Field(..., description="Gross capital gain (CHF)")
    plusValueImposable: float = Field(..., description="Taxable capital gain (CHF)")
    dureeDetention: int = Field(..., description="Years of ownership")
    tauxImpositionPlusValue: float = Field(..., description="Tax rate")
    impotPlusValue: float = Field(..., description="Tax on capital gain (CHF)")
    remploiReport: float = Field(..., description="Tax deferred via reinvestment (CHF)")
    impotEffectif: float = Field(..., description="Actual tax due (CHF)")
    remboursementEplLpp: float = Field(..., description="EPL LPP to repay (CHF)")
    remboursementEpl3a: float = Field(..., description="EPL 3a to repay (CHF)")
    soldeHypotheque: float = Field(..., description="Mortgage payoff (CHF)")
    produitNet: float = Field(..., description="Net proceeds (CHF)")
    checklist: List[str] = Field(default_factory=list, description="Action items")
    alerts: List[str] = Field(default_factory=list, description="Warning messages")
    disclaimer: str = Field(..., description="Legal disclaimer")
    sources: List[str] = Field(default_factory=list, description="Legal references")
    chiffreChoc: dict = Field(default_factory=dict, description="Impact number")
