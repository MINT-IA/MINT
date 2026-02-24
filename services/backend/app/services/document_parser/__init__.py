"""
Document Parser module — Sprint S42-S45.

Service d'extraction structuree de documents financiers suisses
a partir de texte OCR.

Components:
    - document_models: DocumentType, ExtractedField, ExtractionResult, DataSource, ProfileField
    - lpp_certificate_parser: parse_lpp_certificate(), estimate_confidence_delta()
    - tax_declaration_parser: parse_tax_declaration(), estimate_tax_confidence_delta()
    - avs_extract_parser: parse_avs_extract(), estimate_avs_confidence_delta()
    - extraction_confidence_scorer: score_extraction(), rank_fields_by_impact()

Privacy: l'image source n'est jamais stockee. Seules les valeurs extraites
sont conservees localement, chiffrees au repos.

Sources:
    - LPP art. 7-8, 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - OPP3 art. 7 (3e pilier)
    - LIFD art. 25-33, 38 (imposition du revenu et du capital)
    - LHID art. 7-9 (harmonisation fiscale cantonale)
"""

from app.services.document_parser.document_models import (
    DocumentType,
    DataSource,
    ExtractedField,
    ExtractionResult,
    ProfileField,
    DATA_SOURCE_ACCURACY,
)
from app.services.document_parser.lpp_certificate_parser import (
    parse_lpp_certificate,
    estimate_confidence_delta,
    parse_swiss_number,
    KNOWN_FIELD_PATTERNS,
    HIGH_IMPACT_FIELDS,
)
from app.services.document_parser.tax_declaration_parser import (
    parse_tax_declaration,
    estimate_tax_confidence_delta,
    TAX_FIELD_PATTERNS,
    TAX_HIGH_IMPACT_FIELDS,
)
from app.services.document_parser.avs_extract_parser import (
    parse_avs_extract,
    estimate_avs_confidence_delta,
    AVS_FIELD_PATTERNS,
    AVS_HIGH_IMPACT_FIELDS,
)
from app.services.document_parser.extraction_confidence_scorer import (
    score_extraction,
    rank_fields_by_impact,
)

__all__ = [
    "DocumentType",
    "DataSource",
    "ExtractedField",
    "ExtractionResult",
    "ProfileField",
    "DATA_SOURCE_ACCURACY",
    "parse_lpp_certificate",
    "estimate_confidence_delta",
    "parse_swiss_number",
    "KNOWN_FIELD_PATTERNS",
    "HIGH_IMPACT_FIELDS",
    "parse_tax_declaration",
    "estimate_tax_confidence_delta",
    "TAX_FIELD_PATTERNS",
    "TAX_HIGH_IMPACT_FIELDS",
    "parse_avs_extract",
    "estimate_avs_confidence_delta",
    "AVS_FIELD_PATTERNS",
    "AVS_HIGH_IMPACT_FIELDS",
    "score_extraction",
    "rank_fields_by_impact",
]
