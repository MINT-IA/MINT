"""
Swiss LPP (prévoyance professionnelle) certificate field extractor.

Parses structured data from Swiss pension fund certificates in FR, DE, and IT.
Extracts key financial fields: old-age savings, conversion rates, risk coverage,
buyback potential, salary components, and contributions.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, asdict
from typing import Optional

logger = logging.getLogger(__name__)

# Try loading the YAML template; fall back to hardcoded patterns if pyyaml not available
try:
    import yaml  # noqa: F401

    _YAML_AVAILABLE = True
except ImportError:
    _YAML_AVAILABLE = False


@dataclass
class LPPCertificateData:
    """Extracted data from a Swiss LPP pension certificate."""

    # Identifiers
    caisse_name: Optional[str] = None
    assure_name: Optional[str] = None
    date_certificat: Optional[str] = None

    # Core LPP fields
    avoir_vieillesse_obligatoire: Optional[float] = None
    avoir_vieillesse_surobligatoire: Optional[float] = None
    avoir_vieillesse_total: Optional[float] = None

    # Salary & deductions
    salaire_assure: Optional[float] = None
    salaire_avs: Optional[float] = None
    deduction_coordination: Optional[float] = None

    # Conversion rates
    taux_conversion_obligatoire: Optional[float] = None
    taux_conversion_surobligatoire: Optional[float] = None
    taux_conversion_enveloppe: Optional[float] = None

    # Risk coverage
    rente_invalidite_annuelle: Optional[float] = None
    capital_deces: Optional[float] = None
    rente_conjoint_annuelle: Optional[float] = None
    rente_enfant_annuelle: Optional[float] = None

    # Buyback
    rachat_maximum: Optional[float] = None

    # Contributions
    cotisation_employe_annuelle: Optional[float] = None
    cotisation_employeur_annuelle: Optional[float] = None

    # Metadata
    confidence: float = 0.0
    extracted_fields_count: int = 0
    total_fields_count: int = 18

    def to_dict(self) -> dict:
        """Convert to dictionary, excluding metadata fields for the payload."""
        return asdict(self)


# ──────────────────────────────────────────────────────────────────────────────
# Field definitions: keywords per language + extraction config
# ──────────────────────────────────────────────────────────────────────────────

# Each entry maps a LPPCertificateData field name to extraction info.
# "keywords" are tried in order; first match wins.
# "type" can be "amount" (CHF), "rate" (%), or "text".

FIELD_DEFINITIONS: dict[str, dict] = {
    "avoir_vieillesse_obligatoire": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"avoir\s+de\s+vieillesse\s+obligatoire",
                r"avoir\s+vieillesse\s+obligatoire",
                r"capital\s+vieillesse\s+obligatoire",
                r"avoirs?\s+obligatoires?",
                r"part\s+obligatoire",
            ],
            "de": [
                r"obligatorisches?\s+altersguthaben",
                r"altersguthaben\s+obligatorium",
                r"bvg[- ]?altersguthaben",
                r"obligatorischer?\s+teil",
            ],
            "it": [
                r"avere\s+di\s+vecchiaia\s+obbligatorio",
                r"capitale\s+di\s+vecchiaia\s+obbligatorio",
            ],
        },
    },
    "avoir_vieillesse_surobligatoire": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"avoir\s+de\s+vieillesse\s+surobligatoire",
                r"avoir\s+vieillesse\s+surobligatoire",
                r"capital\s+vieillesse\s+surobligatoire",
                r"avoirs?\s+surobligatoires?",
                r"part\s+surobligatoire",
                r"extra[- ]?obligatoire",
            ],
            "de": [
                r"[üu]berobligatorisches?\s+altersguthaben",
                r"altersguthaben\s+[üu]berobligatorium",
                r"ausserobligatorisches?\s+altersguthaben",
                r"[üu]berobligatorischer?\s+teil",
            ],
            "it": [
                r"avere\s+di\s+vecchiaia\s+sovraobbligatorio",
                r"parte\s+sovraobbligatoria",
            ],
        },
    },
    "avoir_vieillesse_total": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"avoir\s+de\s+vieillesse\s+total",
                r"avoir\s+vieillesse\s+total",
                r"capital\s+vieillesse\s+total",
                r"total\s+avoir\s+de\s+vieillesse",
                r"total\s+des?\s+avoirs?",
                # Swiss LPP: "prestation de sortie" IS the total avoir at the
                # certificate date — CPE / Publica / many other caisses use
                # this wording instead of "avoir total" (2e pilier LPP art. 16).
                r"prestation\s+de\s+sortie",
            ],
            "de": [
                r"altersguthaben\s+total",
                r"totales?\s+altersguthaben",
                r"gesamtes?\s+altersguthaben",
            ],
            "it": [
                r"avere\s+di\s+vecchiaia\s+totale",
                r"totale\s+avere\s+di\s+vecchiaia",
            ],
        },
    },
    "salaire_assure": {
        "type": "amount",
        # Swiss certs often print two columns per line: "Bonus  Base" (CPE,
        # PKE, etc.). The authoritative value for salaried employees is the
        # Base column — always the larger of the two. Tell the extractor to
        # pick the max amount found in the keyword context window.
        "prefer": "max",
        "keywords": {
            "fr": [
                r"salaire\s+assur[ée]",
                r"salaire\s+coordonn[ée]",
                r"salaire\s+annuel\s+assur[ée]",
            ],
            "de": [
                r"versicherter?\s+lohn",
                r"versicherter?\s+gehalt",
                r"koordinierter?\s+lohn",
            ],
            "it": [
                r"salario\s+assicurato",
                r"stipendio\s+assicurato",
            ],
        },
    },
    "salaire_avs": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"salaire\s+avs",
                r"salaire\s+brut\s+annuel",
                r"salaire\s+d[ée]terminant\s+avs",
                r"salaire\s+annuel\s+brut",
            ],
            "de": [
                r"ahv[- ]?lohn",
                r"ahv[- ]?gehalt",
                r"massgebender\s+lohn",
                r"bruttolohn",
            ],
            "it": [
                r"salario\s+avs",
                r"stipendio\s+avs",
            ],
        },
    },
    "deduction_coordination": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"d[ée]duction\s+de?\s+coordination",
                r"montant\s+de?\s+coordination",
            ],
            "de": [
                r"koordinationsabzug",
                r"koordinationsbetrag",
            ],
            "it": [
                r"deduzione\s+di\s+coordinamento",
                r"importo\s+di\s+coordinamento",
            ],
        },
    },
    "taux_conversion_obligatoire": {
        "type": "rate",
        "keywords": {
            "fr": [
                r"taux\s+de?\s+conversion\s+obligatoire",
                r"taux\s+de?\s+conversion\s+bvg",
                r"taux\s+de?\s+conversion\s+lpp",
            ],
            "de": [
                r"umwandlungssatz\s+obligatorium",
                r"obligatorischer?\s+umwandlungssatz",
                r"bvg[- ]?umwandlungssatz",
            ],
            "it": [
                r"aliquota\s+di\s+conversione\s+obbligatoria",
                r"tasso\s+di\s+conversione\s+obbligatorio",
            ],
        },
    },
    "taux_conversion_surobligatoire": {
        "type": "rate",
        "keywords": {
            "fr": [
                r"taux\s+de?\s+conversion\s+surobligatoire",
                r"taux\s+de?\s+conversion\s+extra[- ]?obligatoire",
            ],
            "de": [
                r"umwandlungssatz\s+[üu]berobligatorium",
                r"[üu]berobligatorischer?\s+umwandlungssatz",
            ],
            "it": [
                r"aliquota\s+di\s+conversione\s+sovraobbligatoria",
            ],
        },
    },
    "taux_conversion_enveloppe": {
        "type": "rate",
        "keywords": {
            "fr": [
                r"taux\s+de?\s+conversion\s+enveloppe",
                r"taux\s+de?\s+conversion\s+global",
                r"taux\s+d['\u2019]enveloppe",
            ],
            "de": [
                r"umh[üu]llender?\s+umwandlungssatz",
                r"gesamtumwandlungssatz",
            ],
            "it": [
                r"aliquota\s+di\s+conversione\s+complessiva",
            ],
        },
    },
    "rente_invalidite_annuelle": {
        "type": "amount",
        "prefer": "max",
        "keywords": {
            "fr": [
                r"rente\s+d['\u2019]?invalidit[ée]\s+annuelle",
                r"rente\s+d['\u2019]?invalidit[ée]",
                r"rente\s+invalidit[ée]",
                r"prestation\s+d['\u2019]?invalidit[ée]",
            ],
            "de": [
                r"invalidenrente",
                r"j[äa]hrliche\s+invalidenrente",
                r"invaliden-?rente",
            ],
            "it": [
                r"rendita\s+d['\u2019]?invalidit[àa]",
                r"rendita\s+di\s+invalidit[àa]",
            ],
        },
    },
    "capital_deces": {
        "type": "amount",
        "keywords": {
            "fr": [
                # Require the label to be followed by a digit/"CHF" within ~40
                # chars — otherwise we capture the règlement boilerplate
                # "Les dispositions s'appliquent au capital décès" and grab the
                # next unrelated amount (CPE bug: returned rachat-max 539k as
                # capital_deces 2026-04-15).
                r"capital[- ]?d[ée]c[èe]s\s*(?:CHF|Fr\.|\d|:|=)",
                r"capital\s+en\s+cas\s+de\s+d[ée]c[èe]s\s*(?:CHF|Fr\.|\d|:|=)",
                r"prestation\s+de\s+d[ée]c[èe]s\s*(?:CHF|Fr\.|\d|:|=)",
            ],
            "de": [
                r"todesfallkapital",
                r"todesfall[- ]?kapital",
                r"kapital\s+im\s+todesfall",
            ],
            "it": [
                r"capitale\s+in\s+caso\s+di\s+decesso",
                r"capitale\s+di\s+decesso",
            ],
        },
    },
    "rente_conjoint_annuelle": {
        "type": "amount",
        "prefer": "max",
        "keywords": {
            "fr": [
                r"rente\s+de?\s+conjoint",
                r"rente\s+de?\s+veuf",
                r"rente\s+de?\s+veuve",
                r"rente\s+de?\s+partenaire",
            ],
            "de": [
                r"ehegattenrente",
                r"partnerrente",
                r"witwen[- ]?rente",
                r"witwer[- ]?rente",
            ],
            "it": [
                r"rendita\s+per\s+il\s+coniuge",
                r"rendita\s+vedovile",
            ],
        },
    },
    "rente_enfant_annuelle": {
        "type": "amount",
        "prefer": "max",
        "keywords": {
            "fr": [
                r"rente\s+d['\u2019]?enfant",
                r"rente\s+pour\s+enfant",
                r"rente\s+d['\u2019]?orphelin",
            ],
            "de": [
                r"kinderrente",
                r"waisenrente",
                r"kinder[- ]?rente",
            ],
            "it": [
                r"rendita\s+per\s+figli",
                r"rendita\s+per\s+orfani",
            ],
        },
    },
    "rachat_maximum": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"rachat\s+(?:maximum|maximal|possible)",
                r"montant\s+de?\s+rachat",
                r"possibilit[ée]\s+de?\s+rachat",
                r"rachat\s+disponible",
                # CPE / Publica / Swiss Life formulation: "Rachat en vue de la
                # retraite ordinaire à l'âge de 65 ans X'XXX'XXX.XX" — this is
                # the canonical rachat_max (LPP art. 79b), distinct from the
                # early-retirement bridging buyback which is a different number.
                r"rachat\s+en\s+vue\s+de?\s+(?:la\s+)?retraite\s+ordinaire",
            ],
            "de": [
                r"(?:maximaler?|m[öo]glicher?)\s+einkauf",
                r"einkaufspotenzial",
                r"einkaufs?summe",
                r"einkauf\s+m[öo]glich",
            ],
            "it": [
                r"riscatto\s+(?:massimo|possibile)",
                r"possibilit[àa]\s+di\s+riscatto",
            ],
        },
    },
    "cotisation_employe_annuelle": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"cotisation\s+employ[ée]\s+annuelle",
                r"cotisation\s+de?\s+l['\u2019]?employ[ée]",
                r"part\s+employ[ée]",
                r"cotisation\s+salari[ée]",
                r"contribution\s+employ[ée]",
            ],
            "de": [
                r"arbeitnehmer[- ]?beitrag",
                r"beitrag\s+arbeitnehmer",
                r"arbeitnehmeranteil",
            ],
            "it": [
                r"contributo\s+del?\s+dipendente",
                r"contributo\s+lavoratore",
            ],
        },
    },
    "cotisation_employeur_annuelle": {
        "type": "amount",
        "keywords": {
            "fr": [
                r"cotisation\s+employeur\s+annuelle",
                r"cotisation\s+de?\s+l['\u2019]?employeur",
                r"part\s+employeur",
                r"contribution\s+employeur",
            ],
            "de": [
                r"arbeitgeber[- ]?beitrag",
                r"beitrag\s+arbeitgeber",
                r"arbeitgeberanteil",
            ],
            "it": [
                r"contributo\s+del?\s+datore",
                r"contributo\s+datore\s+di\s+lavoro",
            ],
        },
    },
    "caisse_name": {
        "type": "text",
        "keywords": {
            "fr": [
                r"caisse\s+de\s+pension",
                r"caisse\s+de\s+pr[ée]voyance",
                r"institution\s+de\s+pr[ée]voyance",
                r"fondation\s+de\s+pr[ée]voyance",
            ],
            "de": [
                r"pensionskasse",
                r"vorsorgeeinrichtung",
                r"vorsorgestiftung",
            ],
            "it": [
                r"cassa\s+pensione",
                r"istituto\s+di\s+previdenza",
                r"fondazione\s+di\s+previdenza",
            ],
        },
    },
    "date_certificat": {
        "type": "date",
        "keywords": {
            "fr": [
                r"date\s+du\s+certificat",
                r"[ée]tabli\s+le",
                r"valable\s+au",
                r"situation\s+au",
            ],
            "de": [
                r"datum\s+des?\s+ausweises?",
                r"erstellt\s+am",
                r"stand\s+per",
                r"g[üu]ltig\s+per",
            ],
            "it": [
                r"data\s+del\s+certificato",
                r"valido\s+al",
                r"situazione\s+al",
            ],
        },
    },
}

# Fields that hold financial values (for confidence scoring)
FINANCIAL_FIELDS = [
    "avoir_vieillesse_obligatoire",
    "avoir_vieillesse_surobligatoire",
    "avoir_vieillesse_total",
    "salaire_assure",
    "salaire_avs",
    "deduction_coordination",
    "taux_conversion_obligatoire",
    "taux_conversion_surobligatoire",
    "taux_conversion_enveloppe",
    "rente_invalidite_annuelle",
    "capital_deces",
    "rente_conjoint_annuelle",
    "rente_enfant_annuelle",
    "rachat_maximum",
    "cotisation_employe_annuelle",
    "cotisation_employeur_annuelle",
    "caisse_name",
    "date_certificat",
]

# Regex for extracting CHF amounts: handles "CHF 123'456.78", "123,456.78", "123456.78"
# Two patterns tried in order:
# 1. Numbers with separators (apostrophe, space) and optional decimals: 123'456.78
# 2. Plain numbers with optional decimals: 150000.00
_AMOUNT_PATTERNS = [
    # Pattern 1: Numbers with Swiss thousand separators (apostrophe, right-quote, space)
    re.compile(
        r"(?:CHF|Fr\.|SFr\.?)?\s*-?\s*"
        r"(\d{1,3}(?:['\u2019\s]\d{3})+(?:[.,]\d{1,2})?)",
        re.IGNORECASE,
    ),
    # Pattern 2: Plain numbers with optional decimals (e.g., 150000.00, 1234.50)
    re.compile(
        r"(?:CHF|Fr\.|SFr\.?)?\s*-?\s*"
        r"(\d+[.,]\d{1,2})",
        re.IGNORECASE,
    ),
    # Pattern 3: Plain integer numbers (e.g., 150000)
    re.compile(
        r"(?:CHF|Fr\.|SFr\.?)?\s*-?\s*"
        r"(\d{2,})",
        re.IGNORECASE,
    ),
]

# Regex for percentage extraction
_RATE_PATTERN = re.compile(
    r"(\d{1,3}(?:[.,]\d{1,4})?)\s*%",
)

# Regex for dates (dd.mm.yyyy or dd/mm/yyyy or yyyy-mm-dd)
_DATE_PATTERN = re.compile(
    r"(\d{1,2}[./]\d{1,2}[./]\d{4}|\d{4}-\d{2}-\d{2})"
)


class LPPCertificateExtractor:
    """
    Extract structured LPP certificate data from parsed document text and tables.

    Supports French (primary), German, and Italian certificates.
    Uses keyword matching and contextual CHF amount extraction.
    """

    def __init__(self, field_definitions: Optional[dict] = None):
        """
        Initialize the extractor.

        Args:
            field_definitions: Optional custom field definitions. If None,
                uses the built-in FIELD_DEFINITIONS.
        """
        self.field_definitions = field_definitions or FIELD_DEFINITIONS

    def extract(
        self,
        text: str,
        tables: Optional[list[list[list[str]]]] = None,
    ) -> LPPCertificateData:
        """
        Extract LPP certificate fields from text and optional tables.

        Args:
            text: Full text content of the certificate.
            tables: Optional list of tables (each table is a list of rows,
                    each row is a list of cell strings).

        Returns:
            LPPCertificateData with extracted fields and confidence score.
        """
        result = LPPCertificateData()

        if not text and not tables:
            return result

        # Combine table data into searchable text
        combined_text = text or ""
        table_text = self._tables_to_text(tables) if tables else ""
        if table_text:
            combined_text = combined_text + "\n" + table_text

        # Detect language for keyword priority ordering
        detected_lang = self._detect_language(combined_text)
        lang_order = self._get_language_order(detected_lang)

        # Extract each defined field
        for field_name, field_def in self.field_definitions.items():
            if not hasattr(result, field_name):
                continue

            field_type = field_def.get("type", "amount")
            keywords = field_def.get("keywords", {})
            prefer = field_def.get("prefer")

            value = self._extract_field(
                combined_text, keywords, field_type, lang_order, prefer=prefer
            )

            # Also search tables directly for amount/rate fields
            if value is None and tables and field_type in ("amount", "rate"):
                value = self._extract_from_tables(
                    tables, keywords, field_type, lang_order
                )

            if value is not None:
                setattr(result, field_name, value)

        # Calculate confidence
        result.extracted_fields_count = self._count_extracted_fields(result)
        result.confidence = self._calculate_confidence(result)

        return result

    def _extract_field(
        self,
        text: str,
        keywords: dict[str, list[str]],
        field_type: str,
        lang_order: list[str],
        prefer: Optional[str] = None,
    ) -> Optional[float | str]:
        """
        Extract a single field value from text using keyword matching.

        Args:
            text: The text to search in.
            keywords: Dictionary mapping language codes to keyword regex patterns.
            field_type: "amount", "rate", "date", or "text".
            lang_order: Priority order of languages to try.

        Returns:
            Extracted value or None if not found.
        """
        text_lower = text.lower()

        for lang in lang_order:
            lang_keywords = keywords.get(lang, [])
            for kw_pattern in lang_keywords:
                matches = list(
                    re.finditer(kw_pattern, text_lower, re.IGNORECASE)
                )
                for match in matches:
                    # Search in the vicinity of the keyword match
                    # Look at the text from keyword position to ~200 chars after
                    start = match.start()
                    context = text[start : start + 300]

                    if field_type == "amount":
                        if prefer == "max":
                            # Bi-column Swiss cert (Bonus | Base): pick the
                            # larger amount found on the first line of the
                            # keyword window.
                            first_line_ctx = context.split("\n", 1)[0]
                            amounts = self._extract_all_amounts(first_line_ctx)
                            if amounts:
                                return max(amounts)
                        amount = self._extract_amount(context)
                        if amount is not None:
                            return amount
                    elif field_type == "rate":
                        rate = self._extract_rate(context)
                        if rate is not None:
                            return rate
                    elif field_type == "date":
                        date = self._extract_date(context)
                        if date is not None:
                            return date
                    elif field_type == "text":
                        # For text fields, capture the rest of the line
                        text_val = self._extract_text_value(context)
                        if text_val:
                            return text_val

        return None

    def _extract_from_tables(
        self,
        tables: list[list[list[str]]],
        keywords: dict[str, list[str]],
        field_type: str,
        lang_order: list[str],
    ) -> Optional[float]:
        """
        Search tables for a field value using keyword matching in cells.

        Many Swiss LPP certificates present data in table format:
        | Label            | Value        |
        | Avoir vieillesse | CHF 150'000  |
        """
        for table in tables:
            for row in table:
                if not row:
                    continue
                # Check each cell for keyword matches
                for i, cell in enumerate(row):
                    cell_lower = (cell or "").lower()
                    for lang in lang_order:
                        lang_keywords = keywords.get(lang, [])
                        for kw_pattern in lang_keywords:
                            if re.search(kw_pattern, cell_lower, re.IGNORECASE):
                                # Found keyword — look for value in adjacent cells
                                for j in range(len(row)):
                                    if j == i:
                                        continue
                                    val_cell = row[j] or ""
                                    if field_type == "amount":
                                        amount = self._extract_amount(val_cell)
                                        if amount is not None:
                                            return amount
                                    elif field_type == "rate":
                                        rate = self._extract_rate(val_cell)
                                        if rate is not None:
                                            return rate
        return None

    def _extract_all_amounts(self, text: str) -> list[float]:
        """Extract every CHF amount in the text (used when a field is known
        to span a Bonus | Base bi-column layout and we need to pick one)."""
        found: list[float] = []
        for pattern in _AMOUNT_PATTERNS:
            for m in pattern.finditer(text):
                raw = m.group(1)
                if not raw:
                    continue
                value = self._parse_number(raw)
                if value is not None and 0 <= value <= 10_000_000:
                    found.append(value)
        # Dedupe while preserving order (same digit could match multiple
        # patterns) — keep unique floats only.
        seen: set[float] = set()
        unique: list[float] = []
        for v in found:
            if v not in seen:
                seen.add(v)
                unique.append(v)
        return unique

    def _extract_amount(self, text: str) -> Optional[float]:
        """
        Extract a CHF amount from a text snippet.

        Handles formats: "CHF 123'456.78", "123,456.78", "123456",
        "Fr. 1'234.50", etc.

        Tries multiple patterns in order: structured thousands first,
        then plain decimals, then plain integers.
        """
        for pattern in _AMOUNT_PATTERNS:
            matches = list(pattern.finditer(text))
            for m in matches:
                raw = m.group(1)
                if not raw:
                    continue

                value = self._parse_number(raw)
                if value is not None and 0 <= value <= 10_000_000:
                    return value

        return None

    @staticmethod
    def _parse_number(raw: str) -> Optional[float]:
        """Parse a raw number string into a float, handling various formats."""
        # Clean the number: remove thousand separators
        cleaned = raw.replace("'", "").replace("\u2019", "").replace(" ", "")

        # Handle European format (comma as decimal, dot as thousand)
        # vs. Swiss/Anglo format (dot as decimal, apostrophe as thousand)
        if "," in cleaned and "." in cleaned:
            # Both present: the last separator is likely the decimal
            last_comma = cleaned.rfind(",")
            last_dot = cleaned.rfind(".")
            if last_comma > last_dot:
                # European: 1.234,56
                cleaned = cleaned.replace(".", "").replace(",", ".")
            else:
                # Swiss/Anglo: 1,234.56
                cleaned = cleaned.replace(",", "")
        elif "," in cleaned:
            # Only comma: could be decimal separator or thousand separator
            parts = cleaned.split(",")
            if len(parts) == 2 and len(parts[1]) <= 2:
                # Likely decimal: 1234,56
                cleaned = cleaned.replace(",", ".")
            else:
                # Likely thousand separator: 1,234,567
                cleaned = cleaned.replace(",", "")

        try:
            return float(cleaned)
        except ValueError:
            return None

    def _extract_rate(self, text: str) -> Optional[float]:
        """Extract a percentage rate from text (e.g., '6.8%' -> 6.8)."""
        match = _RATE_PATTERN.search(text)
        if match:
            raw = match.group(1).replace(",", ".")
            try:
                value = float(raw)
                # Sanity: conversion rates are typically 0-100%
                if 0 < value <= 100:
                    return value
            except ValueError:
                pass
        return None

    def _extract_date(self, text: str) -> Optional[str]:
        """Extract a date from text."""
        match = _DATE_PATTERN.search(text)
        if match:
            return match.group(1)
        return None

    def _extract_text_value(self, context: str) -> Optional[str]:
        """Extract a text value following a keyword match.

        The keyword match may land in the middle of a header line (e.g.
        "CPE Caisse de Pension Energie" → match starts at "Caisse", so
        first_line is "Caisse de Pension Energie"). Previous logic returned
        the next line whenever no separator was present, which meant
        caisse_name got the phone number line. Corrected behaviour:

          • If the first line contains a separator → value is after sep.
          • Else if the first line has meaningful content (> keyword alone),
            return it.
          • Only fall back to next line if first line is empty or looks
            like a bare label.
        """
        lines = context.split("\n")
        if not lines:
            return None

        first_line = lines[0].strip()

        # Remove common separators
        for sep in [":", "–", "|"]:
            if sep in first_line:
                parts = first_line.split(sep, 1)
                if len(parts) > 1 and parts[1].strip():
                    return parts[1].strip()

        # Meaningful first line (not just a label) — return it directly.
        # A "meaningful" first line has more than 12 chars and contains at
        # least one alphabetic word beyond the keyword itself.
        if first_line and len(first_line) > 12:
            return first_line

        # Otherwise (first line too short / just a label) try the next line.
        if len(lines) > 1:
            next_line = lines[1].strip()
            if next_line and len(next_line) > 2:
                return next_line

        return first_line if len(first_line) > 3 else None

    def _tables_to_text(
        self, tables: list[list[list[str]]]
    ) -> str:
        """Convert table data to searchable text lines."""
        lines = []
        for table in tables:
            for row in table:
                if row:
                    line = " | ".join(str(cell) for cell in row if cell)
                    if line.strip():
                        lines.append(line)
        return "\n".join(lines)

    def _detect_language(self, text: str) -> str:
        """
        Detect the primary language of the certificate text.

        Simple heuristic based on keyword frequency.
        """
        text_lower = text.lower()

        # Count language-specific terms
        scores = {
            "fr": 0,
            "de": 0,
            "it": 0,
        }

        fr_terms = [
            "avoir de vieillesse", "taux de conversion", "salaire assuré",
            "caisse de pension", "prévoyance", "certificat", "rente",
            "cotisation", "rachat", "employeur", "décès",
        ]
        de_terms = [
            "altersguthaben", "umwandlungssatz", "versicherter lohn",
            "pensionskasse", "vorsorge", "ausweis", "rente",
            "beitrag", "einkauf", "arbeitgeber", "todesfall",
        ]
        it_terms = [
            "avere di vecchiaia", "aliquota di conversione", "salario assicurato",
            "cassa pensione", "previdenza", "certificato", "rendita",
            "contributo", "riscatto", "datore", "decesso",
        ]

        for term in fr_terms:
            if term in text_lower:
                scores["fr"] += 1
        for term in de_terms:
            if term in text_lower:
                scores["de"] += 1
        for term in it_terms:
            if term in text_lower:
                scores["it"] += 1

        # Default to French if no clear winner
        max_score = max(scores.values())
        if max_score == 0:
            return "fr"

        return max(scores, key=scores.get)

    def _get_language_order(self, primary: str) -> list[str]:
        """Get priority order of languages, with primary first."""
        all_langs = ["fr", "de", "it"]
        order = [primary]
        for lang in all_langs:
            if lang not in order:
                order.append(lang)
        return order

    def _count_extracted_fields(self, data: LPPCertificateData) -> int:
        """Count how many fields were successfully extracted."""
        count = 0
        for f_name in FINANCIAL_FIELDS:
            value = getattr(data, f_name, None)
            if value is not None:
                count += 1
        return count

    def _calculate_confidence(self, data: LPPCertificateData) -> float:
        """
        Calculate extraction confidence score [0.0 - 1.0].

        Based on:
        - Number of fields extracted vs total possible
        - Presence of key fields (avoir_vieillesse_total, salaire_assure)
        - Logical consistency (total = obligatoire + surobligatoire)
        """
        if data.total_fields_count == 0:
            return 0.0

        # Base confidence from field coverage
        base = data.extracted_fields_count / data.total_fields_count

        # Bonus for key fields
        bonus = 0.0
        if data.avoir_vieillesse_total is not None:
            bonus += 0.05
        if data.salaire_assure is not None:
            bonus += 0.05
        if data.rachat_maximum is not None:
            bonus += 0.05
        if data.taux_conversion_obligatoire is not None:
            bonus += 0.03
        if data.caisse_name is not None:
            bonus += 0.02

        # Consistency check: total ~= obligatoire + surobligatoire
        if (
            data.avoir_vieillesse_total is not None
            and data.avoir_vieillesse_obligatoire is not None
            and data.avoir_vieillesse_surobligatoire is not None
        ):
            expected = (
                data.avoir_vieillesse_obligatoire
                + data.avoir_vieillesse_surobligatoire
            )
            if expected > 0:
                ratio = data.avoir_vieillesse_total / expected
                if 0.95 <= ratio <= 1.05:
                    bonus += 0.05  # Consistent values

        confidence = min(base + bonus, 1.0)
        return round(confidence, 3)
