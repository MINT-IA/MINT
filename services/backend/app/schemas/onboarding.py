"""
Pydantic v2 schemas for the Onboarding module (Sprint S31).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - MinimalProfileRequest: input for minimal profile computation (3 required + 8 optional)
    - MinimalProfileResponse: full projection result with confidence scoring
    - ChiffreChocResponse: single impactful number with educational context
"""

from typing import List, Optional

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================

class OnboardingBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Request
# ===========================================================================

class MinimalProfileRequest(OnboardingBaseModel):
    """Requete pour le calcul du profil minimal d'onboarding.

    Seuls 3 champs sont requis: age, gross_salary, canton.
    Les champs optionnels enrichissent la projection et augmentent
    le score de confiance.
    """

    age: int = Field(
        ..., ge=18, le=70,
        description="Age de l'utilisateur (18-70)",
    )
    gross_salary: float = Field(
        ..., ge=0,
        description="Salaire brut annuel en CHF",
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres majuscules, ex: ZH, VD, GE)",
    )
    household_type: Optional[str] = Field(
        default=None,
        description="Type de menage: single, couple, family (defaut: single)",
    )
    current_savings: Optional[float] = Field(
        default=None, ge=0,
        description="Epargne disponible actuelle en CHF",
    )
    is_property_owner: Optional[bool] = Field(
        default=None,
        description="True si proprietaire d'un bien immobilier",
    )
    existing_3a: Optional[float] = Field(
        default=None, ge=0,
        description="Solde actuel du 3e pilier en CHF",
    )
    existing_lpp: Optional[float] = Field(
        default=None, ge=0,
        description="Avoir LPP actuel en CHF (certificat de prevoyance)",
    )
    lpp_caisse_type: Optional[str] = Field(
        default=None,
        pattern=r"^(base|complementaire)$",
        description="Type de caisse LPP: 'base' ou 'complementaire'",
    )
    total_debts: Optional[float] = Field(
        default=None, ge=0,
        description="Montant total des dettes en CHF",
    )
    monthly_debt_service: Optional[float] = Field(
        default=None, ge=0,
        description="Service de la dette mensuel en CHF",
    )
    stress_type: Optional[str] = Field(
        default=None,
        pattern=r"^(stress_retraite|stress_impots|stress_budget|stress_patrimoine|stress_couple|stress_general)$",
        description="Intention declaree par l'utilisateur a l'onboarding",
    )


# ===========================================================================
# Responses
# ===========================================================================

class MinimalProfileResponse(OnboardingBaseModel):
    """Resultat complet du profil minimal d'onboarding."""

    # Projections
    projected_avs_monthly: float = Field(
        ..., description="Rente AVS mensuelle projetee (CHF)",
    )
    projected_lpp_capital: float = Field(
        ..., description="Capital LPP projete a la retraite (CHF)",
    )
    projected_lpp_monthly: float = Field(
        ..., description="Rente LPP mensuelle projetee (CHF)",
    )
    estimated_replacement_ratio: float = Field(
        ..., description="Taux de remplacement estime (0.0 - 1.0+)",
    )
    estimated_monthly_retirement: float = Field(
        ..., description="Revenu mensuel estime a la retraite (CHF)",
    )
    estimated_monthly_expenses: float = Field(
        ..., description="Charges mensuelles estimees actuelles (CHF)",
    )
    retirement_gap_monthly: float = Field(
        ..., description="Ecart mensuel entre salaire brut et revenu retraite (CHF)",
    )

    # Debt impact
    monthly_debt_impact: float = Field(
        ..., description="Impact mensuel de la dette sur le revenu de retraite (CHF)",
    )

    # Tax
    tax_saving_3a: float = Field(
        ..., description="Economie d'impot annuelle via 3a (CHF)",
    )
    marginal_tax_rate: float = Field(
        ..., description="Taux marginal d'imposition estime (0.0 - 0.50)",
    )

    # Liquidity
    months_liquidity: float = Field(
        ..., description="Nombre de mois de liquidite (epargne / charges)",
    )

    # Confidence & enrichment
    confidence_score: float = Field(
        ..., description="Score de confiance de la projection (0-100%)",
    )
    estimated_fields: List[str] = Field(
        ..., description="Liste des champs estimes par defaut",
    )
    archetype: str = Field(
        ..., description="Archetype financier detecte",
    )

    # Compliance
    disclaimer: str = Field(
        ..., description="Disclaimer legal (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )
    enrichment_prompts: List[str] = Field(
        ..., description="Actions pour ameliorer la precision",
    )


class ChiffreChocResponse(OnboardingBaseModel):
    """Chiffre choc: un nombre marquant avec contexte educatif."""

    category: str = Field(
        ..., description="Categorie: retirement_gap, tax_saving, liquidity, compound_growth, hourly_rate",
    )
    primary_number: float = Field(
        ..., description="Le nombre principal marquant",
    )
    display_text: str = Field(
        ..., description="Texte d'accroche en francais (tu informel)",
    )
    explanation_text: str = Field(
        ..., description="Explication pedagogique",
    )
    action_text: str = Field(
        ..., description="Call-to-action vers le module concerne",
    )
    disclaimer: str = Field(
        ..., description="Disclaimer legal (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )
    confidence_score: float = Field(
        ..., description="Score de confiance de la projection (0-100%)",
    )
    confidence_mode: str = Field(
        default="factual",
        description="Mode de confiance: 'factual' (donnees reelles) ou 'pedagogical' (estimation)",
    )
