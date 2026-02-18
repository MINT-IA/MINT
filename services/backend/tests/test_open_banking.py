"""
Tests for Open Banking module (Sprint S14).

Covers:
    - FINMA gate (503 when disabled, 200 when enabled)
    - bLink connector (sandbox mock data)
    - Transaction categorizer (Swiss-specific patterns)
    - Consent manager (nLPD compliance)
    - Account aggregator (multi-bank aggregation)
    - API endpoints (full integration)
    - Compliance (no banned terms, disclaimer, read-only, gender-neutral)

Target: 41+ tests.

Run: cd services/backend && OPEN_BANKING_ENABLED=true python3 -m pytest tests/test_open_banking.py -v
"""

import os
import re
import pytest
from datetime import datetime, timedelta, timezone

from app.services.open_banking.blink_connector import BLinkConnector, BankAccount
from app.services.open_banking.transaction_categorizer import (
    TransactionCategorizer,
    CATEGORY_RULES,
)
from app.services.open_banking.consent_manager import (
    ConsentManager,
    MAX_CONSENT_DURATION_DAYS,
)
from app.services.open_banking.account_aggregator import AccountAggregator


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def connector():
    return BLinkConnector(sandbox=True)


@pytest.fixture
def categorizer():
    return TransactionCategorizer()


@pytest.fixture
def consent_manager():
    return ConsentManager()


@pytest.fixture
def aggregator(connector, consent_manager, categorizer):
    return AccountAggregator(
        connector=connector,
        consent_manager=consent_manager,
        categorizer=categorizer,
    )


@pytest.fixture(autouse=True)
def set_open_banking_env():
    """Ensure OPEN_BANKING_ENABLED is set for gated endpoint tests."""
    original = os.environ.get("OPEN_BANKING_ENABLED")
    os.environ["OPEN_BANKING_ENABLED"] = "true"
    yield
    if original is None:
        os.environ.pop("OPEN_BANKING_ENABLED", None)
    else:
        os.environ["OPEN_BANKING_ENABLED"] = original


# ===========================================================================
# TestFINMAGate — Feature gate tests (5 tests)
# ===========================================================================

class TestFINMAGate:
    """Tests for the FINMA feature gate on Open Banking endpoints."""

    GATED_ENDPOINTS = [
        ("POST", "/api/v1/open-banking/consent"),
        ("GET", "/api/v1/open-banking/consents"),
        ("GET", "/api/v1/open-banking/accounts"),
        ("GET", "/api/v1/open-banking/accounts/acc-ubs-001/transactions"),
        ("GET", "/api/v1/open-banking/accounts/acc-ubs-001/balance"),
        ("GET", "/api/v1/open-banking/summary"),
        ("POST", "/api/v1/open-banking/categorize"),
    ]

    # Valid POST bodies so Pydantic validation doesn't short-circuit before gate
    _POST_BODIES = {
        "/api/v1/open-banking/consent": {
            "bankId": "ubs", "bankName": "UBS",
            "scopes": ["accounts"],
        },
        "/api/v1/open-banking/categorize": {
            "accountId": "acc-ubs-001",
            "dateFrom": "2025-01-01", "dateTo": "2025-01-31",
        },
    }

    def test_gated_endpoints_return_503_when_disabled(self, client):
        """All gated endpoints should return 503 when OPEN_BANKING_ENABLED is not true."""
        os.environ["OPEN_BANKING_ENABLED"] = "false"

        for method, url in self.GATED_ENDPOINTS:
            if method == "GET":
                response = client.get(url)
            else:
                body = self._POST_BODIES.get(url, {})
                response = client.post(url, json=body)
            assert response.status_code == 503, (
                f"{method} {url} should return 503 when disabled, got {response.status_code}"
            )

    def test_gated_endpoints_accessible_when_enabled(self, client):
        """Gated endpoints should not return 503 when OPEN_BANKING_ENABLED=true."""
        os.environ["OPEN_BANKING_ENABLED"] = "true"

        # Test one representative endpoint — GET /accounts
        response = client.get("/api/v1/open-banking/accounts")
        assert response.status_code != 503

    def test_status_endpoint_always_accessible(self, client):
        """GET /status should work even when Open Banking is disabled."""
        os.environ["OPEN_BANKING_ENABLED"] = "false"

        response = client.get("/api/v1/open-banking/status")
        assert response.status_code == 200
        data = response.json()
        assert data["enabled"] is False
        assert "finmaStatus" in data

    def test_503_error_response_format(self, client):
        """503 error should have the correct JSON format."""
        os.environ["OPEN_BANKING_ENABLED"] = "false"

        response = client.get("/api/v1/open-banking/accounts")
        assert response.status_code == 503
        data = response.json()
        detail = data["detail"]
        assert "message" in detail
        assert "finmaStatus" in detail
        assert detail["finmaStatus"] == "consultation_pending"

    def test_503_contains_contact_info(self, client):
        """503 error should include contact information."""
        os.environ["OPEN_BANKING_ENABLED"] = "false"

        response = client.get("/api/v1/open-banking/accounts")
        assert response.status_code == 503
        data = response.json()
        detail = data["detail"]
        assert "contact" in detail
        assert "support@mint.ch" in detail["contact"]
        assert "support@mint.ch" in detail["message"]


