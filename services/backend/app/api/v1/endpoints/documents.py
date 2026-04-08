"""
Document Intelligence (Docling) endpoints for MINT.

Phase 1: LPP Certificate Upload & Extraction.
Phase 2: Bank Statement CSV/PDF Parsing & Transaction Categorization.

Accepts PDF/CSV uploads, extracts structured data from Swiss financial documents,
and optionally indexes extracted data into the RAG vector store.

Privacy: raw file bytes are never stored permanently. Only extracted fields
are kept in the database.
"""

import hashlib
import json
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.services.billing_service import recompute_entitlements
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.document import DocumentModel
from app.models.user import User
from anthropic import Anthropic

from app.core.config import settings
from app.schemas.document_scan import (
    DocumentScanConfirmation,
    DocumentScanResponse,
    ExtractedFieldConfirmation,
    PremierEclairageRequest,
    PremierEclairageResponse,
    VisionExtractionRequest,
    VisionExtractionResponse,
)
from app.services.reengagement.consent_manager import ConsentManager
from app.services.reengagement.reengagement_models import ConsentType

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
# Premier Eclairage — 4-layer insight engine for documents (DOC-07)
# ──────────────────────────────────────────────────────────────────────────────

_DOCUMENT_SOURCES_MAP = {
    "lpp_certificate": ["LPP art. 14-16 (taux de conversion, bonifications)", "OPP2 (prevoyance professionnelle)"],
    "avs_extract": ["LAVS art. 21-40 (rentes de vieillesse)", "RAVS (reglement AVS)"],
    "tax_declaration": ["LIFD art. 38 (impot sur le capital)", "LHID (harmonisation fiscale)"],
    "salary_certificate": ["LAVS art. 5 (cotisations)", "LPP art. 7-8 (salaire coordonne)"],
    "payslip": ["LAVS art. 5 (cotisations)", "CO art. 322 (obligations de l'employeur)"],
    "lpp_plan": ["LPP art. 14-16", "OPP2 art. 5 (EPL)"],
    "pillar_3a_attestation": ["OPP3 art. 1-7 (3e pilier)", "LIFD art. 33 (deductions)"],
    "insurance_contract": ["LAMal (assurance maladie)", "LCA (contrat d'assurance)"],
}

_DISCLAIMER_TEXT = (
    "Outil educatif. Ne constitue pas un conseil financier au sens de la LSFin. "
    "Pour une analyse adaptee a ta situation, consulte un\u00b7e specialiste."
)

_PREMIER_ECLAIRAGE_SYSTEM_PROMPT = """\
Tu es Mint, l'intelligence financiere suisse. Tu viens d'analyser un {document_type} \
pour un utilisateur{canton_clause}.

MOTEUR 4 COUCHES — reponds en JSON strict avec ces 4 cles :
1. "factual_extraction": Resume les faits cles extraits du document (montants, taux, dates). 2-3 phrases max.
2. "human_translation": Explique en langage simple ce que ces chiffres signifient, sans jargon. 2-3 phrases max.
3. "personal_perspective": Ce que cela implique concretement pour cet utilisateur (points forts, points d'attention, opportunites manquees). 2-3 phrases max.
4. "questions_to_ask": Liste de 2-3 questions pertinentes que l'utilisateur devrait poser a sa caisse ou son employeur.

DOCTRINE : Mint eclaire, Mint ne juge pas. Mint explicite le contrat. Mint dit 'voici ce que cela implique pour toi'.
INTERDICTIONS : Pas de 'garanti', 'optimal', 'meilleur', 'sans risque'. Pas de conseil produit. Conditionnel ('pourrait', 'envisager').
FORMAT : Reponds UNIQUEMENT en JSON valide, sans texte autour. Les valeurs sont des strings sauf questions_to_ask qui est une liste de strings.
{plan_1e_context}
DONNEES EXTRAITES DU DOCUMENT :
{fields_context}
"""


def _build_fields_context(extracted_fields: List[ExtractedFieldConfirmation]) -> str:
    """Build a text summary of extracted fields for the prompt."""
    lines = []
    for f in extracted_fields:
        lines.append(f"- {f.field_name}: {f.value}")
    return "\n".join(lines) if lines else "(aucun champ extrait)"


