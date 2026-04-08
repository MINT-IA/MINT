"""
Pydantic v2 schemas for the Retirement planning module.

Sprint S21 — Retraite complete — Complete retirement planning.
API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - AVS pension estimation (anticipation / normal / deferral)
    - LPP capital vs rente comparison
    - Retirement budget reconciliation + PC eligibility
    - Full retirement assessment (combined endpoint)
"""

from enum import Enum
from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import Dict, List, Optional


# ===========================================================================
# Enums
# ===========================================================================

class RetirementScenario(str, Enum):
    """AVS retirement scenario type."""
    anticipation = "anticipation"
    normal = "normal"
    ajournement = "ajournement"


# ===========================================================================
# AVS Estimation Schemas
# ===========================================================================

class AvsEstimationRequest(BaseModel):
    """Request for AVS pension estimation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    age_actuel: int = Field(
        ..., ge=18, le=70,
        description="Age actuel de la personne",
    )
    age_retraite: int = Field(
        default=65, ge=63, le=70,
        description="Age de depart a la retraite souhaite (63-70)",
    )
    is_couple: bool = Field(
        default=False,
        description="Couple: plafonnement a 150% de la rente individuelle",
    )
    annees_lacunes: int = Field(
        default=0, ge=0, le=44,
        description="Nombre d'annees de lacunes de cotisation AVS",
    )
    esperance_vie: int = Field(
        default=87, ge=65, le=100,
        description="Esperance de vie estimee pour le calcul cumulatif",
    )


class AvsEstimationResponse(BaseModel):
    """Response for AVS pension estimation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    scenario: str = Field(
        ..., description="Type de scenario: anticipation, normal, ajournement",
    )
    age_depart: int = Field(
        ..., description="Age de depart effectif",
    )
    rente_mensuelle: float = Field(
        ..., description="Rente mensuelle estimee (CHF)",
    )
    rente_annuelle: float = Field(
        ..., description="Rente annuelle estimee (CHF)",
    )
    facteur_ajustement: float = Field(
        ..., description="Facteur d'ajustement (1.0 = normal)",
    )
    penalite_ou_bonus_pct: float = Field(
        ..., description="Penalite (-) ou bonus (+) en %",
    )
    rente_couple_mensuelle: Optional[float] = Field(
        default=None,
        description="Rente couple mensuelle si applicable (CHF)",
    )
    duree_estimee_ans: int = Field(
        ..., description="Duree estimee en annees (retraite -> esperance de vie)",
    )
    total_cumule: float = Field(
        ..., description="Total cumule sur la duree estimee (CHF)",
    )
    breakeven_vs_normal: Optional[int] = Field(
        default=None,
        description="Age de breakeven vs scenario normal",
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# LPP Conversion Schemas
# ===========================================================================

class LppConversionRequest(BaseModel):
    """Request for LPP capital vs rente comparison."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    capital_lpp: float = Field(
        ..., gt=0,
        description="Capital LPP total a la retraite (CHF)",
    )
    canton: str = Field(
        default="ZH", min_length=2, max_length=2,
        description="Code canton pour estimation fiscale",
    )
    age_retraite: int = Field(
        default=65, ge=60, le=70,
        description="Age de depart a la retraite",
    )
    esperance_vie: int = Field(
        default=87, ge=65, le=100,
        description="Esperance de vie estimee",
    )


class LppConversionResponse(BaseModel):
    """Response for LPP capital vs rente comparison."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    capital_total: float = Field(
        ..., description="Capital LPP total (CHF)",
    )
    option_rente_brute_mensuelle: float = Field(
        ..., description="Rente brute mensuelle a vie (CHF)",
    )
    option_rente_annuelle: float = Field(
        ..., description="Rente brute annuelle a vie (CHF)",
    )
    rente_impot_annuel: float = Field(
        ..., description="Impot annuel estime sur la rente (LIFD art. 22) (CHF)",
    )
    option_rente_nette_mensuelle: float = Field(
        ..., description="Rente nette mensuelle apres impot sur le revenu (CHF)",
    )
    option_rente_nette_annuelle: float = Field(
        ..., description="Rente nette annuelle apres impot sur le revenu (CHF)",
    )
    option_capital_brut: float = Field(
        ..., description="Capital brut (CHF)",
    )
    option_capital_impot: float = Field(
        ..., description="Impot estime sur le retrait en capital (CHF)",
    )
    option_capital_net: float = Field(
        ..., description="Capital net apres impot (CHF)",
    )
    breakeven_age: int = Field(
        ..., description="Age de breakeven (rente nette > capital net)",
    )
    recommandation_neutre: str = Field(
        ..., description="Recommandation neutre sans biais",
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Retirement Budget Schemas
# ===========================================================================

class RetirementBudgetRequest(BaseModel):
    """Request for retirement budget reconciliation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    avs_mensuel: float = Field(
        ..., ge=0,
        description="Rente AVS mensuelle estimee (CHF)",
    )
    lpp_mensuel: float = Field(
        ..., ge=0,
        description="Rente LPP mensuelle estimee (CHF)",
    )
    capital_3a_net: float = Field(
        default=0, ge=0,
        description="Capital 3a net apres impot (CHF)",
    )
    autres_revenus: float = Field(
        default=0, ge=0,
        description="Autres revenus mensuels (CHF)",
    )
    depenses_mensuelles: float = Field(
        ..., gt=0,
        description="Depenses mensuelles estimees (CHF)",
    )
    revenu_pre_retraite: float = Field(
        ..., gt=0,
        description="Revenu mensuel actuel avant retraite (CHF)",
    )
    is_couple: bool = Field(
        default=False,
        description="Evaluation pour un couple",
    )


class RetirementBudgetResponse(BaseModel):
    """Response for retirement budget reconciliation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    revenus_garantis: Dict[str, float] = Field(
        ..., description="Revenus garantis mensuels par source (AVS, LPP, autres)",
    )
    capital_epuisable: Dict[str, float] = Field(
        ..., description="Capital epuisable mensualise par source (3a). Ce n'est pas un revenu garanti.",
    )
    total_revenus_mensuels: float = Field(
        ..., description="Total des revenus mensuels (revenus garantis + capital epuisable) (CHF)",
    )
    depenses_mensuelles_estimees: float = Field(
        ..., description="Depenses mensuelles estimees (CHF)",
    )
    solde_mensuel: float = Field(
        ..., description="Solde mensuel (positif = surplus, negatif = deficit)",
    )
    taux_remplacement: float = Field(
        ..., description="Taux de remplacement (% du revenu pre-retraite)",
    )
    pc_potentiellement_eligible: bool = Field(
        ..., description="Eligibilite indicative aux prestations complementaires (PC)",
    )
    duree_capital_3a_ans: float = Field(
        ..., description="Duree de couverture du capital 3a en annees",
    )
    alertes: List[str] = Field(
        default_factory=list,
        description="Alertes contextuelles",
    )
    premier_eclairage: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    checklist: List[str] = Field(
        default_factory=list,
        description="Checklist de preparation a la retraite",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="Sources legales",
    )


# ===========================================================================
# Full Retirement Assessment (combined endpoint)
# ===========================================================================

class RetirementFullRequest(BaseModel):
    """Request for complete retirement assessment (all 3 pillars combined)."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    age_actuel: int = Field(
        ..., ge=18, le=70,
        description="Age actuel",
    )
    age_retraite: int = Field(
        default=65, ge=63, le=70,
        description="Age de depart a la retraite souhaite",
    )
    is_couple: bool = Field(
        default=False,
        description="Evaluation pour un couple",
    )
    annees_lacunes: int = Field(
        default=0, ge=0,
        description="Annees de lacunes AVS",
    )
    capital_lpp: float = Field(
        ..., gt=0,
        description="Capital LPP total (CHF)",
    )
    capital_3a: float = Field(
        default=0, ge=0,
        description="Capital 3a total (CHF)",
    )
    canton: str = Field(
        default="ZH",
        description="Code canton",
    )
    depenses_mensuelles: float = Field(
        ..., gt=0,
        description="Depenses mensuelles estimees (CHF)",
    )
    revenu_actuel_mensuel: float = Field(
        ..., gt=0,
        description="Revenu mensuel actuel (CHF)",
    )
    esperance_vie: int = Field(
        default=87,
        description="Esperance de vie estimee",
    )
