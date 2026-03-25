"""
Open Banking endpoints — bLink/SFTI infrastructure.

All gated endpoints require OPEN_BANKING_ENABLED=true environment variable.
Feature gate remains closed until FINMA consultation completes.

Sprint S14 — Open Banking infrastructure.
Lecture seule. Aucune operation d'ecriture ou de transfert.

Endpoints:
    GET  /status                           — Feature status (no gate)
    POST /consent                          — Create banking consent
    DELETE /consent/{consent_id}            — Revoke consent
    GET  /consents                         — List active consents
    GET  /accounts                         — List connected accounts
    GET  /accounts/{account_id}/transactions — List transactions
    GET  /accounts/{account_id}/balance    — Current balance
    GET  /summary                          — Monthly summary
    POST /categorize                       — Re-categorize transactions
"""

import logging
import os
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.auth import require_current_user
from app.models.user import User

logger = logging.getLogger(__name__)
from app.schemas.open_banking import (
    OpenBankingStatusResponse,
    ConsentRequest,
    ConsentResponse,
    BankAccountResponse,
    TransactionResponse,
    BalanceResponse,
    AggregatedViewResponse,
    MonthlySummaryResponse,
    CategorySummaryResponse,
    CategorizeRequest,
    CategorizeResponse,
)
from app.services.open_banking.blink_connector import BLinkConnector
from app.services.open_banking.consent_manager import ConsentManager
from app.services.open_banking.transaction_categorizer import TransactionCategorizer
from app.services.open_banking.account_aggregator import AccountAggregator


router = APIRouter()

# ---------------------------------------------------------------------------
# Shared service instances (in-memory for MVP)
# ---------------------------------------------------------------------------

_connector = BLinkConnector(sandbox=True)
_consent_manager = ConsentManager()
_categorizer = TransactionCategorizer()
_aggregator = AccountAggregator(
    connector=_connector,
    consent_manager=_consent_manager,
    categorizer=_categorizer,
)

# V3-4: Log warning — in-memory mode means consents are lost on restart.
logger.warning(
    "Open Banking running in-memory mode — consents will not survive restart"
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Informations a titre educatif et indicatif uniquement. "
    "Les donnees presentees proviennent d'un environnement de demonstration (sandbox). "
    "MINT ne fournit pas de conseil financier personnalise. "
    "Consultez un ou une specialiste pour toute decision financiere."
)



# ---------------------------------------------------------------------------
# FINMA Gate
# ---------------------------------------------------------------------------

def _check_open_banking_enabled():
    """Check if Open Banking is enabled (requires FINMA consultation).

    Raises HTTPException 503 if the feature gate is closed.
    """
    enabled = os.environ.get("OPEN_BANKING_ENABLED", "false").lower() == "true"
    if not enabled:
        raise HTTPException(
            status_code=503,
            detail={
                "message": (
                    "Service en preparation — consultation reglementaire en cours. "
                    "Contactez support@mint.ch pour plus d'informations."
                ),
                "contact": "support@mint.ch",
                "finmaStatus": "consultation_pending",
            },
        )


# ---------------------------------------------------------------------------
# Status (NO gate — always accessible)
# ---------------------------------------------------------------------------

@router.get("/status", response_model=OpenBankingStatusResponse)
def get_status() -> OpenBankingStatusResponse:
    """Get Open Banking feature status.

    This endpoint is always accessible (no FINMA gate).
    """
    enabled = os.environ.get("OPEN_BANKING_ENABLED", "false").lower() == "true"

    if enabled:
        message = (
            "Open Banking est active en mode sandbox. "
            "Les donnees affichees sont des donnees de demonstration."
        )
        finma_status = "sandbox"
    else:
        message = (
            "Service en preparation — consultation reglementaire en cours. "
            "Contactez support@mint.ch pour plus d'informations."
        )
        finma_status = "consultation_pending"

    return OpenBankingStatusResponse(
        enabled=enabled,
        message=message,
        finmaStatus=finma_status,
        disclaimer=DISCLAIMER,
    )


