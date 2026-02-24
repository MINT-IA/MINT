"""
Pydantic v2 schemas for the Enhanced Confidence Scoring module (Sprint S46).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - ConfidenceScoreRequest: profil + sources pour scoring complet
    - ConfidenceBreakdownSchema: scores sur 3 axes (completeness, accuracy, freshness)
    - EnrichmentPromptSchema: action d'enrichissement classee par impact
    - ConfidenceScoreResponse: resultat complet avec breakdown, prompts, gates
    - EnrichmentRequest / EnrichmentResponse: top actions d'enrichissement
    - FeatureGatesResponse: fonctionnalites debloquees

Sources:
    - DATA_ACQUISITION_STRATEGY.md, section "Confidence Scoring Evolution"
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 38 (imposition du capital)
"""

from typing import Dict, List, Optional, Union

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================

class ConfidenceBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Shared sub-schemas
# ===========================================================================

class FieldSourceSchema(ConfidenceBaseModel):
    """Source d'un champ de profil."""

    field_name: str = Field(
        ..., description="Nom du champ (ex: lpp_total, salaire_brut)",
    )
    source: str = Field(
        ...,
        description="Source de la donnee: user_estimate, user_entry, "
                    "user_entry_cross_validated, document_scan, "
                    "document_scan_verified, open_banking, "
                    "institutional_api, system_estimate",
    )
    updated_at: str = Field(
        ..., description="Date ISO 8601 de derniere mise a jour (ex: 2026-02-24T10:30:00)",
    )
    value: Union[float, str] = Field(
        ..., description="Valeur du champ (montant CHF ou texte)",
    )


class ConfidenceBreakdownSchema(ConfidenceBaseModel):
    """Score de confiance sur 3 axes."""

    completeness: float = Field(
        ..., ge=0, le=100,
        description="Champs remplis, ponderes par importance (0-100)",
    )
    accuracy: float = Field(
        ..., ge=0, le=100,
        description="Qualite des sources de donnees (0-100)",
    )
    freshness: float = Field(
        ..., ge=0, le=100,
        description="Fraicheur des donnees (0-100)",
    )
    overall: float = Field(
        ..., ge=0, le=100,
        description="Score global pondere: 40% completeness + 35% accuracy + 25% freshness",
    )


class EnrichmentPromptSchema(ConfidenceBaseModel):
    """Action recommandee pour ameliorer le score de confiance."""

    field_name: str = Field(
        ..., description="Champ concerne (ex: lpp_total, taux_marginal)",
    )
    action: str = Field(
        ..., description="Texte de l'action en francais (tutoiement)",
    )
    impact_points: float = Field(
        ..., ge=0,
        description="Gain de confiance estime en points (0-100)",
    )
    method: str = Field(
        ...,
        description="Methode d'acquisition: document_scan, manual_entry, "
                    "open_banking, avs_request",
    )
    priority: int = Field(
        ..., ge=1,
        description="Rang de priorite (1 = plus urgent)",
    )


# ===========================================================================
# Score request / response
# ===========================================================================

class ConfidenceScoreRequest(ConfidenceBaseModel):
    """Requete pour le scoring de confiance complet.

    Envoie le profil utilisateur et les sources des champs pour obtenir
    un score multi-dimensionnel avec feature gates et enrichment prompts.
    """

    profile: Dict[str, Union[float, str, bool, None]] = Field(
        ..., description="Profil utilisateur (cles = noms de champs, valeurs = donnees)",
    )
    field_sources: List[FieldSourceSchema] = Field(
        default_factory=list,
        description="Sources des champs du profil (optionnel — si absent, "
                    "seul le score de completude est calcule)",
    )


class ConfidenceScoreResponse(ConfidenceBaseModel):
    """Resultat complet du scoring de confiance."""

    breakdown: ConfidenceBreakdownSchema = Field(
        ..., description="Scores de confiance sur 3 axes + overall",
    )
    enrichment_prompts: List[EnrichmentPromptSchema] = Field(
        ..., description="Actions d'enrichissement classees par impact decroissant",
    )
    feature_gates: Dict[str, bool] = Field(
        ..., description="Fonctionnalites debloquees selon le niveau de confiance",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )


# ===========================================================================
# Enrichment request / response
# ===========================================================================

class EnrichmentRequest(ConfidenceBaseModel):
    """Requete pour les top actions d'enrichissement."""

    profile: Dict[str, Union[float, str, bool, None]] = Field(
        ..., description="Profil utilisateur",
    )
    field_sources: List[FieldSourceSchema] = Field(
        default_factory=list,
        description="Sources des champs existants",
    )
    max_prompts: int = Field(
        default=5, ge=1, le=20,
        description="Nombre maximum de prompts a retourner (1-20, defaut: 5)",
    )


class EnrichmentResponse(ConfidenceBaseModel):
    """Top actions pour ameliorer la precision du profil."""

    enrichment_prompts: List[EnrichmentPromptSchema] = Field(
        ..., description="Actions classees par impact decroissant",
    )
    current_confidence: float = Field(
        ..., ge=0, le=100,
        description="Score de confiance actuel (overall)",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )


# ===========================================================================
# Feature gates response
# ===========================================================================

class FeatureGatesRequest(ConfidenceBaseModel):
    """Requete pour les feature gates (profil simplifie)."""

    profile: Dict[str, Union[float, str, bool, None]] = Field(
        ..., description="Profil utilisateur",
    )
    field_sources: List[FieldSourceSchema] = Field(
        default_factory=list,
        description="Sources des champs existants",
    )


class FeatureGatesResponse(ConfidenceBaseModel):
    """Fonctionnalites debloquees selon le niveau de confiance."""

    feature_gates: Dict[str, bool] = Field(
        ..., description="Fonctionnalites debloquees (nom -> actif/inactif)",
    )
    overall_confidence: float = Field(
        ..., ge=0, le=100,
        description="Score de confiance global actuel",
    )
    next_gate_name: Optional[str] = Field(
        default=None,
        description="Prochaine fonctionnalite a debloquer (si applicable)",
    )
    points_to_next_gate: Optional[float] = Field(
        default=None, ge=0,
        description="Points manquants pour debloquer la prochaine fonctionnalite",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
