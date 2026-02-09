"""
bLink API connector (SIX Financial Information AG).

bLink is the Swiss Open Banking standard by SIX.
API base: https://api.blink.six-group.com/v2/

Current mode: SANDBOX (mock data).
Production mode requires FINMA consultation + bLink contract.

Sprint S14 — Open Banking infrastructure.
Lecture seule. Aucune operation d'ecriture ou de transfert.
"""

from dataclasses import dataclass, field
from typing import List, Optional
from datetime import datetime, timedelta
import uuid


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class BankAccount:
    """Represents a bank account retrieved via bLink."""

    account_id: str
    iban: str
    bank_id: str
    bank_name: str
    account_type: str  # "checking", "savings", "3a", "securities"
    currency: str
    balance: float
    holder_name: str
    last_sync: str  # ISO datetime


@dataclass
class Transaction:
    """Represents a single bank transaction."""

    transaction_id: str
    account_id: str
    date: str  # ISO date (YYYY-MM-DD)
    booking_date: str  # ISO date
    description: str
    amount: float
    currency: str
    is_debit: bool
    merchant: Optional[str] = None
    category: Optional[str] = None
    reference: Optional[str] = None


@dataclass
class AccountBalance:
    """Current balance for an account."""

    account_id: str
    iban: str
    balance: float
    currency: str
    balance_type: str  # "closingAvailable", "expected"
    last_updated: str  # ISO datetime


# ---------------------------------------------------------------------------
# Mock data — realistic Swiss accounts
# ---------------------------------------------------------------------------

_MOCK_ACCOUNTS: List[BankAccount] = [
    BankAccount(
        account_id="acc-ubs-001",
        iban="CH9300762011623852957",
        bank_id="ubs",
        bank_name="UBS",
        account_type="checking",
        currency="CHF",
        balance=8450.00,
        holder_name="Utilisateur MINT",
        last_sync=datetime.utcnow().isoformat() + "Z",
    ),
    BankAccount(
        account_id="acc-pf-002",
        iban="CH1809000000123456789",
        bank_id="postfinance",
        bank_name="PostFinance",
        account_type="savings",
        currency="CHF",
        balance=23100.00,
        holder_name="Utilisateur MINT",
        last_sync=datetime.utcnow().isoformat() + "Z",
    ),
    BankAccount(
        account_id="acc-raif-003",
        iban="CH5280808001234567890",
        bank_id="raiffeisen",
        bank_name="Raiffeisen",
        account_type="3a",
        currency="CHF",
        balance=45000.00,
        holder_name="Utilisateur MINT",
        last_sync=datetime.utcnow().isoformat() + "Z",
    ),
]


def _generate_mock_transactions(account_id: str) -> List[Transaction]:
    """Generate realistic Swiss mock transactions for an account."""
    base_date = datetime(2025, 1, 15)
    transactions = []

    # Transactions for checking account (UBS)
    if account_id == "acc-ubs-001":
        raw = [
            ("2025-01-02", "Migros Plainpalais", -87.30, True, "Migros"),
            ("2025-01-03", "CFF Abonnement general", -340.00, True, "CFF"),
            ("2025-01-05", "Salaire janvier", 6800.00, False, None),
            ("2025-01-07", "Coop Pronto Gare", -23.50, True, "Coop"),
            ("2025-01-08", "Swisscom Mobile", -49.90, True, "Swisscom"),
            ("2025-01-10", "Loyer janvier — Regie Naef", -1850.00, True, "Gerance Naef"),
            ("2025-01-12", "CSS Assurance maladie", -385.00, True, "CSS"),
            ("2025-01-13", "Denner Carouge", -45.60, True, "Denner"),
            ("2025-01-14", "SIG Electricite", -95.00, True, "SIG"),
            ("2025-01-15", "Spotify Premium", -12.90, True, "Spotify"),
            ("2025-01-18", "Pharmacie Sun Store", -32.40, True, "Pharmacie Sun Store"),
            ("2025-01-20", "Parking P+R Bernex", -8.00, True, "Parking"),
            ("2025-01-22", "Netflix", -15.90, True, "Netflix"),
            ("2025-01-25", "Migros Balexert", -112.80, True, "Migros"),
            ("2025-01-28", "Administration fiscale GE", -450.00, True, "Administration fiscale"),
        ]
    elif account_id == "acc-pf-002":
        raw = [
            ("2025-01-05", "Virement depuis UBS", 500.00, False, None),
            ("2025-01-15", "Interet epargne Q4 2024", 12.30, False, None),
        ]
    elif account_id == "acc-raif-003":
        raw = [
            ("2025-01-05", "Versement 3a mensuel", 587.00, False, None),
        ]
    else:
        return []

    for i, (date_str, desc, amount, is_debit, merchant) in enumerate(raw):
        transactions.append(
            Transaction(
                transaction_id=f"tx-{account_id}-{i:03d}",
                account_id=account_id,
                date=date_str,
                booking_date=date_str,
                description=desc,
                amount=amount,
                currency="CHF",
                is_debit=is_debit,
                merchant=merchant,
            )
        )

    return transactions