# ===========================================================================
# TestBLinkConnector — Sandbox mock data (8 tests)
# ===========================================================================

class TestBLinkConnector:
    """Tests for the bLink connector in sandbox mode."""

    def test_sandbox_returns_mock_accounts(self, connector):
        """Sandbox mode should return mock account data."""
        accounts = connector.get_accounts("any-consent-id")
        assert len(accounts) > 0
        assert all(isinstance(a, BankAccount) for a in accounts)

    def test_three_accounts_returned(self, connector):
        """Should return exactly 3 mock accounts (UBS, PostFinance, Raiffeisen)."""
        accounts = connector.get_accounts("consent-123")
        assert len(accounts) == 3
        bank_names = {a.bank_name for a in accounts}
        assert bank_names == {"UBS", "PostFinance", "Raiffeisen"}

    def test_accounts_have_valid_iban_format(self, connector):
        """All accounts should have IBANs starting with CH."""
        accounts = connector.get_accounts("consent-123")
        for acct in accounts:
            assert acct.iban.startswith("CH"), f"IBAN should start with CH: {acct.iban}"
            # Swiss IBAN is 21 characters
            assert len(acct.iban) == 21, f"Swiss IBAN should be 21 chars: {acct.iban}"

    def test_transactions_returned_with_correct_fields(self, connector):
        """Transactions should have all required fields populated."""
        transactions = connector.get_transactions("acc-ubs-001", "2025-01-01", "2025-01-31")
        assert len(transactions) > 0
        for tx in transactions:
            assert tx.transaction_id
            assert tx.account_id == "acc-ubs-001"
            assert tx.date
            assert tx.description
            assert tx.currency == "CHF"

    def test_balance_matches_account(self, connector):
        """Balance should match the account's balance."""
        balance = connector.get_balances("acc-ubs-001")
        assert balance is not None
        assert balance.balance == 8450.00
        assert balance.currency == "CHF"

        # PostFinance
        balance_pf = connector.get_balances("acc-pf-002")
        assert balance_pf is not None
        assert balance_pf.balance == 23100.00

    def test_date_filtering_works(self, connector):
        """Date filtering should return only transactions within range."""
        # Narrow range
        transactions = connector.get_transactions("acc-ubs-001", "2025-01-01", "2025-01-05")
        for tx in transactions:
            assert "2025-01-01" <= tx.date <= "2025-01-05"

    def test_empty_transactions_for_future_dates(self, connector):
        """Future date range should return no transactions."""
        transactions = connector.get_transactions("acc-ubs-001", "2030-01-01", "2030-12-31")
        assert len(transactions) == 0

    def test_account_types_correct(self, connector):
        """Account types should be correctly assigned."""
        accounts = connector.get_accounts("consent-123")
        types = {a.bank_name: a.account_type for a in accounts}
        assert types["UBS"] == "checking"
        assert types["PostFinance"] == "savings"
        assert types["Raiffeisen"] == "3a"


