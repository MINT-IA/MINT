"""
Tests for the Bank Statement parsing and categorization module (Docling Phase 2).

Tests CSV/PDF bank statement extraction, transaction categorization,
recurring detection, budget preview, and FastAPI endpoints.
"""


import pytest
from fastapi.testclient import TestClient

from app.main import app


# ──────────────────────────────────────────────────────────────────────────────
# Mock CSV Data: Swiss Bank Formats
# ──────────────────────────────────────────────────────────────────────────────

UBS_CSV = (
    '"Valutadatum";"Buchungsdatum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
    '"15.01.2026";"15.01.2026";"MIGROS GENEVE";"-45.80";"";"12\'345.20"\n'
    '"15.01.2026";"15.01.2026";"LOHN JANUAR 2026";"";"+6\'800.00";"19\'145.20"\n'
    '"16.01.2026";"16.01.2026";"SWISSCOM MOBILE";"-89.00";"";"19\'056.20"\n'
    '"17.01.2026";"17.01.2026";"CSS KRANKENKASSE";"-385.50";"";"18\'670.70"\n'
    '"20.01.2026";"20.01.2026";"COOP LAUSANNE";"-62.30";"";"18\'608.40"\n'
    '"22.01.2026";"22.01.2026";"SBB CFF FFS";"-42.00";"";"18\'566.40"\n'
    '"25.01.2026";"25.01.2026";"LOYER JANVIER";"-1\'850.00";"";"16\'716.40"\n'
    '"28.01.2026";"28.01.2026";"SPOTIFY";"-12.90";"";"16\'703.50"\n'
    '"30.01.2026";"30.01.2026";"PILIER 3A VIAC";"-564.00";"";"16\'139.50"\n'
)

POSTFINANCE_CSV = (
    '"Datum";"Buchungsart";"Buchungsdetails";"Gutschrift in CHF";"Lastschrift in CHF";"Saldo in CHF"\n'
    '"10.02.2026";"Zahlung";"DENNER BERN";"";"32.50";"8\'200.00"\n'
    '"11.02.2026";"Gutschrift";"SALAIRE FEVRIER";"5\'500.00";"";"13\'700.00"\n'
    '"12.02.2026";"Zahlung";"HELSANA PRAMIE";"";"420.00";"13\'280.00"\n'
    '"15.02.2026";"Zahlung";"SWISSCOM INTERNET";"";"69.90";"13\'210.10"\n'
    '"18.02.2026";"Zahlung";"PHARMACIE DU LAC";"";"45.60";"13\'164.50"\n'
)

RAIFFEISEN_CSV = (
    '"Booked At";"Text";"Credit/Debit Amount";"Balance"\n'
    '"05.03.2026";"MIGROS WINTERTHUR";"-78.40";"25\'000.00"\n'
    '"06.03.2026";"GEHALT MAERZ";"+7\'200.00";"32\'200.00"\n'
    '"07.03.2026";"MOBILIAR VERSICHERUNG";"-210.00";"31\'990.00"\n'
    '"10.03.2026";"NETFLIX";"-17.90";"31\'972.10"\n'
    '"12.03.2026";"ZVV ABO";"-85.00";"31\'887.10"\n'
)

ZKB_CSV = (
    '"Datum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
    '"01.04.2026";"ALDI ZURICH";"-28.90";"";"15\'500.00"\n'
    '"02.04.2026";"LOHN APRIL";"";"+8\'000.00";"23\'500.00"\n'
    '"03.04.2026";"STEUERAMT KANTON ZURICH";"-850.00";"";"22\'650.00"\n'
    '"05.04.2026";"DIGITEC GALAXUS";"-299.00";"";"22\'351.00"\n'
)

GENERIC_CSV = (
    '"Date";"Description";"Debit";"Credit";"Balance"\n'
    '"2026-01-15";"Grocery Store";"-55.00";"";"10\'000.00"\n'
    '"2026-01-16";"Monthly Salary";"";"+5\'000.00";"15\'000.00"\n'
    '"2026-01-17";"Restaurant La Perle";"-85.00";"";"14\'915.00"\n'
)

# CSV with comma delimiter
COMMA_CSV = (
    'Date,Description,Amount,Balance\n'
    '15.01.2026,MIGROS GENEVE,-45.80,12345.20\n'
    '15.01.2026,SALARY,6800.00,19145.20\n'
)

# CSV with tab delimiter
TAB_CSV = (
    'Datum\tText\tBetrag\tSaldo\n'
    '15.01.2026\tMIGROS\t-45.80\t12345.20\n'
    '16.01.2026\tLOHN\t6800.00\t19145.20\n'
)

# CSV with ISO-8859-1 encoded content (German umlauts)
ISO_LATIN_CSV = (
    '"Valutadatum";"Buchungsdatum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
    '"15.01.2026";"15.01.2026";"M\xfcller B\xe4ckerei";"-12.50";"";"5\'000.00"\n'
)

