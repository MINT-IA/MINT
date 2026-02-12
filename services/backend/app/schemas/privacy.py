"""
Pydantic v2 schemas for the nLPD (new Swiss Data Protection Law) privacy module.

Implements:
    - Data export (nLPD art. 25 — droit d'acces / portabilite)
    - Data deletion (nLPD art. 32 — droit a l'effacement)
    - Consent management (nLPD art. 6 — principes de traitement)

API convention: camelCase field names via alias_generator, ConfigDict.
"""

from enum import Enum
from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel
from typing import Dict, List, Optional


# ===========================================================================
# Base config
# ===========================================================================

class PrivacyBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Enums
# ===========================================================================

class ConsentCategory(str, Enum):
    """Categories de traitement des donnees personnelles (nLPD art. 6)."""
    core_profile = "core_profile"
    analytics = "analytics"
    coaching_notifications = "coaching_notifications"
    open_banking = "open_banking"
    document_upload = "document_upload"
    rag_queries = "rag_queries"


class ConsentBasis(str, Enum):
    """Base legale du traitement (nLPD art. 6 al. 6-7)."""
    contract = "contract"
    consent = "consent"
    explicit_consent = "explicit_consent"


class DeletionMode(str, Enum):
    """Mode de suppression des donnees."""
    immediate = "immediate"
    grace_period = "grace_period"


# ===========================================================================
# Data Export Schemas (nLPD art. 25)
# ===========================================================================

class DataExportRequest(PrivacyBaseModel):
    """Requete pour l'export des donnees personnelles (nLPD art. 25)."""

    profile_id: str = Field(
        ..., min_length=1,
        description="Identifiant unique du profil utilisateur",
    )
    include_sessions: bool = Field(
        default=True,
        description="Inclure l'historique des sessions",
    )
    include_reports: bool = Field(
        default=True,
        description="Inclure les rapports generes",
    )
    include_documents: bool = Field(
        default=True,
        description="Inclure les documents uploades",
    )
    include_analytics: bool = Field(
        default=True,
        description="Inclure les evenements analytics",
    )


class DataCategoryExport(PrivacyBaseModel):
    """Detail d'une categorie de donnees exportees."""

    categorie: str = Field(
        ..., description="Nom de la categorie de donnees",
    )
    nombre_enregistrements: int = Field(
        ..., ge=0,
        description="Nombre d'enregistrements dans cette categorie",
    )
    description: str = Field(
        ..., description="Description du type de donnees",
    )
    base_legale: str = Field(
        ..., description="Base legale du traitement (nLPD art. 6)",
    )
    duree_conservation: str = Field(
        ..., description="Duree de conservation prevue",
    )


class DataExportResponse(PrivacyBaseModel):
    """Reponse pour l'export des donnees personnelles (nLPD art. 25)."""

    profile_id: str = Field(
        ..., description="Identifiant du profil",
    )
    date_export: str = Field(
        ..., description="Date et heure de l'export (ISO 8601)",
    )
    format_donnees: str = Field(
        default="JSON",
        description="Format des donnees exportees",
    )
    categories: List[DataCategoryExport] = Field(
        default_factory=list,
        description="Detail par categorie de donnees",
    )
    donnees_profil: Dict = Field(
        default_factory=dict,
        description="Donnees du profil utilisateur",
    )
    donnees_sessions: List[Dict] = Field(
        default_factory=list,
        description="Historique des sessions",
    )
    donnees_rapports: List[Dict] = Field(
        default_factory=list,
        description="Rapports generes",
    )
    donnees_documents: List[Dict] = Field(
        default_factory=list,
        description="Documents uploades",
    )
    donnees_analytics: List[Dict] = Field(
        default_factory=list,
        description="Evenements analytics",
    )
    politique_conservation: Dict[str, str] = Field(
        default_factory=dict,
        description="Politique de conservation par categorie",
    )
    responsable_traitement: str = Field(
        ..., description="Responsable du traitement (nLPD art. 19)",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="References legales nLPD",
    )


# ===========================================================================
# Data Deletion Schemas (nLPD art. 32)
# ===========================================================================

class DataDeletionRequest(PrivacyBaseModel):
    """Requete pour la suppression des donnees personnelles (nLPD art. 32)."""

    profile_id: str = Field(
        ..., min_length=1,
        description="Identifiant unique du profil utilisateur",
    )
    mode: DeletionMode = Field(
        default=DeletionMode.grace_period,
        description="Mode de suppression: immediate ou avec delai de grace (30 jours)",
    )
    raison: Optional[str] = Field(
        default=None,
        description="Raison de la demande de suppression (facultative)",
    )


class DeletionCategoryDetail(PrivacyBaseModel):
    """Detail de la suppression par categorie de donnees."""

    categorie: str = Field(
        ..., description="Nom de la categorie",
    )
    nombre_supprime: int = Field(
        ..., ge=0,
        description="Nombre d'enregistrements supprimes ou marques pour suppression",
    )
    statut: str = Field(
        ..., description="Statut: supprime, marque_pour_suppression, conserve_obligation_legale",
    )
    motif_conservation: Optional[str] = Field(
        default=None,
        description="Motif si les donnees sont conservees (obligation legale)",
    )


class DataDeletionResponse(PrivacyBaseModel):
    """Reponse pour la suppression des donnees personnelles (nLPD art. 32)."""

    profile_id: str = Field(
        ..., description="Identifiant du profil",
    )
    mode: str = Field(
        ..., description="Mode de suppression applique",
    )
    date_demande: str = Field(
        ..., description="Date et heure de la demande (ISO 8601)",
    )
    date_suppression_effective: str = Field(
        ..., description="Date de suppression effective (ISO 8601)",
    )
    delai_grace_jours: int = Field(
        ..., ge=0,
        description="Nombre de jours de delai de grace",
    )
    categories_traitees: List[DeletionCategoryDetail] = Field(
        default_factory=list,
        description="Detail par categorie de donnees",
    )
    total_enregistrements_supprimes: int = Field(
        ..., ge=0,
        description="Nombre total d'enregistrements supprimes",
    )
    donnees_conservees_obligation_legale: bool = Field(
        ..., description="True si certaines donnees sont conservees par obligation legale",
    )
    explication_conservation: Optional[str] = Field(
        default=None,
        description="Explication si des donnees sont conservees",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="References legales nLPD",
    )
    alertes: List[str] = Field(
        default_factory=list,
        description="Alertes et avertissements",
    )


# ===========================================================================
# Consent Management Schemas (nLPD art. 6)
# ===========================================================================

class ConsentStatusRequest(PrivacyBaseModel):
    """Requete pour le statut des consentements (nLPD art. 6)."""

    profile_id: str = Field(
        ..., min_length=1,
        description="Identifiant unique du profil utilisateur",
    )


class ConsentCategoryStatus(PrivacyBaseModel):
    """Statut d'un consentement pour une categorie de traitement."""

    categorie: str = Field(
        ..., description="Categorie de traitement des donnees",
    )
    nom_affiche: str = Field(
        ..., description="Nom affiche pour l'utilisateur (en francais)",
    )
    description: str = Field(
        ..., description="Description du traitement",
    )
    base_legale: ConsentBasis = Field(
        ..., description="Base legale du traitement",
    )
    est_obligatoire: bool = Field(
        ..., description="True si le traitement est requis pour le fonctionnement du service",
    )
    est_actif: bool = Field(
        ..., description="True si le consentement est actuellement actif",
    )
    date_consentement: Optional[str] = Field(
        default=None,
        description="Date du consentement (ISO 8601), null si jamais consenti",
    )
    peut_etre_retire: bool = Field(
        ..., description="True si le consentement peut etre retire (nLPD art. 6 al. 7)",
    )
    impact_retrait: str = Field(
        ..., description="Impact du retrait du consentement sur le service",
    )


class ConsentStatusResponse(PrivacyBaseModel):
    """Reponse pour le statut des consentements (nLPD art. 6)."""

    profile_id: str = Field(
        ..., description="Identifiant du profil",
    )
    date_verification: str = Field(
        ..., description="Date et heure de la verification (ISO 8601)",
    )
    consentements: List[ConsentCategoryStatus] = Field(
        default_factory=list,
        description="Statut de chaque categorie de consentement",
    )
    nb_consentements_actifs: int = Field(
        ..., ge=0,
        description="Nombre de consentements actifs",
    )
    nb_consentements_optionnels: int = Field(
        ..., ge=0,
        description="Nombre de consentements optionnels",
    )
    chiffre_choc: str = Field(
        ..., description="Chiffre choc pedagogique",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="References legales nLPD",
    )


# ===========================================================================
# Consent Update Schema
# ===========================================================================

class ConsentUpdateRequest(PrivacyBaseModel):
    """Requete pour mettre a jour un consentement (nLPD art. 6 al. 7)."""

    profile_id: str = Field(
        ..., min_length=1,
        description="Identifiant unique du profil utilisateur",
    )
    categorie: ConsentCategory = Field(
        ..., description="Categorie de traitement a modifier",
    )
    est_actif: bool = Field(
        ..., description="True pour consentir, False pour retirer le consentement",
    )


class ConsentUpdateResponse(PrivacyBaseModel):
    """Reponse pour la mise a jour d'un consentement."""

    profile_id: str = Field(
        ..., description="Identifiant du profil",
    )
    categorie: str = Field(
        ..., description="Categorie modifiee",
    )
    est_actif: bool = Field(
        ..., description="Nouveau statut du consentement",
    )
    date_modification: str = Field(
        ..., description="Date et heure de la modification (ISO 8601)",
    )
    message: str = Field(
        ..., description="Message de confirmation",
    )
    disclaimer: str = Field(
        ..., description="Avertissement legal",
    )
    sources: List[str] = Field(
        default_factory=list,
        description="References legales nLPD",
    )
