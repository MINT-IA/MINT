"""
Swiss bank statement extractor for MINT Docling pipeline.

Parses CSV and PDF bank statements from major Swiss banks (UBS, PostFinance,
Raiffeisen, ZKB, etc.). Extracts transactions, auto-detects bank format,
and supports Swiss number/date conventions.

Privacy: raw file bytes are never stored — only extracted transaction data is kept.
"""

from __future__ import annotations

import csv
import io
import logging
import re
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────────────────────────────────────
# Data Classes
# ──────────────────────────────────────────────────────────────────────────────


@dataclass
class BankTransaction:
    """A single bank transaction extracted from a statement."""

    date: str  # ISO format YYYY-MM-DD
    description: str  # Transaction description
    amount: float  # Positive = credit, negative = debit
    balance: Optional[float] = None  # Running balance if available
    category: str = "divers"  # Auto-categorized
    subcategory: Optional[str] = None  # More specific category
    is_recurring: bool = False  # Detected as recurring
    raw_text: str = ""  # Original text from statement

    def to_dict(self) -> dict:
        """Convert to dictionary."""
        return asdict(self)


@dataclass
class BankStatementData:
    """Extracted data from a bank statement (CSV or PDF)."""

    bank_name: Optional[str] = None  # Detected bank (UBS, PostFinance, etc.)
    account_type: Optional[str] = None  # Checking, savings, etc.
    period_start: Optional[str] = None  # Statement period start (ISO)
    period_end: Optional[str] = None  # Statement period end (ISO)
    currency: str = "CHF"  # Currency
    transactions: list = field(default_factory=list)  # List of BankTransaction
    total_credits: float = 0.0  # Sum of positive amounts
    total_debits: float = 0.0  # Sum of negative amounts (stored as negative)
    opening_balance: Optional[float] = None
    closing_balance: Optional[float] = None
    confidence: float = 0.0
    warnings: list = field(default_factory=list)

    def to_dict(self) -> dict:
        """Convert to dictionary with nested transactions."""
        d = asdict(self)
        return d


# ──────────────────────────────────────────────────────────────────────────────
# Swiss number / date parsing helpers
# ──────────────────────────────────────────────────────────────────────────────

# Swiss date formats: DD.MM.YYYY, DD/MM/YYYY, YYYY-MM-DD
_SWISS_DATE_PATTERN = re.compile(
    r"(\d{1,2})[./](\d{1,2})[./](\d{4})"
)
_ISO_DATE_PATTERN = re.compile(
    r"(\d{4})-(\d{2})-(\d{2})"
)


def parse_swiss_date(text: str) -> Optional[str]:
    """
    Parse a Swiss date string into ISO format (YYYY-MM-DD).

    Handles DD.MM.YYYY, DD/MM/YYYY, and YYYY-MM-DD formats.

    Args:
        text: Date string to parse.

    Returns:
        ISO date string or None if not parseable.
    """
    if not text:
        return None

    text = text.strip().strip('"').strip("'")

    # Try ISO format first (YYYY-MM-DD)
    iso_match = _ISO_DATE_PATTERN.search(text)
    if iso_match:
        year, month, day = iso_match.group(1), iso_match.group(2), iso_match.group(3)
        try:
            datetime(int(year), int(month), int(day))
            return f"{year}-{month}-{day}"
        except ValueError:
            pass

    # Try Swiss format (DD.MM.YYYY or DD/MM/YYYY)
    swiss_match = _SWISS_DATE_PATTERN.search(text)
    if swiss_match:
        day, month, year = swiss_match.group(1), swiss_match.group(2), swiss_match.group(3)
        try:
            datetime(int(year), int(month), int(day))
            return f"{year}-{month.zfill(2)}-{day.zfill(2)}"
        except ValueError:
            pass

    return None


