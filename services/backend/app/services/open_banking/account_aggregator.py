"""
Account Aggregator — multi-bank account aggregation.

Provides a unified view across all connected banks:
    - Patrimoine total (somme de tous les soldes)
    - Repartition par type de compte (courant, epargne, 3a, titres)
    - Resume mensuel par categorie de depenses

Sprint S14 — Open Banking infrastructure.
Lecture seule. Aucune operation d'ecriture ou de transfert.
"""

from dataclasses import dataclass
from typing import Dict, List, Optional

from app.services.open_banking.blink_connector import BLinkConnector
from app.services.open_banking.consent_manager import ConsentManager
from app.services.open_banking.transaction_categorizer import TransactionCategorizer


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class AccountSummary:
    """Summary of a single account."""

    account_id: str
    iban: str
    bank_name: str
    account_type: str
    balance: float
    currency: str


@dataclass
class CategoryTotal:
    """Totals for a spending category."""

    category: str
    total: float
    percentage: float
    transaction_count: int


@dataclass
class AggregatedView:
    """Aggregated view across all connected accounts."""

    total_balance: float
    currency: str
    accounts: List[AccountSummary]
    category_summary: List[CategoryTotal]
    disclaimer: str


@dataclass
class MonthlySummary:
    """Monthly income/expense summary."""

    month: int
    year: int
    total_income: float
    total_expenses: float
    savings_rate: float  # percentage (0-100)
    categories: List[CategoryTotal]
    disclaimer: str


@dataclass
class CategoryBreakdown:
    """Category breakdown for a date range."""

    date_from: str
    date_to: str
    categories: List[CategoryTotal]
    total_expenses: float
    disclaimer: str


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
# Aggregator
# ---------------------------------------------------------------------------

