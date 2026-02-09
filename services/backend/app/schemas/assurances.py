"""
Pydantic schemas for the Assurances module.

Sprint S13, Chantier 7: Assurances completes.
LAMal franchise optimizer + Coverage checklist.

API convention: camelCase field names.
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
from enum import Enum


# ===========================================================================
# Enums
# ===========================================================================

class AgeCategory(str, Enum):
    adult = "adult"
    child = "child"


class StatutProfessionnel(str, Enum):
    salarie = "salarie"
    independant = "independant"
    sans_emploi = "sans_emploi"


# ===========================================================================
# LAMal Franchise Schemas
# ===========================================================================

class LamalFranchiseRequest(BaseModel):
    """Request model for LAMal franchise optimization."""

    model_config = ConfigDict(populate_by_name=True)

    primeMensuelleBase: float = Field(
        ...,
        description="Prime mensuelle a la franchise 300 CHF (adulte) ou 0 CHF (enfant)",
        gt=0,
    )
    depensesSanteAnnuelles: float = Field(
        ...,
        description="Depenses de sante annuelles estimees (CHF)",
        ge=0,
    )
    ageCategory: AgeCategory = Field(
        AgeCategory.adult,
        description="Categorie d'age : adult ou child",
    )


class FranchiseComparisonResponse(BaseModel):
    """A single franchise level comparison entry."""

    model_config = ConfigDict(populate_by_name=True)

    franchise: int = Field(..., description="Niveau de franchise (CHF)")
    primeAnnuelle: float = Field(..., description="Prime annuelle (CHF)")
    franchiseEffective: float = Field(
        ..., description="Franchise effectivement payee (CHF)"
    )
    quotePart: float = Field(..., description="Quote-part (CHF)")
    coutTotal: float = Field(..., description="Cout total annuel (CHF)")
    economieVsRef: float = Field(
        ..., description="Economie par rapport a la franchise de reference (CHF)"
    )


class BreakEvenResponse(BaseModel):
    """Break-even point between two franchise levels."""

    model_config = ConfigDict(populate_by_name=True)

    franchiseBasse: int = Field(..., description="Franchise basse (CHF)")
    franchiseHaute: int = Field(..., description="Franchise haute (CHF)")
    seuilDepenses: float = Field(
        ..., description="Seuil de depenses au point d'equilibre (CHF)"
    )


class RecommandationResponse(BaseModel):
    """A single recommendation."""

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(..., description="Identifiant de la recommandation")
    titre: str = Field(..., description="Titre")
    description: str = Field(..., description="Description detaillee")
    source: str = Field(..., description="Source legale")
    priorite: str = Field(..., description="Priorite : haute, moyenne, basse")


class LamalFranchiseResponse(BaseModel):
    """Response model for LAMal franchise optimization."""

    model_config = ConfigDict(populate_by_name=True)

    comparaison: List[FranchiseComparisonResponse] = Field(
        ..., description="Comparaison de toutes les franchises"
    )
    franchiseOptimale: int = Field(
        ..., description="Franchise optimale calculee (CHF)"
    )
    breakEvenPoints: List[BreakEvenResponse] = Field(
        default_factory=list,
        description="Points d'equilibre entre franchises consecutives",
    )
    recommandations: List[RecommandationResponse] = Field(
        default_factory=list, description="Recommandations personnalisees"
    )
    alerteDelai: str = Field(
        ..., description="Rappel de delai pour le changement de franchise"
    )
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Coverage Checklist Schemas
# ===========================================================================

class ChecklistItemResponse(BaseModel):
    """A single insurance checklist item."""

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(..., description="Identifiant")
    categorie: str = Field(
        ..., description="Categorie : obligatoire, recommandee, optionnelle"
    )
    titre: str = Field(..., description="Titre de l'assurance")
    description: str = Field(..., description="Description")
    urgence: str = Field(
        ..., description="Urgence : critique, haute, moyenne, basse"
    )
    statut: str = Field(
        ..., description="Statut : couvert, non_couvert, a_verifier"
    )
    coutEstimeAnnuel: Optional[str] = Field(
        None, description="Fourchette de cout annuel estime"
    )
    source: str = Field(..., description="Source legale")


class CoverageCheckRequest(BaseModel):
    """Request model for coverage checklist evaluation."""

    model_config = ConfigDict(populate_by_name=True)

    statutProfessionnel: StatutProfessionnel = Field(
        ..., description="Statut professionnel"
    )
    aHypotheque: bool = Field(
        False, description="A une hypotheque en cours"
    )
    aFamille: bool = Field(
        False, description="A des personnes dependantes"
    )
    estLocataire: bool = Field(
        False, description="Est locataire"
    )
    voyagesFrequents: bool = Field(
        False, description="Voyage frequemment"
    )
    aIjmCollective: bool = Field(
        False, description="A une IJM collective via l'employeur"
    )
    aLaa: bool = Field(
        False, description="A une assurance accidents (LAA)"
    )
    aRcPrivee: bool = Field(
        False, description="A une RC privee"
    )
    aMenage: bool = Field(
        False, description="A une assurance menage"
    )
    aProtectionJuridique: bool = Field(
        False, description="A une protection juridique"
    )
    aAssuranceVoyage: bool = Field(
        False, description="A une assurance voyage"
    )
    aAssuranceDeces: bool = Field(
        False, description="A une assurance deces"
    )
    canton: str = Field(
        "GE",
        description="Canton de residence (code 2 lettres)",
        max_length=2,
    )


class CoverageCheckResponse(BaseModel):
    """Response model for coverage checklist evaluation."""

    model_config = ConfigDict(populate_by_name=True)

    checklist: List[ChecklistItemResponse] = Field(
        ..., description="Liste des assurances evaluees"
    )
    scoreCouverture: int = Field(
        ..., description="Score de couverture (0-100)"
    )
    lacunesCritiques: int = Field(
        ..., description="Nombre de lacunes critiques"
    )
    recommandations: List[RecommandationResponse] = Field(
        default_factory=list, description="Recommandations"
    )
    disclaimer: str = Field(..., description="Avertissement legal")