# ---------------------------------------------------------------------------
# Consent Management
# ---------------------------------------------------------------------------

@router.post("/consent", response_model=ConsentResponse)
def create_consent(request: ConsentRequest, current_user: User = Depends(require_current_user)) -> ConsentResponse:
    """Create a new banking consent (nLPD-compliant).

    Requires explicit opt-in. Scopes must be explicitly chosen.
    Maximum duration: 90 days. Revocable at any time.
    """
    _check_open_banking_enabled()

    try:
        consent = _consent_manager.create_consent(
            user_id=current_user.id,
            bank_id=request.bankId,
            bank_name=request.bankName,
            scopes=request.scopes,
        )
    except ValueError:
        raise HTTPException(status_code=422, detail="Unprocessable input")

    return ConsentResponse(
        consentId=consent.consent_id,
        bankId=consent.bank_id,
        bankName=consent.bank_name,
        scopes=consent.scopes,
        grantedAt=consent.granted_at,
        expiresAt=consent.expires_at,
        status="active",
    )


@router.delete("/consent/{consent_id}")
def revoke_consent(consent_id: str, current_user: User = Depends(require_current_user)):
    """Revoke a banking consent.

    The consent is immediately invalidated. All associated data access stops.
    This action is logged in the audit trail.
    """
    _check_open_banking_enabled()

    # V3-4: IDOR guard — verify consent belongs to the current user.
    consent = _consent_manager.get_consent(consent_id)
    if not consent:
        raise HTTPException(status_code=404, detail="Consentement non trouve.")
    if consent.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acces interdit.")

    success = _consent_manager.revoke_consent(consent_id)
    if not success:
        raise HTTPException(status_code=404, detail="Consentement non trouve.")

    return {
        "ok": True,
        "message": "Consentement revoque avec succes.",
        "consentId": consent_id,
    }


@router.get("/consents", response_model=List[ConsentResponse])
def list_consents(current_user: User = Depends(require_current_user)) -> List[ConsentResponse]:
    """List active consents for the current person."""
    _check_open_banking_enabled()

    consents = _consent_manager.get_active_consents(current_user.id)

    return [
        ConsentResponse(
            consentId=c.consent_id,
            bankId=c.bank_id,
            bankName=c.bank_name,
            scopes=c.scopes,
            grantedAt=c.granted_at,
            expiresAt=c.expires_at,
            status="active",
        )
        for c in consents
    ]


# ---------------------------------------------------------------------------
# Accounts
# ---------------------------------------------------------------------------

@router.get("/accounts", response_model=AggregatedViewResponse)
def list_accounts(current_user: User = Depends(require_current_user)) -> AggregatedViewResponse:
    """List all connected accounts (aggregated view).

    Requires at least one active consent with 'accounts' scope.
    """
    _check_open_banking_enabled()

    view = _aggregator.get_aggregated_view(current_user.id)

    return AggregatedViewResponse(
        totalBalance=view.total_balance,
        accounts=[
            BankAccountResponse(
                accountId=a.account_id,
                iban=a.iban,
                bankName=a.bank_name,
                accountType=a.account_type,
                balance=a.balance,
                currency=a.currency,
                lastSync="",  # Not tracked in aggregated summary
            )
            for a in view.accounts
        ],
        categorySummary=[
            CategorySummaryResponse(
                name=c.category,
                total=c.total,
                percentage=c.percentage,
                transactionCount=c.transaction_count,
            )
            for c in view.category_summary
        ],
        disclaimer=DISCLAIMER,
        finmaStatus="sandbox",
    )


# ---------------------------------------------------------------------------
# Transactions
# ---------------------------------------------------------------------------