class AccountAggregator:
    """Aggregate accounts from multiple banks.

    Provides a unified view across all connected banks:
        - Patrimoine total (somme de tous les soldes)
        - Repartition par type de compte (courant, epargne, 3a, titres)
        - Resume mensuel par categorie de depenses

    Lecture seule — aucune operation d'ecriture, de transfert ou de paiement.
    """

    def __init__(
        self,
        connector: Optional[BLinkConnector] = None,
        consent_manager: Optional[ConsentManager] = None,
        categorizer: Optional[TransactionCategorizer] = None,
    ):
        self.connector = connector or BLinkConnector(sandbox=True)
        self.consent_manager = consent_manager or ConsentManager()
        self.categorizer = categorizer or TransactionCategorizer()

    def get_aggregated_view(self, user_id: str) -> AggregatedView:
        """Get aggregated view across all connected accounts.

        Args:
            user_id: Person's identifier.

        Returns:
            AggregatedView with total balance and per-account summaries.
        """
        consents = self.consent_manager.get_active_consents(user_id)

        all_accounts: List[AccountSummary] = []
        total_balance = 0.0

        for consent in consents:
            if "accounts" not in consent.scopes:
                continue
            accounts = self.connector.get_accounts(consent.consent_id)
            # Filter to accounts belonging to this consent's bank
            bank_accounts = [a for a in accounts if a.bank_id == consent.bank_id]
            for acct in bank_accounts:
                all_accounts.append(
                    AccountSummary(
                        account_id=acct.account_id,
                        iban=acct.iban,
                        bank_name=acct.bank_name,
                        account_type=acct.account_type,
                        balance=acct.balance,
                        currency=acct.currency,
                    )
                )
                total_balance += acct.balance

        return AggregatedView(
            total_balance=total_balance,
            currency="CHF",
            accounts=all_accounts,
            category_summary=[],  # Populated when transactions are fetched
            disclaimer=DISCLAIMER,
        )

    def get_monthly_summary(
        self,
        user_id: str,
        month: int,
        year: int,
    ) -> MonthlySummary:
        """Get monthly transaction summary.

        Args:
            user_id: Person's identifier.
            month: Month number (1-12).
            year: Year (e.g. 2025).

        Returns:
            MonthlySummary with income, expenses, savings rate, and categories.
        """
        date_from = f"{year}-{month:02d}-01"
        if month == 12:
            date_to = f"{year + 1}-01-01"
        else:
            date_to = f"{year}-{month + 1:02d}-01"

        consents = self.consent_manager.get_active_consents(user_id)

        all_transactions = []
        for consent in consents:
            if "transactions" not in consent.scopes:
                continue
            accounts = self.connector.get_accounts(consent.consent_id)
            bank_accounts = [a for a in accounts if a.bank_id == consent.bank_id]
            for acct in bank_accounts:
                txs = self.connector.get_transactions(
                    acct.account_id, date_from, date_to
                )
                all_transactions.extend(txs)

        # Categorize
        categorized = self.categorizer.categorize_batch(all_transactions)

        # Calculate totals
        total_income = sum(t.amount for t in categorized if not t.is_debit)
        total_expenses = abs(sum(t.amount for t in categorized if t.is_debit))

        # Savings rate
        savings_rate = 0.0
        if total_income > 0:
            savings_rate = round(((total_income - total_expenses) / total_income) * 100, 1)

        # Category breakdown (only expenses)
        cat_totals: Dict[str, dict] = {}
        for t in categorized:
            if t.is_debit:
                cat = t.category
                if cat not in cat_totals:
                    cat_totals[cat] = {"total": 0.0, "count": 0}
                cat_totals[cat]["total"] += abs(t.amount)
                cat_totals[cat]["count"] += 1

        categories = []
        for cat_name, data in sorted(
            cat_totals.items(), key=lambda x: x[1]["total"], reverse=True
        ):
            pct = round((data["total"] / total_expenses * 100), 1) if total_expenses > 0 else 0.0
            categories.append(
                CategoryTotal(
                    category=cat_name,
                    total=round(data["total"], 2),
                    percentage=pct,
                    transaction_count=data["count"],
                )
            )

        return MonthlySummary(
            month=month,
            year=year,
            total_income=round(total_income, 2),
            total_expenses=round(total_expenses, 2),
            savings_rate=savings_rate,
            categories=categories,
            disclaimer=DISCLAIMER,
        )

    def get_category_breakdown(
        self,
        user_id: str,
        date_from: str,
        date_to: str,
    ) -> CategoryBreakdown:
        """Get category breakdown for a date range.

        Args:
            user_id: Person's identifier.
            date_from: Start date (YYYY-MM-DD).
            date_to: End date (YYYY-MM-DD).

        Returns:
            CategoryBreakdown with expense categories.
        """
        consents = self.consent_manager.get_active_consents(user_id)

        all_transactions = []
        for consent in consents:
            if "transactions" not in consent.scopes:
                continue
            accounts = self.connector.get_accounts(consent.consent_id)
            bank_accounts = [a for a in accounts if a.bank_id == consent.bank_id]
            for acct in bank_accounts:
                txs = self.connector.get_transactions(
                    acct.account_id, date_from, date_to
                )
                all_transactions.extend(txs)

        categorized = self.categorizer.categorize_batch(all_transactions)

        total_expenses = abs(sum(t.amount for t in categorized if t.is_debit))

        cat_totals: Dict[str, dict] = {}
        for t in categorized:
            if t.is_debit:
                cat = t.category
                if cat not in cat_totals:
                    cat_totals[cat] = {"total": 0.0, "count": 0}
                cat_totals[cat]["total"] += abs(t.amount)
                cat_totals[cat]["count"] += 1

        categories = []
        for cat_name, data in sorted(
            cat_totals.items(), key=lambda x: x[1]["total"], reverse=True
        ):
            pct = round((data["total"] / total_expenses * 100), 1) if total_expenses > 0 else 0.0
            categories.append(
                CategoryTotal(
                    category=cat_name,
                    total=round(data["total"], 2),
                    percentage=pct,
                    transaction_count=data["count"],
                )
            )

        return CategoryBreakdown(
            date_from=date_from,
            date_to=date_to,
            categories=categories,
            total_expenses=round(total_expenses, 2),
            disclaimer=DISCLAIMER,
        )
