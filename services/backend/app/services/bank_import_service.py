"""
Bank statement import service — ISO 20022 (camt.053) XML parser.

Parses Swiss bank statements in ISO 20022 format, extracts transactions,
auto-categorizes them, and deduplicates.

Sprint W14 — Bank import wiring.
"""

from dataclasses import dataclass, field
from typing import List, Optional
from xml.etree import ElementTree as ET


# ---------------------------------------------------------------------------
# Category patterns — Swiss-specific keywords
# ---------------------------------------------------------------------------

CATEGORY_PATTERNS: dict[str, List[str]] = {
    "alimentation": [
        "migros", "coop", "denner", "aldi", "lidl", "manor food", "volg",
        "aligro", "spar", "globus",
    ],
    "transport": [
        "cff", "sbb", "tpg", "tl ", "bvb", "zvv", "bls", "vbl",
        "swisspass", "parking", "essence", "shell", "bp ", "avia",
    ],
    "logement": [
        "loyer", "miete", "rent", "gerance", "verwaltung",
        "hypotheque", "hypothek", "regie",
    ],
    "telecom": [
        "swisscom", "sunrise", "salt", "wingo", "yallo",
    ],
    "assurances": [
        "css", "helsana", "swica", "concordia", "visana", "sanitas",
        "groupe mutuel", "assura", "atupri", "sympany",
        "baloise", "mobiliere", "mobiliar", "zurich", "axa",
        "helvetia", "vaudoise", "generali",
    ],
    "sante": [
        "pharmacie", "apotheke", "medecin", "arzt", "hopital", "spital",
        "dentiste", "zahnarzt", "sun store", "amavita",
    ],
    "loisirs": [
        "spotify", "netflix", "apple", "google play", "cinema", "kino",
        "fitness", "disney",
    ],
    "finances": [
        "twint", "paypal", "revolut",
    ],
    "shopping": [
        "amazon", "aliexpress", "galaxus", "digitec", "zalando",
    ],
    "impots": [
        "administration fiscale", "steuerverwaltung", "impot", "steuer",
    ],
    "revenu": [
        "salaire", "gehalt", "lohn", "revenu", "honoraire",
        "dividende", "interet", "zins",
    ],
    "epargne": [
        "3a", "pilier", "saule", "viac", "frankly", "finpension",
    ],
    "divers": [],
}


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class ImportedTransaction:
    """A single imported transaction."""

    date: str
    description: str
    amount: float
    currency: str
    is_debit: bool
    category: str = "divers"
    confidence: float = 0.0


@dataclass
class BankImportResult:
    """Result of a bank statement import."""

    transactions: List[ImportedTransaction] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    account_iban: Optional[str] = None
    statement_currency: Optional[str] = None
    total_credit: float = 0.0
    total_debit: float = 0.0


# ---------------------------------------------------------------------------
# ISO 20022 namespace
# ---------------------------------------------------------------------------