# ---------------------------------------------------------------------------
# Connector
# ---------------------------------------------------------------------------

class BLinkConnector:
    """bLink API connector (SIX Financial Information).

    bLink is the Swiss Open Banking standard by SIX.
    API base: https://api.blink.six-group.com/v2/

    Current mode: SANDBOX (mock data).
    Production mode requires FINMA consultation + bLink contract.

    Lecture seule — aucune operation d'ecriture, de transfert ou de paiement.
    """

    def __init__(self, sandbox: bool = True):
        self.sandbox = sandbox
        self.base_url = "https://api.blink.six-group.com/v2/"

    def get_accounts(self, consent_id: str) -> List[BankAccount]:
        """Fetch accounts for a given consent.

        Returns mock data in sandbox mode.
        In production, calls bLink GET /accounts with the consent token.

        Args:
            consent_id: Valid consent identifier.

        Returns:
            List of BankAccount objects.
        """
        if self.sandbox:
            # Update last_sync to current time
            accounts = []
            for acct in _MOCK_ACCOUNTS:
                accounts.append(
                    BankAccount(
                        account_id=acct.account_id,
                        iban=acct.iban,
                        bank_id=acct.bank_id,
                        bank_name=acct.bank_name,
                        account_type=acct.account_type,
                        currency=acct.currency,
                        balance=acct.balance,
                        holder_name=acct.holder_name,
                        last_sync=datetime.utcnow().isoformat() + "Z",
                    )
                )
            return accounts

        # Production path (not yet implemented — requires bLink contract)
        raise NotImplementedError(
            "Production bLink calls not available — FINMA consultation pending."
        )

    def get_transactions(
        self,
        account_id: str,
        date_from: str,
        date_to: str,
    ) -> List[Transaction]:
        """Fetch transactions for account within date range.

        Returns mock data in sandbox mode.
        In production, calls bLink GET /accounts/{id}/transactions.

        Args:
            account_id: Account identifier.
            date_from: Start date (YYYY-MM-DD).
            date_to: End date (YYYY-MM-DD).

        Returns:
            Filtered list of Transaction objects.
        """
        if self.sandbox:
            all_tx = _generate_mock_transactions(account_id)
            # Filter by date range
            filtered = [
                tx
                for tx in all_tx
                if date_from <= tx.date <= date_to
            ]
            return filtered

        raise NotImplementedError(
            "Production bLink calls not available — FINMA consultation pending."
        )

    def get_balances(self, account_id: str) -> Optional[AccountBalance]:
        """Fetch current balance for an account.

        Returns mock data in sandbox mode.
        In production, calls bLink GET /accounts/{id}/balances.

        Args:
            account_id: Account identifier.

        Returns:
            AccountBalance object or None if account not found.
        """
        if self.sandbox:
            for acct in _MOCK_ACCOUNTS:
                if acct.account_id == account_id:
                    return AccountBalance(
                        account_id=acct.account_id,
                        iban=acct.iban,
                        balance=acct.balance,
                        currency=acct.currency,
                        balance_type="closingAvailable",
                        last_updated=datetime.utcnow().isoformat() + "Z",
                    )
            return None

        raise NotImplementedError(
            "Production bLink calls not available — FINMA consultation pending."
        )