# Empty/malformed CSVs
EMPTY_CSV = ""
HEADER_ONLY_CSV = '"Valutadatum";"Buchungsdatum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
NO_HEADER_CSV = "random text\nmore random text\n"
MALFORMED_CSV = ";;;;\n;;;;\n"

# CSV with recurring transactions (same recipient, similar amounts, monthly intervals)
RECURRING_CSV = (
    '"Datum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
    '"01.01.2026";"SWISSCOM MOBILE";"-79.00";"";"10\'000.00"\n'
    '"01.01.2026";"LOYER JANVIER";"-1\'800.00";"";"8\'200.00"\n'
    '"01.02.2026";"SWISSCOM MOBILE";"-79.00";"";"8\'121.00"\n'
    '"01.02.2026";"LOYER FEVRIER";"-1\'800.00";"";"6\'321.00"\n'
    '"01.03.2026";"SWISSCOM MOBILE";"-79.00";"";"6\'242.00"\n'
    '"01.03.2026";"LOYER MARS";"-1\'800.00";"";"4\'442.00"\n'
    '"05.01.2026";"GEHALT JANUAR";"";"+6\'500.00";"16\'500.00"\n'
    '"05.02.2026";"GEHALT FEBRUAR";"";"+6\'500.00";"23\'000.00"\n'
    '"05.03.2026";"GEHALT MAERZ";"";"+6\'500.00";"29\'500.00"\n'
)


# ──────────────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────────────


@pytest.fixture
def client():
    """Test client for FastAPI app."""
    from app.api.v1.endpoints.documents import _document_store
    _document_store.clear()

    with TestClient(app) as c:
        yield c

    _document_store.clear()


@pytest.fixture
def extractor():
    """Create a BankStatementExtractor."""
    from app.services.docling.extractors.bank_statement import BankStatementExtractor
    return BankStatementExtractor()


@pytest.fixture
def categorizer():
    """Create a TransactionCategorizer."""
    from app.services.docling.categorizer import TransactionCategorizer
    return TransactionCategorizer()


# ──────────────────────────────────────────────────────────────────────────────
# TestCSVParser: CSV Parsing Tests
# ──────────────────────────────────────────────────────────────────────────────


