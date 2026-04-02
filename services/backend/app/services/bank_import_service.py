"""
Bank statement auto-detection, parsing, and categorization service.

Supports 6 Swiss bank CSV formats + ISO 20022 XML (camt.053/camt.054).
Pure functions — no side effects, fully deterministic and testable.

Privacy: raw file content is parsed in-memory only. No PII is logged.
"""

import csv
import io
import logging
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional

try:
    from defusedxml.ElementTree import fromstring as _defused_fromstring
except ImportError:
    _defused_fromstring = None

from xml.etree.ElementTree import fromstring as _stdlib_fromstring


def safe_fromstring(text):
    """XXE-safe XML parser with defense-in-depth.

    1. Rejects any XML containing <!DOCTYPE or <!ENTITY (no legitimate
       ISO 20022 file uses DTD). This blocks XXE even without defusedxml.
    2. Uses defusedxml if available for additional protection.
    3. Falls back to stdlib parser for clean XML.
    """
    if isinstance(text, str):
        text_bytes = text.encode()
    else:
        text_bytes = text
    upper = text_bytes.upper()
    if b"<!ENTITY" in upper or b"<!DOCTYPE" in upper:
        raise ValueError("XML with DTD/entities rejected for security")
    if _defused_fromstring is not None:
        return _defused_fromstring(text)
    return _stdlib_fromstring(text)


logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────────────────────────────────────
# Data models
# ──────────────────────────────────────────────────────────────────────────────


class BankFormat(str, Enum):
    """Supported Swiss bank statement formats."""

    UBS = "ubs"
    POSTFINANCE = "postfinance"
    RAIFFEISEN = "raiffeisen"
    BCGE_BCV = "bcge_bcv"
    CS_ZKB = "cs_zkb"
    YUH_NEON = "yuh_neon"
    CAMT_053 = "camt_053"
    CAMT_054 = "camt_054"
    UNKNOWN = "unknown"


@dataclass
class Transaction:
    """A single parsed bank transaction."""

    date: datetime
    description: str
    amount: float
    balance: Optional[float] = None
    category: str = "Divers"
    subcategory: Optional[str] = None
    is_recurring: bool = False


@dataclass
class ParseResult:
    """Result of parsing a bank statement."""

    bank_name: str
    format: BankFormat
    transactions: list[Transaction] = field(default_factory=list)
    period_start: Optional[datetime] = None
    period_end: Optional[datetime] = None
    currency: str = "CHF"
    opening_balance: Optional[float] = None
    closing_balance: Optional[float] = None
    total_credits: float = 0.0
    total_debits: float = 0.0
    category_summary: dict[str, float] = field(default_factory=dict)
    confidence: float = 0.0
    warnings: list[str] = field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────────
# Bank format patterns
# ──────────────────────────────────────────────────────────────────────────────

