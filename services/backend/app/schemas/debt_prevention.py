"""
Pydantic v2 schemas for the Debt Prevention module.

Sprint S16 — Gap G6: Prevention dette.
API convention: camelCase field names, ConfigDict.

Covers:
    - Debt ratio assessment
    - Repayment planning (avalanche vs snowball)
    - Professional help resources
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional


# ===========================================================================
# Debt Ratio Schemas
# ===========================================================================

class DebtRatioRequest(BaseModel):
    """Request for debt ratio calculation."""

    model_config = ConfigDict(populate_by_name=True)

    revenusMensuels: float = Field(
        ..., alias="revenusMensuels",
        description="Revenus mensuels nets (CHF)", ge=0
    )
    chargesDetteMensuelles: float = Field(
        ..., alias="chargesDetteMensuelles",
        description="Charges mensuelles de dette (credits, leasing) (CHF)", ge=0
    )
    loyer: float = Field(
        ..., description="Loyer mensuel (CHF)", ge=0
    )
    autresChargesFixes: float = Field(
        0, alias="autresChargesFixes",
        description="Autres charges fixes mensuelles (assurances, etc.) (CHF)", ge=0
    )
    situationFamiliale: str = Field(
        "celibataire", alias="situationFamiliale",
        description="Situation familiale: celibataire ou couple"
    )
    nbEnfants: int = Field(
        0, alias="nbEnfants",
        description="Nombre d'enfants a charge", ge=0
    )


class DebtRatioResponse(BaseModel):
    """Full response for debt ratio assessment."""

    model_config = ConfigDict(populate_by_name=True)

    # Ratio
    ratioEndettement: float = Field(
        ..., alias="ratioEndettement",
        description="Ratio dette/revenu (0-1)"
    )
    ratioPct: float = Field(
        ..., alias="ratioPct",
        description="Ratio en pourcentage (0-100)"
    )
    niveauRisque: str = Field(
        ..., alias="niveauRisque",
        description="Niveau: vert, orange, rouge"
    )

    # Breakdown
    revenusMensuels: float = Field(..., alias="revenusMensuels")
    chargesDetteMensuelles: float = Field(..., alias="chargesDetteMensuelles")
    loyer: float
    autresChargesFixes: float = Field(..., alias="autresChargesFixes")
    totalChargesFixes: float = Field(
        ..., alias="totalChargesFixes",
        description="Total charges fixes (CHF)"
    )
    disponibleMensuel: float = Field(
        ..., alias="disponibleMensuel",
        description="Disponible mensuel apres charges (CHF)"
    )

    # Minimum vital
    minimumVital: float = Field(
        ..., alias="minimumVital",
        description="Minimum vital insaisissable (CHF)"
    )
    margeVsMinimumVital: float = Field(
        ..., alias="margeVsMinimumVital",
        description="Marge par rapport au minimum vital (CHF)"
    )
    enDessousMinimumVital: bool = Field(
        ..., alias="enDessousMinimumVital",
        description="Est-on en dessous du minimum vital?"
    )

    # Compliance
    chiffreChoc: str = Field(
        ..., alias="chiffreChoc",
        description="Chiffre choc"
    )
    recommandations: List[str] = Field(default_factory=list)
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Repayment Plan Schemas
# ===========================================================================

class DebtItemRequest(BaseModel):
    """A single debt item."""

    model_config = ConfigDict(populate_by_name=True)

    nom: str = Field(..., description="Nom de la dette")
    montant: float = Field(..., description="Montant restant (CHF)", ge=0)
    taux: float = Field(..., description="Taux d'interet annuel (0-0.30)", ge=0, le=0.30)
    mensualiteMin: float = Field(
        ..., alias="mensualiteMin",
        description="Mensualite minimale (CHF)", ge=0
    )


class RepaymentPlanRequest(BaseModel):
    """Request for repayment plan."""

    model_config = ConfigDict(populate_by_name=True)

    dettes: List[DebtItemRequest] = Field(
        ..., description="Liste des dettes", min_length=1
    )
    budgetMensuelRemboursement: float = Field(
        ..., alias="budgetMensuelRemboursement",
        description="Budget mensuel total pour le remboursement (CHF)", ge=0
    )
    strategie: str = Field(
        "avalanche", description="Strategie: avalanche ou boule_de_neige"
    )


class MonthlyEntryResponse(BaseModel):
    """A single month in the repayment plan."""

    model_config = ConfigDict(populate_by_name=True)

    mois: int = Field(..., description="Numero du mois")
    detteNom: str = Field(
        ..., alias="detteNom",
        description="Nom de la dette"
    )
    paiement: float = Field(..., description="Paiement ce mois (CHF)")
    dontInterets: float = Field(
        ..., alias="dontInterets",
        description="Part interets (CHF)"
    )
    dontCapital: float = Field(
        ..., alias="dontCapital",
        description="Part capital (CHF)"
    )
    soldeRestant: float = Field(
        ..., alias="soldeRestant",
        description="Solde restant (CHF)"
    )


class DebtPayoffEntryResponse(BaseModel):
    """Summary of when a debt is paid off."""

    model_config = ConfigDict(populate_by_name=True)

    nom: str
    moisLiberation: int = Field(
        ..., alias="moisLiberation",
        description="Mois de liberation"
    )
    totalInterets: float = Field(
        ..., alias="totalInterets",
        description="Total interets payes (CHF)"
    )
    montantInitial: float = Field(
        ..., alias="montantInitial",
        description="Montant initial de la dette (CHF)"
    )


class RepaymentPlanResponse(BaseModel):
    """Full response for repayment plan."""

    model_config = ConfigDict(populate_by_name=True)

    strategie: str
    dureeMois: int = Field(
        ..., alias="dureeMois",
        description="Duree totale en mois"
    )
    totalInterets: float = Field(
        ..., alias="totalInterets",
        description="Total interets payes (CHF)"
    )
    totalRembourse: float = Field(
        ..., alias="totalRembourse",
        description="Total rembourse (CHF)"
    )
    planMensuel: List[MonthlyEntryResponse] = Field(
        ..., alias="planMensuel",
        description="Plan mensuel (resume)"
    )
    payoffs: List[DebtPayoffEntryResponse] = Field(
        ..., description="Liberation de chaque dette"
    )

    budgetMensuel: float = Field(..., alias="budgetMensuel")
    nbDettes: int = Field(..., alias="nbDettes")

    # Compliance
    chiffreChoc: str = Field(
        ..., alias="chiffreChoc",
        description="Chiffre choc"
    )
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Resources Schemas
# ===========================================================================

class HelpResourceResponse(BaseModel):
    """A single help resource."""

    model_config = ConfigDict(populate_by_name=True)

    nom: str
    description: str
    url: Optional[str] = None
    telephone: Optional[str] = None
    canton: Optional[str] = None
    gratuit: bool
    confidentiel: bool
    typeAide: str = Field(
        ..., alias="typeAide",
        description="Type: conseil, juridique, urgence, prevention"
    )


class HelpResourcesResponse(BaseModel):
    """Full response for help resources."""

    model_config = ConfigDict(populate_by_name=True)

    resources: List[HelpResourceResponse]
    canton: str
    situation: str

    # Compliance
    chiffreChoc: str = Field(
        ..., alias="chiffreChoc",
        description="Chiffre choc"
    )
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")