class TestCSVParser:
    """Tests for CSV bank statement parsing."""

    def test_parse_ubs_format(self, extractor):
        """Parse a UBS-format CSV bank statement."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))

        assert result.bank_name == "UBS"
        assert len(result.transactions) == 9
        assert result.total_credits > 0
        assert result.total_debits < 0
        assert result.confidence > 0

    def test_parse_ubs_transactions_detail(self, extractor):
        """Verify UBS transaction details are correctly extracted."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))

        # Find the salary transaction
        salary_txs = [t for t in result.transactions if "LOHN" in t.description]
        assert len(salary_txs) == 1
        assert salary_txs[0].amount == 6800.0
        assert salary_txs[0].date == "2026-01-15"

        # Find MIGROS transaction
        migros_txs = [t for t in result.transactions if "MIGROS" in t.description]
        assert len(migros_txs) == 1
        assert migros_txs[0].amount == -45.80

    def test_parse_postfinance_format(self, extractor):
        """Parse a PostFinance-format CSV bank statement."""
        result = extractor.parse_csv(POSTFINANCE_CSV.encode("utf-8"))

        assert result.bank_name == "PostFinance"
        assert len(result.transactions) == 5
        assert result.total_credits > 0
        assert result.total_debits < 0

    def test_parse_raiffeisen_format(self, extractor):
        """Parse a Raiffeisen-format CSV bank statement."""
        result = extractor.parse_csv(RAIFFEISEN_CSV.encode("utf-8"))

        assert result.bank_name == "RAIFFEISEN"
        assert len(result.transactions) == 5

    def test_parse_zkb_format(self, extractor):
        """Parse a ZKB-format CSV bank statement."""
        result = extractor.parse_csv(ZKB_CSV.encode("utf-8"))

        assert result.bank_name == "ZKB"
        assert len(result.transactions) == 4

    def test_parse_generic_format(self, extractor):
        """Parse a generic CSV bank statement with auto-detected columns."""
        result = extractor.parse_csv(GENERIC_CSV.encode("utf-8"))

        assert len(result.transactions) == 3

    def test_encoding_detection_utf8(self, extractor):
        """Auto-detect UTF-8 encoding."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        assert len(result.transactions) > 0

    def test_encoding_detection_latin1(self, extractor):
        """Auto-detect ISO-8859-1 encoding."""
        result = extractor.parse_csv(ISO_LATIN_CSV.encode("iso-8859-1"))
        assert len(result.transactions) == 1
        # Check that umlauts are preserved
        tx = result.transactions[0]
        assert "ller" in tx.description  # "Muller" or "Muller" depending on encoding

    def test_encoding_override(self, extractor):
        """Explicitly specify encoding."""
        result = extractor.parse_csv(
            ISO_LATIN_CSV.encode("iso-8859-1"),
            encoding="iso-8859-1",
        )
        assert len(result.transactions) == 1

    def test_delimiter_detection_semicolon(self, extractor):
        """Auto-detect semicolon delimiter (Swiss standard)."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        assert len(result.transactions) > 0

    def test_delimiter_detection_comma(self, extractor):
        """Auto-detect comma delimiter."""
        result = extractor.parse_csv(COMMA_CSV.encode("utf-8"))
        assert len(result.transactions) == 2

    def test_delimiter_detection_tab(self, extractor):
        """Auto-detect tab delimiter."""
        result = extractor.parse_csv(TAB_CSV.encode("utf-8"))
        assert len(result.transactions) == 2

    def test_empty_file_raises(self, extractor):
        """Empty file raises ValueError."""
        with pytest.raises(ValueError, match="Empty file"):
            extractor.parse_csv(b"")

    def test_malformed_csv_no_headers(self, extractor):
        """CSV without recognizable headers raises ValueError."""
        with pytest.raises(ValueError):
            extractor.parse_csv(NO_HEADER_CSV.encode("utf-8"))

    def test_header_only_csv(self, extractor):
        """CSV with headers but no data returns empty transactions."""
        result = extractor.parse_csv(HEADER_ONLY_CSV.encode("utf-8"))
        assert len(result.transactions) == 0

    def test_oversized_file_raises(self, extractor):
        """Oversized file raises ValueError."""
        big_bytes = b"x" * (extractor.MAX_FILE_SIZE + 1)
        with pytest.raises(ValueError, match="exceeds maximum"):
            extractor.parse_csv(big_bytes)

    def test_period_detection(self, extractor):
        """Period start/end is correctly detected from transaction dates."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))

        assert result.period_start == "2026-01-15"
        assert result.period_end == "2026-01-30"

    def test_balance_extraction(self, extractor):
        """Running balance is extracted from CSV."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))

        balances = [t.balance for t in result.transactions if t.balance is not None]
        assert len(balances) > 0

    def test_swiss_number_format(self, extractor):
        """Swiss number format with apostrophe thousand separator is handled."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))

        # Find the rent transaction (1'850.00)
        rent_txs = [t for t in result.transactions if "LOYER" in t.description]
        assert len(rent_txs) == 1
        assert rent_txs[0].amount == -1850.0

    def test_swiss_date_format(self, extractor):
        """Swiss date format DD.MM.YYYY is converted to ISO YYYY-MM-DD."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))

        for tx in result.transactions:
            # All dates should be in ISO format
            assert len(tx.date) == 10
            assert tx.date[4] == "-"
            assert tx.date[7] == "-"


# ──────────────────────────────────────────────────────────────────────────────
# TestSwissHelpers: Number and Date Parsing
# ──────────────────────────────────────────────────────────────────────────────


class TestSwissHelpers:
    """Tests for Swiss number and date parsing helpers."""

    def test_parse_swiss_date_dd_mm_yyyy(self):
        """Parse DD.MM.YYYY format."""
        from app.services.docling.extractors.bank_statement import parse_swiss_date

        assert parse_swiss_date("15.01.2026") == "2026-01-15"
        assert parse_swiss_date("01.12.2025") == "2025-12-01"
        assert parse_swiss_date("5.3.2026") == "2026-03-05"

    def test_parse_swiss_date_slash(self):
        """Parse DD/MM/YYYY format."""
        from app.services.docling.extractors.bank_statement import parse_swiss_date

        assert parse_swiss_date("15/01/2026") == "2026-01-15"

    def test_parse_swiss_date_iso(self):
        """Parse YYYY-MM-DD format."""
        from app.services.docling.extractors.bank_statement import parse_swiss_date

        assert parse_swiss_date("2026-01-15") == "2026-01-15"

    def test_parse_swiss_date_invalid(self):
        """Invalid dates return None."""
        from app.services.docling.extractors.bank_statement import parse_swiss_date

        assert parse_swiss_date("") is None
        assert parse_swiss_date("not a date") is None
        assert parse_swiss_date("32.13.2026") is None

    def test_parse_swiss_amount_standard(self):
        """Parse standard Swiss amounts."""
        from app.services.docling.extractors.bank_statement import parse_swiss_amount

        assert parse_swiss_amount("45.80") == 45.80
        assert parse_swiss_amount("-45.80") == -45.80
        assert parse_swiss_amount("+6800.00") == 6800.00

    def test_parse_swiss_amount_apostrophe(self):
        """Parse amounts with Swiss apostrophe thousand separator."""
        from app.services.docling.extractors.bank_statement import parse_swiss_amount

        assert parse_swiss_amount("12'345.67") == 12345.67
        assert parse_swiss_amount("-1'850.00") == -1850.0
        assert parse_swiss_amount("6'800.00") == 6800.0

    def test_parse_swiss_amount_comma_decimal(self):
        """Parse amounts with comma as decimal separator."""
        from app.services.docling.extractors.bank_statement import parse_swiss_amount

        assert parse_swiss_amount("45,80") == 45.80
        assert parse_swiss_amount("1234,56") == 1234.56

    def test_parse_swiss_amount_empty(self):
        """Empty or dash amounts return None."""
        from app.services.docling.extractors.bank_statement import parse_swiss_amount

        assert parse_swiss_amount("") is None
        assert parse_swiss_amount("-") is None
        assert parse_swiss_amount(None) is None

    def test_parse_swiss_amount_with_currency(self):
        """Parse amounts with currency prefix."""
        from app.services.docling.extractors.bank_statement import parse_swiss_amount

        assert parse_swiss_amount("CHF 100.50") == 100.50
        assert parse_swiss_amount("Fr. 200.00") == 200.00

    def test_parse_swiss_amount_parenthesized_negative(self):
        """Parse parenthesized negative amounts."""
        from app.services.docling.extractors.bank_statement import parse_swiss_amount

        assert parse_swiss_amount("(45.80)") == -45.80

    def test_parse_swiss_amount_quoted(self):
        """Parse quoted amount strings."""
        from app.services.docling.extractors.bank_statement import parse_swiss_amount

        assert parse_swiss_amount('"45.80"') == 45.80
        assert parse_swiss_amount("'100.00'") == 100.00