# Each entry: delimiter, header_pattern (regex matching the CSV header line),
# date_col, description_col, amount_col, balance_col (0-indexed),
# date_format, encoding, bank display name
BANK_PATTERNS: dict[BankFormat, dict] = {
    BankFormat.UBS: {
        "delimiter": ";",
        "header_pattern": re.compile(
            r"(Buchungsdatum|Date de transaction|Trade date)", re.IGNORECASE
        ),
        "date_col": 0,
        "description_col": 1,
        "amount_col": 2,
        "balance_col": 3,
        "date_formats": ["%d.%m.%Y", "%Y-%m-%d"],
        "encoding": "utf-8-sig",
        "bank_name": "UBS",
    },
    BankFormat.POSTFINANCE: {
        "delimiter": ";",
        "header_pattern": re.compile(
            r"(Buchungsdatum|Date comptable|Gutschrift|Belastung)", re.IGNORECASE
        ),
        "date_col": 0,
        "description_col": 1,
        "amount_col": 2,
        "balance_col": 3,
        "date_formats": ["%d.%m.%Y", "%Y-%m-%d"],
        "encoding": "utf-8-sig",
        "bank_name": "PostFinance",
        # PostFinance often has credit/debit in separate columns
        "credit_col": 2,
        "debit_col": 3,
        "balance_col_alt": 4,
    },
    BankFormat.RAIFFEISEN: {
        "delimiter": ";",
        "header_pattern": re.compile(
            r"(IBAN|Kontonummer|Booked At|Bookingdate)", re.IGNORECASE
        ),
        "date_col": 0,
        "description_col": 1,
        "amount_col": 2,
        "balance_col": 3,
        "date_formats": ["%d.%m.%Y", "%Y-%m-%d"],
        "encoding": "utf-8-sig",
        "bank_name": "Raiffeisen",
    },
    BankFormat.BCGE_BCV: {
        "delimiter": ";",
        "header_pattern": re.compile(r"(Date valeur|BCV|BCGE)", re.IGNORECASE),
        "date_col": 0,
        "description_col": 1,
        "amount_col": 2,
        "balance_col": 3,
        "date_formats": ["%d.%m.%Y", "%d/%m/%Y"],
        "encoding": "utf-8-sig",
        "bank_name": "BCGE/BCV",
    },
    BankFormat.CS_ZKB: {
        "delimiter": ",",
        "header_pattern": re.compile(
            r"(Booking Date|Buchungsdatum|Date|ZKB|Credit Suisse)", re.IGNORECASE
        ),
        "date_col": 0,
        "description_col": 1,
        "amount_col": 2,
        "balance_col": 3,
        "date_formats": ["%d.%m.%Y", "%Y-%m-%d", "%m/%d/%Y"],
        "encoding": "utf-8-sig",
        "bank_name": "CS/ZKB",
    },
    BankFormat.YUH_NEON: {
        "delimiter": ",",
        "header_pattern": re.compile(r"(Date|Datum|Yuh|Neon)", re.IGNORECASE),
        "date_col": 0,
        "description_col": 1,
        "amount_col": 2,
        "balance_col": None,
        "date_formats": ["%Y-%m-%d", "%d.%m.%Y"],
        "encoding": "utf-8",
        "bank_name": "Yuh/Neon",
    },
}


# ──────────────────────────────────────────────────────────────────────────────
# Swiss transaction categorization
# ──────────────────────────────────────────────────────────────────────────────