def parse_swiss_amount(text: str) -> Optional[float]:
    """
    Parse a Swiss-formatted amount string into a float.

    Handles:
    - Apostrophe as thousand separator: 12'345.67
    - Right single quote as thousand separator: 12\u2019345.67
    - Comma as decimal separator: 12345,67
    - Negative signs: -45.80, (45.80)
    - Quoted values: "45.80", "-45.80"
    - Empty strings → None

    Args:
        text: Amount string to parse.

    Returns:
        Float value or None if not parseable.
    """
    if not text:
        return None

    text = text.strip().strip('"').strip("'")

    if not text or text == "-" or text == "":
        return None

    # Track sign
    negative = False

    # Handle parenthesized negatives: (45.80) -> -45.80
    if text.startswith("(") and text.endswith(")"):
        text = text[1:-1]
        negative = True

    # Handle leading minus or plus
    if text.startswith("-"):
        negative = True
        text = text[1:]
    elif text.startswith("+"):
        text = text[1:]

    # Remove currency prefixes
    for prefix in ["CHF", "Fr.", "SFr.", "EUR", "USD"]:
        text = text.replace(prefix, "")

    text = text.strip()

    if not text:
        return None

    # Remove Swiss thousand separators (apostrophe, right single quote, space)
    text = text.replace("'", "").replace("\u2019", "").replace(" ", "")

    # Handle European comma as decimal separator
    # If both comma and dot exist, the last one is the decimal separator
    if "," in text and "." in text:
        last_comma = text.rfind(",")
        last_dot = text.rfind(".")
        if last_comma > last_dot:
            # European: 1.234,56
            text = text.replace(".", "").replace(",", ".")
        else:
            # Swiss/Anglo: 1,234.56
            text = text.replace(",", "")
    elif "," in text:
        # Only comma: check if it's a decimal separator
        parts = text.split(",")
        if len(parts) == 2 and len(parts[1]) <= 2:
            # Likely decimal: 1234,56
            text = text.replace(",", ".")
        else:
            # Likely thousand separator: 1,234,567
            text = text.replace(",", "")

    try:
        value = float(text)
        if negative:
            value = -abs(value)
        return value
    except ValueError:
        return None


# ──────────────────────────────────────────────────────────────────────────────
# Bank format detection
# ──────────────────────────────────────────────────────────────────────────────

# Known Swiss bank CSV column signatures
BANK_SIGNATURES = {
    "ubs": {
        "columns": [
            ["valutadatum", "buchungsdatum", "buchungstext", "belastung", "gutschrift", "saldo"],
            ["valuta", "buchung", "text", "belastung", "gutschrift", "saldo"],
        ],
        "date_col": 0,
        "description_col": 2,
        "debit_col": 3,
        "credit_col": 4,
        "balance_col": 5,
    },
    "postfinance": {
        "columns": [
            ["datum", "buchungsart", "buchungsdetails", "gutschrift in chf", "lastschrift in chf", "saldo in chf"],
            ["datum", "avis", "details", "gutschrift", "lastschrift", "saldo"],
            ["date", "type", "details", "credit", "debit", "balance"],
        ],
        "date_col": 0,
        "description_col": 2,
        "credit_col": 3,
        "debit_col": 4,
        "balance_col": 5,
    },
    "raiffeisen": {
        "columns": [
            ["booked at", "text", "credit/debit amount", "balance"],
            ["valuta", "text", "betrag", "saldo"],
        ],
        "date_col": 0,
        "description_col": 1,
        "amount_col": 2,
        "balance_col": 3,
    },
    "zkb": {
        "columns": [
            ["datum", "buchungstext", "belastung", "gutschrift", "saldo"],
            ["valutadatum", "text", "belastung", "gutschrift", "saldo"],
        ],
        "date_col": 0,
        "description_col": 1,
        "debit_col": 2,
        "credit_col": 3,
        "balance_col": 4,
    },
}


def _normalize_header(header: str) -> str:
    """Normalize a header string for comparison."""
    return header.strip().strip('"').strip("'").lower().strip()


def detect_bank_format(headers: list[str]) -> tuple[Optional[str], Optional[dict]]:
    """
    Detect the bank format from CSV column headers.

    Args:
        headers: List of column header strings.

    Returns:
        Tuple of (bank_name, column_mapping) or (None, None) if not recognized.
    """
    normalized = [_normalize_header(h) for h in headers]

    for bank_name, signature in BANK_SIGNATURES.items():
        for expected_cols in signature["columns"]:
            if len(normalized) >= len(expected_cols):
                # Check if all expected columns are present (in order)
                match = True
                for i, expected in enumerate(expected_cols):
                    if i < len(normalized):
                        if expected not in normalized[i] and normalized[i] not in expected:
                            match = False
                            break
                    else:
                        match = False
                        break

                if match:
                    return bank_name, signature

    return None, None


