"""
Pydantic v2 schemas for the Coach Narrative module (Sprint S35).

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - CoachContextRequest — input for narrative generation
    - CoachNarrativeResponse — all 4 narrative components
    - ComponentNarrativeResponse — single component response

Sources:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
"""

from typing import Dict, List, Optional

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel


# ===========================================================================
# Base config
# ===========================================================================

class CoachBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Request schemas
# ===========================================================================

class CoachContextRequest(CoachBaseModel):
    """Requete de contexte pour la generation de narratifs coach."""

    first_name: str = Field(
        default="utilisateur",
        description="Prenom de l'utilisateur",
    )
    archetype: str = Field(
        default="swiss_native",
        description="Archetype financier (swiss_native, expat_eu, etc.)",
    )
    age: int = Field(
        default=30, ge=18, le=99,
        description="Age de l'utilisateur",
    )
    canton: str = Field(
        default="VD",
        description="Canton de domicile fiscal",
    )
    fri_total: float = Field(
        default=0.0, ge=0.0, le=100.0,
        description="Score FRI total (0-100)",
    )
    fri_delta: float = Field(
        default=0.0,
        description="Variation FRI depuis le dernier check-in",
    )
    primary_focus: str = Field(
        default="",
        description="Priorite financiere actuelle",
    )
    replacement_ratio: float = Field(
        default=0.0, ge=0.0, le=2.0,
        description="Taux de remplacement estime (0-1)",
    )
    months_liquidity: float = Field(
        default=0.0, ge=0.0,
        description="Mois de reserve de liquidite",
    )
    tax_saving_potential: float = Field(
        default=0.0, ge=0.0,
        description="Potentiel d'economie fiscale 3a (CHF)",
    )
    confidence_score: float = Field(
        default=0.0, ge=0.0, le=100.0,
        description="Score de confiance de la projection (0-100)",
    )
    days_since_last_visit: int = Field(
        default=0, ge=0,
        description="Jours depuis la derniere visite",
    )
    fiscal_season: str = Field(
        default="",
        description="Saison fiscale: '3a_deadline', 'tax_declaration', ''",
    )
    upcoming_event: str = Field(
        default="",
        description="Evenement de vie a venir",
    )
    check_in_streak: int = Field(
        default=0, ge=0,
        description="Nombre de check-ins consecutifs",
    )
    last_milestone: str = Field(
        default="",
        description="Dernier milestone atteint",
    )


# ===========================================================================
# Response schemas
# ===========================================================================

class CoachNarrativeResponse(CoachBaseModel):
    """Reponse complete du coach: 4 composants narratifs."""

    greeting: str = Field(
        ..., description="Message d'accueil personnalise",
    )
    score_summary: str = Field(
        ..., description="Resume du score FRI avec tendance",
    )
    tip_narrative: str = Field(
        ..., description="Conseil educatif personnalise",
    )
    chiffre_choc_reframe: str = Field(
        ..., description="Recontextualisation du chiffre choc",
    )
    used_fallback: Dict[str, bool] = Field(
        ..., description="Indique si le fallback a ete utilise par composant",
    )
    disclaimer: str = Field(
        ..., description="Disclaimer legal obligatoire",
    )
    sources: List[str] = Field(
        ..., description="References legales",
    )


class ComponentNarrativeResponse(CoachBaseModel):
    """Reponse pour un seul composant narratif."""

    component: str = Field(
        ..., description="Type de composant (greeting, score_summary, etc.)",
    )
    text: str = Field(
        ..., description="Texte narratif genere",
    )
    used_fallback: bool = Field(
        ..., description="Indique si le fallback a ete utilise",
    )
    disclaimer: str = Field(
        ..., description="Disclaimer legal obligatoire",
    )
    sources: List[str] = Field(
        ..., description="References legales",
    )