# Pattern → (category, subcategory)
CATEGORY_PATTERNS: list[tuple[re.Pattern, str, Optional[str]]] = [
    # Housing
    (re.compile(r"\b(loyer|miete|rent|immobili|wohnung)\b", re.I), "Logement", "loyer"),
    (re.compile(r"\b(hypoth[eè]que|mortgage|hypothek)\b", re.I), "Logement", "hypotheque"),
    (re.compile(r"\b(Compagnie Industrielle|SIG|romande energie|alpiq|SIE|BKW|EWZ)\b", re.I), "Logement", "energie"),
    (re.compile(r"\b(Serafe|Billag)\b", re.I), "Logement", "redevance"),
    # Food & groceries
    (re.compile(r"\b(Migros|M-Budget|Denner)\b", re.I), "Alimentation", "supermarche"),
    (re.compile(r"\b(Coop|Coop\s+Prix|Fust)\b", re.I), "Alimentation", "supermarche"),
    (re.compile(r"\b(Aldi|Lidl)\b", re.I), "Alimentation", "discount"),
    (re.compile(r"\b(Volg|Spar|Aligro|Manor Food)\b", re.I), "Alimentation", "supermarche"),
    # Transport
    (re.compile(r"\b(CFF|SBB|FFS|BLS|TL Lausanne|TPG|ZVV|Unireso|tpf)\b", re.I), "Transport", "transports_publics"),
    (re.compile(r"\b(demi-tarif|Halbtax|AG |GA )\b", re.I), "Transport", "abonnement"),
    (re.compile(r"\b(Shell|Avia|BP |Coop Pronto|Migrol|Agrola)\b", re.I), "Transport", "essence"),
    (re.compile(r"\b(TCS|Touring Club|parking|Parkhaus)\b", re.I), "Transport", "auto"),
    # Insurance
    (re.compile(r"\b(CSS|Helsana|Swica|Assura|Visana|Groupe Mutuel|Concordia|Sanitas|Atupri|KPT)\b", re.I), "Assurance", "lamal"),
    (re.compile(r"\b(Mobiliar|Vaudoise|Zurich|AXA|Helvetia|Baloise|Generali|Allianz)\b", re.I), "Assurance", "rc_menage"),
    (re.compile(r"\b(SUVA|Caisse AVS|Caisse de pension|BVG|LPP)\b", re.I), "Assurance", "social"),
    # Telecom
    (re.compile(r"\b(Swisscom|Sunrise|Salt|UPC|Quickline|Init7|Wingo|Yallo|Lycamobile)\b", re.I), "Telecom", None),
    # Taxes
    (re.compile(r"\b(imp[oô]t|Steuer|Tax|AFC|fisc|service des contributions)\b", re.I), "Impots", None),
    # Health
    (re.compile(r"\b(pharma\w*|apotheke|dr\.|m[eé]decin|Arzt|h[oô]pital|Spital|laborat|dentist|Zahnarzt|opticien)\b", re.I), "Sante", None),
    # Leisure
    (re.compile(r"\b(Fnac|Interdiscount|MediaMarkt|Digitec|Galaxus)\b", re.I), "Loisirs", "electronique"),
    (re.compile(r"\b(cinema|Kino|Pathé|th[eé][aâ]tre|concert|mus[eé]e|Museum)\b", re.I), "Loisirs", "culture"),
    (re.compile(r"\b(fitness|gym|sport|Ochsner|Decathlon|SportXX)\b", re.I), "Loisirs", "sport"),
    (re.compile(r"\b(Spotify|Netflix|Disney|Apple Music|YouTube|Amazon Prime)\b", re.I), "Loisirs", "streaming"),
    # Restaurant
    (re.compile(r"\b(restaurant|Gasthaus|pizz|kebab|McDo|McDonald|Burger King|Starbucks|caf[eé])\b", re.I), "Restaurant", None),
    # Savings / investment
    (re.compile(r"\b(virement.*[eé]pargne|[eé]pargne|Sparen|3a|3e pilier|Frankly|VIAC|Finpension|Descartes)\b", re.I), "Epargne", None),
    # Salary
    (re.compile(r"\b(salaire|Lohn|Gehalt|salary|wages|bonus|gratification)\b", re.I), "Salaire", None),
]


def _sanitize_csv_field(value: str) -> str:
    """Prevent formula injection in CSV/spreadsheet fields.

    Strips leading characters that could be interpreted as formulas
    by spreadsheet applications (=, +, -, @, tab, CR).
    """
    if value and value[0] in ("=", "+", "-", "@", "\t", "\r"):
        return "'" + value
    return value


def categorize_transaction(description: str) -> tuple[str, Optional[str]]:
    """
    Categorize a transaction based on Swiss merchant/keyword patterns.

    Returns:
        (category, subcategory) tuple
    """
    for pattern, category, subcategory in CATEGORY_PATTERNS:
        if pattern.search(description):
            return category, subcategory
    return "Divers", None


# ──────────────────────────────────────────────────────────────────────────────
# Format auto-detection
# ──────────────────────────────────────────────────────────────────────────────


def detect_format(content: str, filename: str) -> BankFormat:
    """
    Auto-detect the bank statement format from file content and extension.

    Args:
        content: file content as string (first ~2000 chars is sufficient)
        filename: original filename (for extension-based detection)

    Returns:
        Detected BankFormat
    """
    lower_name = filename.lower()

    # XML detection — ISO 20022
    if lower_name.endswith(".xml") or content.lstrip().startswith("<?xml"):
        if "camt.054" in content[:2000]:
            return BankFormat.CAMT_054
        if "camt.053" in content[:2000] or "BkToCstmrStmt" in content[:2000]:
            return BankFormat.CAMT_053
        # Generic XML with ISO 20022 namespace
        if "urn:iso:std:iso:20022" in content[:2000]:
            return BankFormat.CAMT_053
        return BankFormat.UNKNOWN

    # CSV detection — match header line against bank patterns
    if lower_name.endswith(".csv") or not lower_name.endswith(".xml"):
        # Read just the first few lines for header detection
        first_lines = content[:2000]

        for bank_format, pattern_info in BANK_PATTERNS.items():
            header_re: re.Pattern = pattern_info["header_pattern"]
            if header_re.search(first_lines):
                return bank_format

        # Fallback: try to detect delimiter and return generic
        if ";" in first_lines:
            # Semi-colon delimited — most Swiss banks
            return BankFormat.UBS  # Default to UBS-like parsing
        if "," in first_lines:
            return BankFormat.YUH_NEON  # Comma-delimited neobanks

    return BankFormat.UNKNOWN


