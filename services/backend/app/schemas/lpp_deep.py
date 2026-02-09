"""
Pydantic v2 schemas for the LPP Deep Dive module.

Sprint S15 — Chantier 4: LPP approfondi.
API convention: camelCase field names, ConfigDict.

Covers:
    - Rachat echelonne (stepped buyback) simulator
    - Libre passage (vested benefits) advisor
    - EPL (home ownership encouragement) simulator
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
from enum import Enum


# ===========================================================================
# Enums
# ===========================================================================

class StatutLibrePassageEnum(str, Enum):
    changement_emploi = "changement_emploi"
    depart_suisse = "depart_suisse"
    cessation_activite = "cessation_activite"


class DestinationDepartEnum(str, Enum):
    eu_aele = "eu_aele"
    hors_eu = "hors_eu"


# ===========================================================================
# Rachat Echelonne Schemas
# ===========================================================================

class RachatEchelonneRequest(BaseModel):
    """Request for stepped LPP buyback simulation."""

    model_config = ConfigDict(populate_by_name=True)

    avoirActuel: float = Field(
        ..., description="Avoir LPP actuel (CHF)", ge=0
    )
    rachatMax: float = Field(
        ..., description="Montant de rachat maximum selon le certificat LPP (CHF)", ge=0
    )
    revenuImposable: float = Field(
        ..., description="Revenu imposable annuel (CHF)", ge=0
    )
    tauxMarginalEstime: Optional[float] = Field(
        None, description="Taux marginal estime (0-1). Si absent, calcule selon le canton.", ge=0, le=1
    )
    canton: str = Field(
        ..., description="Code canton (ex: ZH, VD, GE)", min_length=2, max_length=2
    )
    horizonRachatAnnees: int = Field(
        3, description="Nombre d'annees pour echelonner le rachat (1-5)", ge=1, le=5
    )


class RachatAnnuelEntryResponse(BaseModel):
    """A single year in the stepped buyback plan."""

    model_config = ConfigDict(populate_by_name=True)

    annee: int = Field(..., description="Annee du plan (1-5)")
    montantRachat: float = Field(..., description="Montant du rachat pour cette annee (CHF)")
    revenuImposableAvant: float = Field(..., description="Revenu imposable avant rachat (CHF)")
    revenuImposableApres: float = Field(..., description="Revenu imposable apres rachat (CHF)")
    tauxMarginalAvant: float = Field(..., description="Taux marginal avant rachat")
    tauxMarginalApres: float = Field(..., description="Taux marginal apres rachat")
    economieFiscale: float = Field(..., description="Economie fiscale (CHF)")
    coutNet: float = Field(..., description="Cout net du rachat (CHF)")


class RachatEchelonneResponse(BaseModel):
    """Full response for stepped buyback simulation."""

    model_config = ConfigDict(populate_by_name=True)

    plan: List[RachatAnnuelEntryResponse] = Field(
        ..., description="Plan annuel de rachat echelonne"
    )
    horizonAnnees: int = Field(..., description="Nombre d'annees du plan")
    totalRachat: float = Field(..., description="Total des rachats (CHF)")
    totalEconomieFiscale: float = Field(
        ..., description="Economie fiscale totale echelonnee (CHF)"
    )
    totalCoutNet: float = Field(..., description="Cout net total (CHF)")

    # Bloc comparison
    blocEconomieFiscale: float = Field(
        ..., description="Economie fiscale si rachat en bloc (1 an) (CHF)"
    )
    blocCoutNet: float = Field(
        ..., description="Cout net si rachat en bloc (1 an) (CHF)"
    )

    # Delta
    economieVsBloc: float = Field(
        ..., description="Gain de l'echelonnement vs bloc (CHF)"
    )
    economieVsBlocPct: float = Field(
        ..., description="Gain en pourcentage (%)"
    )

    canton: str = Field(..., description="Canton utilise pour le calcul")
    blocageEplFin: int = Field(
        ..., description="Annee a partir de laquelle un retrait EPL est possible"
    )

    alerts: List[str] = Field(default_factory=list, description="Alertes et recommandations")
    sources: List[str] = Field(default_factory=list, description="Sources legales")
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Libre Passage Schemas
# ===========================================================================

class LibrePassageRequest(BaseModel):
    """Request for libre passage analysis."""

    model_config = ConfigDict(populate_by_name=True)

    statut: StatutLibrePassageEnum = Field(
        ..., description="Statut: changement_emploi, depart_suisse, cessation_activite"
    )
    avoirLibrePassage: float = Field(
        ..., description="Montant total des avoirs de libre passage (CHF)", ge=0
    )
    age: int = Field(..., description="Age de la personne", ge=18, le=70)
    aNouvelEmployeur: bool = Field(
        False, description="La personne a-t-elle un nouvel employeur?"
    )
    delaiJours: Optional[int] = Field(
        None, description="Nombre de jours depuis le depart de l'ancien employeur", ge=0
    )
    destination: Optional[DestinationDepartEnum] = Field(
        None, description="Destination en cas de depart de Suisse (eu_aele, hors_eu)"
    )
    avoirObligatoire: Optional[float] = Field(
        None, description="Part obligatoire LPP (CHF)", ge=0
    )
    avoirSurobligatoire: Optional[float] = Field(
        None, description="Part surobligatoire LPP (CHF)", ge=0
    )


class ActionItemResponse(BaseModel):
    """A single action item."""

    model_config = ConfigDict(populate_by_name=True)

    description: str = Field(..., description="Description de l'action")
    delai: Optional[str] = Field(None, description="Delai ou echeance")
    priorite: str = Field("haute", description="Priorite: haute, moyenne, basse")
    sourceLegale: Optional[str] = Field(None, description="Source legale")


class AlerteResponse(BaseModel):
    """An alert for the user."""

    model_config = ConfigDict(populate_by_name=True)

    niveau: str = Field(..., description="Niveau: critique, important, info")
    message: str = Field(..., description="Message d'alerte")
    sourceLegale: Optional[str] = Field(None, description="Source legale")


class RecommandationResponse(BaseModel):
    """A recommendation."""

    model_config = ConfigDict(populate_by_name=True)

    titre: str = Field(..., description="Titre de la recommandation")
    description: str = Field(..., description="Description detaillee")
    sourceLegale: Optional[str] = Field(None, description="Source legale")


class LibrePassageResponse(BaseModel):
    """Full response for libre passage analysis."""

    model_config = ConfigDict(populate_by_name=True)

    statut: str = Field(..., description="Statut analyse")
    checklist: List[ActionItemResponse] = Field(
        ..., description="Liste des actions a entreprendre"
    )
    alertes: List[AlerteResponse] = Field(
        ..., description="Alertes importantes"
    )
    recommandations: List[RecommandationResponse] = Field(
        ..., description="Recommandations personnalisees"
    )
    peutRetirerCapital: bool = Field(
        ..., description="La personne peut-elle retirer son capital?"
    )
    montantRetirable: float = Field(
        ..., description="Montant retirable (CHF)"
    )
    montantBloque: float = Field(
        ..., description="Montant bloque (CHF)"
    )
    sources: List[str] = Field(default_factory=list, description="Sources legales")
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# EPL Schemas
# ===========================================================================

class EPLRequest(BaseModel):
    """Request for EPL (home ownership encouragement) simulation."""

    model_config = ConfigDict(populate_by_name=True)

    avoirLppTotal: float = Field(
        ..., description="Avoir LPP total (CHF)", ge=0
    )
    avoirObligatoire: float = Field(
        ..., description="Part obligatoire (CHF)", ge=0
    )
    avoirSurobligatoire: float = Field(
        ..., description="Part surobligatoire (CHF)", ge=0
    )
    age: int = Field(..., description="Age de la personne", ge=18, le=70)
    montantRetraitSouhaite: float = Field(
        ..., description="Montant de retrait souhaite (CHF)", ge=0
    )
    aRacheteRecemment: bool = Field(
        False, description="Un rachat LPP a-t-il ete effectue recemment?"
    )
    anneesDernierRachat: Optional[int] = Field(
        None, description="Nombre d'annees depuis le dernier rachat", ge=0
    )
    avoirA50Ans: Optional[float] = Field(
        None, description="Avoir LPP a 50 ans (si connu, pour la regle des 50 ans)", ge=0
    )
    canton: str = Field(
        "ZH", description="Code canton pour l'estimation fiscale", min_length=2, max_length=2
    )


class ImpactPrestationsResponse(BaseModel):
    """Impact on death and disability benefits."""

    model_config = ConfigDict(populate_by_name=True)

    renteInvaliditeReductionPct: float = Field(
        ..., description="Reduction de la rente d'invalidite (%)"
    )
    capitalDecesReductionPct: float = Field(
        ..., description="Reduction du capital deces (%)"
    )
    renteInvaliditeReductionChf: float = Field(
        ..., description="Reduction estimee de la rente d'invalidite (CHF/an)"
    )
    capitalDecesReductionChf: float = Field(
        ..., description="Reduction estimee du capital deces (CHF)"
    )
    message: str = Field(
        ..., description="Explication de l'impact sur les prestations"
    )


class EPLResponse(BaseModel):
    """Full response for EPL simulation."""

    model_config = ConfigDict(populate_by_name=True)

    montantRetirableMax: float = Field(
        ..., description="Montant maximum retirable (CHF)"
    )
    montantDemande: float = Field(
        ..., description="Montant demande (CHF)"
    )
    montantEffectif: float = Field(
        ..., description="Montant effectivement retirable (CHF)"
    )
    respecteMinimum: bool = Field(
        ..., description="Le minimum de 20'000 CHF est-il respecte?"
    )
    age: int = Field(..., description="Age de la personne")
    regleAge50Appliquee: bool = Field(
        ..., description="La regle des 50 ans est-elle appliquee?"
    )
    avoirA50Ans: Optional[float] = Field(
        None, description="Avoir a 50 ans (si connu)"
    )

    # Tax
    impotRetraitEstime: float = Field(
        ..., description="Impot sur le retrait estime (CHF)"
    )
    canton: str = Field(..., description="Canton utilise pour le calcul fiscal")
    tauxImpotRetrait: float = Field(
        ..., description="Taux d'impot sur le retrait en capital"
    )

    # Impact on benefits
    impactPrestations: ImpactPrestationsResponse = Field(
        ..., description="Impact sur les prestations de risque"
    )

    # Buyback blocage
    blocageRachat: bool = Field(
        ..., description="Le retrait est-il bloque suite a un rachat recent?"
    )
    anneesDernierRachat: Optional[int] = Field(
        None, description="Annees depuis le dernier rachat"
    )
    anneesRestantesBlocage: int = Field(
        ..., description="Annees restantes de blocage"
    )

    # Checklist, alerts
    checklist: List[str] = Field(default_factory=list, description="Checklist des actions")
    alertes: List[str] = Field(default_factory=list, description="Alertes")
    sources: List[str] = Field(default_factory=list, description="Sources legales")
    disclaimer: str = Field(..., description="Avertissement legal")
