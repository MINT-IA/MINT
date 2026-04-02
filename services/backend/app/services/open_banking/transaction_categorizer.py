"""
Transaction categorizer for Swiss Open Banking data.

Auto-categorizes transactions using Swiss-specific merchant patterns.
Supports bilingual merchant names (FR/DE) common in Switzerland.

Sprint S14 — Open Banking infrastructure.
"""

from dataclasses import dataclass
from typing import List, Optional, Tuple


# ---------------------------------------------------------------------------
# Category rules — Swiss-specific merchant patterns
# ---------------------------------------------------------------------------

CATEGORY_RULES: dict[str, List[str]] = {
    "alimentation": [
        "migros", "coop", "denner", "aldi", "lidl", "manor food", "volg",
        "aligro", "otto's", "spar", "par", "globus", "epicerie",
    ],
    "transport": [
        "cff", "sbb", "tpg", "tl ", "bvb", "zvv", "bls", "vbl",
        "swisspass", "parking", "essence", "benzin", "shell", "bp ",
        "avia", "socar", "migrol",
    ],
    "logement": [
        "loyer", "miete", "rent", "gerance", "verwaltung",
        "hypotheque", "hypothek", "regie",
    ],
    "telecom": [
        "swisscom", "sunrise", "salt", "wingo", "yallo", "m-budget mobile",
    ],
    "assurances": [
        "css", "helsana", "swica", "concordia", "visana", "sanitas",
        "groupe mutuel", "assura", "atupri", "sympany", "okk",
        "baloise", "mobiliere", "mobiliar", "zurich", "axa",
        "helvetia", "vaudoise", "generali",
    ],
    "energie": [
        "sig", "romande energie", "bkw", "ewz", "ckw", "groupe e",
        "alpiq", "repower", "axpo",
    ],
    "sante": [
        "pharmacie", "apotheke", "medecin", "arzt", "hopital", "spital",
        "dentiste", "zahnarzt", "sun store", "amavita",
    ],
    "loisirs": [
        "spotify", "netflix", "apple", "google play", "cinema", "kino",
        "fitness", "pathe", "blue cinema", "disney",
    ],
    "finances": [
        "twint", "paypal", "revolut",
    ],
    "shopping": [
        "amazon", "aliexpress", "galaxus", "digitec", "zalando",
    ],
    "impots": [
        "administration fiscale", "steuerverwaltung", "impot", "steuer",
        "afc", "fisc",
    ],
    "revenu": [
        "salaire", "gehalt", "lohn", "revenu", "honoraire", "honorar",
        "dividende", "interet", "zins", "remboursement",
    ],
    "epargne": [
        "3a", "pilier", "saule", "viac", "frankly", "finpension",
        "versement epargne",
    ],
    "divers": [],
}


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class CategorizedTransaction:
    """A transaction with its assigned category."""

    transaction_id: str
    date: str
    description: str
    amount: float
    currency: str
    is_debit: bool
    category: str
    confidence: float  # 0.0 to 1.0
    match_type: str  # "auto" or "manual"
    merchant: Optional[str] = None


# ---------------------------------------------------------------------------
# Categorizer
# ---------------------------------------------------------------------------

class TransactionCategorizer:
    """Auto-categorize transactions using Swiss-specific merchant patterns.

    Matching is case-insensitive and uses substring matching.
    First matching category wins (categories are checked in definition order).
    Unknown transactions are categorized as 'divers'.
    """

    def __init__(self, rules: Optional[dict[str, List[str]]] = None):
        self.rules = rules or CATEGORY_RULES

    def categorize_one(
        self,
        description: str,
        merchant: Optional[str] = None,
    ) -> Tuple[str, float]:
        """Categorize a single transaction.

        Args:
            description: Transaction description text.
            merchant: Optional merchant name.

        Returns:
            Tuple of (category, confidence_score).
        """
        text = f"{description} {merchant or ''}".lower().strip()

        for category, patterns in self.rules.items():
            if category == "divers":
                continue
            for pattern in patterns:
                if pattern.lower() in text:
                    # Higher confidence if matched on merchant name
                    confidence = 0.95 if merchant and pattern.lower() in merchant.lower() else 0.80
                    return category, confidence

        return "divers", 0.30

    def categorize_batch(
        self,
        transactions: list,
    ) -> List[CategorizedTransaction]:
        """Categorize a batch of transactions.

        Args:
            transactions: List of Transaction objects (from blink_connector).

        Returns:
            List of CategorizedTransaction objects.
        """
        results = []
        for tx in transactions:
            category, confidence = self.categorize_one(
                tx.description,
                tx.merchant,
            )
            results.append(
                CategorizedTransaction(
                    transaction_id=tx.transaction_id,
                    date=tx.date,
                    description=tx.description,
                    amount=tx.amount,
                    currency=tx.currency,
                    is_debit=tx.is_debit,
                    category=category,
                    confidence=confidence,
                    match_type="auto",
                    merchant=tx.merchant,
                )
            )
        return results

    def get_categories(self) -> List[str]:
        """Return list of all available categories."""
        return list(self.rules.keys())
