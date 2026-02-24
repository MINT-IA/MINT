"""
Dataclasses for the Document Parser module — Sprint S42-S43.

Defines shared types for structured document extraction:
- DocumentType: enum of supported document types
- ExtractedField: a single extracted field with confidence and source text
- ExtractionResult: full extraction result with compliance fields
- DataSource: enum of data provenance levels
- ProfileField: a profile field with source tracking

Privacy: l'image source n'est jamais stockee. Seules les valeurs extraites
sont conservees localement, chiffrees au repos.

Sources:
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 38 (imposition du capital)
    - CO art. 330a (certificat de travail)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Union


class DocumentType(str, Enum):
    """Types de documents financiers suisses supportes."""

    lpp_certificate = "lpp_certificate"
    tax_declaration = "tax_declaration"
    avs_extract = "avs_extract"
    three_a_attestation = "three_a_attestation"
    mortgage_attestation = "mortgage_attestation"


class DataSource(str, Enum):
    """Provenance d'une donnee de profil — par qualite croissante.

    Chaque source a un poids de fiabilite implicite utilise par
    le ConfidenceScorer pour ponderer les projections.
    """

    user_estimate = "user_estimate"
    user_entry = "user_entry"
    user_entry_cross_validated = "user_entry_cross_validated"
    document_scan = "document_scan"
    document_scan_verified = "document_scan_verified"
    open_banking = "open_banking"
    institutional_api = "institutional_api"
    system_estimate = "system_estimate"


# Accuracy weights by data source (used in confidence scoring)
DATA_SOURCE_ACCURACY: dict[DataSource, float] = {
    DataSource.user_estimate: 0.25,
    DataSource.user_entry: 0.50,
    DataSource.user_entry_cross_validated: 0.70,
    DataSource.document_scan: 0.85,
    DataSource.document_scan_verified: 0.95,
    DataSource.open_banking: 1.00,
    DataSource.institutional_api: 0.95,
    DataSource.system_estimate: 0.25,
}


@dataclass
class ExtractedField:
    """Un champ extrait d'un document financier.

    Attributes:
        field_name: Identifiant du champ (ex: avoir_total, taux_conversion_oblig).
        value: Valeur extraite (montant CHF, pourcentage, ou texte).
        confidence: Qualite d'extraction [0-1]. 1.0 = extraction sans ambiguite.
        source_text: Fragment de texte brut d'ou la valeur a ete extraite.
        needs_review: True si la valeur necessite une confirmation utilisateur.
    """

    field_name: str
    value: Union[float, str]
    confidence: float  # 0-1
    source_text: str
    needs_review: bool = False


@dataclass
class ExtractionResult:
    """Resultat complet d'une extraction de document.

    Contient les champs extraits, la confiance globale, le gain potentiel
    sur le ConfidenceScore du profil, et les champs de compliance obligatoires.

    Privacy: l'image source n'est jamais stockee. Seules les valeurs extraites
    sont conservees.
    """

    document_type: DocumentType
    fields: List[ExtractedField] = field(default_factory=list)
    overall_confidence: float = 0.0
    confidence_delta: float = 0.0
    warnings: List[str] = field(default_factory=list)
    disclaimer: str = (
        "Cet outil est educatif et ne constitue pas un conseil financier, "
        "fiscal ou juridique personnalise. Les valeurs extraites sont indicatives "
        "et doivent etre verifiees. Consulte un-e specialiste pour ta situation "
        "personnelle (LSFin art. 3). L'image source n'est jamais stockee."
    )
    sources: List[str] = field(default_factory=lambda: [
        "LPP art. 7 (seuil d'entree: 22'680 CHF)",
        "LPP art. 8 (deduction de coordination: 26'460 CHF)",
        "LPP art. 14 (taux de conversion minimum: 6.8%)",
        "LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)",
        "LPP art. 79b al. 3 (blocage rachat: 3 ans)",
    ])

    def get_field(self, field_name: str) -> ExtractedField | None:
        """Retourne un champ extrait par son nom, ou None."""
        for f in self.fields:
            if f.field_name == field_name:
                return f
        return None

    def get_field_value(self, field_name: str) -> Union[float, str, None]:
        """Retourne la valeur d'un champ extrait, ou None."""
        f = self.get_field(field_name)
        return f.value if f else None


@dataclass
class ProfileField:
    """Un champ de profil avec tracabilite de la source.

    Permet de savoir d'ou vient chaque donnee du profil et
    quand elle a ete mise a jour pour calculer la fraicheur.
    """

    field_name: str
    value: Union[float, str]
    source: DataSource
    updated_at: str  # ISO 8601 datetime
    field_confidence: float  # 0-1, based on source quality
