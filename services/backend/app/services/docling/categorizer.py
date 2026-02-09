"""
Rule-based transaction categorization for Swiss banking.

Categorizes bank transactions using multilingual keyword matching (FR, DE, IT),
regex patterns, and recurring transaction detection. Designed for Swiss
residents' typical banking patterns.

Categories align with the MINT budget module for seamless import.
"""

from __future__ import annotations

import logging
import re
from collections import defaultdict
from dataclasses import dataclass
from typing import Optional

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────────────────────────────────────
# Category Definitions
# ──────────────────────────────────────────────────────────────────────────────

CATEGORIES: dict[str, dict] = {
    "logement": {
        "keywords": [
            "loyer", "miete", "affitto", "hypothek", "hypo", "nebenkosten",
            "charges", "immobili", "wohnung", "apartment", "appartement",
            "genossenschaft", "hausverwaltung", "conciergerie",
        ],
        "patterns": [
            r"(?i)immobilien.*verwaltung",
            r"(?i)regie.*immobil",
            r"(?i)r[ée]gie\s+immobili[eè]re",
        ],
        "subcategories": {
            "loyer": ["loyer", "miete", "affitto", "mietvertrag"],
            "hypotheque": ["hypothek", "hypo", "mortgage"],
            "charges": ["nebenkosten", "charges", "heizung", "chauffage"],
        },
        "icon": "home",
    },
    "alimentation": {
        "keywords": [
            "migros", "coop", "denner", "aldi", "lidl", "spar", "manor food",
            "volg", "primo", "aligro", "prodega", "leshop", "farmy",
            "globus", "lebensmittel", "epicerie", "alimentari",
        ],
        "patterns": [],
        "subcategories": {
            "supermarche": ["migros", "coop", "denner", "aldi", "lidl", "spar", "volg"],
            "epicerie_fine": ["manor food", "globus", "aligro"],
            "en_ligne": ["leshop", "farmy"],
        },
        "icon": "shopping_cart",
    },
    "transport": {
        "keywords": [
            "cff", "sbb", "ffs", "tpg", "tl", "bvb", "zvv", "bls", "parking",
            "parkhaus", "shell", "bp", "avia", "migrol", "coop pronto",
            "uber", "bolt", "taxi", "autobahnvignette", "vignette",
            "garage", "auto", "tcs", "amag",
        ],
        "patterns": [
            r"(?i)tank(stelle)?",
            r"(?i)carburant",
            r"(?i)benzin",
        ],
        "subcategories": {
            "train": ["cff", "sbb", "ffs", "bls"],
            "bus_tram": ["tpg", "tl", "bvb", "zvv"],
            "carburant": ["shell", "bp", "avia", "migrol", "coop pronto"],
            "taxi_vtc": ["uber", "bolt", "taxi"],
            "parking": ["parking", "parkhaus"],
        },
        "icon": "directions_car",
    },
    "assurance": {
        "keywords": [
            "css", "helsana", "swica", "visana", "concordia", "sanitas",
            "groupe mutuel", "assura", "atupri", "krankenkasse",
            "mobiliar", "zurich versicherung", "zurich insurance",
            "axa", "helvetia", "allianz", "generali",
            "baloise", "vaudoise", "versicherung", "assurance",
            "sympany", "okk", "kpt", "egs",
        ],
        "patterns": [
            r"(?i)pr[ée]voyance",
            r"(?i)police\s+\d+",
            r"(?i)zurich\s+(vie|leben|vita|assur)",
        ],
        "subcategories": {
            "maladie": [
                "css", "helsana", "swica", "visana", "concordia", "sanitas",
                "groupe mutuel", "assura", "atupri", "krankenkasse",
                "sympany", "okk", "kpt",
            ],
            "menage_rc": ["mobiliar", "zurich versicherung", "axa", "helvetia", "baloise", "vaudoise"],
            "auto": ["tcs"],
        },
        "icon": "shield",
    },
    "telecom": {
        "keywords": [
            "swisscom", "sunrise", "salt", "yallo", "wingo", "m-budget mobile",
            "coop mobile", "billag", "serafe", "internet", "upc", "quickline",
            "init7",
        ],
        "patterns": [],
        "subcategories": {
            "mobile": ["swisscom", "sunrise", "salt", "yallo", "wingo", "m-budget mobile", "coop mobile"],
            "internet": ["upc", "quickline", "init7", "internet"],
            "redevance": ["billag", "serafe"],
        },
        "icon": "phone",
    },
    "impots": {
        "keywords": [
            "steueramt", "impot", "steuern", "administration fiscale",
            "afc", "estv", "imp\u00f4t", "taxe",
        ],
        "patterns": [
            r"(?i)(canton|gemeinde|commune).*steuer",
            r"(?i)imp[oô]t.*cantonal",
            r"(?i)imp[oô]t.*communal",
            r"(?i)imp[oô]t.*f[ée]d[ée]ral",
        ],
        "subcategories": {
            "cantonal": ["canton", "cantonal"],
            "communal": ["gemeinde", "commune", "communal"],
            "federal": ["estv", "afc", "federal"],
        },
        "icon": "account_balance",
    },
    "sante": {
        "keywords": [
            "pharmacie", "apotheke", "arzt", "medecin", "m\u00e9decin", "doctor",
            "hopital", "h\u00f4pital", "spital", "hospital", "dentiste", "zahnarzt",
            "opticien", "optiker", "laboratoire", "labor", "physioth",
            "kieferorthop", "orthodont",
        ],
        "patterns": [
            r"(?i)dr\.\s+\w+",
            r"(?i)cabinet\s+m[ée]dical",
            r"(?i)praxis",
        ],
        "subcategories": {
            "medecin": ["arzt", "medecin", "m\u00e9decin", "doctor", "praxis", "cabinet"],
            "pharmacie": ["pharmacie", "apotheke"],
            "dentiste": ["dentiste", "zahnarzt"],
            "hopital": ["hopital", "h\u00f4pital", "spital", "hospital"],
            "optique": ["opticien", "optiker"],
        },
        "icon": "local_hospital",
    },
    "loisirs": {
        "keywords": [
            "spotify", "netflix", "disney", "apple.com", "google play",
            "kino", "cinema", "cin\u00e9ma", "fitness", "sport", "club",
            "youtube", "amazon prime", "hbo", "dazn", "twitch",
            "fnac", "ticketcorner", "starticket", "eventbrite",
        ],
        "patterns": [
            r"(?i)abo(nnement)?.*streaming",
        ],
        "subcategories": {
            "streaming": ["spotify", "netflix", "disney", "apple.com", "youtube", "amazon prime", "hbo", "dazn"],
            "cinema": ["kino", "cinema", "cin\u00e9ma"],
            "sport": ["fitness", "sport", "club"],
            "evenements": ["ticketcorner", "starticket", "eventbrite"],
        },
        "icon": "sports_esports",
    },
    "education": {
        "keywords": [
            "universit", "hochschule", "ecole", "\u00e9cole", "schule", "formation",
            "ausbildung", "cours", "kurs", "weiterbildung", "studien",
            "biblioth", "udemy", "coursera",
        ],
        "patterns": [
            r"(?i)(uni|eth|epfl|hes|fh)\s",
        ],
        "subcategories": {
            "universite": ["universit", "hochschule", "eth", "epfl"],
            "formation": ["formation", "ausbildung", "weiterbildung", "cours", "kurs"],
            "en_ligne": ["udemy", "coursera"],
        },
        "icon": "school",
    },
    "epargne": {
        "keywords": [
            "3a", "s\u00e4ule 3a", "pilier 3a", "pilastro 3a",
            "viac", "frankly", "finpension", "liberty", "valuepension",
            "sparkonto", "compte epargne", "conto risparmio",
        ],
        "patterns": [
            r"(?i)3[ae]\s*konto",
            r"(?i)3[ae]\s*compte",
            r"(?i)pr[ée]voyance\s+li[ée]e",
        ],
        "subcategories": {
            "pilier_3a": ["3a", "viac", "frankly", "finpension", "liberty", "valuepension"],
            "epargne_libre": ["sparkonto", "compte epargne", "conto risparmio"],
        },
        "icon": "savings",
    },
    "salaire": {
        "keywords": [
            "salaire", "lohn", "gehalt", "stipendio", "salario",
            "honoraire", "honorar",
        ],
        "patterns": [
            r"(?i)(lohn|salaire|gehalt).*zahlung",
            r"(?i)versement\s+salaire",
        ],
        "subcategories": {
            "salaire_mensuel": ["salaire", "lohn", "gehalt"],
            "honoraires": ["honoraire", "honorar"],
        },
        "icon": "payments",
    },
    "restaurant": {
        "keywords": [
            "restaurant", "mcdonald", "burger king", "starbucks", "cafe",
            "caf\u00e9", "kaffee", "pizza", "kebab", "sushi", "thai", "takeaway",
            "take away", "lieferung", "livraison", "just eat", "uber eats",
            "smood", "eat.ch",
        ],
        "patterns": [
            r"(?i)rest\.\s+\w+",
            r"(?i)gastro",
        ],
        "subcategories": {
            "restaurant": ["restaurant", "gastro"],
            "fast_food": ["mcdonald", "burger king", "kebab"],
            "cafe": ["starbucks", "cafe", "caf\u00e9", "kaffee"],
            "livraison": ["just eat", "uber eats", "smood", "eat.ch", "lieferung", "livraison"],
        },
        "icon": "restaurant",
    },
    "shopping": {
        "keywords": [
            "h&m", "zara", "manor", "ikea", "mediamarkt", "media markt",
            "digitec", "galaxus", "amazon", "zalando", "aliexpress",
            "interdiscount", "fust", "brack",
        ],
        "patterns": [],
        "subcategories": {
            "vetements": ["h&m", "zara", "zalando"],
            "electronique": ["mediamarkt", "media markt", "digitec", "galaxus", "interdiscount", "fust", "brack"],
            "maison": ["ikea", "manor"],
            "en_ligne": ["amazon", "aliexpress"],
        },
        "icon": "shopping_bag",
    },
    "divers": {
        "keywords": [],  # Fallback category
        "patterns": [],
        "subcategories": {},
        "icon": "category",
    },
}