@router.get(
    "/accounts/{account_id}/transactions",
    response_model=List[TransactionResponse],
)
def list_transactions(
    account_id: str,
    date_from: str = Query("2025-01-01", description="Date de debut (YYYY-MM-DD)"),
    date_to: str = Query("2025-12-31", description="Date de fin (YYYY-MM-DD)"),
    category: Optional[str] = Query(None, description="Filtrer par categorie"),
    current_user: User = Depends(require_current_user),
) -> List[TransactionResponse]:
    """List transactions for an account with optional filters.

    Requires an active consent with 'transactions' scope.
    """
    _check_open_banking_enabled()

    transactions = _connector.get_transactions(account_id, date_from, date_to)
    categorized = _categorizer.categorize_batch(transactions)

    if category:
        categorized = [t for t in categorized if t.category == category]

    return [
        TransactionResponse(
            id=t.transaction_id,
            date=t.date,
            description=t.description,
            amount=t.amount,
            currency=t.currency,
            category=t.category,
            merchant=t.merchant,
            isDebit=t.is_debit,
            confidence=t.confidence,
        )
        for t in categorized
    ]


# ---------------------------------------------------------------------------
# Balance
# ---------------------------------------------------------------------------

@router.get(
    "/accounts/{account_id}/balance",
    response_model=BalanceResponse,
)
def get_balance(account_id: str, current_user: User = Depends(require_current_user)) -> BalanceResponse:
    """Get current balance for an account.

    Requires an active consent with 'balances' scope.
    """
    _check_open_banking_enabled()

    balance = _connector.get_balances(account_id)
    if not balance:
        raise HTTPException(status_code=404, detail="Compte non trouve.")

    return BalanceResponse(
        accountId=balance.account_id,
        iban=balance.iban,
        balance=balance.balance,
        currency=balance.currency,
        lastUpdated=balance.last_updated,
        disclaimer=DISCLAIMER,
        finmaStatus="sandbox",
    )


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

@router.get("/summary", response_model=MonthlySummaryResponse)
def get_monthly_summary(
    month: int = Query(1, ge=1, le=12, description="Mois (1-12)"),
    year: int = Query(2025, description="Annee"),
    current_user: User = Depends(require_current_user),
) -> MonthlySummaryResponse:
    """Get aggregated monthly summary across all connected accounts."""
    _check_open_banking_enabled()

    summary = _aggregator.get_monthly_summary(current_user.id, month, year)

    return MonthlySummaryResponse(
        month=summary.month,
        year=summary.year,
        totalIncome=summary.total_income,
        totalExpenses=summary.total_expenses,
        categories=[
            CategorySummaryResponse(
                name=c.category,
                total=c.total,
                percentage=c.percentage,
                transactionCount=c.transaction_count,
            )
            for c in summary.categories
        ],
        savingsRate=summary.savings_rate,
        disclaimer=DISCLAIMER,
        finmaStatus="sandbox",
    )


# ---------------------------------------------------------------------------
# Categorize
# ---------------------------------------------------------------------------

@router.post("/categorize", response_model=CategorizeResponse)
def categorize_transactions(request: CategorizeRequest, current_user: User = Depends(require_current_user)) -> CategorizeResponse:
    """Re-categorize transactions for an account.

    Uses Swiss-specific merchant patterns (Migros, Coop, CFF, etc.).
    """
    _check_open_banking_enabled()

    transactions = _connector.get_transactions(
        request.accountId, request.dateFrom, request.dateTo
    )
    categorized = _categorizer.categorize_batch(transactions)

    categories_used = list(set(t.category for t in categorized))

    return CategorizeResponse(
        transactions=[
            TransactionResponse(
                id=t.transaction_id,
                date=t.date,
                description=t.description,
                amount=t.amount,
                currency=t.currency,
                category=t.category,
                merchant=t.merchant,
                isDebit=t.is_debit,
                confidence=t.confidence,
            )
            for t in categorized
        ],
        categoriesUsed=sorted(categories_used),
        disclaimer=DISCLAIMER,
        finmaStatus="sandbox",
    )