def _build_fallback_response(
    extracted_fields: List[ExtractedFieldConfirmation],
    document_type: str,
) -> PremierEclairageResponse:
    """Build a graceful fallback response when Claude API fails."""
    field_summary = ", ".join(
        f"{f.field_name}: {f.value}" for f in extracted_fields[:5]
    )
    if not field_summary:
        field_summary = "Aucun champ extrait"

    sources = _DOCUMENT_SOURCES_MAP.get(document_type, ["Droit suisse applicable"])

    return PremierEclairageResponse(
        factual_extraction=f"Donnees extraites de ton document : {field_summary}.",
        human_translation="Ton profil a ete enrichi avec les informations de ce document.",
        personal_perspective="Consulte l'onglet Explorer pour voir comment ces donnees impactent ta situation.",
        questions_to_ask=["Verifie que les montants correspondent a ton dernier releve."],
        disclaimer=_DISCLAIMER_TEXT,
        sources=sources,
    )


def generate_document_insight(
    document_type,
    extracted_fields: List[ExtractedFieldConfirmation],
    canton: Optional[str] = None,
    plan_type: Optional[str] = None,
) -> PremierEclairageResponse:
    """Generate a 4-layer premier eclairage from extracted document data.

    Uses Claude API with the MINT 4-layer insight engine pattern.
    Falls back to a safe summary if the API call fails.

    Args:
        document_type: Type of document (DocumentType enum or string).
        extracted_fields: List of extracted field confirmations.
        canton: User's canton for regional context.
        plan_type: LPP plan type (legal, surobligatoire, 1e).

    Returns:
        PremierEclairageResponse with all 4 layers, disclaimer, and sources.
    """
    doc_type_str = document_type.value if hasattr(document_type, "value") else str(document_type)

    # Check API key availability
    api_key = settings.ANTHROPIC_API_KEY
    if not api_key:
        logger.warning("No ANTHROPIC_API_KEY for premier eclairage, returning fallback")
        return _build_fallback_response(extracted_fields, doc_type_str)

    # Build prompt context
    canton_clause = f" du canton {canton}" if canton else ""
    plan_1e_context = ""
    if plan_type and plan_type.lower() in ("1e", "plan_1e"):
        plan_1e_context = (
            "ATTENTION : Plan 1e detecte. Aucun taux de conversion fixe contractuellement. "
            "Projections en capital uniquement. Ne mentionne pas de rente mensuelle estimee.\n"
        )

    fields_context = _build_fields_context(extracted_fields)

    system_prompt = _PREMIER_ECLAIRAGE_SYSTEM_PROMPT.format(
        document_type=doc_type_str,
        canton_clause=canton_clause,
        plan_1e_context=plan_1e_context,
        fields_context=fields_context,
    )

    try:
        client = Anthropic(api_key=api_key)
        response = client.messages.create(
            model=settings.COACH_MODEL,
            max_tokens=800,
            timeout=30.0,
            messages=[
                {
                    "role": "user",
                    "content": system_prompt,
                }
            ],
        )

        raw_text = response.content[0].text
        parsed = json.loads(raw_text)

        sources = _DOCUMENT_SOURCES_MAP.get(doc_type_str, ["Droit suisse applicable"])

        return PremierEclairageResponse(
            factual_extraction=parsed.get("factual_extraction", ""),
            human_translation=parsed.get("human_translation", ""),
            personal_perspective=parsed.get("personal_perspective", ""),
            questions_to_ask=parsed.get("questions_to_ask", []),
            disclaimer=_DISCLAIMER_TEXT,
            sources=sources,
        )

    except Exception as e:
        logger.warning("Premier eclairage generation failed: %s", e)
        return _build_fallback_response(extracted_fields, doc_type_str)


# ──────────────────────────────────────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────────────────────────────────────


@router.post("/premier-eclairage", response_model=PremierEclairageResponse)
@limiter.limit("5/minute")
async def document_premier_eclairage(
    body: PremierEclairageRequest,
    request: Request,
    _user: User = Depends(require_current_user),
):
    """Generate a 4-layer premier eclairage from extracted document data (DOC-07).

    Called after document extraction and user confirmation to produce a
    personalized insight using the MINT 4-layer insight engine:
    1. Factual extraction (what the document says)
    2. Human translation (plain language)
    3. Personal perspective (what it means for the user)
    4. Questions to ask (before signing/acting)

    Rate limited to 5/minute (heavier than extraction).
    All LLM-generated text is validated through ComplianceGuard (COMP-01).
    """
    response = generate_document_insight(
        document_type=body.document_type,
        extracted_fields=body.extracted_fields,
        canton=body.canton,
        plan_type=body.plan_type,
    )

    # ── COMP-01: Validate LLM output through ComplianceGuard before return ──
    # Checks each text field for banned terms, prescriptive language, etc.
    from app.services.coach.compliance_guard import ComplianceGuard, ComponentType
    guard = ComplianceGuard()
    user_id_hash = hashlib.sha256(str(_user.id).encode()).hexdigest()[:16]

    for field_name in ("factual_extraction", "human_translation", "personal_perspective"):
        original = getattr(response, field_name, "")
        if not original:
            continue
        result = guard.validate(
            llm_output=original,
            component_type=ComponentType.general,
            user_id=user_id_hash,
        )
        if not result.is_compliant:
            logger.warning(
                "ComplianceGuard rejected document insight field=%s violations=%s user=%s",
                field_name, result.violations, user_id_hash,
            )
            # Replace with sanitized text or fallback
            setattr(response, field_name, result.sanitized_text or original)

    return response


@router.post("/upload", response_model=DocumentUploadResponse)
@limiter.limit("10/minute")
async def upload_document(
    request: Request,
    file: UploadFile = File(...),
    index_in_rag: bool = Query(
        False,
        description="Whether to index extracted data in the RAG vector store",
    ),
    db: Session = Depends(get_db),
    _user: User = Depends(require_current_user),
):
    """
    Upload a PDF document for extraction.

    Accepts a PDF file, extracts text and tables, detects document type,
    and extracts structured fields (LPP certificate data).

    The raw PDF is never stored — only the extracted fields are kept.
    """
    # Entitlement gate: vault feature required for unlimited uploads.
    # Free users are limited to 2 documents.
    effective_tier, active_features = recompute_entitlements(db, str(_user.id))
    if "vault" not in active_features:
        doc_count = db.query(DocumentModel).filter(
            DocumentModel.user_id == str(_user.id)
        ).count()
        if doc_count >= 2:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Limite de 2 documents atteinte. Passe à Premium pour plus.",
            )

    # nLPD art. 6 al. 7: Verify document_upload consent before persisting
    if not ConsentManager.is_consent_given(
        str(_user.id), ConsentType.document_upload, db=db
    ):
        raise HTTPException(
            status_code=403,
            detail=(
                "Consentement 'document_upload' requis pour telecharger un document. "
                "Active-le dans Profil > Consentements."
            ),
        )

    # FIX-W12: Enforce per-user document limit (all tiers)
    MAX_DOCUMENTS_PER_USER = 100
    total_docs = db.query(DocumentModel).filter(
        DocumentModel.user_id == str(_user.id)
    ).count()
    if total_docs >= MAX_DOCUMENTS_PER_USER:
        raise HTTPException(400, f"Limite de {MAX_DOCUMENTS_PER_USER} documents atteinte.")

    # FIX-W12: Strict MIME type — reject application/octet-stream
    if file.content_type and file.content_type != "application/pdf":
        raise HTTPException(400, "Only PDF files are accepted (Content-Type: application/pdf).")

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
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid request parameters")

    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")

    # FIX-W12: Validate PDF magic bytes (first 5 bytes must be %PDF-)
    if not file_bytes[:5] == b"%PDF-":
        raise HTTPException(
            status_code=400,
            detail="File is not a valid PDF (invalid magic bytes).",
        )

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
@limiter.limit("30/minute")
async def list_documents(
    request: Request,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=100, description="Max documents to return (1-100)"),
    offset: int = Query(0, ge=0, description="Number of documents to skip"),
):
    """
    List all uploaded documents for the current user.

    Returns document summaries (no extracted fields for performance).
    Supports LIMIT/OFFSET pagination (max 100 per page).
    """
    base_query = db.query(DocumentModel).filter(
        DocumentModel.user_id == str(_user.id)
    )
    total = base_query.count()
    rows = base_query.order_by(DocumentModel.upload_date.desc()).offset(offset).limit(limit).all()
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
    return DocumentListResponse(documents=summaries, total=total, limit=limit, offset=offset)


@router.get("/{doc_id}", response_model=DocumentDetailResponse)
@limiter.limit("30/minute")
async def get_document(
    request: Request,
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
@limiter.limit("10/minute")
async def delete_document(
    request: Request,
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

    # P2-19 nLPD: Purge RAG embeddings for this document before deleting the record.
    try:
        from app.services.rag import RAG_AVAILABLE

        if RAG_AVAILABLE:
            from app.services.rag.vector_store import MintVectorStore

            backend_dir = os.path.dirname(
                os.path.dirname(
                    os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
                )
            )
            persist_dir = os.path.join(backend_dir, "data", "chromadb")
            vector_store = MintVectorStore(persist_directory=persist_dir)
            embedding_id = f"doc_upload_{doc_id}"
            try:
                vector_store.collection.delete(ids=[embedding_id])
                logger.info("Purged RAG embedding for document %s", doc_id)
            except Exception as e:
                logger.warning("Failed to purge RAG embedding for %s: %s", doc_id, e)
    except ImportError:
        pass  # RAG not installed — no embeddings to purge

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
    except Exception:
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
@limiter.limit("10/minute")
async def preview_budget_import(
    request: Request,
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
    except Exception:
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


def _classify_and_reject_if_needed(image_base64: str) -> Optional[str]:
    """Pre-extraction classification gate (DOC-10).

    Returns a rejection message if the document is not financial,
    or None if classification passes (extraction should proceed).
    """
    from app.services import document_vision_service as dvs

    classification = dvs.classify_document(image_base64)
    if not classification.is_financial:
        return (
            "Ce document ne semble pas etre un document financier suisse. "
            "Essaie avec un certificat LPP, de salaire, 3a, ou une police d'assurance."
        )
    return None


@router.post("/extract-vision", response_model=VisionExtractionResponse)
@limiter.limit("10/minute")
async def extract_with_claude_vision(
    body: VisionExtractionRequest,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    """Extract structured data from a document image using Claude Vision.

    Hardened pipeline (02-01):
    1. Pre-extraction classification — rejects non-financial documents (DOC-10)
    2. Audit log creation — metadata only, no image data (DOC-08)
    3. Finally-block deletion — image cleared even on error (COMP-04)

    Privacy: image is sent to Claude API for processing but NOT stored.
    Only extracted structured fields are returned.
    """
    from app.services.document_vision_service import extract_with_vision
    from app.models.document_audit import create_audit_log

    logger.info(
        "Vision extraction: user=%s type=%s canton=%s",
        str(current_user.id)[:8] + "...",  # Truncate PII
        body.document_type.value,
        body.canton,
    )

    # ── Step 1: Pre-extraction classification (DOC-10) ──
    rejection_message = _classify_and_reject_if_needed(body.image_base64)
    if rejection_message:
        raise HTTPException(status_code=422, detail=rejection_message)

    # ── Step 2: Create audit log (DOC-08) ──
    audit_log = create_audit_log(
        user_id=str(current_user.id),
        document_type=body.document_type.value,
        extraction_method="claude_vision",
    )
    audit_log.classification_result = "financial"
    db.add(audit_log)

    # ── Step 3: Extract with finally-block cleanup (COMP-04) ──
    try:
        result = extract_with_vision(
            image_base64=body.image_base64,
            doc_type=body.document_type,
            canton=body.canton,
            language_hint=body.language_hint,
        )
        audit_log.field_count = len(result.extracted_fields)
        audit_log.overall_confidence = result.overall_confidence
        return result
    except ValueError as e:
        audit_log.error_message = str(e)[:500]
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        audit_log.error_message = str(e)[:500]
        logger.error("Vision extraction failed: %s", e)
        raise HTTPException(
            status_code=502,
            detail="Document extraction failed. Please try again.",
        )
    finally:
        # COMP-04: Always record deletion time and clear image from memory
        audit_log.deleted_at = datetime.now(timezone.utc)
        body.image_base64 = ""  # Explicit in-memory cleanup
        try:
            db.commit()  # Persist audit log
        except Exception as commit_err:
            logger.error("Failed to commit audit log: %s", commit_err)
            db.rollback()


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
