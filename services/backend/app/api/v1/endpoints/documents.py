"""
Document Intelligence (Docling) endpoints for MINT.

Phase 1: LPP Certificate Upload & Extraction.
Phase 2: Bank Statement CSV/PDF Parsing & Transaction Categorization.

Accepts PDF/CSV uploads, extracts structured data from Swiss financial documents,
and optionally indexes extracted data into the RAG vector store.

Privacy: raw file bytes are never stored permanently. Only extracted fields
are kept in the in-memory document store.
"""

import logging
import os
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, File, HTTPException, Query, UploadFile

from app.schemas.document import (
    BankStatementUploadResponse,
    BudgetImportPreview,
    DocumentDeleteResponse,
    DocumentDetailResponse,
    DocumentListResponse,
    DocumentSummary,
    DocumentUploadResponse,
    TransactionResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter()

# In-memory document store (Phase 1 — will migrate to DB in Phase 2)
_document_store: dict[str, dict] = {}


def _get_document_store() -> dict:
    """Get the in-memory document store (for testing override)."""
    return _document_store


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────


def _detect_document_type(text: str) -> str:
    """
    Detect the type of Swiss financial document from its text.

    Returns: 'lpp_certificate', 'salary_slip', or 'unknown'.
    """
    text_lower = text.lower()

    # LPP / BVG certificate indicators
    lpp_keywords = [
        "avoir de vieillesse",
        "taux de conversion",
        "caisse de pension",
        "prévoyance professionnelle",
        "certificat de prévoyance",
        "certificat d'assurance",
        "lpp",
        "altersguthaben",
        "umwandlungssatz",
        "pensionskasse",
        "vorsorgeausweis",
        "bvg",
        "avere di vecchiaia",
        "previdenza professionale",
    ]

    # Salary slip indicators
    salary_keywords = [
        "fiche de salaire",
        "bulletin de paie",
        "décompte de salaire",
        "lohnabrechnung",
        "gehaltsabrechnung",
        "net à payer",
        "nettolohn",
    ]

    lpp_score = sum(1 for kw in lpp_keywords if kw in text_lower)
    salary_score = sum(1 for kw in salary_keywords if kw in text_lower)

    if lpp_score >= 2:
        return "lpp_certificate"
    elif salary_score >= 2:
        return "salary_slip"
    elif lpp_score >= 1:
        return "lpp_certificate"
    elif salary_score >= 1:
        return "salary_slip"

    return "unknown"


def _index_in_rag(doc_id: str, extracted_fields: dict, document_type: str) -> bool:
    """
    Index extracted document data in the RAG vector store.

    Allows users to ask questions about their own certificate
    via the RAG chat interface.

    Returns True if indexing succeeded, False otherwise.
    """
    try:
        from app.services.rag import RAG_AVAILABLE

        if not RAG_AVAILABLE:
            logger.info("RAG not available, skipping document indexation")
            return False

        from app.services.rag.vector_store import MintVectorStore

        backend_dir = os.path.dirname(
            os.path.dirname(
                os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
            )
        )
        persist_dir = os.path.join(backend_dir, "data", "chromadb")
        vector_store = MintVectorStore(persist_directory=persist_dir)

        # Build a structured text summary of the extracted fields
        text_parts = [f"Document type: {document_type}"]
        for key, value in extracted_fields.items():
            if value is not None and key not in (
                "confidence",
                "extracted_fields_count",
                "total_fields_count",
            ):
                text_parts.append(f"{key}: {value}")

        text = "\n".join(text_parts)

        documents = [
            {
                "id": f"doc_upload_{doc_id}",
                "text": text,
                "metadata": {
                    "source": f"uploaded_{document_type}",
                    "category": "user_document",
                    "document_type": document_type,
                    "document_id": doc_id,
                    "language": "fr",
                },
            }
        ]

        count = vector_store.add_documents(documents)
        logger.info("Indexed document %s in RAG vector store (%d chunks)", doc_id, count)
        return count > 0

    except Exception as e:
        logger.warning("Failed to index document in RAG (non-fatal): %s", e)
        return False


# ──────────────────────────────────────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────────────────────────────────────


@router.post("/upload", response_model=DocumentUploadResponse)
async def upload_document(
    file: UploadFile = File(...),
    index_in_rag: bool = Query(
        False,
        description="Whether to index extracted data in the RAG vector store",
    ),
):
    """
    Upload a PDF document for extraction.

    Accepts a PDF file, extracts text and tables, detects document type,
    and extracts structured fields (LPP certificate data).

    The raw PDF is never stored — only the extracted fields are kept.
    """
    # Validate file type
    if file.content_type and file.content_type not in (
        "application/pdf",
        "application/octet-stream",
    ):
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file.content_type}. Only PDF files are accepted.",
        )

    # Check filename extension
    filename = file.filename or ""
    if not filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=400,
            detail="File must have a .pdf extension.",
        )

    # Read file bytes
    try:
        file_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {str(e)}")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")

    # Import docling components
    try:
        from app.services.docling.parser import DocumentParser
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="Docling dependencies not installed. Install with: pip install -e '.[docling]'",
        )

    warnings: list[str] = []

    # Parse PDF
    try:
        parser = DocumentParser()
        parsed = parser.parse_pdf(file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not parsed.full_text.strip():
        warnings.append("No text could be extracted from the PDF (scanned image?)")

    # Detect document type
    doc_type = _detect_document_type(parsed.full_text)
    if doc_type == "unknown":
        warnings.append(
            "Could not identify document type. Attempting LPP extraction anyway."
        )

    # Extract fields (attempt LPP extraction regardless of detected type)
    extractor = LPPCertificateExtractor()
    all_tables = []
    for page in parsed.pages:
        all_tables.extend(page.tables)

    extracted = extractor.extract(parsed.full_text, tables=all_tables)

    if extracted.extracted_fields_count == 0 and doc_type != "salary_slip":
        warnings.append(
            "No LPP certificate fields could be extracted. "
            "The document may not be a pension certificate."
        )

    # Generate document ID
    doc_id = str(uuid.uuid4())[:12]

    # Prepare extracted fields dict (exclude metadata fields)
    extracted_dict = extracted.to_dict()
    # Remove internal metadata from the user-facing payload
    extracted_dict.pop("confidence", None)
    extracted_dict.pop("extracted_fields_count", None)
    extracted_dict.pop("total_fields_count", None)

    # Preview text (first 500 chars, privacy-safe)
    raw_preview = parsed.full_text[:500] if parsed.full_text else ""

    # Store in memory (no raw PDF stored — privacy by design)
    now = datetime.now(timezone.utc).isoformat()
    _document_store[doc_id] = {
        "id": doc_id,
        "document_type": doc_type,
        "upload_date": now,
        "confidence": extracted.confidence,
        "fields_found": extracted.extracted_fields_count,
        "fields_total": extracted.total_fields_count,
        "extracted_fields": extracted_dict,
        "warnings": warnings,
    }

    # Optionally index in RAG
    rag_indexed = False
    if index_in_rag and extracted.extracted_fields_count > 0:
        rag_indexed = _index_in_rag(doc_id, extracted_dict, doc_type)

    return DocumentUploadResponse(
        document_id=doc_id,
        document_type=doc_type,
        extracted_fields=extracted_dict,
        confidence=extracted.confidence,
        fields_found=extracted.extracted_fields_count,
        fields_total=extracted.total_fields_count,
        raw_text_preview=raw_preview,
        warnings=warnings,
        rag_indexed=rag_indexed,
    )


@router.get("/", response_model=DocumentListResponse)
async def list_documents():
    """
    List all uploaded documents.

    Returns document summaries (no extracted fields for performance).
    """
    store = _get_document_store()
    summaries = [
        DocumentSummary(
            id=doc["id"],
            document_type=doc["document_type"],
            upload_date=doc["upload_date"],
            confidence=doc["confidence"],
            fields_found=doc["fields_found"],
        )
        for doc in store.values()
    ]
    return DocumentListResponse(documents=summaries)


@router.get("/{doc_id}", response_model=DocumentDetailResponse)
async def get_document(doc_id: str):
    """
    Get a specific document by ID.

    Returns full extracted fields and metadata.
    """
    store = _get_document_store()
    if doc_id not in store:
        raise HTTPException(status_code=404, detail=f"Document {doc_id} not found")

    doc = store[doc_id]
    return DocumentDetailResponse(
        id=doc["id"],
        document_type=doc["document_type"],
        upload_date=doc["upload_date"],
        confidence=doc["confidence"],
        fields_found=doc["fields_found"],
        fields_total=doc["fields_total"],
        extracted_fields=doc["extracted_fields"],
        warnings=doc["warnings"],
    )


@router.delete("/{doc_id}", response_model=DocumentDeleteResponse)
async def delete_document(doc_id: str):
    """
    Delete a document by ID.

    Removes all stored data for privacy. This is irreversible.
    """
    store = _get_document_store()
    if doc_id not in store:
        raise HTTPException(status_code=404, detail=f"Document {doc_id} not found")

    del store[doc_id]
    return DocumentDeleteResponse(deleted=True, id=doc_id)


# ──────────────────────────────────────────────────────────────────────────────
# Phase 2: Bank Statement Upload
# ──────────────────────────────────────────────────────────────────────────────


@router.post("/upload-statement", response_model=BankStatementUploadResponse)
async def upload_bank_statement(
    file: UploadFile = File(...),
):
    """
    Upload a CSV or PDF bank statement for parsing and categorization.

    Accepts CSV or PDF files from Swiss banks (UBS, PostFinance, Raiffeisen, ZKB).
    Auto-detects bank format, extracts transactions, categorizes spending,
    and returns a budget-ready summary.

    The raw file is never stored — only extracted transactions are kept.
    """
    filename = file.filename or ""
    filename_lower = filename.lower()

    # Validate file extension
    if not (filename_lower.endswith(".csv") or filename_lower.endswith(".pdf")):
        raise HTTPException(
            status_code=400,
            detail="File must have a .csv or .pdf extension.",
        )

    # Read file bytes
    try:
        file_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {str(e)}")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")

    # Import bank statement components
    try:
        from app.services.docling.extractors.bank_statement import (
            BankStatementExtractor,
        )
        from app.services.docling.categorizer import TransactionCategorizer
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="Docling dependencies not installed. Install with: pip install -e '.[docling]'",
        )

    extractor = BankStatementExtractor()
    categorizer = TransactionCategorizer()

    # Parse based on file type
    try:
        if filename_lower.endswith(".csv"):
            statement = extractor.parse_csv(file_bytes)
        else:
            statement = extractor.parse_pdf(file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Categorize transactions
    categorizer.categorize_transactions(statement.transactions)

    # Build response
    category_summary = categorizer.compute_category_summary(statement.transactions)

    # Recurring transactions
    recurring_txs = [
        TransactionResponse(
            date=tx.date,
            description=tx.description,
            amount=tx.amount,
            balance=tx.balance,
            category=tx.category,
            subcategory=tx.subcategory,
            is_recurring=tx.is_recurring,
        )
        for tx in statement.transactions
        if tx.is_recurring
    ]

    # All transactions
    all_txs = [
        TransactionResponse(
            date=tx.date,
            description=tx.description,
            amount=tx.amount,
            balance=tx.balance,
            category=tx.category,
            subcategory=tx.subcategory,
            is_recurring=tx.is_recurring,
        )
        for tx in statement.transactions
    ]

    return BankStatementUploadResponse(
        document_type="bank_statement",
        bank_name=statement.bank_name,
        period_start=statement.period_start,
        period_end=statement.period_end,
        currency=statement.currency,
        transactions=all_txs,
        total_credits=statement.total_credits,
        total_debits=statement.total_debits,
        opening_balance=statement.opening_balance,
        closing_balance=statement.closing_balance,
        confidence=statement.confidence,
        warnings=statement.warnings,
        category_summary=category_summary,
        recurring_monthly=recurring_txs,
    )


@router.post("/upload-statement/preview", response_model=BudgetImportPreview)
async def preview_budget_import(
    file: UploadFile = File(...),
):
    """
    Preview what a bank statement import would look like in the budget module.

    Returns estimated monthly income, expenses, top categories, recurring charges,
    and savings rate — without storing any data.
    """
    filename = file.filename or ""
    filename_lower = filename.lower()

    if not (filename_lower.endswith(".csv") or filename_lower.endswith(".pdf")):
        raise HTTPException(
            status_code=400,
            detail="File must have a .csv or .pdf extension.",
        )

    try:
        file_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {str(e)}")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")

    try:
        from app.services.docling.extractors.bank_statement import (
            BankStatementExtractor,
        )
        from app.services.docling.categorizer import TransactionCategorizer
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="Docling dependencies not installed.",
        )

    extractor = BankStatementExtractor()
    categorizer = TransactionCategorizer()

    try:
        if filename_lower.endswith(".csv"):
            statement = extractor.parse_csv(file_bytes)
        else:
            statement = extractor.parse_pdf(file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    categorizer.categorize_transactions(statement.transactions)
    preview = categorizer.compute_budget_preview(statement.transactions)

    return BudgetImportPreview(**preview)