# ──────────────────────────────────────────────────────────────────────────────
# CSV parser
# ──────────────────────────────────────────────────────────────────────────────


def _parse_amount(raw: str) -> Optional[float]:
    """Parse a Swiss-formatted amount string to float.

    Handles:
        1'234.56, 1234.56, -1'234.56, 1.234,56 (DE format)
    """
    if not raw or not raw.strip():
        return None
    cleaned = raw.strip().replace("'", "").replace("\u2019", "").replace(" ", "")
    # Handle German format: 1.234,56 → 1234.56
    if "," in cleaned and "." in cleaned:
        if cleaned.index(",") > cleaned.index("."):
            cleaned = cleaned.replace(".", "").replace(",", ".")
    elif "," in cleaned:
        cleaned = cleaned.replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return None


def _parse_date(raw: str, formats: list[str]) -> Optional[datetime]:
    """Try multiple date formats and return the first match."""
    stripped = raw.strip()
    for fmt in formats:
        try:
            return datetime.strptime(stripped, fmt)
        except ValueError:
            continue
    return None


def parse_csv(
    content: str,
    bank_format: BankFormat,
) -> ParseResult:
    """
    Parse a CSV bank statement using the detected bank format.

    Args:
        content: full CSV file content as string
        bank_format: detected bank format

    Returns:
        ParseResult with transactions and summaries
    """
    if bank_format not in BANK_PATTERNS:
        return ParseResult(
            bank_name="Unknown",
            format=bank_format,
            warnings=["Format CSV non reconnu"],
        )

    pattern = BANK_PATTERNS[bank_format]
    delimiter = pattern["delimiter"]
    date_col = pattern["date_col"]
    desc_col = pattern["description_col"]
    amount_col = pattern["amount_col"]
    balance_col = pattern.get("balance_col")
    date_formats = pattern["date_formats"]
    bank_name = pattern["bank_name"]

    transactions: list[Transaction] = []
    warnings: list[str] = []
    header_found = False

    reader = csv.reader(io.StringIO(content), delimiter=delimiter)
    row_count = 0

    for row in reader:
        row_count += 1
        if row_count > 10000:
            warnings.append("Fichier tronque a 10'000 lignes")
            break

        # Skip empty rows
        if not row or all(not cell.strip() for cell in row):
            continue

        # Find header row
        if not header_found:
            row_text = delimiter.join(row)
            header_re: re.Pattern = pattern["header_pattern"]
            if header_re.search(row_text):
                header_found = True
            continue

        # Parse data rows
        try:
            max_col = max(
                c for c in [date_col, desc_col, amount_col, balance_col] if c is not None
            )
            if len(row) <= max_col:
                continue

            date = _parse_date(row[date_col], date_formats)
            if date is None:
                continue

            raw_desc = row[desc_col].strip() if desc_col < len(row) else ""
            description = _sanitize_csv_field(raw_desc)
            amount = _parse_amount(row[amount_col])
            if amount is None:
                # Try credit/debit split (PostFinance style)
                credit_col = pattern.get("credit_col")
                debit_col = pattern.get("debit_col")
                if credit_col is not None and debit_col is not None:
                    credit = _parse_amount(row[credit_col]) if credit_col < len(row) else None
                    debit = _parse_amount(row[debit_col]) if debit_col < len(row) else None
                    if credit is not None and credit != 0:
                        amount = abs(credit)
                    elif debit is not None and debit != 0:
                        amount = -abs(debit)
                    else:
                        continue
                else:
                    continue

            balance = None
            if balance_col is not None and balance_col < len(row):
                balance = _parse_amount(row[balance_col])
            # Check alt balance col (PostFinance)
            balance_col_alt = pattern.get("balance_col_alt")
            if balance is None and balance_col_alt is not None and balance_col_alt < len(row):
                balance = _parse_amount(row[balance_col_alt])

            category, subcategory = categorize_transaction(description)
            transactions.append(
                Transaction(
                    date=date,
                    description=description,
                    amount=amount,
                    balance=balance,
                    category=category,
                    subcategory=subcategory,
                )
            )
        except (IndexError, ValueError) as e:
            logger.debug("Skipping row %d: %s", row_count, e)
            continue

    if not header_found:
        warnings.append("En-tete CSV non detecte — tentative de parsing brut")

    return _finalize_result(transactions, bank_name, bank_format, warnings)


