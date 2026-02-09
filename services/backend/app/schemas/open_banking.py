"""
Pydantic v2 schemas for Open Banking module.

Sprint S14: bLink/SFTI Open Banking infrastructure.
API convention: camelCase field names.
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
from enum import Enum


# ===========================================================================
# Enums
# ===========================================================================

class AccountType(str, Enum):
    checking = "checking"
    savings = "savings"
    pillar3a = "3a"
    securities = "securities"


class ConsentStatus(str, Enum):
    active = "active"
    revoked = "revoked"
    expired = "expired"


# ===========================================================================
# Bank Account Schemas
# ===========================================================================

class BankAccountResponse(BaseModel):
    """A connected bank account."""

    model_config = ConfigDict(populate_by_name=True)

    accountId: str = Field(..., description="Identifiant du compte")
    iban: str = Field(..., description="IBAN du compte")
    bankName: str = Field(..., description="Nom de la banque")
    accountType: str = Field(..., description="Type de compte (checking, savings, 3a, securities)")
    balance: float = Field(..., description="Solde actuel (CHF)")
    currency: str = Field("CHF", description="Devise")
    lastSync: str = Field(..., description="Derniere synchronisation (ISO datetime)")


# ===========================================================================
# Transaction Schemas
# ===========================================================================

class TransactionResponse(BaseModel):
    """A single bank transaction."""

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(..., description="Identifiant de la transaction")
    date: str = Field(..., description="Date de la transaction (YYYY-MM-DD)")
    description: str = Field(..., description="Description")
    amount: float = Field(..., description="Montant (CHF)")
    currency: str = Field("CHF", description="Devise")
    category: str = Field(..., description="Categorie de depense")
    merchant: Optional[str] = Field(None, description="Nom du commercant")
    isDebit: bool = Field(..., description="Debit (true) ou credit (false)")
    confidence: float = Field(
        ..., description="Score de confiance de la categorisation (0-1)"
    )


# ===========================================================================
# Consent Schemas
# ===========================================================================

class ConsentRequest(BaseModel):
    """Request to create a new banking consent."""

    model_config = ConfigDict(populate_by_name=True)

    bankId: str = Field(
        ..., description="Identifiant de la banque (ex: ubs, postfinance, raiffeisen)"
    )
    bankName: str = Field(..., description="Nom de la banque")
    scopes: List[str] = Field(
        ..., description="Scopes demandes : accounts, balances, transactions"
    )


class ConsentResponse(BaseModel):
    """A banking consent."""

    model_config = ConfigDict(populate_by_name=True)

    consentId: str = Field(..., description="Identifiant du consentement")
    bankId: str = Field(..., description="Identifiant de la banque")
    bankName: str = Field(..., description="Nom de la banque")
    scopes: List[str] = Field(..., description="Scopes accordes")
    grantedAt: str = Field(..., description="Date d'octroi (ISO datetime)")
    expiresAt: str = Field(
        ..., description="Date d'expiration (ISO datetime, max 90 jours)"
    )
    status: str = Field(..., description="Statut : active, revoked, expired")


# ===========================================================================
# Aggregated View Schemas
# ===========================================================================

class CategorySummaryResponse(BaseModel):
    """Summary for a single spending category."""

    model_config = ConfigDict(populate_by_name=True)

    name: str = Field(..., description="Nom de la categorie")
    total: float = Field(..., description="Total des depenses (CHF)")
    percentage: float = Field(..., description="Pourcentage du total")
    transactionCount: int = Field(..., description="Nombre de transactions")


class AggregatedViewResponse(BaseModel):
    """Aggregated view across all connected accounts."""

    model_config = ConfigDict(populate_by_name=True)

    totalBalance: float = Field(..., description="Solde total (CHF)")
    accounts: List[BankAccountResponse] = Field(
        ..., description="Liste des comptes connectes"
    )
    categorySummary: List[CategorySummaryResponse] = Field(
        default_factory=list, description="Resume par categorie"
    )
    disclaimer: str = Field(..., description="Avertissement legal")
    finmaStatus: str = Field(
        "sandbox", description="Statut FINMA (sandbox, consultation_pending, approved)"
    )


class MonthlySummaryResponse(BaseModel):
    """Monthly financial summary."""

    model_config = ConfigDict(populate_by_name=True)

    month: int = Field(..., description="Mois (1-12)")
    year: int = Field(..., description="Annee")
    totalIncome: float = Field(..., description="Revenu total du mois (CHF)")
    totalExpenses: float = Field(..., description="Depenses totales du mois (CHF)")
    categories: List[CategorySummaryResponse] = Field(
        ..., description="Repartition par categorie"
    )
    savingsRate: float = Field(
        ..., description="Taux d'epargne en pourcentage (0-100)"
    )
    disclaimer: str = Field(..., description="Avertissement legal")
    finmaStatus: str = Field(
        "sandbox", description="Statut FINMA"
    )


class CategoryBreakdownResponse(BaseModel):
    """Category breakdown for a date range."""

    model_config = ConfigDict(populate_by_name=True)

    categories: List[CategorySummaryResponse] = Field(
        ..., description="Liste des categories"
    )
    totalExpenses: float = Field(..., description="Total des depenses (CHF)")
    disclaimer: str = Field(..., description="Avertissement legal")
    finmaStatus: str = Field(
        "sandbox", description="Statut FINMA"
    )


# ===========================================================================
# Status Schema
# ===========================================================================

class OpenBankingStatusResponse(BaseModel):
    """Open Banking feature status."""

    model_config = ConfigDict(populate_by_name=True)

    enabled: bool = Field(
        ..., description="Indique si Open Banking est active"
    )
    message: str = Field(..., description="Message de statut")
    finmaStatus: str = Field(
        ..., description="Statut FINMA (sandbox, consultation_pending, approved)"
    )
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Categorize Request
# ===========================================================================

class CategorizeRequest(BaseModel):
    """Request to re-categorize transactions."""

    model_config = ConfigDict(populate_by_name=True)

    accountId: str = Field(..., description="Identifiant du compte")
    dateFrom: str = Field(..., description="Date de debut (YYYY-MM-DD)")
    dateTo: str = Field(..., description="Date de fin (YYYY-MM-DD)")


class CategorizeResponse(BaseModel):
    """Response with categorized transactions."""

    model_config = ConfigDict(populate_by_name=True)

    transactions: List[TransactionResponse] = Field(
        ..., description="Transactions categorisees"
    )
    categoriesUsed: List[str] = Field(
        ..., description="Categories utilisees"
    )
    disclaimer: str = Field(..., description="Avertissement legal")
    finmaStatus: str = Field(
        "sandbox", description="Statut FINMA"
    )


# ===========================================================================
# Balance Schema
# ===========================================================================

class BalanceResponse(BaseModel):
    """Current account balance."""

    model_config = ConfigDict(populate_by_name=True)

    accountId: str = Field(..., description="Identifiant du compte")
    iban: str = Field(..., description="IBAN")
    balance: float = Field(..., description="Solde actuel (CHF)")
    currency: str = Field("CHF", description="Devise")
    lastUpdated: str = Field(..., description="Derniere mise a jour (ISO datetime)")
    disclaimer: str = Field(..., description="Avertissement legal")
    finmaStatus: str = Field(
        "sandbox", description="Statut FINMA"
    )