# ──────────────────────────────────────────────────────────────────────────────
# TransactionCategorizer
# ──────────────────────────────────────────────────────────────────────────────


@dataclass
class CategorizationResult:
    """Result of categorizing a single transaction."""

    category: str
    subcategory: Optional[str] = None
    confidence: float = 0.0


class TransactionCategorizer:
    """
    Rule-based transaction categorizer for Swiss banking.

    Features:
    - Case-insensitive keyword matching on transaction descriptions
    - Regex patterns for complex matches
    - Recurring transaction detection
    - Sub-categorization where possible
    - Multilingual: FR, DE, IT keywords
    """

    def __init__(self, categories: Optional[dict] = None):
        """
        Initialize the categorizer.

        Args:
            categories: Optional custom category definitions.
                If None, uses the built-in CATEGORIES.
        """
        self.categories = categories or CATEGORIES

    def categorize(self, description: str) -> CategorizationResult:
        """
        Categorize a single transaction by its description.

        Args:
            description: Transaction description text.

        Returns:
            CategorizationResult with category, subcategory, and confidence.
        """
        if not description:
            return CategorizationResult(category="divers", confidence=0.0)

        desc_lower = description.lower()

        # Try each category in priority order
        for cat_name, cat_def in self.categories.items():
            if cat_name == "divers":
                continue  # Skip fallback until the end

            # Check keywords
            keywords = cat_def.get("keywords", [])
            for keyword in keywords:
                if keyword.lower() in desc_lower:
                    subcategory = self._find_subcategory(
                        desc_lower, cat_def.get("subcategories", {})
                    )
                    return CategorizationResult(
                        category=cat_name,
                        subcategory=subcategory,
                        confidence=0.9,
                    )

            # Check regex patterns
            patterns = cat_def.get("patterns", [])
            for pattern in patterns:
                if re.search(pattern, description):
                    subcategory = self._find_subcategory(
                        desc_lower, cat_def.get("subcategories", {})
                    )
                    return CategorizationResult(
                        category=cat_name,
                        subcategory=subcategory,
                        confidence=0.7,
                    )

        # Fallback to divers
        return CategorizationResult(category="divers", confidence=0.1)

    def categorize_transactions(
        self, transactions: list
    ) -> list:
        """
        Categorize a list of BankTransaction objects in-place.

        Also detects recurring transactions.

        Args:
            transactions: List of BankTransaction objects.

        Returns:
            The same list with category, subcategory, and is_recurring set.
        """
        for tx in transactions:
            result = self.categorize(tx.description)
            tx.category = result.category
            tx.subcategory = result.subcategory

        # Detect recurring transactions
        self._detect_recurring(transactions)

        return transactions

    def compute_category_summary(
        self, transactions: list
    ) -> dict[str, float]:
        """
        Compute total spending per category.

        Args:
            transactions: List of categorized BankTransaction objects.

        Returns:
            Dictionary mapping category name to total amount (negative for expenses).
        """
        summary: dict[str, float] = defaultdict(float)

        for tx in transactions:
            summary[tx.category] += tx.amount

        # Round values
        return {k: round(v, 2) for k, v in sorted(summary.items())}

    def compute_budget_preview(
        self, transactions: list
    ) -> dict:
        """
        Compute a budget import preview from transactions.

        Returns estimated monthly income, expenses, top categories,
        recurring charges, and savings rate.

        Args:
            transactions: List of categorized BankTransaction objects.

        Returns:
            Budget preview dictionary.
        """
        if not transactions:
            return {
                "estimated_monthly_income": 0.0,
                "estimated_monthly_expenses": 0.0,
                "top_categories": [],
                "recurring_charges": [],
                "savings_rate": 0.0,
            }

        # Determine the time span (in months)
        dates = [tx.date for tx in transactions if tx.date]
        if not dates:
            months = 1.0
        else:
            sorted_dates = sorted(dates)
            try:
                from datetime import datetime as dt
                first = dt.strptime(sorted_dates[0], "%Y-%m-%d")
                last = dt.strptime(sorted_dates[-1], "%Y-%m-%d")
                delta_days = (last - first).days
                months = max(delta_days / 30.44, 1.0)  # At least 1 month
            except (ValueError, TypeError):
                months = 1.0

        # Calculate totals
        total_income = sum(tx.amount for tx in transactions if tx.amount > 0)
        total_expenses = sum(abs(tx.amount) for tx in transactions if tx.amount < 0)

        monthly_income = round(total_income / months, 2)
        monthly_expenses = round(total_expenses / months, 2)

        # Category breakdown (expenses only)
        cat_totals: dict[str, float] = defaultdict(float)
        for tx in transactions:
            if tx.amount < 0:
                cat_totals[tx.category] += abs(tx.amount)

        # Top categories by amount
        sorted_cats = sorted(cat_totals.items(), key=lambda x: x[1], reverse=True)
        top_categories = []
        for cat, amount in sorted_cats[:10]:
            percentage = round(amount / total_expenses * 100, 1) if total_expenses > 0 else 0.0
            top_categories.append({
                "category": cat,
                "amount": round(amount / months, 2),
                "percentage": percentage,
            })

        # Recurring charges
        recurring = [
            {
                "description": tx.description,
                "amount": tx.amount,
                "frequency": "monthly",
            }
            for tx in transactions
            if tx.is_recurring and tx.amount < 0
        ]
        # Deduplicate by description (keep first occurrence)
        seen = set()
        unique_recurring = []
        for r in recurring:
            key = (r["description"].lower()[:30], round(r["amount"], 0))
            if key not in seen:
                seen.add(key)
                unique_recurring.append(r)

        # Savings rate
        savings_rate = 0.0
        if monthly_income > 0:
            savings_rate = round(
                (monthly_income - monthly_expenses) / monthly_income * 100, 1
            )

        return {
            "estimated_monthly_income": monthly_income,
            "estimated_monthly_expenses": monthly_expenses,
            "top_categories": top_categories,
            "recurring_charges": unique_recurring,
            "savings_rate": savings_rate,
        }

    # ──────────────────────────────────────────────────────────────────────
    # Internal helpers
    # ──────────────────────────────────────────────────────────────────────

    def _find_subcategory(
        self,
        description_lower: str,
        subcategories: dict[str, list[str]],
    ) -> Optional[str]:
        """Find the most specific subcategory for a transaction."""
        for subcat_name, subcat_keywords in subcategories.items():
            for keyword in subcat_keywords:
                if keyword.lower() in description_lower:
                    return subcat_name
        return None

    def _detect_recurring(self, transactions: list) -> None:
        """
        Detect recurring transactions in a list of BankTransaction objects.

        A transaction is considered recurring if:
        - Same description (normalized) appears 2+ times
        - Amounts are within 5% of each other
        - Dates are roughly monthly (25-35 day intervals)
        """
        if len(transactions) < 2:
            return

        # Group by normalized description prefix
        groups: dict[str, list] = defaultdict(list)
        for tx in transactions:
            key = self._normalize_description(tx.description)
            if key:
                groups[key].append(tx)

        for key, group in groups.items():
            if len(group) < 2:
                continue

            # Check if amounts are similar (within 5%)
            amounts = [abs(tx.amount) for tx in group if tx.amount != 0]
            if not amounts:
                continue

            avg_amount = sum(amounts) / len(amounts)
            amounts_similar = all(
                abs(a - avg_amount) / avg_amount <= 0.05 if avg_amount > 0 else True
                for a in amounts
            )

            if not amounts_similar:
                continue

            # Check if dates are roughly monthly
            dates_valid = self._check_monthly_pattern(
                [tx.date for tx in group if tx.date]
            )

            if amounts_similar and (dates_valid or len(group) >= 3):
                for tx in group:
                    tx.is_recurring = True

    @staticmethod
    def _normalize_description(description: str) -> str:
        """Normalize a description for recurring detection."""
        if not description:
            return ""
        # Take first 30 chars, lowercase, remove digits/dates
        normalized = description.lower()[:30]
        # Remove date-like patterns and transaction IDs
        normalized = re.sub(r"\d{2,}", "", normalized)
        normalized = re.sub(r"\s+", " ", normalized).strip()
        return normalized

    @staticmethod
    def _check_monthly_pattern(dates: list[str]) -> bool:
        """
        Check if dates follow a roughly monthly pattern.

        Dates should be approximately 25-35 days apart.
        """
        if len(dates) < 2:
            return False

        try:
            from datetime import datetime as dt

            parsed = sorted(dt.strptime(d, "%Y-%m-%d") for d in dates)
            intervals = [
                (parsed[i + 1] - parsed[i]).days
                for i in range(len(parsed) - 1)
            ]

            if not intervals:
                return False

            # At least one interval should be roughly monthly (25-35 days)
            return any(25 <= interval <= 35 for interval in intervals)

        except (ValueError, TypeError):
            return False