# ──────────────────────────────────────────────────────────────────────────────
# ISO 20022 XML parser (camt.053 / camt.054)
# ──────────────────────────────────────────────────────────────────────────────

_ISO20022_NS = {
    "ns": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.04",
    "ns2": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.02",
    "ns8": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.08",
    "ns054": "urn:iso:std:iso:20022:tech:xsd:camt.054.001.04",
    "ns054v2": "urn:iso:std:iso:20022:tech:xsd:camt.054.001.02",
    "ns054v8": "urn:iso:std:iso:20022:tech:xsd:camt.054.001.08",
}


def parse_iso20022_xml(content: str) -> ParseResult:
    """
    Parse an ISO 20022 XML file (camt.053 or camt.054).

    Supports multiple namespace versions (v02, v04, v08).

    Args:
        content: XML file content as string

    Returns:
        ParseResult with extracted transactions
    """
    warnings: list[str] = []
    transactions: list[Transaction] = []
    bank_name = "ISO 20022"
    detected_format = BankFormat.CAMT_053

    try:
        root = safe_fromstring(content)
    except (ET.ParseError, ValueError) as e:
        return ParseResult(
            bank_name=bank_name,
            format=detected_format,
            warnings=[f"Erreur de parsing XML : {e}"],
        )

    # Detect namespace from root tag
    ns_match = re.match(r"\{(.+)\}", root.tag)
    ns = ns_match.group(1) if ns_match else ""

    if "camt.054" in ns:
        detected_format = BankFormat.CAMT_054

    # Find all entries (Ntry) — works for both camt.053 and camt.054
    entries = root.findall(f".//{{{ns}}}Ntry") if ns else root.findall(".//Ntry")

    if not entries:
        # Try without namespace (some files strip ns)
        entries = root.findall(".//Ntry")

    for entry in entries:
        try:
            # Amount
            amt_elem = entry.find(f"{{{ns}}}Amt") if ns else entry.find("Amt")
            if amt_elem is None:
                continue
            amount = float(amt_elem.text or "0")
            currency = amt_elem.get("Ccy", "CHF")

            # Credit/Debit indicator
            cdi_elem = entry.find(f"{{{ns}}}CdtDbtInd") if ns else entry.find("CdtDbtInd")
            if cdi_elem is not None and cdi_elem.text == "DBIT":
                amount = -abs(amount)
            else:
                amount = abs(amount)

            # Booking date
            date = None
            bk_dt = entry.find(f"{{{ns}}}BookgDt") if ns else entry.find("BookgDt")
            if bk_dt is not None:
                dt_elem = bk_dt.find(f"{{{ns}}}Dt") if ns else bk_dt.find("Dt")
                if dt_elem is not None and dt_elem.text:
                    date = _parse_date(dt_elem.text, ["%Y-%m-%d"])

            if date is None:
                # Try value date
                val_dt = entry.find(f"{{{ns}}}ValDt") if ns else entry.find("ValDt")
                if val_dt is not None:
                    dt_elem = val_dt.find(f"{{{ns}}}Dt") if ns else val_dt.find("Dt")
                    if dt_elem is not None and dt_elem.text:
                        date = _parse_date(dt_elem.text, ["%Y-%m-%d"])

            if date is None:
                continue

            # Description — try multiple locations
            description = ""
            # NtryDtls > TxDtls > RmtInf > Ustrd
            for path_parts in [
                ["NtryDtls", "TxDtls", "RmtInf", "Ustrd"],
                ["NtryDtls", "TxDtls", "AddtlTxInf"],
                ["AddtlNtryInf"],
            ]:
                elem = entry
                for part in path_parts:
                    if elem is not None:
                        elem = elem.find(f"{{{ns}}}{part}") if ns else elem.find(part)
                if elem is not None and elem.text:
                    description = _sanitize_csv_field(elem.text.strip())
                    break

            category, subcategory = categorize_transaction(description)
            transactions.append(
                Transaction(
                    date=date,
                    description=description,
                    amount=amount,
                    category=category,
                    subcategory=subcategory,
                )
            )
        except (ValueError, AttributeError) as e:
            logger.debug("Skipping XML entry: %s", e)
            continue

    # Try to extract bank name from BkToCstmrStmt > GrpHdr > MsgId or Stmt > Acct > Svcr
    svcr = root.find(f".//{{{ns}}}Svcr/{{{ns}}}FinInstnId/{{{ns}}}Nm") if ns else root.find(".//Svcr/FinInstnId/Nm")
    if svcr is not None and svcr.text:
        bank_name = svcr.text.strip()

    return _finalize_result(transactions, bank_name, detected_format, warnings)