# ===========================================================================
# TestTransactionCategorizer — Swiss patterns (10 tests)
# ===========================================================================

class TestTransactionCategorizer:
    """Tests for Swiss-specific transaction categorization."""

    def test_migros_categorized_as_alimentation(self, categorizer):
        """Migros should be categorized as alimentation."""
        cat, conf = categorizer.categorize_one("Migros Plainpalais", "Migros")
        assert cat == "alimentation"
        assert conf > 0.5

    def test_cff_categorized_as_transport(self, categorizer):
        """CFF (SBB) should be categorized as transport."""
        cat, _ = categorizer.categorize_one("CFF Abonnement general", "CFF")
        assert cat == "transport"

    def test_sbb_categorized_as_transport(self, categorizer):
        """SBB should be categorized as transport."""
        cat, _ = categorizer.categorize_one("SBB Halbtax", "SBB")
        assert cat == "transport"

    def test_swisscom_categorized_as_telecom(self, categorizer):
        """Swisscom should be categorized as telecom."""
        cat, _ = categorizer.categorize_one("Swisscom Mobile", "Swisscom")
        assert cat == "telecom"

    def test_css_categorized_as_assurances(self, categorizer):
        """CSS should be categorized as assurances."""
        cat, _ = categorizer.categorize_one("CSS Assurance maladie", "CSS")
        assert cat == "assurances"

    def test_helsana_categorized_as_assurances(self, categorizer):
        """Helsana should be categorized as assurances."""
        cat, _ = categorizer.categorize_one("Helsana Prime mensuelle", "Helsana")
        assert cat == "assurances"

    def test_loyer_categorized_as_logement(self, categorizer):
        """Loyer should be categorized as logement."""
        cat, _ = categorizer.categorize_one("Loyer janvier — Regie Naef")
        assert cat == "logement"

    def test_unknown_merchant_categorized_as_divers(self, categorizer):
        """Unknown merchant should be categorized as divers."""
        cat, conf = categorizer.categorize_one("XYZ Random Payment 123")
        assert cat == "divers"
        assert conf < 0.5

    def test_case_insensitive_matching(self, categorizer):
        """Matching should be case-insensitive."""
        cat1, _ = categorizer.categorize_one("MIGROS ZÜRICH")
        cat2, _ = categorizer.categorize_one("migros zurich")
        assert cat1 == "alimentation"
        assert cat2 == "alimentation"

    def test_batch_categorization(self, connector, categorizer):
        """Batch categorization should process multiple transactions."""
        transactions = connector.get_transactions("acc-ubs-001", "2025-01-01", "2025-01-31")
        categorized = categorizer.categorize_batch(transactions)
        assert len(categorized) == len(transactions)
        for t in categorized:
            assert t.category in CATEGORY_RULES
            assert 0.0 <= t.confidence <= 1.0
            assert t.match_type == "auto"

    def test_confidence_score_present(self, categorizer):
        """Every categorization should return a confidence score."""
        cat, conf = categorizer.categorize_one("Migros", "Migros")
        assert isinstance(conf, float)
        assert 0.0 <= conf <= 1.0

    def test_first_match_wins(self, categorizer):
        """When a description could match multiple categories, first match wins."""
        # "Pharmacie" matches sante, not alimentation
        cat, _ = categorizer.categorize_one("Pharmacie Sun Store")
        assert cat == "sante"


# ===========================================================================
# TestConsentManager — nLPD compliance (8 tests)
# ===========================================================================

