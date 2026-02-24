"""
Pydantic v2 schemas for the Precision module (Sprint S41).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - FieldHelpResponse: aide contextuelle par champ financier
    - CrossValidationRequest / CrossValidationResponse: validation croisee
    - SmartDefaultRequest / SmartDefaultResponse: estimations contextuelles
    - PrecisionPromptRequest / PrecisionPromptResponse: demandes de precision

Sources:
    - LPP art. 7, 8, 15-16 (prevoyance professionnelle)
    - LAVS art. 29ter, 34 (duree cotisation, rente)
    - OPP3 art. 7 (plafond 3a)
    - LIFD art. 38 (imposition du capital)
"""

from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================

class PrecisionBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# FieldHelp
# ===========================================================================

class FieldHelpResponse(PrecisionBaseModel):
    """Aide contextuelle pour un champ financier."""

    field_name: str = Field(
        ..., description="Nom du champ financier",
    )
    where_to_find: str = Field(
        ..., description="Ou trouver ce chiffre (texte explicatif en francais)",
    )
    document_name: str = Field(
        ..., description="Nom du document source",
    )
    german_name: str = Field(
        ..., description="Nom en allemand pour les bilingues FR/DE",
    )
    fallback_estimation: str = Field(
        ..., description="Explication de l'estimation de repli si la valeur est inconnue",
    )


# ===========================================================================
# CrossValidation
# ===========================================================================

class CrossValidationRequest(PrecisionBaseModel):
    """Requete de validation croisee du profil.

    Tous les champs sont optionnels — seuls les champs fournis sont valides.
    La validation croise les champs entre eux pour detecter les incoherences.
    """

    age: Optional[int] = Field(
        default=None, ge=0, le=120,
        description="Age de l'utilisateur",
    )
    salaire_brut: Optional[float] = Field(
        default=None, ge=0,
        description="Salaire brut annuel en CHF",
    )
    salaire_net: Optional[float] = Field(
        default=None, ge=0,
        description="Salaire net annuel en CHF",
    )
    canton: Optional[str] = Field(
        default=None, min_length=2, max_length=2,
        description="Code canton (2 lettres, ex: ZH, VD, GE)",
    )
    lpp_total: Optional[float] = Field(
        default=None, ge=0,
        description="Avoir LPP total en CHF",
    )
    lpp_obligatoire: Optional[float] = Field(
        default=None, ge=0,
        description="Part obligatoire LPP en CHF",
    )
    pillar_3a_balance: Optional[float] = Field(
        default=None, ge=0,
        description="Solde 3e pilier en CHF",
    )
    mortgage_remaining: Optional[float] = Field(
        default=None, ge=0,
        description="Hypotheque restante en CHF",
    )
    is_property_owner: Optional[bool] = Field(
        default=None,
        description="True si proprietaire",
    )
    is_independant: Optional[bool] = Field(
        default=None,
        description="True si independant",
    )
    has_lpp: Optional[bool] = Field(
        default=None,
        description="True si affilie a une caisse LPP",
    )
    taux_marginal: Optional[float] = Field(
        default=None, ge=0, le=1,
        description="Taux marginal d'imposition (0-1)",
    )
    monthly_expenses: Optional[float] = Field(
        default=None, ge=0,
        description="Charges mensuelles en CHF",
    )


class CrossValidationAlertSchema(PrecisionBaseModel):
    """Schema d'une alerte de validation croisee."""

    field_name: str = Field(
        ..., description="Champ concerne par l'alerte",
    )
    severity: Literal["warning", "error"] = Field(
        ..., description="Severite: warning (inhabituel) ou error (incoherence forte)",
    )
    message: str = Field(
        ..., description="Message explicatif en francais (tutoiement)",
    )
    suggestion: str = Field(
        ..., description="Suggestion pour corriger l'incoherence",
    )


class CrossValidationResponse(PrecisionBaseModel):
    """Resultat de la validation croisee."""

    alerts: List[CrossValidationAlertSchema] = Field(
        ..., description="Liste des alertes de coherence",
    )
    alert_count: int = Field(
        ..., description="Nombre total d'alertes",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )


# ===========================================================================
# SmartDefaults
# ===========================================================================

class SmartDefaultRequest(PrecisionBaseModel):
    """Requete pour les estimations contextuelles."""

    archetype: str = Field(
        ...,
        description="Archetype financier: swiss_native, expat_eu, expat_non_eu, "
                    "independent_with_lpp, independent_no_lpp, cross_border, etc.",
    )
    age: int = Field(
        ..., ge=18, le=70,
        description="Age de l'utilisateur (18-70)",
    )
    salary: float = Field(
        ..., ge=0,
        description="Salaire brut annuel en CHF",
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres, ex: ZH, VD, GE)",
    )


class SmartDefaultSchema(PrecisionBaseModel):
    """Schema d'une estimation contextuelle."""

    field_name: str = Field(
        ..., description="Champ estime",
    )
    value: float = Field(
        ..., description="Valeur estimee",
    )
    source: str = Field(
        ..., description="Explication transparente de la methode d'estimation",
    )
    confidence: float = Field(
        ..., ge=0, le=1,
        description="Fiabilite de l'estimation (0-1)",
    )


class SmartDefaultResponse(PrecisionBaseModel):
    """Resultat des estimations contextuelles."""

    defaults: List[SmartDefaultSchema] = Field(
        ..., description="Liste des estimations contextuelles",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )


# ===========================================================================
# PrecisionPrompts
# ===========================================================================

class PrecisionPromptRequest(PrecisionBaseModel):
    """Requete pour les demandes de precision contextuelles."""

    context: str = Field(
        ...,
        description="Contexte declencheur: rente_vs_capital, tax_optimization, "
                    "fri_display, retirement_projection, mortgage_check",
    )
    # Profile fields (all optional — only supplied fields are checked)
    lpp_total: Optional[float] = Field(
        default=None, ge=0,
        description="Avoir LPP total en CHF",
    )
    lpp_obligatoire: Optional[float] = Field(
        default=None, ge=0,
        description="Part obligatoire LPP en CHF",
    )
    taux_marginal: Optional[float] = Field(
        default=None, ge=0, le=1,
        description="Taux marginal d'imposition (0-1)",
    )
    pillar_3a_balance: Optional[float] = Field(
        default=None, ge=0,
        description="Solde 3e pilier en CHF",
    )
    avs_contribution_years: Optional[int] = Field(
        default=None, ge=0, le=44,
        description="Annees de cotisation AVS (0-44)",
    )
    monthly_expenses: Optional[float] = Field(
        default=None, ge=0,
        description="Charges mensuelles en CHF",
    )
    mortgage_remaining: Optional[float] = Field(
        default=None, ge=0,
        description="Hypotheque restante en CHF",
    )


class PrecisionPromptSchema(PrecisionBaseModel):
    """Schema d'une demande de precision."""

    trigger: str = Field(
        ..., description="Contexte declencheur",
    )
    field_needed: str = Field(
        ..., description="Champ necessaire pour plus de precision",
    )
    prompt_text: str = Field(
        ..., description="Texte de la demande en francais (tutoiement)",
    )
    impact_text: str = Field(
        ..., description="Impact attendu sur la precision si le champ est renseigne",
    )


class PrecisionPromptResponse(PrecisionBaseModel):
    """Resultat des demandes de precision."""

    prompts: List[PrecisionPromptSchema] = Field(
        ..., description="Liste des demandes de precision",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )
