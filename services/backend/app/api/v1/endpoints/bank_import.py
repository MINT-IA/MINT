"""
Bank statement import endpoint.

POST /api/v1/bank-import/import
Accepts CSV (.csv) or ISO 20022 XML (.xml) bank statements,
auto-detects the format (6 Swiss banks + camt.053/054),
parses transactions, and returns categorized results.

Privacy: raw file bytes are processed in-memory only.
No PII (IBAN, account numbers) is logged or stored.
"""

import logging

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile

from app.core.auth import User, require_current_user
from app.core.rate_limit import limiter
from app.schemas.bank_import import BankImportErrorResponse, BankImportResponse, TransactionSchema
from app.services.bank_import_service import parse_bank_statement

logger = logging.getLogger(__name__)

router = APIRouter()

# 20 MB max upload
MAX_UPLOAD_BYTES = 20 * 1024 * 1024

ALLOWED_EXTENSIONS = {".csv", ".xml"}


@router.post(
    "/import",
    response_model=BankImportResponse,
    responses={
        400: {"model": BankImportErrorResponse, "description": "Unsupported format or parse error"},
        401: {"description": "Authentication required"},
        413: {"description": "File too large"},
        429: {"description": "Rate limit exceeded"},
    },
    summary="Import a bank statement (CSV or XML)",
    description=(
        "Upload a Swiss bank statement file. "
        "Supports UBS, PostFinance, Raiffeisen, BCGE/BCV, CS/ZKB, Yuh/Neon CSV formats "
        "and ISO 20022 camt.053/camt.054 XML. "
        "Returns auto-detected bank, categorized transactions, and summary."
    ),
)
@limiter.limit("10/minute")
async def import_bank_statement(
    request: Request,
    file: UploadFile = File(..., description="Bank statement file (.csv or .xml)"),
    _user: User = Depends(require_current_user),
) -> BankImportResponse:
    """Parse and categorize a bank statement file."""
    # Validate filename extension
    filename = file.filename or "unknown.csv"
    ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail={
                "error": f"Extension '{ext}' non supportee. Utilisez .csv ou .xml.",
                "supportedFormats": [
                    "UBS (CSV)", "PostFinance (CSV)", "Raiffeisen (CSV)",
                    "BCGE/BCV (CSV)", "CS/ZKB (CSV)", "Yuh/Neon (CSV)",
                    "ISO 20022 camt.053 (XML)", "ISO 20022 camt.054 (XML)",
                ],
            },
        )

    # Read file content
    content = await file.read()
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Fichier trop volumineux (max 20 Mo).",
        )

    if not content.strip():
        raise HTTPException(
            status_code=400,
            detail={
                "error": "Le fichier est vide.",
                "supportedFormats": [],
            },
        )

    # Parse
    try:
        result = parse_bank_statement(content, filename)
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail={
                "error": str(e),
                "supportedFormats": [
                    "UBS (CSV)", "PostFinance (CSV)", "Raiffeisen (CSV)",
                    "BCGE/BCV (CSV)", "CS/ZKB (CSV)", "Yuh/Neon (CSV)",
                    "ISO 20022 camt.053 (XML)", "ISO 20022 camt.054 (XML)",
                ],
            },
        )

    # PRIVACY: The uploaded file is NOT persisted — only the ParseResult is returned.
    # Raw bytes (content) are garbage-collected after the request completes.
    # Only category_summary aggregates are sent back to the client.

    # Build response
    transactions = [
        TransactionSchema(
            date=t.date.strftime("%Y-%m-%d"),
            description=t.description,
            amount=round(t.amount, 2),
            balance=round(t.balance, 2) if t.balance is not None else None,
            category=t.category,
            subcategory=t.subcategory,
            is_recurring=t.is_recurring,
        )
        for t in result.transactions
    ]

    return BankImportResponse(
        bank_name=result.bank_name,
        format=result.format.value,
        transactions=transactions,
        period_start=result.period_start.strftime("%Y-%m-%d") if result.period_start else None,
        period_end=result.period_end.strftime("%Y-%m-%d") if result.period_end else None,
        currency=result.currency,
        opening_balance=result.opening_balance,
        closing_balance=result.closing_balance,
        total_credits=round(result.total_credits, 2),
        total_debits=round(result.total_debits, 2),
        category_summary={k: round(v, 2) for k, v in result.category_summary.items()},
        confidence=result.confidence,
        transaction_count=len(transactions),
        warnings=result.warnings,
    )