class TestConsentManager:
    """Tests for nLPD-compliant consent management."""

    def test_create_consent_returns_valid_consent(self, consent_manager):
        """Creating a consent should return a valid consent object."""
        consent = consent_manager.create_consent(
            user_id="user-001",
            bank_id="ubs",
            bank_name="UBS",
            scopes=["accounts", "balances"],
        )
        assert consent.consent_id
        assert consent.user_id == "user-001"
        assert consent.bank_id == "ubs"
        assert consent.bank_name == "UBS"
        assert consent.scopes == ["accounts", "balances"]
        assert not consent.revoked

    def test_consent_has_90_day_expiry(self, consent_manager):
        """Consent should expire in 90 days."""
        consent = consent_manager.create_consent(
            user_id="user-001",
            bank_id="ubs",
            bank_name="UBS",
            scopes=["accounts"],
        )
        granted = datetime.fromisoformat(consent.granted_at.replace("Z", ""))
        expires = datetime.fromisoformat(consent.expires_at.replace("Z", ""))
        delta = expires - granted
        assert delta.days == MAX_CONSENT_DURATION_DAYS

    def test_revoke_consent_works(self, consent_manager):
        """Revoking a consent should mark it as revoked."""
        consent = consent_manager.create_consent(
            user_id="user-001",
            bank_id="ubs",
            bank_name="UBS",
            scopes=["accounts"],
        )
        assert consent_manager.is_consent_valid(consent.consent_id)

        result = consent_manager.revoke_consent(consent.consent_id)
        assert result is True
        assert not consent_manager.is_consent_valid(consent.consent_id)

    def test_revoked_consent_is_invalid(self, consent_manager):
        """A revoked consent should be reported as invalid."""
        consent = consent_manager.create_consent(
            user_id="user-001",
            bank_id="ubs",
            bank_name="UBS",
            scopes=["accounts"],
        )
        consent_manager.revoke_consent(consent.consent_id)
        assert not consent_manager.is_consent_valid(consent.consent_id)

    def test_expired_consent_is_invalid(self, consent_manager):
        """An expired consent should be reported as invalid."""
        consent = consent_manager.create_consent(
            user_id="user-001",
            bank_id="ubs",
            bank_name="UBS",
            scopes=["accounts"],
        )
        # Manually set expiry to the past
        consent.expires_at = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat() + "Z"
        assert not consent_manager.is_consent_valid(consent.consent_id)

    def test_list_active_consents_excludes_revoked(self, consent_manager):
        """Listing active consents should exclude revoked ones."""
        c1 = consent_manager.create_consent(
            user_id="user-001", bank_id="ubs", bank_name="UBS", scopes=["accounts"]
        )
        c2 = consent_manager.create_consent(
            user_id="user-001", bank_id="postfinance", bank_name="PostFinance", scopes=["accounts"]
        )
        consent_manager.revoke_consent(c1.consent_id)

        active = consent_manager.get_active_consents("user-001")
        ids = [c.consent_id for c in active]
        assert c1.consent_id not in ids
        assert c2.consent_id in ids

    def test_audit_log_records_operations(self, consent_manager):
        """Audit log should record create and revoke operations."""
        consent = consent_manager.create_consent(
            user_id="user-001", bank_id="ubs", bank_name="UBS", scopes=["accounts"]
        )
        consent_manager.revoke_consent(consent.consent_id)

        log = consent_manager.get_consent_audit_log("user-001")
        assert len(log) >= 2
        actions = [entry["action"] for entry in log]
        assert "created" in actions
        assert "revoked" in actions

    def test_granular_scopes_work(self, consent_manager):
        """Each scope should be individually selectable."""
        # Single scope
        c1 = consent_manager.create_consent(
            user_id="user-001", bank_id="ubs", bank_name="UBS", scopes=["accounts"]
        )
        assert c1.scopes == ["accounts"]

        # Multiple scopes
        c2 = consent_manager.create_consent(
            user_id="user-001",
            bank_id="postfinance",
            bank_name="PostFinance",
            scopes=["accounts", "balances", "transactions"],
        )
        assert set(c2.scopes) == {"accounts", "balances", "transactions"}

        # Invalid scope
        with pytest.raises(ValueError):
            consent_manager.create_consent(
                user_id="user-001",
                bank_id="raiffeisen",
                bank_name="Raiffeisen",
                scopes=["write_access"],  # Invalid
            )


# ===========================================================================
# TestAccountAggregator — Multi-bank aggregation (5 tests)
# ===========================================================================

