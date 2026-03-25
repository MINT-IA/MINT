"""
Document Parser endpoints — Sprint S42-S45.

POST /api/v1/document-parser/parse            — parse un texte OCR et extrait les champs
POST /api/v1/document-parser/confidence-delta  — estime le gain en confiance
GET  /api/v1/document-parser/field-impact/{document_type} — classement des champs par impact

Supporte: certificat LPP, declaration fiscale, extrait AVS.

Tous les endpoints sont stateless (pas de stockage de donnees).
Pure computation sur le texte fourni.

Privacy: l'image source n'est jamais stockee. Seules les valeurs extraites
sont retournees au client. Aucune donnee n'est persistee cote serveur.

Sources:
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 25-33, 38 (imposition du revenu et du capital)
    - LHID art. 7-9 (harmonisation fiscale cantonale)
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from app.core.rate_limit import limiter

from app.schemas.document_parser import (
    ParseDocumentRequest,
    ExtractionResultResponse,
    ExtractedFieldResponse,
    ConfidenceDeltaRequest,
    ConfidenceDeltaResponse,
    FieldImpactResponse,
    FieldImpactItem,
)
from app.services.document_parser.document_models import DocumentType
from app.services.document_parser.lpp_certificate_parser import (
    parse_lpp_certificate,
    estimate_confidence_delta,
)
from app.services.document_parser.tax_declaration_parser import (
    parse_tax_declaration,
    estimate_tax_confidence_delta,
)
from app.services.document_parser.avs_extract_parser import (
    parse_avs_extract,
    estimate_avs_confidence_delta,
)
from app.services.document_parser.extraction_confidence_scorer import (
    score_extraction,
    rank_fields_by_impact,
)


router = APIRouter()

# ══════════════════════════════════════════════════════════════════════════════
# Compliance constants
# ══════════════════════════════════════════════════════════════════════════════

_DISCLAIMER = (
    "Cet outil est educatif et ne constitue pas un conseil financier, "
    "fiscal ou juridique personnalise. Les valeurs extraites sont indicatives "
    "et doivent etre verifiees. Consulte un-e specialiste pour ta situation "
    "personnelle (LSFin art. 3). L'image source n'est jamais stockee."
)

_SOURCES = [
    "LPP art. 7 (seuil d'entree: 22'680 CHF)",
    "LPP art. 8 (deduction de coordination: 26'460 CHF)",
    "LPP art. 14 (taux de conversion minimum: 6.8%)",
    "LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)",
    "LPP art. 79b al. 3 (blocage rachat: 3 ans)",
]

# Supported document types
_VALID_DOCUMENT_TYPES = {
    "lpp_certificate",
    "tax_declaration",
    "avs_extract",
    "three_a_attestation",
    "mortgage_attestation",
}


# ══════════════════════════════════════════════════════════════════════════════
# POST /parse
# ══════════════════════════════════════════════════════════════════════════════


@router.post("/parse", response_model=ExtractionResultResponse)
@limiter.limit("30/minute")
def parse_document(request: Request, body: ParseDocumentRequest) -> ExtractionResultResponse:
    """Parse un texte OCR de document financier et extrait les champs structures.

    Actuellement supporte: certificat de prevoyance LPP (FR + DE).
    Extrait ~15 champs cles avec confiance et texte source.

    Privacy: l'image source n'est jamais stockee. Le texte OCR est traite
    en memoire et n'est pas persiste.

    Args:
        request: Texte OCR, type de document, profil optionnel.

    Returns:
        ExtractionResultResponse avec champs extraits, confiance, warnings,
        disclaimer et sources legales.
    """
    if body.document_type not in _VALID_DOCUMENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Type de document non supporte: {body.document_type}. "
                   f"Types supportes: {', '.join(sorted(_VALID_DOCUMENT_TYPES))}",
        )

    # Route to the appropriate parser
    current_profile = body.current_profile or {}

    if body.document_type == "lpp_certificate":
        result = parse_lpp_certificate(body.text)
        delta = estimate_confidence_delta(result, current_profile)
    elif body.document_type == "tax_declaration":
        result = parse_tax_declaration(body.text)
        delta = estimate_tax_confidence_delta(result, current_profile)
    elif body.document_type == "avs_extract":
        result = parse_avs_extract(body.text)
        delta = estimate_avs_confidence_delta(result, current_profile)
    else:
        raise HTTPException(
            status_code=501,
            detail=f"Le parsing de '{body.document_type}' n'est pas encore "
                   "implemente. Types supportes: lpp_certificate, tax_declaration, avs_extract.",
        )
    result.confidence_delta = delta

    # Calculate extraction quality score
    ext_score = score_extraction(result)

    return ExtractionResultResponse(
        document_type=result.document_type.value,
        fields=[
            ExtractedFieldResponse(
                field_name=f.field_name,
                value=f.value,
                confidence=f.confidence,
                source_text=f.source_text,
                needs_review=f.needs_review,
            )
            for f in result.fields
        ],
        overall_confidence=result.overall_confidence,
        confidence_delta=delta,
        extraction_score=ext_score,
        warnings=result.warnings,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


# ══════════════════════════════════════════════════════════════════════════════
# POST /confidence-delta
# ══════════════════════════════════════════════════════════════════════════════


@router.post("/confidence-delta", response_model=ConfidenceDeltaResponse)
@limiter.limit("30/minute")
def get_confidence_delta(request: Request, body: ConfidenceDeltaRequest) -> ConfidenceDeltaResponse:
    """Estime le gain en confiance apres extraction d'un document.

    Compare les champs extraits avec le profil actuel pour determiner
    combien de points de ConfidenceScore seraient gagnes.

    Args:
        request: Texte OCR, type de document, profil actuel.

    Returns:
        ConfidenceDeltaResponse avec delta, nombre de champs nouveaux/ameliores.
    """
    current_profile = body.current_profile or {}

    # Route to the appropriate parser
    if body.document_type == "lpp_certificate":
        result = parse_lpp_certificate(body.text)
        delta = estimate_confidence_delta(result, current_profile)
    elif body.document_type == "tax_declaration":
        result = parse_tax_declaration(body.text)
        delta = estimate_tax_confidence_delta(result, current_profile)
    elif body.document_type == "avs_extract":
        result = parse_avs_extract(body.text)
        delta = estimate_avs_confidence_delta(result, current_profile)
    else:
        raise HTTPException(
            status_code=501,
            detail=f"Le parsing de '{body.document_type}' n'est pas encore "
                   "implemente. Types supportes: lpp_certificate, tax_declaration, avs_extract.",
        )

    # Count new vs improved fields
    fields_new = 0
    fields_improved = 0
    for field in result.fields:
        # Map extraction field name to profile key
        profile_key = _field_to_profile_key(field.field_name)
        if profile_key and profile_key in current_profile:
            fields_improved += 1
        else:
            fields_new += 1

    return ConfidenceDeltaResponse(
        confidence_delta=delta,
        fields_extracted=len(result.fields),
        fields_new=fields_new,
        fields_improved=fields_improved,
        disclaimer=result.disclaimer,
        sources=result.sources,
    )


# ══════════════════════════════════════════════════════════════════════════════
# GET /field-impact/{document_type}
# ══════════════════════════════════════════════════════════════════════════════


@router.get("/field-impact/{document_type}", response_model=FieldImpactResponse)
@limiter.limit("60/minute")
def get_field_impact(request: Request, document_type: str) -> FieldImpactResponse:
    """Retourne le classement des champs par impact sur la precision des projections.

    Chaque champ est classe par son impact (0-10) sur les projections
    financieres, avec une explication de pourquoi il est important.

    Args:
        document_type: Type de document (lpp_certificate, tax_declaration, etc.).

    Returns:
        FieldImpactResponse avec champs classes par impact decroissant.
    """
    if document_type not in _VALID_DOCUMENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Type de document non supporte: {document_type}. "
                   f"Types supportes: {', '.join(sorted(_VALID_DOCUMENT_TYPES))}",
        )

    try:
        doc_type = DocumentType(document_type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Type de document invalide: {document_type}",
        )

    # Get all fields for this document type (all are "missing" to show full ranking)
    from app.services.document_parser.extraction_confidence_scorer import _FIELD_IMPACT

    doc_fields = _FIELD_IMPACT.get(doc_type, {})
    all_field_names = list(doc_fields.keys())

    ranked = rank_fields_by_impact(all_field_names, doc_type)

    return FieldImpactResponse(
        document_type=document_type,
        fields=[
            FieldImpactItem(
                field_name=item["field_name"],
                impact=item["impact"],
                reason=item["reason"],
                projection_affected=item["projection_affected"],
            )
            for item in ranked
        ],
        disclaimer=_DISCLAIMER,
        sources=_SOURCES,
    )


# ══════════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════════


def _field_to_profile_key(field_name: str) -> str | None:
    """Mappe un nom de champ extraction vers le champ profil correspondant."""
    mapping = {
        # LPP certificate fields
        "avoir_total": "lpp_total",
        "part_obligatoire": "lpp_obligatoire",
        "part_surobligatoire": "lpp_surobligatoire",
        "taux_conversion_oblig": "conversion_rate_oblig",
        "taux_conversion_suroblig": "conversion_rate_suroblig",
        "lacune_rachat": "buyback_potential",
        "rente_projetee": "projected_rente_lpp",
        "capital_projete_65": "projected_capital_65",
        "prestation_invalidite": "disability_coverage",
        "prestation_deces": "death_coverage",
        "cotisation_employe": "employee_lpp_contribution",
        "cotisation_employeur": "employer_lpp_contribution",
        "salaire_assure": "lpp_insured_salary",
        # Tax declaration fields
        "revenu_imposable": "actual_taxable_income",
        "fortune_imposable": "actual_taxable_wealth",
        "deductions_effectuees": "actual_deductions",
        "impot_cantonal": "actual_cantonal_tax",
        "impot_federal": "actual_federal_tax",
        "taux_marginal_effectif": "actual_marginal_rate",
        # AVS extract fields
        "annees_cotisation": "avs_contribution_years",
        "ramd": "avs_ramd",
        "lacunes_cotisation": "avs_gaps",
        "bonifications_educatives": "avs_education_credits",
    }
    return mapping.get(field_name)
