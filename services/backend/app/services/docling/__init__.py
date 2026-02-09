"""
Docling module for MINT — Document Intelligence Pipeline.

Phase 1: LPP Certificate Upload & Extraction.
Uses pdfplumber for lightweight PDF text extraction and structured field parsing
from Swiss LPP (prévoyance professionnelle) certificates.

Dependencies are optional — install with: pip install -e ".[docling]"
"""

try:
    from app.services.docling.parser import DocumentParser, ParsedDocument, PageContent
    from app.services.docling.extractors.lpp_certificate import (
        LPPCertificateExtractor,
        LPPCertificateData,
    )

    DOCLING_AVAILABLE = True
except ImportError:
    DOCLING_AVAILABLE = False

__all__ = [
    "DocumentParser",
    "ParsedDocument",
    "PageContent",
    "LPPCertificateExtractor",
    "LPPCertificateData",
    "DOCLING_AVAILABLE",
]