# ──────────────────────────────────────────────────────────────────────────────
# Result finalization
# ──────────────────────────────────────────────────────────────────────────────


def _finalize_result(
    transactions: list[Transaction],
    bank_name: str,
    bank_format: BankFormat,
    warnings: list[str],
) -> ParseResult:
    """Compute summaries and return a complete ParseResult."""
    if not transactions:
        return ParseResult(
            bank_name=bank_name,
            format=bank_format,
            warnings=warnings + ["Aucune transaction trouvee"],
            confidence=0.0,
        )

    # Sort by date
    transactions.sort(key=lambda t: t.date)

    # Compute summaries
    total_credits = sum(t.amount for t in transactions if t.amount > 0)
    total_debits = sum(t.amount for t in transactions if t.amount < 0)

    # Category summary (absolute values for expenses)
    category_summary: dict[str, float] = {}
    for t in transactions:
        if t.amount < 0:  # Expenses only
            cat = t.category
            category_summary[cat] = category_summary.get(cat, 0.0) + abs(t.amount)

    # Period
    period_start = transactions[0].date
    period_end = transactions[-1].date

    # Balances
    opening_balance = transactions[0].balance
    closing_balance = transactions[-1].balance

    # Confidence: based on how many transactions were categorized
    categorized = sum(1 for t in transactions if t.category != "Divers")
    confidence = min(0.95, 0.5 + (categorized / max(len(transactions), 1)) * 0.45)

    return ParseResult(
        bank_name=bank_name,
        format=bank_format,
        transactions=transactions,
        period_start=period_start,
        period_end=period_end,
        currency="CHF",
        opening_balance=opening_balance,
        closing_balance=closing_balance,
        total_credits=total_credits,
        total_debits=total_debits,
        category_summary=category_summary,
        confidence=round(confidence, 2),
        warnings=warnings,
    )


# ──────────────────────────────────────────────────────────────────────────────
# Main entry point
# ──────────────────────────────────────────────────────────────────────────────