_NS = {"camt": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"}
# Fallback namespaces for older camt versions
_NS_FALLBACKS = [
    {"camt": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.02"},
    {"camt": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.04"},
]


# ---------------------------------------------------------------------------
# Categorizer (lightweight, reuses CATEGORY_PATTERNS)
# ---------------------------------------------------------------------------

def categorize_description(description: str) -> tuple[str, float]:
    """Categorize a transaction description using keyword matching.

    Returns:
        Tuple of (category, confidence).
    """
    text = description.lower()
    for category, patterns in CATEGORY_PATTERNS.items():
        if category == "divers":
            continue
        for pattern in patterns:
            if pattern in text:
                return category, 0.80
    return "divers", 0.30


# ---------------------------------------------------------------------------
# XML parser
# ---------------------------------------------------------------------------

def _find_with_fallback(root: ET.Element, path: str, ns: dict) -> Optional[ET.Element]:
    """Try to find an element with the primary NS, then fallback NSes."""
    elem = root.find(path, ns)
    if elem is not None:
        return elem
    for fallback_ns in _NS_FALLBACKS:
        elem = root.find(path.replace("camt:", "camt:"), fallback_ns)
        if elem is not None:
            return elem
    return None


def _findall_with_fallback(root: ET.Element, path: str, ns: dict) -> list:
    """Try to findall with the primary NS, then fallback NSes."""
    elems = root.findall(path, ns)
    if elems:
        return elems
    for fallback_ns in _NS_FALLBACKS:
        elems = root.findall(path.replace("camt:", "camt:"), fallback_ns)
        if elems:
            return elems
    return []


def parse_iso20022_xml(xml_content: str) -> BankImportResult:
    """Parse an ISO 20022 camt.053 XML bank statement.

    Extracts transactions with their actual currency from the <Ccy> element
    instead of hardcoding CHF.

    Args:
        xml_content: Raw XML string.

    Returns:
        BankImportResult with parsed transactions.
    """
    result = BankImportResult()

    try:
        root = ET.fromstring(xml_content)
    except ET.ParseError as e:
        result.warnings.append(f"Erreur de parsing XML : {e}")
        return result

    # Detect the namespace from the root element
    ns = _NS
    root_tag = root.tag
    if "}" in root_tag:
        detected_ns = root_tag.split("}")[0].lstrip("{")
        ns = {"camt": detected_ns}

    # Extract account IBAN
    iban_elem = _find_with_fallback(
        root,
        ".//camt:Stmt/camt:Acct/camt:Id/camt:IBAN",
        ns,
    )
    if iban_elem is not None and iban_elem.text:
        result.account_iban = iban_elem.text.strip()

    # Extract statement-level currency from <Ccy> element
    ccy_elem = _find_with_fallback(
        root,
        ".//camt:Stmt/camt:Acct/camt:Ccy",
        ns,
    )
    statement_currency = ccy_elem.text.strip() if ccy_elem is not None and ccy_elem.text else None
    result.statement_currency = statement_currency

    # Parse entries
    entries = _findall_with_fallback(root, ".//camt:Stmt/camt:Ntry", ns)

    transactions: List[ImportedTransaction] = []
    for entry in entries:
        tx = _parse_entry(entry, ns, statement_currency)
        if tx is not None:
            transactions.append(tx)

    # --- Duplicate detection (hash-based dedup) ---
    seen: set = set()
    unique_transactions: List[ImportedTransaction] = []
    for t in transactions:
        key = (t.date, t.description, t.amount)
        if key not in seen:
            seen.add(key)
            unique_transactions.append(t)
        else:
            result.warnings.append(
                f"Doublon ignoré : {t.description} {t.amount}"
            )

    # Categorize
    for tx in unique_transactions:
        category, confidence = categorize_description(tx.description)
        tx.category = category
        tx.confidence = confidence

    # Compute totals
    for tx in unique_transactions:
        if tx.is_debit:
            result.total_debit += abs(tx.amount)
        else:
            result.total_credit += abs(tx.amount)

    result.transactions = unique_transactions
    return result


def _parse_entry(
    entry: ET.Element,
    ns: dict,
    statement_currency: Optional[str],
) -> Optional[ImportedTransaction]:
    """Parse a single camt.053 Ntry element into an ImportedTransaction."""

    # Amount + currency
    amt_elem = entry.find("camt:Amt", ns)
    if amt_elem is None or amt_elem.text is None:
        return None

    try:
        amount = float(amt_elem.text.strip())
    except ValueError:
        return None

    # Use currency from the entry's Ccy attribute, falling back to statement currency
    currency = amt_elem.get("Ccy") or statement_currency or "CHF"

    # Credit/Debit indicator
    cdi_elem = entry.find("camt:CdtDbtInd", ns)
    is_debit = cdi_elem is not None and cdi_elem.text and cdi_elem.text.strip() == "DBIT"

    # Booking date
    date_elem = entry.find("camt:BookgDt/camt:Dt", ns)
    date_str = date_elem.text.strip() if date_elem is not None and date_elem.text else ""

    # Description — try multiple paths
    description = ""
    # 1. Structured remittance info
    ustrd = entry.find(
        ".//camt:NtryDtls/camt:TxDtls/camt:RmtInf/camt:Ustrd", ns
    )
    if ustrd is not None and ustrd.text:
        description = ustrd.text.strip()
    else:
        # 2. Additional entry info
        addl = entry.find("camt:AddtlNtryInf", ns)
        if addl is not None and addl.text:
            description = addl.text.strip()

    if is_debit:
        amount = -abs(amount)

    return ImportedTransaction(
        date=date_str,
        description=description,
        amount=amount,
        currency=currency,
        is_debit=is_debit,
    )