# ──────────────────────────────────────────────────────────────────────────────
# Generic column detection
# ──────────────────────────────────────────────────────────────────────────────

# Patterns for detecting column types in unknown formats
_DATE_HEADER_PATTERNS = [
    r"(?i)dat(e|um)", r"(?i)valuta", r"(?i)booked", r"(?i)date\s+valeur",
]
_DESCRIPTION_HEADER_PATTERNS = [
    r"(?i)text", r"(?i)beschreibung", r"(?i)description", r"(?i)libell[ée]",
    r"(?i)buchung", r"(?i)detail", r"(?i)motif",
]
_AMOUNT_HEADER_PATTERNS = [
    r"(?i)amount", r"(?i)betrag", r"(?i)montant", r"(?i)credit.*debit",
    r"(?i)debit.*credit",
]
_DEBIT_HEADER_PATTERNS = [
    r"(?i)belastung", r"(?i)lastschrift", r"(?i)debit", r"(?i)d[ée]bit",
    r"(?i)ausgabe",
]
_CREDIT_HEADER_PATTERNS = [
    r"(?i)gutschrift", r"(?i)credit", r"(?i)cr[ée]dit", r"(?i)einnahme",
]
_BALANCE_HEADER_PATTERNS = [
    r"(?i)saldo", r"(?i)balance", r"(?i)solde",
]


def _detect_column_type(header: str) -> Optional[str]:
    """Detect column type from header name."""
    h = header.strip().lower()

    for pattern in _DATE_HEADER_PATTERNS:
        if re.search(pattern, h):
            return "date"
    for pattern in _DEBIT_HEADER_PATTERNS:
        if re.search(pattern, h):
            return "debit"
    for pattern in _CREDIT_HEADER_PATTERNS:
        if re.search(pattern, h):
            return "credit"
    for pattern in _BALANCE_HEADER_PATTERNS:
        if re.search(pattern, h):
            return "balance"
    for pattern in _AMOUNT_HEADER_PATTERNS:
        if re.search(pattern, h):
            return "amount"
    for pattern in _DESCRIPTION_HEADER_PATTERNS:
        if re.search(pattern, h):
            return "description"

    return None


def detect_generic_columns(headers: list[str]) -> Optional[dict]:
    """
    Auto-detect column mapping from headers for unknown bank formats.

    Args:
        headers: List of column header strings.

    Returns:
        Column mapping dict or None if minimum columns not found.
    """
    col_map = {}

    for i, header in enumerate(headers):
        col_type = _detect_column_type(header)
        if col_type:
            if col_type == "date" and "date_col" not in col_map:
                col_map["date_col"] = i
            elif col_type == "description" and "description_col" not in col_map:
                col_map["description_col"] = i
            elif col_type == "amount" and "amount_col" not in col_map:
                col_map["amount_col"] = i
            elif col_type == "debit" and "debit_col" not in col_map:
                col_map["debit_col"] = i
            elif col_type == "credit" and "credit_col" not in col_map:
                col_map["credit_col"] = i
            elif col_type == "balance" and "balance_col" not in col_map:
                col_map["balance_col"] = i

    # Minimum: need at least a date column and either amount or debit/credit
    has_date = "date_col" in col_map
    has_amount = (
        "amount_col" in col_map
        or "debit_col" in col_map
        or "credit_col" in col_map
    )

    if has_date and has_amount:
        return col_map

    return None


# ──────────────────────────────────────────────────────────────────────────────
# BankStatementExtractor
# ──────────────────────────────────────────────────────────────────────────────


