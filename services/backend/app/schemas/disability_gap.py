"""
Pydantic v2 schemas for the Disability Gap simulator.

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - DisabilityGapRequest: input for the 3-phase gap simulation
    - DisabilityGapResponse: full result with phases, risk, alerts, compliance
"""

from enum import Enum
from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List


# ===========================================================================
# Base config
# ===========================================================================

class DisabilityGapBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Enums
# ===========================================================================

class EmploymentStatusEnum(str, Enum):
    """Statut professionnel de l'utilisateur."""
    employee = "employee"
    self_employed = "self_employed"
    mixed = "mixed"
    unemployed = "unemployed"
    student = "student"


# ===========================================================================
# Request
# ===========================================================================

class DisabilityGapRequest(DisabilityGapBaseModel):
    """Requete pour la simulation du gap d'invalidite."""

    revenu_mensuel_net: float = Field(
        ..., ge=0,
        description="Revenu mensuel net actuel en CHF",
    )
    statut_professionnel: EmploymentStatusEnum = Field(
        ...,
        description="Statut professionnel (employee, self_employed, mixed, unemployed, student)",
    )
    canton: str = Field(
        ..., min_length=2, max_length=2,
        description="Code canton (2 lettres majuscules, ex: ZH, VD, GE)",
    )
    annees_anciennete: int = Field(
        ..., ge=0,
        description="Annees d'anciennete chez l'employeur actuel",
    )
    has_ijm_collective: bool = Field(
        ...,
        description="True si couvert par une IJM collective ou individuelle",
    )
    degre_invalidite: int = Field(
        ..., ge=0, le=100,
        description="Degre d'invalidite estime en % (0-100)",
    )
    lpp_disability_benefit: float = Field(
        default=0.0, ge=0,
        description="Rente d'invalidite LPP mensuelle si connue (CHF)",
    )


# ===========================================================================
# Response
# ===========================================================================

class DisabilityGapResponse(DisabilityGapBaseModel):
    """Resultat complet de la simulation du gap d'invalidite sur 3 phases."""

    # Current income
    revenu_actuel: float = Field(
        ..., description="Revenu mensuel net actuel (CHF)",
    )

    # Phase 1: Employer coverage (CO art. 324a)
    phase1_duration_weeks: float = Field(
        ..., description="Duree couverture employeur en semaines",
    )
    phase1_monthly_benefit: float = Field(
        ..., description="Prestation mensuelle phase 1 (CHF)",
    )
    phase1_gap: float = Field(
        ..., description="Gap mensuel phase 1 (CHF)",
    )

    # Phase 2: IJM (daily indemnity insurance)
    phase2_duration_months: float = Field(
        ..., description="Duree couverture IJM en mois",
    )
    phase2_monthly_benefit: float = Field(
        ..., description="Prestation mensuelle phase 2 (CHF)",
    )
    phase2_gap: float = Field(
        ..., description="Gap mensuel phase 2 (CHF)",
    )

    # Phase 3: AI + LPP (long term)
    phase3_monthly_benefit: float = Field(
        ..., description="Prestation mensuelle phase 3 AI + LPP (CHF)",
    )
    phase3_gap: float = Field(
        ..., description="Gap mensuel phase 3 (CHF)",
    )

    # Summary
    risk_level: str = Field(
        ..., description="Niveau de risque: critical, high, medium, low",
    )
    alerts: List[str] = Field(
        default_factory=list, description="Alertes et avertissements",
    )
    ai_rente_mensuelle: float = Field(
        ..., description="Rente AI mensuelle estimee (CHF)",
    )
    lpp_disability_benefit: float = Field(
        ..., description="Rente d'invalidite LPP mensuelle (CHF)",
    )

    # Compliance
    chiffre_choc: str = Field(
        ..., description="Chiffre choc: un nombre marquant avec explication",
    )
    disclaimer: str = Field(
        ..., description="Disclaimer legal (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )
