"""
Tests for Document Intelligence (Docling) endpoints.

Tests the 6 routes in /api/v1/documents:
  - POST /upload (PDF upload with docling extraction)
  - GET / (list all documents)
  - GET /{doc_id} (get single document)
  - DELETE /{doc_id} (delete document)
  - POST /upload-statement (bank statement CSV/PDF upload)
  - POST /upload-statement/preview (budget import preview)

Uses mocked docling dependencies so tests run without pdfplumber/docling installed.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints.documents import _detect_document_type
from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.document import DocumentModel
from app.main import app
from tests.conftest import TestingSessionLocal

# Re-use conftest's test DB infrastructure
from tests.conftest import TestingSessionLocal, override_get_db


def _fake_user():
    """Return a mock user object for auth override."""
    from unittest.mock import MagicMock
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    return user


def _override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def _ensure_premium_subscription():
    """Ensure the test user has a premium subscription for vault access."""
    from datetime import timedelta
    from app.models.billing import SubscriptionModel
    db = TestingSessionLocal()
    try:
        existing = (
            db.query(SubscriptionModel)
            .filter(SubscriptionModel.user_id == "test-user-id")
            .first()
        )
        if not existing:
            sub = SubscriptionModel(
                user_id="test-user-id",
                tier="premium",
                status="active",
                source="test",
                current_period_end=datetime.utcnow() + timedelta(days=30),
            )
            db.add(sub)
            db.commit()
    finally:
        db.close()


# ──────────────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────────────


def _mock_entitlements_premium():
    """Patch recompute_entitlements to grant premium access (all features)."""
    from app.services.billing_service import ALL_FEATURES
    return patch(
        "app.api.v1.endpoints.documents.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


@pytest.fixture
def client():
    """Test client with test DB and auth override."""
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user

    # Grant document_upload consent for the test user (nLPD opt-in model)
    from app.services.reengagement.consent_manager import ConsentManager
    from app.services.reengagement.reengagement_models import ConsentType
    db = TestingSessionLocal()
    ConsentManager.update_consent("test-user-id", ConsentType.document_upload, True, db=db)
    db.close()

    with _mock_entitlements_premium(), TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_db, None)


@pytest.fixture
def populated_store():
    """Pre-populate the document table with sample documents."""
    db = TestingSessionLocal()
    now = datetime.now(timezone.utc)

    db.add(DocumentModel(
        id="doc-aaa",
        user_id="test-user-id",
        document_type="lpp_certificate",
        upload_date=now,
        confidence=0.85,
        fields_found=15,
        fields_total=18,
        extracted_fields={"avoir_vieillesse_total": 166300.0},
        warnings=[],
    ))
    db.add(DocumentModel(
        id="doc-bbb",
        user_id="test-user-id",
        document_type="salary_slip",
        upload_date=now,
        confidence=0.60,
        fields_found=5,
        fields_total=18,
        extracted_fields={"salaire_avs": 95000.0},
        warnings=["Partial extraction"],
    ))
    db.add(DocumentModel(
        id="doc-ccc",
        user_id="test-user-id",
        document_type="unknown",
        upload_date=now,
        confidence=0.0,
        fields_found=0,
        fields_total=18,
        extracted_fields={},
        warnings=["Could not identify document type"],
    ))
    db.commit()
    db.close()
    yield


# ──────────────────────────────────────────────────────────────────────────────
# Mock helpers for docling dependencies
# ──────────────────────────────────────────────────────────────────────────────


@dataclass
class MockPageContent:
    """Mock of docling PageContent dataclass."""
    page_number: int = 1
    text: str = ""
    tables: list = field(default_factory=list)


@dataclass
class MockParsedDocument:
    """Mock of docling ParsedDocument dataclass."""
    full_text: str = ""
    pages: list = field(default_factory=list)
    metadata: dict = field(default_factory=dict)


@dataclass
class MockLPPCertificateData:
    """Mock of LPPCertificateData dataclass."""
    confidence: float = 0.85
    extracted_fields_count: int = 15
    total_fields_count: int = 18
    avoir_vieillesse_total: Optional[float] = 166300.0
    salaire_avs: Optional[float] = 95000.0
    salaire_assure: Optional[float] = 68540.0

    def to_dict(self):
        return {
            "avoir_vieillesse_total": self.avoir_vieillesse_total,
            "salaire_avs": self.salaire_avs,
            "salaire_assure": self.salaire_assure,
            "confidence": self.confidence,
            "extracted_fields_count": self.extracted_fields_count,
            "total_fields_count": self.total_fields_count,
        }


@dataclass
class MockBankTransaction:
    """Mock of BankTransaction dataclass."""
    date: str = "2026-01-15"
    description: str = "MIGROS"
    amount: float = -45.80
    balance: Optional[float] = 12345.20
    category: str = "alimentation"
    subcategory: Optional[str] = "supermarche"
    is_recurring: bool = False
    raw_text: str = ""


@dataclass
class MockBankStatementData:
    """Mock of BankStatementData dataclass."""
    bank_name: Optional[str] = "UBS"
    period_start: Optional[str] = "2026-01-15"
    period_end: Optional[str] = "2026-01-30"
    currency: str = "CHF"
    transactions: list = field(default_factory=list)
    total_credits: float = 6800.0
    total_debits: float = -2487.50
    opening_balance: Optional[float] = 12345.20
    closing_balance: Optional[float] = 16139.50
    confidence: float = 0.80
    warnings: list = field(default_factory=list)


def _make_mock_parser():
    """Create a mock DocumentParser that returns structured data."""
    parser = MagicMock()

    parsed_doc = MockParsedDocument(
        full_text="Caisse de pension: Retraites Populaires\n"
                  "Certificat de prévoyance professionnelle\n"
                  "Avoir de vieillesse total: CHF 166'300.00\n"
                  "Salaire AVS: CHF 95'000.00",
        pages=[MockPageContent(page_number=1, text="sample text", tables=[])],
        metadata={"page_count": 1, "file_size_bytes": 1024, "parsed_pages": 1},
    )
    parser.parse_pdf.return_value = parsed_doc
    return parser


def _make_mock_extractor():
    """Create a mock LPPCertificateExtractor."""
    extractor = MagicMock()
    extractor.extract.return_value = MockLPPCertificateData()
    return extractor


def _make_mock_bank_extractor(transactions=None):
    """Create a mock BankStatementExtractor."""
    if transactions is None:
        transactions = [
            MockBankTransaction(
                date="2026-01-15",
                description="MIGROS GENEVE",
                amount=-45.80,
                balance=12345.20,
                category="alimentation",
                subcategory="supermarche",
                is_recurring=False,
            ),
            MockBankTransaction(
                date="2026-01-15",
                description="LOHN JANUAR",
                amount=6800.0,
                balance=19145.20,
                category="salaire",
                subcategory=None,
                is_recurring=True,
            ),
        ]

    mock_statement = MockBankStatementData(transactions=transactions)

    extractor = MagicMock()
    extractor.parse_csv.return_value = mock_statement
    extractor.parse_pdf.return_value = mock_statement
    return extractor


def _make_mock_categorizer():
    """Create a mock TransactionCategorizer."""
    categorizer = MagicMock()
    categorizer.compute_category_summary.return_value = {
        "alimentation": -45.80,
        "salaire": 6800.0,
    }
    categorizer.compute_budget_preview.return_value = {
        "estimated_monthly_income": 6800.0,
        "estimated_monthly_expenses": 2487.50,
        "top_categories": [
            {"category": "logement", "amount": 1850.0, "percentage": 74.3},
        ],
        "recurring_charges": [
            {"description": "SWISSCOM", "amount": -79.0, "frequency": "monthly"},
        ],
        "savings_rate": 63.4,
    }
    return categorizer


# Patch paths for docling imports inside documents.py
PARSER_PATCH = "app.services.docling.parser.DocumentParser"
LPP_EXTRACTOR_PATCH = "app.services.docling.extractors.lpp_certificate.LPPCertificateExtractor"
BANK_EXTRACTOR_PATCH = "app.services.docling.extractors.bank_statement.BankStatementExtractor"
CATEGORIZER_PATCH = "app.services.docling.categorizer.TransactionCategorizer"


# ──────────────────────────────────────────────────────────────────────────────
# 1. Helper function tests: _detect_document_type
# ──────────────────────────────────────────────────────────────────────────────


class TestDetectDocumentType:
    """Tests for the _detect_document_type helper function."""

    def test_detect_lpp_certificate_with_multiple_keywords(self):
        """Text with 2+ LPP keywords returns 'lpp_certificate'."""
        text = (
            "Certificat de prévoyance professionnelle\n"
            "Avoir de vieillesse total: CHF 166'300\n"
            "Taux de conversion: 6.8%"
        )
        assert _detect_document_type(text) == "lpp_certificate"

    def test_detect_salary_slip_with_multiple_keywords(self):
        """Text with 2+ salary keywords returns 'salary_slip'."""
        text = (
            "Fiche de salaire - Janvier 2025\n"
            "Décompte de salaire\n"
            "Net à payer: CHF 6'800.00"
        )
        assert _detect_document_type(text) == "salary_slip"

    def test_detect_unknown_no_keywords(self):
        """Text with no financial keywords returns 'unknown'."""
        text = "This is a random document about cooking recipes."
        assert _detect_document_type(text) == "unknown"

    def test_detect_lpp_wins_over_salary_when_mixed(self):
        """When both LPP and salary keywords present, LPP with higher score wins."""
        text = (
            "Certificat de prévoyance professionnelle\n"
            "Avoir de vieillesse total: CHF 166'300\n"
            "Taux de conversion: 6.8%\n"
            "Caisse de pension\n"
            "Fiche de salaire\n"
        )
        # 4 LPP keywords vs 1 salary keyword -> LPP wins (score >= 2)
        assert _detect_document_type(text) == "lpp_certificate"

    def test_detect_single_lpp_keyword_threshold(self):
        """A single LPP keyword still returns 'lpp_certificate' (score == 1)."""
        text = "Ce document contient le mot lpp quelque part."
        assert _detect_document_type(text) == "lpp_certificate"

    def test_detect_single_salary_keyword_threshold(self):
        """A single salary keyword returns 'salary_slip' (score == 1)."""
        text = "Votre nettolohn pour le mois de janvier."
        assert _detect_document_type(text) == "salary_slip"

    def test_detect_case_insensitive(self):
        """Detection is case-insensitive."""
        text = "AVOIR DE VIEILLESSE total: CHF 100'000\nTAUX DE CONVERSION: 6.8%"
        assert _detect_document_type(text) == "lpp_certificate"

    def test_detect_german_lpp_keywords(self):
        """German LPP keywords are detected."""
        text = "Pensionskasse\nAltersguthaben: CHF 155'000\nUmwandlungssatz: 6.8%"
        assert _detect_document_type(text) == "lpp_certificate"

    def test_detect_empty_string(self):
        """Empty string returns 'unknown'."""
        assert _detect_document_type("") == "unknown"


# ──────────────────────────────────────────────────────────────────────────────
# 2. CRUD document store tests (via API)
# ──────────────────────────────────────────────────────────────────────────────


class TestDocumentStoreCRUD:
    """Tests for CRUD operations on the in-memory document store."""

    def test_list_documents_empty(self, client):
        """GET /api/v1/documents/ returns empty list when store is empty."""
        response = client.get("/api/v1/documents/")
        assert response.status_code == 200
        data = response.json()
        assert data["documents"] == []

    def test_list_documents_returns_stored(self, client, populated_store):
        """GET /api/v1/documents/ returns all stored documents."""
        response = client.get("/api/v1/documents/")
        assert response.status_code == 200
        data = response.json()
        assert len(data["documents"]) == 3

    def test_list_documents_summary_fields(self, client, populated_store):
        """Document summaries contain the expected fields."""
        response = client.get("/api/v1/documents/")
        data = response.json()
        doc = data["documents"][0]
        assert "id" in doc
        assert "document_type" in doc
        assert "upload_date" in doc
        assert "confidence" in doc
        assert "fields_found" in doc

    def test_get_document_by_valid_id(self, client, populated_store):
        """GET /api/v1/documents/{doc_id} returns the correct document."""
        response = client.get("/api/v1/documents/doc-aaa")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "doc-aaa"
        assert data["document_type"] == "lpp_certificate"
        assert data["confidence"] == 0.85
        assert data["fields_found"] == 15
        assert data["fields_total"] == 18
        assert data["extracted_fields"]["avoir_vieillesse_total"] == 166300.0

    def test_get_document_by_invalid_id(self, client):
        """GET /api/v1/documents/{doc_id} returns 404 for unknown ID."""
        response = client.get("/api/v1/documents/nonexistent-id")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]

    def test_delete_document_by_valid_id(self, client, populated_store):
        """DELETE /api/v1/documents/{doc_id} removes the document."""
        response = client.delete("/api/v1/documents/doc-aaa")
        assert response.status_code == 200
        data = response.json()
        assert data["deleted"] is True
        assert data["id"] == "doc-aaa"

        # Verify it is gone
        get_resp = client.get("/api/v1/documents/doc-aaa")
        assert get_resp.status_code == 404

    def test_delete_document_by_invalid_id(self, client):
        """DELETE /api/v1/documents/{doc_id} returns 404 for unknown ID."""
        response = client.delete("/api/v1/documents/nonexistent-id")
        assert response.status_code == 404

    def test_store_multiple_and_list_all(self, client, populated_store):
        """Store has 3 docs, list returns all 3."""
        response = client.get("/api/v1/documents/")
        assert response.status_code == 200
        ids = [d["id"] for d in response.json()["documents"]]
        assert "doc-aaa" in ids
        assert "doc-bbb" in ids
        assert "doc-ccc" in ids

    def test_delete_one_then_list_shows_remaining(self, client, populated_store):
        """Delete one document, list shows remaining."""
        client.delete("/api/v1/documents/doc-bbb")
        response = client.get("/api/v1/documents/")
        assert response.status_code == 200
        ids = [d["id"] for d in response.json()["documents"]]
        assert "doc-bbb" not in ids
        assert len(ids) == 2


# ──────────────────────────────────────────────────────────────────────────────
# 3. Upload validation tests
# ──────────────────────────────────────────────────────────────────────────────


class TestUploadValidation:
    """Tests for file upload validation (content type, extension, empty file)."""

    def test_upload_invalid_content_type(self, client):
        """POST /upload with invalid content type returns 400."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("document.pdf", b"dummy content", "text/plain")},
        )
        assert response.status_code == 400
        assert "Only PDF files are accepted" in response.json()["detail"]

    def test_upload_wrong_extension(self, client):
        """POST /upload with non-.pdf extension returns 400."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("image.png", b"dummy", "application/pdf")},
        )
        assert response.status_code == 400
        assert ".pdf" in response.json()["detail"]

    def test_upload_empty_file(self, client):
        """POST /upload with empty file returns 400."""
        # application/octet-stream is now rejected (FIX-W12), use application/pdf
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("empty.pdf", b"", "application/pdf")},
        )
        assert response.status_code == 400
        assert "Empty file" in response.json()["detail"]

    def test_upload_octet_stream_rejected(self, client):
        """POST /upload with application/octet-stream is rejected (FIX-W12)."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("doc.pdf", b"%PDF-1.4 content", "application/octet-stream")},
        )
        assert response.status_code == 400
        assert "Only PDF files are accepted" in response.json()["detail"]

    def test_upload_invalid_magic_bytes(self, client):
        """POST /upload with non-PDF content returns 400 (FIX-W12 magic bytes)."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("fake.pdf", b"<html>not a pdf</html>", "application/pdf")},
        )
        assert response.status_code == 400
        assert "invalid magic bytes" in response.json()["detail"]

    def test_upload_statement_wrong_extension(self, client):
        """POST /upload-statement with unsupported extension returns 400."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("data.xlsx", b"content", "application/octet-stream")},
        )
        assert response.status_code == 400
        assert ".csv or .pdf" in response.json()["detail"]

    def test_upload_statement_empty_file(self, client):
        """POST /upload-statement with empty file returns 400."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("empty.csv", b"", "text/csv")},
        )
        assert response.status_code == 400
        assert "Empty file" in response.json()["detail"]

    def test_upload_preview_wrong_extension(self, client):
        """POST /upload-statement/preview with unsupported extension returns 400."""
        response = client.post(
            "/api/v1/documents/upload-statement/preview",
            files={"file": ("data.txt", b"content", "text/plain")},
        )
        assert response.status_code == 400
        assert ".csv or .pdf" in response.json()["detail"]

    def test_upload_preview_empty_file(self, client):
        """POST /upload-statement/preview with empty file returns 400."""
        response = client.post(
            "/api/v1/documents/upload-statement/preview",
            files={"file": ("empty.csv", b"", "text/csv")},
        )
        assert response.status_code == 400
        assert "Empty file" in response.json()["detail"]


# ──────────────────────────────────────────────────────────────────────────────
# 4. Upload with mocked docling
# ──────────────────────────────────────────────────────────────────────────────


class TestUploadWithMockedDocling:
    """Tests for PDF upload with mocked docling parser/extractor."""

    @patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor())
    @patch(PARSER_PATCH, return_value=_make_mock_parser())
    def test_upload_pdf_success(self, MockParser, MockExtractor, client):
        """POST /upload with valid PDF and mocked docling returns 200."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 mock", "application/pdf")},
        )
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert data["document_type"] in ("lpp_certificate", "salary_slip", "unknown")
        assert "extracted_fields" in data
        assert "confidence" in data
        assert "fields_found" in data
        assert "fields_total" in data
        assert "raw_text_preview" in data
        assert "warnings" in data
        assert isinstance(data["warnings"], list)

    @patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor())
    @patch(PARSER_PATCH, return_value=_make_mock_parser())
    def test_upload_pdf_auto_detection(self, MockParser, MockExtractor, client):
        """Upload populates document_type from auto-detection."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 mock", "application/pdf")},
        )
        assert response.status_code == 200
        data = response.json()
        # The mock text includes LPP keywords so it should detect lpp_certificate
        assert data["document_type"] == "lpp_certificate"

    @patch("app.api.v1.endpoints.documents._index_in_rag", return_value=True)
    @patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor())
    @patch(PARSER_PATCH, return_value=_make_mock_parser())
    def test_upload_pdf_with_rag_indexing(
        self, MockParser, MockExtractor, MockRAG, client
    ):
        """Upload with index_in_rag=true sets rag_indexed field."""
        response = client.post(
            "/api/v1/documents/upload?index_in_rag=true",
            files={"file": ("cert.pdf", b"%PDF-1.4 mock", "application/pdf")},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["rag_indexed"] is True

    @patch(CATEGORIZER_PATCH, return_value=_make_mock_categorizer())
    @patch(BANK_EXTRACTOR_PATCH, return_value=_make_mock_bank_extractor())
    def test_upload_statement_csv_success(
        self, MockBankExtractor, MockCategorizer, client
    ):
        """POST /upload-statement with CSV file returns 200."""
        csv_content = b"Datum;Buchungstext;Belastung\n15.01.2026;MIGROS;-45.80"
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("statement.csv", csv_content, "text/csv")},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["document_type"] == "bank_statement"
        assert data["bank_name"] == "UBS"
        assert len(data["transactions"]) == 2
        assert data["total_credits"] == 6800.0
        assert data["total_debits"] == -2487.50
        assert "category_summary" in data
        assert "recurring_monthly" in data
        assert "confidence" in data

    @patch(CATEGORIZER_PATCH, return_value=_make_mock_categorizer())
    @patch(BANK_EXTRACTOR_PATCH, return_value=_make_mock_bank_extractor())
    def test_upload_statement_pdf_success(
        self, MockBankExtractor, MockCategorizer, client
    ):
        """POST /upload-statement with PDF bank statement returns 200."""
        response = client.post(
            "/api/v1/documents/upload-statement",
            files={"file": ("statement.pdf", b"%PDF-1.4 bank", "application/pdf")},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["document_type"] == "bank_statement"

    @patch(CATEGORIZER_PATCH, return_value=_make_mock_categorizer())
    @patch(BANK_EXTRACTOR_PATCH, return_value=_make_mock_bank_extractor())
    def test_budget_preview_success(
        self, MockBankExtractor, MockCategorizer, client
    ):
        """POST /upload-statement/preview returns budget preview."""
        csv_content = b"Datum;Buchungstext;Belastung\n15.01.2026;MIGROS;-45.80"
        response = client.post(
            "/api/v1/documents/upload-statement/preview",
            files={"file": ("statement.csv", csv_content, "text/csv")},
        )
        assert response.status_code == 200
        data = response.json()
        assert "estimated_monthly_income" in data
        assert "estimated_monthly_expenses" in data
        assert "top_categories" in data
        assert "recurring_charges" in data
        assert "savings_rate" in data
        assert data["estimated_monthly_income"] == 6800.0
        assert data["savings_rate"] == 63.4


# ──────────────────────────────────────────────────────────────────────────────
# 5. Integration tests (full CRUD cycle with mocked docling)
# ──────────────────────────────────────────────────────────────────────────────


class TestIntegration:
    """Integration tests for the full document lifecycle."""

    @patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor())
    @patch(PARSER_PATCH, return_value=_make_mock_parser())
    def test_full_crud_cycle(self, MockParser, MockExtractor, client):
        """Upload -> list -> get -> delete -> verify gone."""
        # Upload
        upload_resp = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 data", "application/pdf")},
        )
        assert upload_resp.status_code == 200
        doc_id = upload_resp.json()["id"]

        # List
        list_resp = client.get("/api/v1/documents/")
        assert list_resp.status_code == 200
        assert len(list_resp.json()["documents"]) == 1
        assert list_resp.json()["documents"][0]["id"] == doc_id

        # Get
        get_resp = client.get(f"/api/v1/documents/{doc_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["id"] == doc_id
        assert "extracted_fields" in get_resp.json()

        # Delete
        del_resp = client.delete(f"/api/v1/documents/{doc_id}")
        assert del_resp.status_code == 200
        assert del_resp.json()["deleted"] is True

        # Verify gone
        get_resp2 = client.get(f"/api/v1/documents/{doc_id}")
        assert get_resp2.status_code == 404

        list_resp2 = client.get("/api/v1/documents/")
        assert list_resp2.json()["documents"] == []

    @patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor())
    @patch(PARSER_PATCH, return_value=_make_mock_parser())
    def test_document_type_detection_in_upload_flow(
        self, MockParser, MockExtractor, client
    ):
        """Document type detection is integrated in the upload flow."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 data", "application/pdf")},
        )
        assert response.status_code == 200
        doc_id = response.json()["id"]

        # Get the stored document and verify type is set
        get_resp = client.get(f"/api/v1/documents/{doc_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["document_type"] in (
            "lpp_certificate",
            "salary_slip",
            "unknown",
        )

    @patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor())
    @patch(PARSER_PATCH, return_value=_make_mock_parser())
    def test_multiple_uploads_delete_one(self, MockParser, MockExtractor, client):
        """Upload 3 docs, list shows 3, delete 1, list shows 2."""
        doc_ids = []
        for i in range(3):
            resp = client.post(
                "/api/v1/documents/upload",
                files={
                    "file": (f"cert_{i}.pdf", b"%PDF-1.4 data", "application/pdf")
                },
            )
            assert resp.status_code == 200
            doc_ids.append(resp.json()["id"])

        # List shows 3
        list_resp = client.get("/api/v1/documents/")
        assert len(list_resp.json()["documents"]) == 3

        # Delete the second
        del_resp = client.delete(f"/api/v1/documents/{doc_ids[1]}")
        assert del_resp.status_code == 200

        # List shows 2
        list_resp2 = client.get("/api/v1/documents/")
        remaining_ids = [d["id"] for d in list_resp2.json()["documents"]]
        assert len(remaining_ids) == 2
        assert doc_ids[1] not in remaining_ids
        assert doc_ids[0] in remaining_ids
        assert doc_ids[2] in remaining_ids

    @patch(LPP_EXTRACTOR_PATCH, return_value=_make_mock_extractor())
    @patch(PARSER_PATCH, return_value=_make_mock_parser())
    def test_privacy_raw_text_preview_limited(
        self, MockParser, MockExtractor, client
    ):
        """raw_text_preview is limited to 500 characters."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", b"%PDF-1.4 data", "application/pdf")},
        )
        assert response.status_code == 200
        preview = response.json()["raw_text_preview"]
        assert isinstance(preview, str)
        assert len(preview) <= 500


# ──────────────────────────────────────────────────────────────────────────────
# 6. Schema validation tests
# ──────────────────────────────────────────────────────────────────────────────


class TestSchemaValidation:
    """Tests for Pydantic schema validation of document models."""

    def test_document_upload_response_schema(self):
        """DocumentUploadResponse validates correctly."""
        from app.schemas.document import DocumentUploadResponse

        resp = DocumentUploadResponse(
            id="test-123",
            document_type="lpp_certificate",
            confidence=0.85,
            fields_found=15,
            fields_total=18,
        )
        assert resp.id == "test-123"
        assert resp.rag_indexed is False
        assert resp.warnings == []

    def test_document_summary_schema(self):
        """DocumentSummary validates correctly."""
        from app.schemas.document import DocumentSummary

        summary = DocumentSummary(
            id="test-123",
            document_type="lpp_certificate",
            upload_date="2025-01-01T00:00:00Z",
            confidence=0.85,
            fields_found=15,
        )
        assert summary.id == "test-123"

    def test_document_delete_response_schema(self):
        """DocumentDeleteResponse validates correctly."""
        from app.schemas.document import DocumentDeleteResponse

        resp = DocumentDeleteResponse(deleted=True, id="test-123")
        assert resp.deleted is True
        assert resp.id == "test-123"

    def test_budget_import_preview_schema(self):
        """BudgetImportPreview validates with defaults."""
        from app.schemas.document import BudgetImportPreview

        preview = BudgetImportPreview()
        assert preview.estimated_monthly_income == 0.0
        assert preview.estimated_monthly_expenses == 0.0
        assert preview.savings_rate == 0.0
        assert preview.top_categories == []
        assert preview.recurring_charges == []

    def test_transaction_response_schema(self):
        """TransactionResponse validates correctly."""
        from app.schemas.document import TransactionResponse

        tx = TransactionResponse(
            date="2026-01-15",
            description="MIGROS",
            amount=-45.80,
            category="alimentation",
        )
        assert tx.date == "2026-01-15"
        assert tx.amount == -45.80
        assert tx.is_recurring is False
        assert tx.balance is None