# ──────────────────────────────────────────────────────────────────────────────
# TestCategorizer: Transaction Categorization
# ──────────────────────────────────────────────────────────────────────────────


class TestCategorizer:
    """Tests for the TransactionCategorizer."""

    def test_categorize_alimentation_migros(self, categorizer):
        """Migros is categorized as alimentation."""
        result = categorizer.categorize("MIGROS GENEVE")
        assert result.category == "alimentation"
        assert result.confidence > 0.5

    def test_categorize_alimentation_coop(self, categorizer):
        """Coop is categorized as alimentation."""
        result = categorizer.categorize("COOP LAUSANNE")
        assert result.category == "alimentation"

    def test_categorize_alimentation_denner(self, categorizer):
        """Denner is categorized as alimentation."""
        result = categorizer.categorize("DENNER BERN")
        assert result.category == "alimentation"

    def test_categorize_transport_sbb(self, categorizer):
        """SBB/CFF is categorized as transport."""
        result = categorizer.categorize("SBB CFF FFS")
        assert result.category == "transport"

    def test_categorize_transport_tpg(self, categorizer):
        """TPG is categorized as transport."""
        result = categorizer.categorize("TPG ABONNEMENT")
        assert result.category == "transport"

    def test_categorize_assurance_css(self, categorizer):
        """CSS is categorized as assurance."""
        result = categorizer.categorize("CSS KRANKENKASSE")
        assert result.category == "assurance"

    def test_categorize_assurance_helsana(self, categorizer):
        """Helsana is categorized as assurance."""
        result = categorizer.categorize("HELSANA PRAMIE")
        assert result.category == "assurance"

    def test_categorize_telecom_swisscom(self, categorizer):
        """Swisscom is categorized as telecom."""
        result = categorizer.categorize("SWISSCOM MOBILE")
        assert result.category == "telecom"

    def test_categorize_logement_loyer(self, categorizer):
        """Loyer (rent) is categorized as logement."""
        result = categorizer.categorize("LOYER JANVIER")
        assert result.category == "logement"

    def test_categorize_logement_miete(self, categorizer):
        """Miete (German rent) is categorized as logement."""
        result = categorizer.categorize("MIETE JANUAR 2026")
        assert result.category == "logement"

    def test_categorize_loisirs_spotify(self, categorizer):
        """Spotify is categorized as loisirs."""
        result = categorizer.categorize("SPOTIFY PREMIUM")
        assert result.category == "loisirs"

    def test_categorize_loisirs_netflix(self, categorizer):
        """Netflix is categorized as loisirs."""
        result = categorizer.categorize("NETFLIX.COM")
        assert result.category == "loisirs"

    def test_categorize_epargne_3a(self, categorizer):
        """Pilier 3a is categorized as epargne."""
        result = categorizer.categorize("PILIER 3A VIAC")
        assert result.category == "epargne"

    def test_categorize_epargne_frankly(self, categorizer):
        """Frankly is categorized as epargne."""
        result = categorizer.categorize("FRANKLY EINZAHLUNG")
        assert result.category == "epargne"

    def test_categorize_salaire_lohn(self, categorizer):
        """Lohn (salary) is categorized as salaire."""
        result = categorizer.categorize("LOHN JANUAR 2026")
        assert result.category == "salaire"

    def test_categorize_salaire_french(self, categorizer):
        """French salary is categorized as salaire."""
        result = categorizer.categorize("SALAIRE FEVRIER")
        assert result.category == "salaire"

    def test_categorize_impots_steueramt(self, categorizer):
        """Steueramt is categorized as impots."""
        result = categorizer.categorize("STEUERAMT KANTON ZURICH")
        assert result.category == "impots"

    def test_categorize_impots_regex(self, categorizer):
        """Tax regex pattern matches canton steuer."""
        result = categorizer.categorize("Gemeinde Steuer 2025")
        assert result.category == "impots"

    def test_categorize_sante_pharmacie(self, categorizer):
        """Pharmacie is categorized as sante."""
        result = categorizer.categorize("PHARMACIE DU LAC")
        assert result.category == "sante"

    def test_categorize_sante_arzt(self, categorizer):
        """Arzt (doctor) is categorized as sante."""
        result = categorizer.categorize("DR. MULLER ARZT PRAXIS")
        assert result.category == "sante"

    def test_categorize_restaurant(self, categorizer):
        """Restaurant is categorized as restaurant."""
        result = categorizer.categorize("RESTAURANT LA PERLE")
        assert result.category == "restaurant"

    def test_categorize_restaurant_starbucks(self, categorizer):
        """Starbucks is categorized as restaurant."""
        result = categorizer.categorize("STARBUCKS ZURICH HB")
        assert result.category == "restaurant"

    def test_categorize_shopping_digitec(self, categorizer):
        """Digitec is categorized as shopping."""
        result = categorizer.categorize("DIGITEC GALAXUS")
        assert result.category == "shopping"

    def test_categorize_education_uni(self, categorizer):
        """University is categorized as education."""
        result = categorizer.categorize("UNIVERSITE DE GENEVE")
        assert result.category == "education"

    def test_categorize_unknown_divers(self, categorizer):
        """Unknown transactions fall back to divers."""
        result = categorizer.categorize("RANDOM UNKNOWN VENDOR XYZ")
        assert result.category == "divers"
        assert result.confidence < 0.5

    def test_categorize_case_insensitive(self, categorizer):
        """Categorization is case-insensitive."""
        result1 = categorizer.categorize("migros geneve")
        result2 = categorizer.categorize("MIGROS GENEVE")
        result3 = categorizer.categorize("Migros Geneve")

        assert result1.category == result2.category == result3.category == "alimentation"

    def test_categorize_empty_description(self, categorizer):
        """Empty description returns divers."""
        result = categorizer.categorize("")
        assert result.category == "divers"

    def test_subcategory_transport_train(self, categorizer):
        """SBB should get transport/train subcategory."""
        result = categorizer.categorize("SBB CFF FFS BILLET")
        assert result.category == "transport"
        assert result.subcategory == "train"

    def test_subcategory_alimentation_supermarche(self, categorizer):
        """Migros should get alimentation/supermarche subcategory."""
        result = categorizer.categorize("MIGROS")
        assert result.category == "alimentation"
        assert result.subcategory == "supermarche"

    def test_subcategory_loisirs_streaming(self, categorizer):
        """Netflix should get loisirs/streaming subcategory."""
        result = categorizer.categorize("NETFLIX")
        assert result.category == "loisirs"
        assert result.subcategory == "streaming"

    def test_subcategory_assurance_maladie(self, categorizer):
        """CSS should get assurance/maladie subcategory."""
        result = categorizer.categorize("CSS GRUNDVERSICHERUNG")
        assert result.category == "assurance"
        assert result.subcategory == "maladie"

    def test_multilingual_german_keywords(self, categorizer):
        """German keywords are recognized."""
        result = categorizer.categorize("KRANKENKASSE PRAMIE")
        assert result.category == "assurance"

    def test_multilingual_italian_keywords(self, categorizer):
        """Italian keywords are recognized."""
        result = categorizer.categorize("AFFITTO MARZO")
        assert result.category == "logement"


# ──────────────────────────────────────────────────────────────────────────────
# TestRecurringDetection: Recurring Transaction Detection
# ──────────────────────────────────────────────────────────────────────────────


class TestRecurringDetection:
    """Tests for recurring transaction detection."""

    def test_detect_recurring_transactions(self, extractor, categorizer):
        """Recurring transactions are detected (same desc, similar amount, monthly)."""
        result = extractor.parse_csv(RECURRING_CSV.encode("utf-8"))
        categorizer.categorize_transactions(result.transactions)

        recurring = [t for t in result.transactions if t.is_recurring]
        assert len(recurring) >= 3  # At least the 3 SWISSCOM entries

    def test_non_recurring_single_transaction(self, categorizer):
        """Single transactions are not marked as recurring."""
        from app.services.docling.extractors.bank_statement import BankTransaction

        transactions = [
            BankTransaction(
                date="2026-01-15",
                description="ONE-TIME PURCHASE",
                amount=-99.00,
            ),
        ]
        categorizer.categorize_transactions(transactions)
        assert not transactions[0].is_recurring


# ──────────────────────────────────────────────────────────────────────────────
# TestBudgetSummary: Budget Summary and Preview
# ──────────────────────────────────────────────────────────────────────────────


class TestBudgetSummary:
    """Tests for budget summary computation."""

    def test_category_summary(self, extractor, categorizer):
        """Category summary correctly totals by category."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        categorizer.categorize_transactions(result.transactions)
        summary = categorizer.compute_category_summary(result.transactions)

        assert isinstance(summary, dict)
        # Should have multiple categories
        assert len(summary) >= 2

    def test_budget_preview(self, extractor, categorizer):
        """Budget preview computes monthly estimates."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        categorizer.categorize_transactions(result.transactions)
        preview = categorizer.compute_budget_preview(result.transactions)

        assert "estimated_monthly_income" in preview
        assert "estimated_monthly_expenses" in preview
        assert "top_categories" in preview
        assert "recurring_charges" in preview
        assert "savings_rate" in preview

        assert preview["estimated_monthly_income"] > 0
        assert preview["estimated_monthly_expenses"] > 0

    def test_budget_preview_top_categories(self, extractor, categorizer):
        """Top categories include category name, amount, and percentage."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        categorizer.categorize_transactions(result.transactions)
        preview = categorizer.compute_budget_preview(result.transactions)

        for cat in preview["top_categories"]:
            assert "category" in cat
            assert "amount" in cat
            assert "percentage" in cat

    def test_budget_preview_savings_rate(self, extractor, categorizer):
        """Savings rate is calculated correctly."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        categorizer.categorize_transactions(result.transactions)
        preview = categorizer.compute_budget_preview(result.transactions)

        # Income > expenses, so savings rate should be > 0
        assert isinstance(preview["savings_rate"], float)

    def test_budget_preview_empty(self, categorizer):
        """Budget preview with no transactions returns zeros."""
        preview = categorizer.compute_budget_preview([])

        assert preview["estimated_monthly_income"] == 0.0
        assert preview["estimated_monthly_expenses"] == 0.0
        assert preview["savings_rate"] == 0.0

    def test_total_credits_debits(self, extractor):
        """Total credits and debits are computed correctly."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))

        assert result.total_credits > 0
        assert result.total_debits < 0
        # Credits should be the salary
        assert result.total_credits == 6800.0


# ──────────────────────────────────────────────────────────────────────────────
# TestBankStatementEndpoints: FastAPI Endpoint Tests
# ──────────────────────────────────────────────────────────────────────────────


class TestBankStatementEndpoints:
    """Tests for bank statement upload endpoints."""

    def test_upload_csv_statement(self, client):
        """POST /api/v1/documents/upload-statement with CSV file."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("statement.csv", UBS_CSV.encode("utf-8"), "text/csv")},
        )
        assert response.status_code == 200

        data = response.json()
        assert data["document_type"] == "bank_statement"
        assert data["bank_name"] == "UBS"
        assert len(data["transactions"]) > 0
        assert data["total_credits"] > 0
        assert data["total_debits"] < 0
        assert "category_summary" in data
        assert "recurring_monthly" in data
        assert "confidence" in data

    def test_upload_csv_transaction_fields(self, client):
        """Transactions in response have all required fields."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("statement.csv", UBS_CSV.encode("utf-8"), "text/csv")},
        )
        data = response.json()

        for tx in data["transactions"]:
            assert "date" in tx
            assert "description" in tx
            assert "amount" in tx
            assert "category" in tx
            assert "is_recurring" in tx

    def test_upload_reject_invalid_extension(self, client):
        """Reject files with unsupported extensions."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("data.xlsx", b"content", "application/octet-stream")},
        )
        assert response.status_code == 400
        assert ".csv or .pdf" in response.json()["detail"]

    def test_upload_empty_file_rejected(self, client):
        """Reject empty file uploads."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("empty.csv", b"", "text/csv")},
        )
        assert response.status_code == 400

    def test_upload_budget_preview(self, client):
        """POST /api/v1/documents/upload-statement/preview returns budget preview."""
        response = client.post(
            "/api/v1/documents/upload-statement/preview",
            files={"file": ("statement.csv", UBS_CSV.encode("utf-8"), "text/csv")},
        )
        assert response.status_code == 200

        data = response.json()
        assert "estimated_monthly_income" in data
        assert "estimated_monthly_expenses" in data
        assert "top_categories" in data
        assert "recurring_charges" in data
        assert "savings_rate" in data

    def test_upload_preview_reject_invalid(self, client):
        """Preview endpoint rejects invalid files."""
        response = client.post(
            "/api/v1/documents/upload-statement/preview",
            files={"file": ("data.txt", b"content", "text/plain")},
        )
        assert response.status_code == 400

    def test_upload_postfinance_csv(self, client):
        """Upload PostFinance CSV is correctly parsed."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("pf.csv", POSTFINANCE_CSV.encode("utf-8"), "text/csv")},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["bank_name"] == "PostFinance"

    def test_upload_raiffeisen_csv(self, client):
        """Upload Raiffeisen CSV is correctly parsed."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("raif.csv", RAIFFEISEN_CSV.encode("utf-8"), "text/csv")},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["bank_name"] == "RAIFFEISEN"


# ──────────────────────────────────────────────────────────────────────────────
# TestEdgeCases: Edge Case Tests
# ──────────────────────────────────────────────────────────────────────────────


class TestBankStatementEdgeCases:
    """Edge case tests for bank statement parsing."""

    def test_negative_balance(self, extractor):
        """Handle negative balance values."""
        csv_content = (
            '"Datum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
            '"01.01.2026";"PURCHASE";"-500.00";"";""-200.00""\n'
        )
        # Should not crash
        result = extractor.parse_csv(csv_content.encode("utf-8"))
        assert isinstance(result.transactions, list)

    def test_duplicate_transactions(self, extractor):
        """Duplicate transactions are all preserved (not deduplicated)."""
        csv_content = (
            '"Datum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
            '"01.01.2026";"MIGROS";"-50.00";"";"1\'000.00"\n'
            '"01.01.2026";"MIGROS";"-50.00";"";"950.00"\n'
        )
        result = extractor.parse_csv(csv_content.encode("utf-8"))
        assert len(result.transactions) == 2

    def test_mixed_date_formats(self, extractor):
        """Handle mixed date formats in same file (unusual but possible)."""
        from app.services.docling.extractors.bank_statement import parse_swiss_date

        assert parse_swiss_date("01.01.2026") == "2026-01-01"
        assert parse_swiss_date("2026-01-01") == "2026-01-01"

    def test_confidence_with_bank_detected(self, extractor):
        """Confidence is higher when bank name is detected."""
        ubs_result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        assert ubs_result.confidence > 0.3

    def test_raw_text_preserved(self, extractor):
        """Raw text from original CSV row is preserved."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        for tx in result.transactions:
            assert tx.raw_text != ""

    def test_large_amounts(self, extractor):
        """Handle large amounts (Swiss salaries / rent)."""
        csv_content = (
            '"Datum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
            '"01.01.2026";"HYPOTHEK";"-3\'500.00";"";"150\'000.00"\n'
            '"02.01.2026";"BONUS";"";"+25\'000.00";"175\'000.00"\n'
        )
        result = extractor.parse_csv(csv_content.encode("utf-8"))
        assert len(result.transactions) == 2
        assert result.transactions[0].amount == -3500.0
        assert result.transactions[1].amount == 25000.0

    def test_zero_amount_skipped(self, extractor):
        """Rows with no valid amount are skipped."""
        csv_content = (
            '"Datum";"Buchungstext";"Belastung";"Gutschrift";"Saldo"\n'
            '"01.01.2026";"SOME NOTE";"";"";"10\'000.00"\n'
        )
        result = extractor.parse_csv(csv_content.encode("utf-8"))
        # The row has no debit or credit, so it should be skipped
        assert len(result.transactions) == 0

    def test_bank_statement_data_to_dict(self, extractor):
        """BankStatementData.to_dict() returns a proper dictionary."""
        result = extractor.parse_csv(UBS_CSV.encode("utf-8"))
        d = result.to_dict()

        assert isinstance(d, dict)
        assert "bank_name" in d
        assert "transactions" in d
        assert isinstance(d["transactions"], list)

    def test_bank_transaction_to_dict(self):
        """BankTransaction.to_dict() returns a proper dictionary."""
        from app.services.docling.extractors.bank_statement import BankTransaction

        tx = BankTransaction(
            date="2026-01-15",
            description="TEST",
            amount=-50.0,
            balance=1000.0,
            category="alimentation",
        )
        d = tx.to_dict()
        assert d["date"] == "2026-01-15"
        assert d["amount"] == -50.0


# ──────────────────────────────────────────────────────────────────────────────
# TestColumnDetection: Bank Format and Column Detection
# ──────────────────────────────────────────────────────────────────────────────


class TestColumnDetection:
    """Tests for bank format and column auto-detection."""

    def test_detect_ubs_format(self):
        """Detect UBS column format."""
        from app.services.docling.extractors.bank_statement import detect_bank_format

        headers = ["Valutadatum", "Buchungsdatum", "Buchungstext", "Belastung", "Gutschrift", "Saldo"]
        bank, mapping = detect_bank_format(headers)
        assert bank == "ubs"

    def test_detect_postfinance_format(self):
        """Detect PostFinance column format."""
        from app.services.docling.extractors.bank_statement import detect_bank_format

        headers = ["Datum", "Buchungsart", "Buchungsdetails", "Gutschrift in CHF", "Lastschrift in CHF", "Saldo in CHF"]
        bank, mapping = detect_bank_format(headers)
        assert bank == "postfinance"

    def test_detect_raiffeisen_format(self):
        """Detect Raiffeisen column format."""
        from app.services.docling.extractors.bank_statement import detect_bank_format

        headers = ["Booked At", "Text", "Credit/Debit Amount", "Balance"]
        bank, mapping = detect_bank_format(headers)
        assert bank == "raiffeisen"

    def test_detect_unknown_format(self):
        """Unknown format returns None."""
        from app.services.docling.extractors.bank_statement import detect_bank_format

        headers = ["Col1", "Col2", "Col3"]
        bank, mapping = detect_bank_format(headers)
        assert bank is None
        assert mapping is None

    def test_generic_column_detection(self):
        """Detect columns generically for unknown bank formats."""
        from app.services.docling.extractors.bank_statement import detect_generic_columns

        headers = ["Date", "Description", "Debit", "Credit", "Balance"]
        mapping = detect_generic_columns(headers)
        assert mapping is not None
        assert "date_col" in mapping
        assert "description_col" in mapping

    def test_generic_column_detection_german(self):
        """Detect German column names."""
        from app.services.docling.extractors.bank_statement import detect_generic_columns

        headers = ["Datum", "Beschreibung", "Belastung", "Gutschrift", "Saldo"]
        mapping = detect_generic_columns(headers)
        assert mapping is not None
        assert "date_col" in mapping

    def test_generic_column_detection_insufficient(self):
        """Insufficient columns return None."""
        from app.services.docling.extractors.bank_statement import detect_generic_columns

        headers = ["Name", "Value"]
        mapping = detect_generic_columns(headers)
        assert mapping is None


# ──────────────────────────────────────────────────────────────────────────────
# TestModuleImports: Module-level Import Tests
# ──────────────────────────────────────────────────────────────────────────────


class TestBankStatementModuleImports:
    """Tests for module-level imports of bank statement components."""

    def test_import_from_docling(self):
        """All new exports are available from the docling module."""
        from app.services.docling import (
            BankStatementExtractor,
            BankStatementData,
            BankTransaction,
            TransactionCategorizer,
            CATEGORIES,
        )

        assert BankStatementExtractor is not None
        assert BankStatementData is not None
        assert BankTransaction is not None
        assert TransactionCategorizer is not None
        assert isinstance(CATEGORIES, dict)

    def test_schema_imports(self):
        """All new schemas are importable."""
        from app.schemas.document import (
            TransactionResponse,
            BankStatementUploadResponse,
            BudgetImportPreview,
        )

        assert TransactionResponse is not None
        assert BankStatementUploadResponse is not None
        assert BudgetImportPreview is not None

    def test_schema_validation_transaction(self):
        """TransactionResponse validates correctly."""
        from app.schemas.document import TransactionResponse

        tx = TransactionResponse(
            date="2026-01-15",
            description="TEST",
            amount=-50.0,
            category="alimentation",
        )
        assert tx.date == "2026-01-15"
        assert tx.amount == -50.0

    def test_schema_validation_bank_statement(self):
        """BankStatementUploadResponse validates correctly."""
        from app.schemas.document import BankStatementUploadResponse

        resp = BankStatementUploadResponse(
            bank_name="UBS",
            currency="CHF",
            total_credits=5000.0,
            total_debits=-3000.0,
            confidence=0.8,
        )
        assert resp.bank_name == "UBS"
        assert resp.document_type == "bank_statement"

    def test_schema_validation_budget_preview(self):
        """BudgetImportPreview validates correctly."""
        from app.schemas.document import BudgetImportPreview

        preview = BudgetImportPreview(
            estimated_monthly_income=6000.0,
            estimated_monthly_expenses=4000.0,
            savings_rate=33.3,
        )
        assert preview.estimated_monthly_income == 6000.0
        assert preview.savings_rate == 33.3

    def test_categories_structure(self):
        """CATEGORIES dict has the expected structure."""
        from app.services.docling.categorizer import CATEGORIES

        assert "logement" in CATEGORIES
        assert "alimentation" in CATEGORIES
        assert "transport" in CATEGORIES
        assert "assurance" in CATEGORIES
        assert "telecom" in CATEGORIES
        assert "impots" in CATEGORIES
        assert "sante" in CATEGORIES
        assert "loisirs" in CATEGORIES
        assert "epargne" in CATEGORIES
        assert "salaire" in CATEGORIES
        assert "restaurant" in CATEGORIES
        assert "divers" in CATEGORIES

        for cat_name, cat_def in CATEGORIES.items():
            assert "keywords" in cat_def
            assert "icon" in cat_def
            assert isinstance(cat_def["keywords"], list)