def parse_bank_statement(
    content: bytes,
    filename: str,
) -> ParseResult:
    """
    Auto-detect format and parse a bank statement file.

    Args:
        content: raw file bytes
        filename: original filename (used for format detection)

    Returns:
        ParseResult with all transactions, summaries, and metadata

    Raises:
        ValueError: if file cannot be parsed at all
    """
    # Decode content
    text = ""
    for encoding in ["utf-8-sig", "utf-8", "latin-1", "cp1252"]:
        try:
            text = content.decode(encoding)
            break
        except (UnicodeDecodeError, UnicodeError):
            continue

    if not text.strip():
        raise ValueError("Le fichier est vide ou ne peut pas etre decode.")

    # Detect format
    detected = detect_format(text, filename)

    if detected == BankFormat.UNKNOWN:
        raise ValueError(
            "Format de releve bancaire non reconnu. "
            "Formats supportes : UBS, PostFinance, Raiffeisen, BCGE/BCV, CS/ZKB, Yuh/Neon, ISO 20022 (camt.053/054)."
        )

    # Route to appropriate parser
    if detected in (BankFormat.CAMT_053, BankFormat.CAMT_054):
        return parse_iso20022_xml(text)
    else:
        return parse_csv(text, detected)


# ──────────────────────────────────────────────────────────────────────────────
# W14 — Lightweight import models (currency-aware, dedup, categorization)
# ──────────────────────────────────────────────────────────────────────────────

# Keyword-based category patterns (lightweight, for W14 import flow)
W14_CATEGORY_PATTERNS: dict[str, list[str]] = {
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


@dataclass
class ImportedTransaction:
    """A single imported transaction (W14 lightweight model)."""

    date: str
    description: str
    amount: float
    currency: str
    is_debit: bool
    category: str = "divers"
    confidence: float = 0.0


@dataclass
class BankImportResult:
    """Result of a bank statement import (W14 lightweight model)."""

    transactions: list[ImportedTransaction] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    account_iban: Optional[str] = None
    statement_currency: Optional[str] = None
    total_credit: float = 0.0
    total_debit: float = 0.0


# ISO 20022 namespace helpers for W14 import
_W14_NS = {"camt": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"}
_W14_NS_FALLBACKS = [
    {"camt": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.02"},
    {"camt": "urn:iso:std:iso:20022:tech:xsd:camt.053.001.04"},
]


def categorize_description(description: str) -> tuple[str, float]:
    """Categorize a transaction description using keyword matching.

    Returns:
        Tuple of (category, confidence).
    """
    text = description.lower()
    for category, patterns in W14_CATEGORY_PATTERNS.items():
        if category == "divers":
            continue
        for pattern in patterns:
            if pattern in text:
                return category, 0.80
    return "divers", 0.30


def _find_with_fallback(root: ET.Element, path: str, ns: dict) -> Optional[ET.Element]:
    """Try to find an element with the primary NS, then fallback NSes."""
    elem = root.find(path, ns)
    if elem is not None:
        return elem
    for fallback_ns in _W14_NS_FALLBACKS:
        elem = root.find(path.replace("camt:", "camt:"), fallback_ns)
        if elem is not None:
            return elem
    return None


def _findall_with_fallback(root: ET.Element, path: str, ns: dict) -> list:
    """Try to findall with the primary NS, then fallback NSes."""
    elems = root.findall(path, ns)
    if elems:
        return elems
    for fallback_ns in _W14_NS_FALLBACKS:
        elems = root.findall(path.replace("camt:", "camt:"), fallback_ns)
        if elems:
            return elems
    return []


def import_iso20022_xml(xml_content: str) -> BankImportResult:
    """Parse an ISO 20022 camt.053 XML bank statement (W14 import flow).

    Extracts transactions with their actual currency from the <Ccy> element
    instead of hardcoding CHF.  Includes deduplication.

    Args:
        xml_content: Raw XML string.

    Returns:
        BankImportResult with parsed transactions.
    """
    result = BankImportResult()

    try:
        root = safe_fromstring(xml_content)
    except (ET.ParseError, ValueError) as e:
        result.warnings.append(f"Erreur de parsing XML : {e}")
        return result

    # Detect the namespace from the root element
    ns = _W14_NS
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

    transactions: list[ImportedTransaction] = []
    for entry in entries:
        tx = _parse_import_entry(entry, ns, statement_currency)
        if tx is not None:
            transactions.append(tx)

    # --- Duplicate detection (hash-based dedup) ---
    seen: set = set()
    unique_transactions: list[ImportedTransaction] = []
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


def _parse_import_entry(
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