class TestAccountAggregator:
    """Tests for multi-bank account aggregation."""

    def _setup_consents(self, consent_manager):
        """Create consents for all 3 test banks."""
        consent_manager.create_consent(
            user_id="user-mvp-001",
            bank_id="ubs",
            bank_name="UBS",
            scopes=["accounts", "balances", "transactions"],
        )
        consent_manager.create_consent(
            user_id="user-mvp-001",
            bank_id="postfinance",
            bank_name="PostFinance",
            scopes=["accounts", "balances", "transactions"],
        )
        consent_manager.create_consent(
            user_id="user-mvp-001",
            bank_id="raiffeisen",
            bank_name="Raiffeisen",
            scopes=["accounts", "balances", "transactions"],
        )

    def test_aggregated_view_sums_balances(self, aggregator, consent_manager):
        """Aggregated view should sum all account balances."""
        self._setup_consents(consent_manager)

        view = aggregator.get_aggregated_view("user-mvp-001")
        expected_total = 8450.00 + 23100.00 + 45000.00
        assert view.total_balance == expected_total
        assert len(view.accounts) == 3

    def test_monthly_summary_calculates_income_expenses(self, aggregator, consent_manager):
        """Monthly summary should separate income from expenses."""
        self._setup_consents(consent_manager)

        summary = aggregator.get_monthly_summary("user-mvp-001", 1, 2025)
        assert summary.total_income > 0
        assert summary.total_expenses > 0
        assert summary.month == 1
        assert summary.year == 2025

    def test_category_breakdown_percentages_sum_to_100(self, aggregator, consent_manager):
        """Category percentages should sum to approximately 100%."""
        self._setup_consents(consent_manager)

        summary = aggregator.get_monthly_summary("user-mvp-001", 1, 2025)
        if summary.categories:
            total_pct = sum(c.percentage for c in summary.categories)
            assert 99.0 <= total_pct <= 101.0, (
                f"Category percentages sum to {total_pct}, expected ~100"
            )

    def test_savings_rate_calculation(self, aggregator, consent_manager):
        """Savings rate should be (income - expenses) / income * 100."""
        self._setup_consents(consent_manager)

        summary = aggregator.get_monthly_summary("user-mvp-001", 1, 2025)
        if summary.total_income > 0:
            expected_rate = round(
                ((summary.total_income - summary.total_expenses) / summary.total_income) * 100,
                1,
            )
            assert summary.savings_rate == expected_rate

    def test_empty_accounts_returns_zero_totals(self, aggregator):
        """No consents should return zero totals."""
        view = aggregator.get_aggregated_view("nonexistent-user")
        assert view.total_balance == 0.0
        assert len(view.accounts) == 0


# ===========================================================================
# TestOpenBankingEndpoints — API integration (5 tests)
# ===========================================================================

