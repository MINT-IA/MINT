"""
Pydantic v2 schemas for the Pillar 3a Deep Dive module.

Sprint S16 — Gap G1: 3a Deep.
API convention: camelCase field names, ConfigDict.

Covers:
    - Staggered withdrawal (multi-account tax optimization)
    - Real return calculator (with marginal tax rate)
    - Provider comparator (fintech vs bank vs insurance)
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional


# ===========================================================================
# Staggered Withdrawal Schemas
# ===========================================================================

class StaggeredWithdrawalRequest(BaseModel):
    """Request for staggered 3a withdrawal simulation."""

    model_config = ConfigDict(populate_by_name=True)

    avoirTotal: float = Field(
        ..., alias="avoirTotal",
        description="Avoir 3a total (CHF)", ge=0
    )
    nbComptes: int = Field(
        3, alias="nbComptes",
        description="Nombre de comptes 3a (1-5)", ge=1, le=5
    )
    canton: str = Field(
        ..., description="Code canton (ex: ZH, VD, GE)",
        min_length=2, max_length=2
    )
    revenuImposable: float = Field(
        ..., alias="revenuImposable",
        description="Revenu imposable annuel (CHF)", ge=0, le=10_000_000
    )
    ageRetraitDebut: int = Field(
        60, alias="ageRetraitDebut",
        description="Age au premier retrait", ge=59, le=70
    )
    ageRetraitFin: int = Field(
        64, alias="ageRetraitFin",
        description="Age au dernier retrait", ge=59, le=70
    )


class YearlyWithdrawalEntryResponse(BaseModel):
    """A single year in the staggered withdrawal plan."""

    model_config = ConfigDict(populate_by_name=True)

    annee: int = Field(..., description="Annee du plan (1-based)")
    age: int = Field(..., description="Age au moment du retrait")
    montantRetrait: float = Field(
        ..., alias="montantRetrait",
        description="Montant retire cette annee (CHF)"
    )
    tauxImposition: float = Field(
        ..., alias="tauxImposition",
        description="Taux d'imposition effectif"
    )
    impot: float = Field(..., description="Impot paye (CHF)")
    netRecu: float = Field(
        ..., alias="netRecu",
        description="Montant net recu (CHF)"
    )


class StaggeredWithdrawalResponse(BaseModel):
    """Full response for staggered withdrawal simulation."""

    model_config = ConfigDict(populate_by_name=True)

    # Bloc
    blocTax: float = Field(
        ..., alias="blocTax",
        description="Impot si retrait en bloc (CHF)"
    )
    blocTauxEffectif: float = Field(
        ..., alias="blocTauxEffectif",
        description="Taux effectif retrait en bloc"
    )

    # Staggered
    staggeredTax: float = Field(
        ..., alias="staggeredTax",
        description="Impot total echelonne (CHF)"
    )
    staggeredTauxEffectif: float = Field(
        ..., alias="staggeredTauxEffectif",
        description="Taux effectif moyen echelonne"
    )

    # Delta
    economy: float = Field(..., description="Economie fiscale (CHF)")
    economyPct: float = Field(
        ..., alias="economyPct",
        description="Economie en pourcentage (%)"
    )

    # Plan
    optimalAccounts: int = Field(
        ..., alias="optimalAccounts",
        description="Nombre optimal de comptes recommande"
    )
    yearlyPlan: List[YearlyWithdrawalEntryResponse] = Field(
        ..., alias="yearlyPlan",
        description="Plan annuel de retrait"
    )

    # Metadata
    avoirTotal: float = Field(..., alias="avoirTotal")
    nbComptes: int = Field(..., alias="nbComptes")
    canton: str = Field(..., description="Canton utilise")

    # Compliance
    premierEclairage: str = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc pour l'utilisateur"
    )
    alerts: List[str] = Field(default_factory=list)
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Real Return Schemas
# ===========================================================================

class RealReturnRequest(BaseModel):
    """Request for real return calculation."""

    model_config = ConfigDict(populate_by_name=True)

    versementAnnuel: float = Field(
        ..., alias="versementAnnuel",
        description="Versement annuel 3a (CHF)", ge=0, le=36288
    )
    tauxMarginal: float = Field(
        ..., alias="tauxMarginal",
        description="Taux marginal d'imposition (0-0.5)", ge=0, le=0.5
    )
    rendementBrut: float = Field(
        0.04, alias="rendementBrut",
        description="Rendement brut annuel (0-0.15)", ge=-0.10, le=0.15
    )
    fraisGestion: float = Field(
        0.005, alias="fraisGestion",
        description="Frais de gestion annuels (0-0.05)", ge=0, le=0.05
    )
    dureeAnnees: int = Field(
        30, alias="dureeAnnees",
        description="Duree en annees", ge=1, le=50
    )
    inflation: float = Field(
        0.01, description="Taux d'inflation annuel (0-0.10)", ge=0, le=0.10
    )


class RealReturnResponse(BaseModel):
    """Full response for real return calculation."""

    model_config = ConfigDict(populate_by_name=True)

    # 3a projection
    versementAnnuel: float = Field(..., alias="versementAnnuel")
    totalVerse: float = Field(..., alias="totalVerse")
    capitalFinal3a: float = Field(
        ..., alias="capitalFinal3a",
        description="Capital final 3a (CHF)"
    )
    rendementNetAnnuel: float = Field(
        ..., alias="rendementNetAnnuel",
        description="Rendement net annuel (apres frais et inflation)"
    )
    totalEconomiesFiscales: float = Field(
        ..., alias="totalEconomiesFiscales",
        description="Total des economies fiscales sur la duree (CHF)"
    )

    # Real return
    rendementReelAnnualise: float = Field(
        ..., alias="rendementReelAnnualise",
        description="Rendement reel annualise incluant economies fiscales (%)"
    )
    rendementBrut: float = Field(..., alias="rendementBrut")
    fraisGestion: float = Field(..., alias="fraisGestion")
    inflation: float = Field(...)

    # Comparison
    capitalFinalEpargne: float = Field(
        ..., alias="capitalFinalEpargne",
        description="Capital final sur compte epargne (CHF)"
    )
    rendementEpargne: float = Field(
        ..., alias="rendementEpargne",
        description="Taux du compte epargne (%)"
    )
    avantage3aVsEpargne: float = Field(
        ..., alias="avantage3aVsEpargne",
        description="Avantage 3a vs epargne (CHF)"
    )

    # Metadata
    dureeAnnees: int = Field(..., alias="dureeAnnees")
    tauxMarginal: float = Field(..., alias="tauxMarginal")

    # Compliance
    premierEclairage: str = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc"
    )
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Provider Comparator Schemas
# ===========================================================================

class ProviderCompareRequest(BaseModel):
    """Request for provider comparison."""

    model_config = ConfigDict(populate_by_name=True)

    age: int = Field(..., description="Age actuel", ge=18, le=70)
    versementAnnuel: float = Field(
        ..., alias="versementAnnuel",
        description="Versement annuel 3a (CHF)", ge=0, le=36288
    )
    duree: int = Field(..., description="Duree en annees", ge=1, le=50)
    profilRisque: str = Field(
        "equilibre", alias="profilRisque",
        description="Profil de risque: prudent, equilibre, dynamique"
    )


class ProviderProjectionResponse(BaseModel):
    """Projection for a single provider."""

    model_config = ConfigDict(populate_by_name=True)

    nom: str = Field(..., description="Nom du provider")
    typeProvider: str = Field(
        ..., alias="typeProvider",
        description="Type: fintech, banque, assurance"
    )
    rendementBrut: float = Field(..., alias="rendementBrut")
    fraisGestion: float = Field(..., alias="fraisGestion")
    rendementNet: float = Field(..., alias="rendementNet")
    capitalFinal: float = Field(
        ..., alias="capitalFinal",
        description="Capital final projete (CHF)"
    )
    totalVerse: float = Field(..., alias="totalVerse")
    gainNet: float = Field(
        ..., alias="gainNet",
        description="Gain net (CHF)"
    )
    engagementAnnees: Optional[int] = Field(
        None, alias="engagementAnnees",
        description="Duree d'engagement minimale (annees)"
    )
    note: str = Field(..., description="Description")
    warning: Optional[str] = Field(
        None, description="Avertissement special"
    )


class ProviderCompareResponse(BaseModel):
    """Full response for provider comparison."""

    model_config = ConfigDict(populate_by_name=True)

    projections: List[ProviderProjectionResponse] = Field(
        ..., description="Projections par provider"
    )
    capitalPlusHaut: str = Field(
        ..., alias="capitalPlusHaut",
        description="Nom du provider au capital final le plus haut"
    )
    capitalPlusBas: str = Field(
        ..., alias="capitalPlusBas",
        description="Nom du provider au capital final le plus bas"
    )
    differenceMax: float = Field(
        ..., alias="differenceMax",
        description="Ecart max entre le plus haut et le plus bas (CHF)"
    )

    # Input summary
    age: int
    versementAnnuel: float = Field(..., alias="versementAnnuel")
    duree: int
    profilRisque: str = Field(..., alias="profilRisque")

    # Compliance
    premierEclairage: str = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc"
    )
    baseLegale: str = Field(..., alias="baseLegale")
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")