class BankStatementExtractor:
    """
    Extract structured transaction data from Swiss bank statements.

    Supports CSV and PDF formats from UBS, PostFinance, Raiffeisen, ZKB,
    and generic formats with auto-detection.
    """

    # Supported encodings for Swiss bank CSVs
    ENCODINGS = ["utf-8", "iso-8859-1", "windows-1252", "utf-8-sig"]

    # Supported delimiters
    DELIMITERS = [";", ",", "\t"]

    # Maximum file size: 10 MB
    MAX_FILE_SIZE = 10 * 1024 * 1024

    def parse_csv(
        self,
        file_bytes: bytes,
        encoding: Optional[str] = None,
    ) -> BankStatementData:
        """
        Parse a CSV bank statement from raw bytes.

        Auto-detects encoding, delimiter, header row, and bank format.

        Args:
            file_bytes: Raw CSV file content as bytes.
            encoding: Optional encoding override. If None, auto-detected.

        Returns:
            BankStatementData with extracted transactions.

        Raises:
            ValueError: If the file is empty, too large, or unparseable.
        """
        if not file_bytes:
            raise ValueError("Empty file provided")

        if len(file_bytes) > self.MAX_FILE_SIZE:
            raise ValueError(
                f"File size ({len(file_bytes)} bytes) exceeds maximum "
                f"({self.MAX_FILE_SIZE} bytes)"
            )

        result = BankStatementData()

        # Step 1: Decode the file
        text = self._decode_bytes(file_bytes, encoding)
        if not text.strip():
            raise ValueError("File contains no readable text")

        # Step 2: Detect delimiter
        delimiter = self._detect_delimiter(text)

        # Step 3: Find header row and parse CSV
        lines = text.splitlines()
        header_idx, headers = self._find_header_row(lines, delimiter)

        if header_idx is None or not headers:
            raise ValueError(
                "Could not detect column headers in CSV. "
                "Expected columns like: Datum, Text, Betrag, Saldo"
            )

        # Step 4: Detect bank format
        bank_name, col_mapping = detect_bank_format(headers)

        if bank_name:
            result.bank_name = bank_name.upper()
            if bank_name == "postfinance":
                result.bank_name = "PostFinance"
            elif bank_name == "zkb":
                result.bank_name = "ZKB"
        else:
            # Try generic column detection
            col_mapping = detect_generic_columns(headers)
            if col_mapping is None:
                raise ValueError(
                    "Could not detect column mapping. Headers found: "
                    + ", ".join(headers)
                )
            result.bank_name = None

        # Step 5: Parse data rows
        data_lines = lines[header_idx + 1:]
        transactions = self._parse_rows(data_lines, delimiter, col_mapping, result)
        result.transactions = transactions

        # Step 6: Compute summary
        self._compute_summary(result)

        return result

    def parse_pdf(self, file_bytes: bytes) -> BankStatementData:
        """
        Parse a PDF bank statement using the DocumentParser.

        Uses pdfplumber for table extraction, then applies the same
        column detection logic as CSV parsing.

        Args:
            file_bytes: Raw PDF file content as bytes.

        Returns:
            BankStatementData with extracted transactions.

        Raises:
            ValueError: If the file is empty or not a valid PDF.
        """
        try:
            from app.services.docling.parser import DocumentParser
        except ImportError:
            raise ValueError(
                "pdfplumber is not installed. Install with: pip install -e '.[docling]'"
            )

        parser = DocumentParser()
        parsed = parser.parse_pdf(file_bytes)

        result = BankStatementData()

        # Try to extract from tables first (most reliable for bank statements)
        all_tables = []
        for page in parsed.pages:
            all_tables.extend(page.tables)

        if all_tables:
            transactions = self._extract_from_tables(all_tables, result)
            result.transactions = transactions
        else:
            # Fallback: try to parse text as CSV-like content
            if parsed.full_text.strip():
                result.warnings.append(
                    "No tables found in PDF. Attempting text-based extraction."
                )
                transactions = self._extract_from_text(parsed.full_text, result)
                result.transactions = transactions

        if not result.transactions:
            result.warnings.append(
                "No transactions could be extracted from the PDF."
            )

        self._compute_summary(result)
        return result

    # ──────────────────────────────────────────────────────────────────────
    # Internal helpers
    # ──────────────────────────────────────────────────────────────────────

    def _decode_bytes(
        self, file_bytes: bytes, encoding: Optional[str] = None
    ) -> str:
        """Decode file bytes, trying multiple encodings."""
        if encoding:
            try:
                return file_bytes.decode(encoding)
            except (UnicodeDecodeError, LookupError):
                pass

        for enc in self.ENCODINGS:
            try:
                return file_bytes.decode(enc)
            except UnicodeDecodeError:
                continue

        raise ValueError(
            "Could not decode file with any supported encoding: "
            + ", ".join(self.ENCODINGS)
        )

    def _detect_delimiter(self, text: str) -> str:
        """Auto-detect the CSV delimiter from the first few lines."""
        # Count occurrences of each delimiter in the first 10 lines
        lines = text.splitlines()[:10]
        sample = "\n".join(lines)

        counts = {}
        for delim in self.DELIMITERS:
            counts[delim] = sample.count(delim)

        # Return the delimiter with highest count, default to semicolon (Swiss standard)
        if not any(counts.values()):
            return ";"

        return max(counts, key=counts.get)

    def _find_header_row(
        self, lines: list[str], delimiter: str
    ) -> tuple[Optional[int], list[str]]:
        """
        Find the header row in a CSV file.

        Swiss bank CSVs often have metadata rows before the actual headers.
        We look for the first row that looks like column headers.
        """
        for i, line in enumerate(lines[:20]):  # Search first 20 lines
            if not line.strip():
                continue

            # Split the line
            try:
                reader = csv.reader(io.StringIO(line), delimiter=delimiter)
                cells = next(reader)
            except (csv.Error, StopIteration):
                continue

            if len(cells) < 2:
                continue

            # Check if this looks like a header row:
            # - Contains date-like column names
            # - Contains amount/text-like column names
            normalized = [_normalize_header(c) for c in cells]
            has_date_col = any(
                re.search(p, c) for c in normalized for p in _DATE_HEADER_PATTERNS
            )
            has_text_or_amount = any(
                re.search(p, c)
                for c in normalized
                for p in (
                    _DESCRIPTION_HEADER_PATTERNS
                    + _AMOUNT_HEADER_PATTERNS
                    + _DEBIT_HEADER_PATTERNS
                    + _CREDIT_HEADER_PATTERNS
                )
            )

            if has_date_col and has_text_or_amount:
                return i, cells

        return None, []

    def _parse_rows(
        self,
        data_lines: list[str],
        delimiter: str,
        col_mapping: dict,
        result: BankStatementData,
    ) -> list[BankTransaction]:
        """Parse data rows into BankTransaction objects."""
        transactions = []

        for line in data_lines:
            line = line.strip()
            if not line:
                continue

            try:
                reader = csv.reader(io.StringIO(line), delimiter=delimiter)
                cells = next(reader)
            except (csv.Error, StopIteration):
                continue

            tx = self._row_to_transaction(cells, col_mapping, result)
            if tx is not None:
                transactions.append(tx)

        return transactions

    def _row_to_transaction(
        self,
        cells: list[str],
        col_mapping: dict,
        result: BankStatementData,
    ) -> Optional[BankTransaction]:
        """Convert a single CSV row to a BankTransaction."""
        try:
            # Extract date
            date_col = col_mapping.get("date_col")
            if date_col is not None and date_col < len(cells):
                date_str = parse_swiss_date(cells[date_col])
            else:
                date_str = None

            if not date_str:
                return None  # Skip rows without a valid date

            # Extract description
            desc_col = col_mapping.get("description_col")
            description = ""
            if desc_col is not None and desc_col < len(cells):
                description = cells[desc_col].strip().strip('"')

            # Extract amount
            amount = self._extract_amount_from_row(cells, col_mapping)
            if amount is None:
                return None  # Skip rows without a valid amount

            # Extract balance
            balance = None
            bal_col = col_mapping.get("balance_col")
            if bal_col is not None and bal_col < len(cells):
                balance = parse_swiss_amount(cells[bal_col])

            # Build raw_text from original cells
            raw_text = ";".join(cells)

            return BankTransaction(
                date=date_str,
                description=description,
                amount=amount,
                balance=balance,
                raw_text=raw_text,
            )

        except (IndexError, ValueError) as e:
            logger.debug("Skipping row due to parse error: %s", e)
            return None

    def _extract_amount_from_row(
        self, cells: list[str], col_mapping: dict
    ) -> Optional[float]:
        """Extract amount from a row, handling debit/credit columns or single amount column."""
        # Single amount column (Raiffeisen-style)
        if "amount_col" in col_mapping:
            amt_col = col_mapping["amount_col"]
            if amt_col < len(cells):
                return parse_swiss_amount(cells[amt_col])
            return None

        # Separate debit/credit columns (UBS/PostFinance-style)
        debit_col = col_mapping.get("debit_col")
        credit_col = col_mapping.get("credit_col")

        amount = None

        if credit_col is not None and credit_col < len(cells):
            credit_val = parse_swiss_amount(cells[credit_col])
            if credit_val is not None:
                amount = abs(credit_val)

        if debit_col is not None and debit_col < len(cells):
            debit_val = parse_swiss_amount(cells[debit_col])
            if debit_val is not None:
                # Debit values: make negative if not already
                amount = -abs(debit_val)

        return amount

    def _extract_from_tables(
        self,
        tables: list[list[list[str]]],
        result: BankStatementData,
    ) -> list[BankTransaction]:
        """Extract transactions from PDF table data."""
        all_transactions = []

        for table in tables:
            if not table or len(table) < 2:
                continue

            # First row might be headers
            headers = table[0]
            bank_name, col_mapping = detect_bank_format(headers)

            if bank_name:
                result.bank_name = bank_name.upper()
                if bank_name == "postfinance":
                    result.bank_name = "PostFinance"
                elif bank_name == "zkb":
                    result.bank_name = "ZKB"
            else:
                col_mapping = detect_generic_columns(headers)
                if col_mapping is None:
                    continue

            # Parse data rows
            for row in table[1:]:
                tx = self._row_to_transaction(row, col_mapping, result)
                if tx is not None:
                    all_transactions.append(tx)

        return all_transactions

    def _extract_from_text(
        self,
        text: str,
        result: BankStatementData,
    ) -> list[BankTransaction]:
        """Fallback: extract transactions from text content."""
        transactions = []

        # Try to find lines that look like transaction entries
        # Pattern: date followed by description and amount
        tx_pattern = re.compile(
            r"(\d{1,2}[./]\d{1,2}[./]\d{4})\s+"  # Date
            r"(.+?)\s+"  # Description
            r"(-?[\d']+(?:[.,]\d{2})?)\s*$",  # Amount
            re.MULTILINE,
        )

        for match in tx_pattern.finditer(text):
            date_str = parse_swiss_date(match.group(1))
            description = match.group(2).strip()
            amount = parse_swiss_amount(match.group(3))

            if date_str and amount is not None:
                transactions.append(
                    BankTransaction(
                        date=date_str,
                        description=description,
                        amount=amount,
                        raw_text=match.group(0),
                    )
                )

        return transactions

    def _compute_summary(self, result: BankStatementData) -> None:
        """Compute summary fields from extracted transactions."""
        if not result.transactions:
            return

        total_credits = 0.0
        total_debits = 0.0

        dates = []

        for tx in result.transactions:
            if tx.amount > 0:
                total_credits += tx.amount
            elif tx.amount < 0:
                total_debits += tx.amount

            if tx.date:
                dates.append(tx.date)

        result.total_credits = round(total_credits, 2)
        result.total_debits = round(total_debits, 2)

        # Determine period
        if dates:
            sorted_dates = sorted(dates)
            result.period_start = sorted_dates[0]
            result.period_end = sorted_dates[-1]

        # Opening/closing balance from first/last transactions
        if result.transactions:
            first_tx = result.transactions[0]
            last_tx = result.transactions[-1]
            if first_tx.balance is not None:
                result.opening_balance = first_tx.balance
            if last_tx.balance is not None:
                result.closing_balance = last_tx.balance

        # Confidence scoring
        result.confidence = self._calculate_confidence(result)

    def _calculate_confidence(self, result: BankStatementData) -> float:
        """
        Calculate extraction confidence score [0.0 - 1.0].

        Based on:
        - Number of transactions extracted
        - Bank name detected
        - Balance consistency
        - Date validity
        """
        if not result.transactions:
            return 0.0

        score = 0.0

        # Base: at least some transactions found
        tx_count = len(result.transactions)
        if tx_count >= 10:
            score += 0.3
        elif tx_count >= 5:
            score += 0.2
        elif tx_count >= 1:
            score += 0.1

        # Bank name detected
        if result.bank_name:
            score += 0.2

        # Period detected
        if result.period_start and result.period_end:
            score += 0.1

        # Balances present
        balances_present = sum(
            1 for tx in result.transactions if tx.balance is not None
        )
        if balances_present > 0:
            score += 0.1

        # All transactions have valid dates
        valid_dates = sum(1 for tx in result.transactions if tx.date)
        if valid_dates == tx_count:
            score += 0.1

        # All transactions have descriptions
        has_desc = sum(1 for tx in result.transactions if tx.description)
        if has_desc == tx_count:
            score += 0.1

        # No warnings
        if not result.warnings:
            score += 0.1

        return min(round(score, 3), 1.0)