class TestOpenBankingEndpoints:
    """Tests for the FastAPI endpoints."""

    def test_status_returns_200(self, client):
        """GET /status should return 200 with correct structure."""
        response = client.get("/api/v1/open-banking/status")
        assert response.status_code == 200
        data = response.json()
        assert "enabled" in data
        assert "message" in data
        assert "finmaStatus" in data
        assert "disclaimer" in data

    def test_consent_lifecycle(self, client):
        """Create, list, and revoke consent via API."""
        # Create
        response = client.post(
            "/api/v1/open-banking/consent",
            json={
                "bankId": "ubs",
                "bankName": "UBS",
                "scopes": ["accounts", "balances"],
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["bankId"] == "ubs"
        assert data["status"] == "active"
        consent_id = data["consentId"]

        # List
        response = client.get("/api/v1/open-banking/consents")
        assert response.status_code == 200
        consents = response.json()
        assert any(c["consentId"] == consent_id for c in consents)

        # Revoke
        response = client.delete(f"/api/v1/open-banking/consent/{consent_id}")
        assert response.status_code == 200
        assert response.json()["ok"] is True

    def test_transactions_endpoint(self, client):
        """GET /accounts/{id}/transactions should return categorized transactions."""
        response = client.get(
            "/api/v1/open-banking/accounts/acc-ubs-001/transactions",
            params={"date_from": "2025-01-01", "date_to": "2025-01-31"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) > 0
        first = data[0]
        assert "id" in first
        assert "category" in first
        assert "isDebit" in first
        assert "confidence" in first

    def test_balance_endpoint(self, client):
        """GET /accounts/{id}/balance should return balance."""
        response = client.get("/api/v1/open-banking/accounts/acc-ubs-001/balance")
        assert response.status_code == 200
        data = response.json()
        assert data["balance"] == 8450.00
        assert data["currency"] == "CHF"
        assert "disclaimer" in data
        assert "finmaStatus" in data

    def test_categorize_endpoint(self, client):
        """POST /categorize should categorize transactions."""
        response = client.post(
            "/api/v1/open-banking/categorize",
            json={
                "accountId": "acc-ubs-001",
                "dateFrom": "2025-01-01",
                "dateTo": "2025-01-31",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "transactions" in data
        assert "categoriesUsed" in data
        assert len(data["transactions"]) > 0
        assert "disclaimer" in data


# ===========================================================================
# TestOpenBankingCompliance — Compliance checks (5 tests)
# ===========================================================================

class TestOpenBankingCompliance:
    """Tests for compliance rules (banned terms, disclaimer, read-only, nLPD)."""

    # Banned terms: "garanti", "assure" (as guarantee), "certain"
    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
    ]

    def _collect_all_text(self, data) -> str:
        """Recursively collect all text from a response."""
        texts = []
        if isinstance(data, dict):
            for value in data.values():
                texts.append(self._collect_all_text(value))
        elif isinstance(data, list):
            for item in data:
                texts.append(self._collect_all_text(item))
        elif isinstance(data, str):
            texts.append(data)
        return " ".join(texts)

    def test_no_banned_terms_in_responses(self, client):
        """No response should contain banned terms (garanti, certain, etc.)."""
        endpoints = [
            ("GET", "/api/v1/open-banking/status"),
            ("GET", "/api/v1/open-banking/accounts/acc-ubs-001/balance"),
            ("GET", "/api/v1/open-banking/accounts/acc-ubs-001/transactions"),
        ]

        for method, url in endpoints:
            response = client.get(url)
            data = response.json()
            all_text = self._collect_all_text(data).lower()

            for pattern in self.BANNED_PATTERNS:
                matches = re.findall(pattern, all_text, re.IGNORECASE)
                assert len(matches) == 0, (
                    f"Banned pattern '{pattern}' found in {url}: {matches}"
                )

    def test_disclaimer_present_in_responses(self, client):
        """Disclaimer should be present in all data responses."""
        response = client.get("/api/v1/open-banking/status")
        data = response.json()
        assert "disclaimer" in data
        assert len(data["disclaimer"]) > 50
        assert "educatif" in data["disclaimer"].lower() or "indicatif" in data["disclaimer"].lower()

        response = client.get("/api/v1/open-banking/accounts/acc-ubs-001/balance")
        data = response.json()
        assert "disclaimer" in data
        assert len(data["disclaimer"]) > 50

    def test_all_responses_include_finma_status(self, client):
        """All relevant responses should include finmaStatus field."""
        response = client.get("/api/v1/open-banking/status")
        assert "finmaStatus" in response.json()

        response = client.get("/api/v1/open-banking/accounts/acc-ubs-001/balance")
        assert "finmaStatus" in response.json()

    def test_read_only_no_write_endpoints(self, client):
        """There should be no write/transfer/payment endpoints."""
        # These should NOT exist (404 or 405)
        dangerous_paths = [
            "/api/v1/open-banking/transfer",
            "/api/v1/open-banking/payment",
            "/api/v1/open-banking/write",
            "/api/v1/open-banking/accounts/acc-ubs-001/transfer",
        ]
        for path in dangerous_paths:
            response = client.post(path, json={})
            # Should be 404 (not found) or 405 (method not allowed)
            assert response.status_code in (404, 405, 422), (
                f"Dangerous endpoint {path} returned {response.status_code}"
            )

    def test_nlpd_consent_required_before_data_access(self, consent_manager, connector):
        """Data access should require valid consent (nLPD compliance)."""
        # No consent created — aggregator should return empty
        aggregator = AccountAggregator(
            connector=connector,
            consent_manager=consent_manager,
        )
        view = aggregator.get_aggregated_view("user-no-consent")
        assert view.total_balance == 0.0
        assert len(view.accounts) == 0
