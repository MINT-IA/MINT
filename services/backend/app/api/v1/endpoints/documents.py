"""
Document Intelligence (Docling) endpoints for MINT.

Phase 1: LPP Certificate Upload & Extraction.
Phase 2: Bank Statement CSV/PDF Parsing & Transaction Categorization.

Accepts PDF/CSV uploads, extracts structured data from Swiss financial documents,
and optionally indexes extracted data into the RAG vector store.

Privacy: raw file bytes are never stored permanently. Only extracted fields
are kept in the database.
"""

import logging
import os
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.document import DocumentModel
from app.models.user import User

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

# Max upload size: 20 MB (LPP certificates, salary slips, bank statements)
MAX_UPLOAD_BYTES = 20 * 1024 * 1024


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
@limiter.limit("10/minute")
async def upload_document(
    request: Request,
    file: UploadFile = File(...),
    index_in_rag: bool = Query(
        False,
        description="Whether to index extracted data in the RAG vector store",
    ),
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
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
            detail="Unsupported file type. Only PDF files are accepted.",
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
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")

    if len(file_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Fichier trop volumineux ({len(file_bytes) // (1024*1024)} Mo). Maximum: {MAX_UPLOAD_BYTES // (1024*1024)} Mo.",
        )

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
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

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

    # Persist to database (no raw PDF stored — privacy by design)
    now = datetime.now(timezone.utc)
    doc_model = DocumentModel(
        id=doc_id,
        user_id=str(_user.id),
        document_type=doc_type,
        upload_date=now,
        confidence=extracted.confidence,
        fields_found=extracted.extracted_fields_count,
        fields_total=extracted.total_fields_count,
        extracted_fields=extracted_dict,
        warnings=warnings,
    )
    db.add(doc_model)
    db.commit()

    # Optionally index in RAG
    rag_indexed = False
    if index_in_rag and extracted.extracted_fields_count > 0:
        rag_indexed = _index_in_rag(doc_id, extracted_dict, doc_type)

    return DocumentUploadResponse(
        id=doc_id,
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
async def list_documents(
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    """
    List all uploaded documents for the current user.

    Returns document summaries (no extracted fields for performance).
    """
    rows = db.query(DocumentModel).filter(
        DocumentModel.user_id == str(_user.id)
    ).all()
    summaries = [
        DocumentSummary(
            id=row.id,
            document_type=row.document_type,
            upload_date=row.upload_date.isoformat() if row.upload_date else None,
            confidence=row.confidence,
            fields_found=row.fields_found,
        )
        for row in rows
    ]
    return DocumentListResponse(documents=summaries)


@router.get("/{doc_id}", response_model=DocumentDetailResponse)
async def get_document(
    doc_id: str,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    """
    Get a specific document by ID.

    Returns full extracted fields and metadata.
    Only the document owner can access it.
    """
    row = db.query(DocumentModel).filter(DocumentModel.id == doc_id).first()
    if not row:
        raise HTTPException(status_code=404, detail=f"Document {doc_id} not found")

    if row.user_id != str(_user.id):
        raise HTTPException(status_code=403, detail="Not authorized to access this document")
    return DocumentDetailResponse(
        id=row.id,
        document_type=row.document_type,
        upload_date=row.upload_date.isoformat() if row.upload_date else None,
        confidence=row.confidence,
        fields_found=row.fields_found,
        fields_total=row.fields_total,
        extracted_fields=row.extracted_fields or {},
        warnings=row.warnings or [],
    )


@router.delete("/{doc_id}", response_model=DocumentDeleteResponse)
async def delete_document(
    doc_id: str,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    """
    Delete a document by ID.

    Removes all stored data for privacy. This is irreversible.
    Only the document owner can delete it.
    """
    row = db.query(DocumentModel).filter(DocumentModel.id == doc_id).first()
    if not row:
        raise HTTPException(status_code=404, detail=f"Document {doc_id} not found")

    if row.user_id != str(_user.id):
        raise HTTPException(status_code=403, detail="Not authorized to delete this document")

    db.delete(row)
    db.commit()
    return DocumentDeleteResponse(deleted=True, id=doc_id)


# ──────────────────────────────────────────────────────────────────────────────
# Phase 2: Bank Statement Upload
# ──────────────────────────────────────────────────────────────────────────────


@router.post("/upload-statement", response_model=BankStatementUploadResponse)
@limiter.limit("10/minute")
async def upload_bank_statement(
    request: Request,  # Required by slowapi limiter
    file: UploadFile = File(...),
    _user: User = Depends(require_current_user),
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
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")

    if len(file_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Fichier trop volumineux ({len(file_bytes) // (1024*1024)} Mo). Maximum: {MAX_UPLOAD_BYTES // (1024*1024)} Mo.",
        )

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
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

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
    _user: User = Depends(require_current_user),
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
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")

    if len(file_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Fichier trop volumineux ({len(file_bytes) // (1024*1024)} Mo). Maximum: {MAX_UPLOAD_BYTES // (1024*1024)} Mo.",
        )

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
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    categorizer.categorize_transactions(statement.transactions)
    preview = categorizer.compute_budget_preview(statement.transactions)

    return BudgetImportPreview(**preview)


# ════════════════════════════════════════════════════════════
#  SCAN CONFIRMATION + CLAUDE VISION EXTRACTION
# ════════════════════════════════════════════════════════════

from app.schemas.document_scan import (
    DocumentScanConfirmation,
    DocumentScanResponse,
    VisionExtractionRequest,
    VisionExtractionResponse,
)


@router.post("/scan-confirmation", response_model=DocumentScanResponse)
@limiter.limit("30/minute")
async def confirm_document_scan(
    body: DocumentScanConfirmation,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    """Receive confirmed document scan extraction from mobile.

    Called after user reviews and confirms OCR/Vision extracted fields.
    Syncs extracted data to the user's profile on the backend.

    Privacy: no raw document image is sent — only confirmed field values.
    """
    logger.info(
        "Scan confirmation: user=%s type=%s fields=%d confidence=%.2f method=%s",
        str(current_user.id)[:8] + "...",  # Truncate PII
        body.document_type.value,
        len(body.confirmed_fields),
        body.overall_confidence,
        body.extraction_method,
    )

    # Store scan metadata for audit trail
    scan_id = str(uuid.uuid4())
    doc_model = DocumentModel(
        id=scan_id,
        user_id=str(current_user.id),
        document_type=body.document_type.value,
        upload_date=datetime.now(timezone.utc),
        confidence=body.overall_confidence,
        overall_confidence=body.overall_confidence,
        extraction_method=body.extraction_method,
        fields_found=len(body.confirmed_fields),
        fields_total=len(body.confirmed_fields),
        extracted_fields={f.field_name: f.value for f in body.confirmed_fields},
        warnings=[],
    )
    db.add(doc_model)
    db.commit()

    # Calculate confidence delta (how much this scan improves profile)
    confidence_delta = _estimate_scan_confidence_delta(body)

    return DocumentScanResponse(
        status="confirmed",
        fields_updated=len(body.confirmed_fields),
        confidence_delta=confidence_delta,
        message=f"Scan {body.document_type.value} synced ({len(body.confirmed_fields)} fields)",
    )


@router.post("/extract-vision", response_model=VisionExtractionResponse)
@limiter.limit("10/minute")
async def extract_with_claude_vision(
    body: VisionExtractionRequest,
    request: Request,
    current_user: User = Depends(require_current_user),
):
    """Extract structured data from a document image using Claude Vision.

    Replaces MLKit OCR with Claude Vision for better accuracy on
    Swiss financial documents (LPP certs, tax declarations, etc.).

    Privacy: image is sent to Claude API for processing but NOT stored.
    Only extracted structured fields are returned.
    """
    from app.services.document_vision_service import extract_with_vision

    logger.info(
        "Vision extraction: user=%s type=%s canton=%s",
        str(current_user.id)[:8] + "...",  # Truncate PII
        body.document_type.value,
        body.canton,
    )

    try:
        result = extract_with_vision(
            image_base64=body.image_base64,
            doc_type=body.document_type,
            canton=body.canton,
            language_hint=body.language_hint,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("Vision extraction failed: %s", e)
        raise HTTPException(
            status_code=502,
            detail="Document extraction failed. Please try again.",
        )


def _estimate_scan_confidence_delta(body: DocumentScanConfirmation) -> float:
    """Estimate how much a scan confirmation improves profile confidence.

    Based on document type and number of high-confidence fields.
    """
    base_delta = {
        "lpp_certificate": 0.27,
        "avs_extract": 0.22,
        "tax_declaration": 0.17,
        "salary_certificate": 0.20,
        "payslip": 0.10,
        "lease_contract": 0.08,
        "lpp_plan": 0.12,
        "insurance_contract": 0.05,
    }
    delta = base_delta.get(body.document_type.value, 0.05)

    # Reduce delta if confidence is low
    if body.overall_confidence < 0.5:
        delta *= 0.5

    return round(delta, 2)
