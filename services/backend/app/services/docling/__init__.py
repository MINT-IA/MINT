"""
Docling module for MINT — Document Intelligence Pipeline.

Phase 1: LPP Certificate Upload & Extraction.
Phase 2: Bank Statement CSV/PDF Parsing & Transaction Categorization.

Uses pdfplumber for lightweight PDF text extraction and structured field parsing
from Swiss financial documents (LPP certificates, bank statements, etc.).

Dependencies are optional — install with: pip install -e ".[docling]"
"""

try:
    from app.services.docling.parser import DocumentParser, ParsedDocument, PageContent
    from app.services.docling.extractors.lpp_certificate import (
        LPPCertificateExtractor,
        LPPCertificateData,
    )
    from app.services.docling.extractors.bank_statement import (
        BankStatementExtractor,
        BankStatementData,
        BankTransaction,
    )
    from app.services.docling.categorizer import (
        TransactionCategorizer,
        CATEGORIES,
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
    "BankStatementExtractor",
    "BankStatementData",
    "BankTransaction",
    "TransactionCategorizer",
    "CATEGORIES",
    "DOCLING_AVAILABLE",
]
