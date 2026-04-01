"""
Pydantic v2 schemas for the Unemployment (LACI) + First Job module.

Sprint S19 — Chomage (LACI) + Premier emploi.
API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - Unemployment benefits calculator (LACI art. 8-27)
    - First job salary onboarding (AVS, LPP, 3a, LAMal)
"""

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import List, Optional


# ===========================================================================
# Timeline Step (shared)
# ===========================================================================

class TimelineStep(BaseModel):
    """A single step in the post-job-loss timeline."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    jour: int = Field(
        ..., description="Numero du jour (0, 1, 5, 30, etc.)"
    )
    action: str = Field(
        ..., description="Action a entreprendre"
    )
    description: str = Field(
        ..., description="Description detaillee de l'action"
    )
    urgence: str = Field(
        ..., description="Niveau d'urgence: immediate, semaine1, mois1, mois3"
    )


# ===========================================================================
# Unemployment Benefits Schemas
# ===========================================================================

# ===========================================================================
# Checklist & ORP link response models
# ===========================================================================

class UnemploymentChecklistResponse(BaseModel):
    """Response for the generic unemployment checklist endpoint."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    checklist: List[str] = Field(
        default_factory=list, description="Liste d'actions a entreprendre"
    )
    timeline: List[TimelineStep] = Field(
        default_factory=list, description="Timeline post-perte d'emploi"
    )


class OrpLinkResponse(BaseModel):
    """Response for the ORP link endpoint."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    canton: str = Field(..., description="Code canton (ex: ZH, VD, GE)")
    url: str = Field(..., description="URL de l'ORP cantonal")


# ===========================================================================
# Unemployment Benefits Schemas
# ===========================================================================

class UnemploymentBenefitsRequest(BaseModel):
    """Request for LACI unemployment benefits calculation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    gain_assure_mensuel: float = Field(
        ..., description="Gain assure mensuel (dernier salaire) en CHF", ge=0
    )
    age: int = Field(
        ..., description="Age actuel", ge=16, le=70
    )
    annees_cotisation: int = Field(
        ..., description="Mois de cotisation durant les 2 dernieres annees (0-24)",
        ge=0, le=24,
    )
    has_children: bool = Field(
        False, description="A des enfants a charge?"
    )
    has_disability: bool = Field(
        False, description="Situation de handicap?"
    )
    canton: str = Field(
        "ZH", description="Code canton (ex: ZH, VD, GE)", min_length=2, max_length=2
    )
    date_licenciement: Optional[str] = Field(
        None, description="Date de licenciement (ISO 8601, ex: 2026-03-01)"
    )


class UnemploymentBenefitsResponse(BaseModel):
    """Response for LACI unemployment benefits calculation."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    taux_indemnite: float = Field(
        ..., description="Taux d'indemnisation (0.70 ou 0.80)"
    )
    gain_assure_retenu: float = Field(
        ..., description="Gain assure retenu (plafond: 12'350 CHF/mois)"
    )
    indemnite_journaliere: float = Field(
        ..., description="Indemnite journaliere (CHF)"
    )
    indemnite_mensuelle: float = Field(
        ..., description="Indemnite mensuelle estimee (CHF, base 21.75 jours)"
    )
    nombre_indemnites: int = Field(
        ..., description="Nombre total d'indemnites journalieres (200-520)"
    )
    duree_mois: float = Field(
        ..., description="Duree estimee en mois"
    )
    delai_carence_jours: int = Field(
        ..., description="Delai de carence en jours"
    )
    eligible: bool = Field(
        ..., description="Eligible aux indemnites de chomage?"
    )
    raison_non_eligible: Optional[str] = Field(
        None, description="Raison de non-eligibilite"
    )
    timeline: List[TimelineStep] = Field(
        default_factory=list, description="Timeline post-perte d'emploi"
    )
    checklist: List[str] = Field(
        default_factory=list, description="Liste d'actions a entreprendre"
    )
    alertes: List[str] = Field(
        default_factory=list, description="Alertes et avertissements"
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )


# ===========================================================================
# Salary Breakdown (First Job)
# ===========================================================================

class SalaryBreakdown(BaseModel):
    """Decomposition detaillee du salaire brut -> net."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    brut: float = Field(
        ..., description="Salaire brut mensuel (CHF)"
    )
    avs_ai_apg: float = Field(
        ..., description="Cotisation AVS/AI/APG employe (5.30%)"
    )
    ac: float = Field(
        ..., description="Cotisation assurance-chomage (1.1%)"
    )
    aanp: float = Field(
        ..., description="Cotisation AANP estimee (~1.3%)"
    )
    lpp_employe: float = Field(
        ..., description="Cotisation LPP part employe (CHF)"
    )
    impot_source: Optional[float] = Field(
        None, description="Impot a la source (si applicable)"
    )
    net_estime: float = Field(
        ..., description="Salaire net estime (CHF)"
    )
    cotisations_invisibles_employeur: float = Field(
        ..., description="Cotisations invisibles payees par l'employeur (CHF)"
    )


# ===========================================================================
# Pillar 3a Advice (First Job)
# ===========================================================================

class Pillar3aAdvice(BaseModel):
    """Recommandation 3e pilier pour un premier emploi."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    eligible: bool = Field(
        ..., description="Eligible au pilier 3a?"
    )
    plafond_annuel: float = Field(
        ..., description="Plafond annuel 3a (CHF)"
    )
    montant_mensuel_suggere: float = Field(
        ..., description="Montant mensuel suggere (CHF)"
    )
    economie_fiscale_estimee: float = Field(
        ..., description="Economie fiscale estimee (CHF/an)"
    )
    alerte_assurance_vie: str = Field(
        ..., description="Alerte concernant les produits 3a lies a une assurance-vie"
    )


# ===========================================================================
# LAMal Franchise Advice (First Job)
# ===========================================================================

class FranchiseOption(BaseModel):
    """Une option de franchise LAMal."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    franchise: int = Field(
        ..., description="Montant de la franchise (CHF)"
    )
    prime_mensuelle_estimee: float = Field(
        ..., description="Prime mensuelle estimee (CHF)"
    )
    cout_annuel_max: float = Field(
        ..., description="Cout annuel maximum (primes + franchise + quote-part)"
    )


class LamalAdvice(BaseModel):
    """Recommandation LAMal pour un premier emploi."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    franchises_disponibles: List[FranchiseOption] = Field(
        default_factory=list, description="Options de franchise disponibles"
    )
    franchise_recommandee: int = Field(
        ..., description="Franchise recommandee (CHF)"
    )
    economie_annuelle_vs_300: float = Field(
        ..., description="Economie annuelle vs franchise 300 (CHF)"
    )


# ===========================================================================
# First Job Schemas
# ===========================================================================

class FirstJobRequest(BaseModel):
    """Request for first job salary analysis."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    salaire_brut_mensuel: float = Field(
        ..., description="Salaire brut mensuel (CHF)", ge=0, le=10_000_000
    )
    canton: str = Field(
        "ZH", description="Code canton (ex: ZH, VD, GE)", min_length=2, max_length=2
    )
    age: int = Field(
        ..., description="Age de la personne", ge=15, le=70
    )
    etat_civil: str = Field(
        "celibataire", description="Etat civil (celibataire, marie, etc.)"
    )
    has_children: bool = Field(
        False, description="A des enfants a charge?"
    )
    taux_activite: float = Field(
        100.0, description="Taux d'activite en pourcent (ex: 80.0)", ge=0, le=100
    )


class FirstJobResponse(BaseModel):
    """Response for first job salary analysis."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    decomposition_salaire: SalaryBreakdown = Field(
        ..., description="Decomposition detaillee du salaire"
    )
    recommandations_3a: Pillar3aAdvice = Field(
        ..., description="Recommandations 3e pilier"
    )
    recommandation_lamal: LamalAdvice = Field(
        ..., description="Recommandation franchise LAMal"
    )
    checklist_premier_emploi: List[str] = Field(
        default_factory=list, description="Checklist premier emploi"
    )
    alertes: List[str] = Field(
        default_factory=list, description="Alertes et avertissements"
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique"
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal"
    )
    sources: List[str] = Field(
        default_factory=list, description="Sources legales"
    )
