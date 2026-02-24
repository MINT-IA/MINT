"""
Pydantic v2 schemas for Document Parser — Sprint S42-S43.

API convention: camelCase field names via alias_generator, ConfigDict.

Covers:
    - ParseDocumentRequest: texte OCR + type de document + profil optionnel
    - ExtractedFieldResponse: un champ extrait
    - ExtractionResultResponse: resultat complet d'extraction
    - ConfidenceDeltaResponse: estimation du gain en confiance
    - FieldImpactResponse: classement des champs par impact

Sources:
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - LIFD art. 38 (imposition du capital)
"""

from typing import Dict, List, Literal, Optional, Union

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# ══════════════════════════════════════════════════════════════════════════════
# Base config
# ══════════════════════════════════════════════════════════════════════════════


class DocumentParserBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ══════════════════════════════════════════════════════════════════════════════
# Requests
# ══════════════════════════════════════════════════════════════════════════════


class ParseDocumentRequest(DocumentParserBaseModel):
    """Requete de parsing d'un texte OCR de document financier."""

    text: str = Field(
        ...,
        min_length=1,
        description="Texte brut issu de l'OCR du document",
    )
    document_type: Literal[
        "lpp_certificate",
        "tax_declaration",
        "avs_extract",
        "three_a_attestation",
        "mortgage_attestation",
    ] = Field(
        "lpp_certificate",
        description="Type de document financier",
    )
    current_profile: Optional[Dict[str, Union[float, str]]] = Field(
        default=None,
        description="Profil actuel de l'utilisateur (pour calculer le delta de confiance)",
    )


class ConfidenceDeltaRequest(DocumentParserBaseModel):
    """Requete d'estimation du gain en confiance."""

    text: str = Field(
        ...,
        min_length=1,
        description="Texte brut issu de l'OCR du document",
    )
    document_type: Literal[
        "lpp_certificate",
        "tax_declaration",
        "avs_extract",
        "three_a_attestation",
        "mortgage_attestation",
    ] = Field(
        "lpp_certificate",
        description="Type de document financier",
    )
    current_profile: Dict[str, Union[float, str]] = Field(
        default_factory=dict,
        description="Profil actuel de l'utilisateur",
    )


# ══════════════════════════════════════════════════════════════════════════════
# Responses
# ══════════════════════════════════════════════════════════════════════════════


class ExtractedFieldResponse(DocumentParserBaseModel):
    """Un champ extrait d'un document financier."""

    field_name: str = Field(
        ..., description="Identifiant du champ (ex: avoir_total, taux_conversion_oblig)",
    )
    value: Union[float, str] = Field(
        ..., description="Valeur extraite (montant CHF ou pourcentage)",
    )
    confidence: float = Field(
        ..., ge=0.0, le=1.0,
        description="Qualite d'extraction [0-1]",
    )
    source_text: str = Field(
        ..., description="Fragment de texte brut d'ou la valeur a ete extraite",
    )
    needs_review: bool = Field(
        False, description="True si la valeur necessite une confirmation utilisateur",
    )


class ExtractionResultResponse(DocumentParserBaseModel):
    """Resultat complet d'extraction d'un document financier."""

    document_type: str = Field(
        ..., description="Type de document traite",
    )
    fields: List[ExtractedFieldResponse] = Field(
        default_factory=list,
        description="Champs extraits avec confiance et texte source",
    )
    overall_confidence: float = Field(
        0.0, ge=0.0, le=1.0,
        description="Confiance globale de l'extraction [0-1]",
    )
    confidence_delta: float = Field(
        0.0, ge=0.0,
        description="Augmentation estimee du ConfidenceScore en points de pourcentage",
    )
    extraction_score: float = Field(
        0.0, ge=0.0, le=100.0,
        description="Score de qualite de l'extraction (0-100)",
    )
    warnings: List[str] = Field(
        default_factory=list,
        description="Alertes et incoherences detectees",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )


class ConfidenceDeltaResponse(DocumentParserBaseModel):
    """Estimation du gain en confiance apres scan d'un document."""

    confidence_delta: float = Field(
        ..., ge=0.0,
        description="Augmentation estimee du ConfidenceScore en points de pourcentage",
    )
    fields_extracted: int = Field(
        ..., ge=0,
        description="Nombre de champs extraits du document",
    )
    fields_new: int = Field(
        ..., ge=0,
        description="Nombre de champs qui n'etaient pas dans le profil",
    )
    fields_improved: int = Field(
        ..., ge=0,
        description="Nombre de champs existants ameliores (estimation -> document)",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )


class FieldImpactItem(DocumentParserBaseModel):
    """Un champ avec son impact sur la precision."""

    field_name: str = Field(
        ..., description="Identifiant du champ",
    )
    impact: int = Field(
        ..., ge=0, le=10,
        description="Score d'impact sur la precision (0-10)",
    )
    reason: str = Field(
        ..., description="Raison de l'importance de ce champ",
    )
    projection_affected: str = Field(
        ..., description="Projections impactees par ce champ",
    )


class FieldImpactResponse(DocumentParserBaseModel):
    """Classement des champs par impact sur la precision des projections."""

    document_type: str = Field(
        ..., description="Type de document concerne",
    )
    fields: List[FieldImpactItem] = Field(
        ..., description="Champs classes par impact decroissant",
    )
    disclaimer: str = Field(
        ..., description="Mention legale (outil educatif, LSFin)",
    )
    sources: List[str] = Field(
        ..., description="References legales suisses",
    )
