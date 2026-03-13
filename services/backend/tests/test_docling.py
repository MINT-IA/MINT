"""
Tests for the Docling (Document Intelligence) module.

Tests PDF parser, LPP certificate extractor, FastAPI endpoints,
and RAG integration for document indexing.
"""

import importlib

import pytest

_chromadb_available = importlib.util.find_spec("chromadb") is not None
requires_chromadb = pytest.mark.skipif(
    not _chromadb_available,
    reason="chromadb not installed — skip RAG integration tests",
)

_pdfplumber_available = importlib.util.find_spec("pdfplumber") is not None
requires_pdfplumber = pytest.mark.skipif(
    not _pdfplumber_available,
    reason="pdfplumber not installed — skip docling tests (pip install -e '.[docling]')",
)


# ──────────────────────────────────────────────────────────────────────────────
# Helpers: Create minimal valid PDF bytes using pdfplumber's sister lib
# ──────────────────────────────────────────────────────────────────────────────


def _make_pdf_bytes(text_content: str) -> bytes:
    """
    Create a minimal valid PDF file with the given text content.

    Uses a hand-built PDF structure (no external library needed).
    This produces a single-page PDF with embedded text.
    """
    # Minimal PDF 1.4 structure
    # Split text into lines for positioning
    lines = text_content.split("\n")
    text_ops = []
    y = 750  # Start near top
    for line in lines:
        escaped = line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        text_ops.append(f"BT /F1 10 Tf {50} {y} Td ({escaped}) Tj ET")
        y -= 14  # Line spacing
        if y < 50:
            break

    stream_content = "\n".join(text_ops)
    stream_bytes = stream_content.encode("latin-1")
    stream_length = len(stream_bytes)

    pdf_parts = []

    # Header
    pdf_parts.append(b"%PDF-1.4\n")

    # Object 1: Catalog
    obj1_offset = sum(len(p) for p in pdf_parts)
    pdf_parts.append(b"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

    # Object 2: Pages
    obj2_offset = sum(len(p) for p in pdf_parts)
    pdf_parts.append(b"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")

    # Object 3: Page
    obj3_offset = sum(len(p) for p in pdf_parts)
    pdf_parts.append(
        b"3 0 obj\n<< /Type /Page /Parent 2 0 R "
        b"/MediaBox [0 0 612 792] "
        b"/Contents 4 0 R "
        b"/Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n"
    )

    # Object 4: Content stream
    obj4_offset = sum(len(p) for p in pdf_parts)
    obj4_header = f"4 0 obj\n<< /Length {stream_length} >>\nstream\n".encode("latin-1")
    obj4_footer = b"\nendstream\nendobj\n"
    pdf_parts.append(obj4_header + stream_bytes + obj4_footer)

    # Object 5: Font
    obj5_offset = sum(len(p) for p in pdf_parts)
    pdf_parts.append(
        b"5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"
    )

    # Cross-reference table
    xref_offset = sum(len(p) for p in pdf_parts)
    xref = "xref\n0 6\n"
    xref += "0000000000 65535 f \n"
    xref += f"{obj1_offset:010d} 00000 n \n"
    xref += f"{obj2_offset:010d} 00000 n \n"
    xref += f"{obj3_offset:010d} 00000 n \n"
    xref += f"{obj4_offset:010d} 00000 n \n"
    xref += f"{obj5_offset:010d} 00000 n \n"
    pdf_parts.append(xref.encode("latin-1"))

    # Trailer
    trailer = (
        f"trailer\n<< /Size 6 /Root 1 0 R >>\n"
        f"startxref\n{xref_offset}\n%%EOF\n"
    )
    pdf_parts.append(trailer.encode("latin-1"))

    return b"".join(pdf_parts)


# Sample LPP certificate text in French
SAMPLE_LPP_TEXT_FR = """
Caisse de pension: Caisse de prévoyance de l'État de Vaud
Certificat de prévoyance professionnelle
Date du certificat: 01.01.2025

Assuré: Jean Dupont

Salaire AVS: CHF 95'000.00
Déduction de coordination: CHF 26'460.00
Salaire assuré: CHF 68'540.00

Avoir de vieillesse obligatoire: CHF 120'500.00
Avoir de vieillesse surobligatoire: CHF 45'800.00
Avoir de vieillesse total: CHF 166'300.00

Taux de conversion obligatoire: 6.8%
Taux de conversion surobligatoire: 5.2%
Taux de conversion enveloppe: 5.8%

Rente d'invalidité annuelle: CHF 42'000.00
Capital-décès: CHF 200'000.00
Rente de conjoint annuelle: CHF 21'000.00
Rente d'enfant annuelle: CHF 8'400.00

Rachat maximum possible: CHF 85'000.00

Cotisation employé annuelle: CHF 4'500.00
Cotisation employeur annuelle: CHF 6'750.00
"""

# Sample LPP certificate text in German
SAMPLE_LPP_TEXT_DE = """
Pensionskasse: BVK Personalvorsorge des Kantons Zürich
Vorsorgeausweis
Datum des Ausweises: 01.01.2025

Versicherte Person: Max Müller

AHV-Lohn: CHF 110'000.00
Koordinationsabzug: CHF 26'460.00
Versicherter Lohn: CHF 83'540.00

Obligatorisches Altersguthaben: CHF 155'000.00
Überobligatorisches Altersguthaben: CHF 62'000.00
Altersguthaben total: CHF 217'000.00

Umwandlungssatz Obligatorium: 6.8%
Überobligatorischer Umwandlungssatz: 4.9%

Invalidenrente: CHF 52'000.00
Todesfallkapital: CHF 280'000.00
Ehegattenrente: CHF 26'000.00
Kinderrente: CHF 10'400.00

Maximaler Einkauf: CHF 120'000.00

Arbeitnehmerbeitrag: CHF 5'800.00
Arbeitgeberbeitrag: CHF 8'700.00
"""

# Sample LPP certificate text in Italian
SAMPLE_LPP_TEXT_IT = """
Cassa pensione: Istituto di previdenza del Canton Ticino
Certificato di previdenza professionale
Data del certificato: 01.01.2025

Assicurato: Marco Rossi

Salario AVS: CHF 88'000.00
Deduzione di coordinamento: CHF 26'460.00
Salario assicurato: CHF 61'540.00

Avere di vecchiaia obbligatorio: CHF 98'000.00
Avere di vecchiaia sovraobbligatorio: CHF 35'000.00
Avere di vecchiaia totale: CHF 133'000.00

Aliquota di conversione obbligatoria: 6.8%
Aliquota di conversione sovraobbligatoria: 5.0%

Rendita d'invalidità: CHF 38'000.00
Capitale in caso di decesso: CHF 170'000.00
Rendita per il coniuge: CHF 19'000.00
Rendita per figli: CHF 7'600.00

Riscatto massimo: CHF 65'000.00
"""

# Sample with table-like structure
SAMPLE_LPP_TABLE_TEXT = """Caisse de pension: Retraites Populaires

Prestations | Obligatoire | Surobligatoire | Total
Avoir de vieillesse | CHF 80'000 | CHF 30'000 | CHF 110'000
Taux de conversion | 6.8% | 5.0% | 5.6%
Rente d'invalidité | CHF 30'000 | CHF 12'000 | CHF 42'000
"""


# ──────────────────────────────────────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────────────────────────────────────


@pytest.fixture(autouse=True)
def _clear_document_store():
    """Clear the in-memory document store between tests."""
    from app.api.v1.endpoints.documents import _document_store
    _document_store.clear()
    yield
    _document_store.clear()


@pytest.fixture
def sample_pdf_bytes():
    """Create a minimal valid PDF with LPP certificate content."""
    return _make_pdf_bytes(SAMPLE_LPP_TEXT_FR)


@pytest.fixture
def sample_pdf_de_bytes():
    """Create a minimal valid PDF with German LPP content."""
    return _make_pdf_bytes(SAMPLE_LPP_TEXT_DE)


@pytest.fixture
def sample_pdf_it_bytes():
    """Create a minimal valid PDF with Italian LPP content."""
    return _make_pdf_bytes(SAMPLE_LPP_TEXT_IT)


@pytest.fixture
def empty_pdf_bytes():
    """Create a minimal valid PDF with no text content."""
    return _make_pdf_bytes("")


@pytest.fixture
def non_lpp_pdf_bytes():
    """Create a PDF with non-LPP content."""
    return _make_pdf_bytes("This is just a regular document with no financial terms.")


# ──────────────────────────────────────────────────────────────────────────────
# DocumentParser Tests
# ──────────────────────────────────────────────────────────────────────────────


@requires_pdfplumber
class TestDocumentParser:
    """Tests for the DocumentParser class."""

    def test_parse_valid_pdf(self, sample_pdf_bytes):
        """Parse a valid PDF and verify structure."""
        from app.services.docling.parser import DocumentParser

        parser = DocumentParser()
        result = parser.parse_pdf(sample_pdf_bytes)

        assert result is not None
        assert len(result.pages) > 0
        assert result.metadata["page_count"] >= 1
        assert result.metadata["file_size_bytes"] > 0
        assert isinstance(result.full_text, str)

    def test_parse_empty_bytes(self):
        """Parsing empty bytes raises ValueError."""
        from app.services.docling.parser import DocumentParser

        parser = DocumentParser()
        with pytest.raises(ValueError, match="Empty file"):
            parser.parse_pdf(b"")

    def test_parse_non_pdf(self):
        """Parsing non-PDF bytes raises ValueError."""
        from app.services.docling.parser import DocumentParser

        parser = DocumentParser()
        with pytest.raises(ValueError, match="does not appear to be a valid PDF"):
            parser.parse_pdf(b"This is not a PDF file at all.")

    def test_parse_corrupted_pdf(self):
        """Parsing corrupted PDF raises ValueError."""
        from app.services.docling.parser import DocumentParser

        parser = DocumentParser()
        with pytest.raises(ValueError):
            parser.parse_pdf(b"%PDF-1.4\nThis is corrupted content with no valid structure")

    def test_parse_oversized_file(self):
        """Parsing oversized file raises ValueError."""
        from app.services.docling.parser import DocumentParser

        parser = DocumentParser()
        # Create bytes exceeding MAX_FILE_SIZE
        big_bytes = b"%PDF-1.4" + b"\x00" * (parser.MAX_FILE_SIZE + 1)
        with pytest.raises(ValueError, match="exceeds maximum"):
            parser.parse_pdf(big_bytes)

    def test_page_content_structure(self, sample_pdf_bytes):
        """Verify PageContent dataclass has correct fields."""
        from app.services.docling.parser import DocumentParser

        parser = DocumentParser()
        result = parser.parse_pdf(sample_pdf_bytes)

        page = result.pages[0]
        assert hasattr(page, "page_number")
        assert hasattr(page, "text")
        assert hasattr(page, "tables")
        assert page.page_number == 1
        assert isinstance(page.tables, list)

    def test_metadata_contains_required_fields(self, sample_pdf_bytes):
        """Verify metadata has page_count, file_size_bytes, parsed_pages."""
        from app.services.docling.parser import DocumentParser

        parser = DocumentParser()
        result = parser.parse_pdf(sample_pdf_bytes)

        assert "page_count" in result.metadata
        assert "file_size_bytes" in result.metadata
        assert "parsed_pages" in result.metadata


# ──────────────────────────────────────────────────────────────────────────────
# LPP Certificate Extractor Tests
# ──────────────────────────────────────────────────────────────────────────────


@requires_pdfplumber
class TestLPPCertificateExtractor:
    """Tests for the LPPCertificateExtractor class."""

    def test_extract_french_certificate(self):
        """Extract fields from a French LPP certificate."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract(SAMPLE_LPP_TEXT_FR)

        # Core old-age savings
        assert result.avoir_vieillesse_obligatoire == 120500.0
        assert result.avoir_vieillesse_surobligatoire == 45800.0
        assert result.avoir_vieillesse_total == 166300.0

        # Salary
        assert result.salaire_assure == 68540.0
        assert result.salaire_avs == 95000.0
        assert result.deduction_coordination == 26460.0

        # Conversion rates
        assert result.taux_conversion_obligatoire == 6.8
        assert result.taux_conversion_surobligatoire == 5.2
        assert result.taux_conversion_enveloppe == 5.8

        # Risk coverage
        assert result.rente_invalidite_annuelle == 42000.0
        assert result.capital_deces == 200000.0
        assert result.rente_conjoint_annuelle == 21000.0
        assert result.rente_enfant_annuelle == 8400.0

        # Buyback
        assert result.rachat_maximum == 85000.0

        # Contributions
        assert result.cotisation_employe_annuelle == 4500.0
        assert result.cotisation_employeur_annuelle == 6750.0

        # Date
        assert result.date_certificat == "01.01.2025"

        # Confidence should be high with all fields extracted
        assert result.confidence > 0.5
        assert result.extracted_fields_count >= 15

    def test_extract_german_certificate(self):
        """Extract fields from a German LPP certificate."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract(SAMPLE_LPP_TEXT_DE)

        # Key German fields
        assert result.avoir_vieillesse_obligatoire == 155000.0
        assert result.avoir_vieillesse_surobligatoire == 62000.0
        assert result.avoir_vieillesse_total == 217000.0
        assert result.salaire_assure == 83540.0
        assert result.salaire_avs == 110000.0
        assert result.taux_conversion_obligatoire == 6.8
        assert result.rente_invalidite_annuelle == 52000.0
        assert result.capital_deces == 280000.0
        assert result.rachat_maximum == 120000.0

        assert result.confidence > 0.5
        assert result.extracted_fields_count >= 10

    def test_extract_italian_certificate(self):
        """Extract fields from an Italian LPP certificate."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract(SAMPLE_LPP_TEXT_IT)

        assert result.avoir_vieillesse_obligatoire == 98000.0
        assert result.avoir_vieillesse_surobligatoire == 35000.0
        assert result.avoir_vieillesse_total == 133000.0
        assert result.salaire_assure == 61540.0
        assert result.taux_conversion_obligatoire == 6.8
        assert result.rachat_maximum == 65000.0

        assert result.confidence > 0.3
        assert result.extracted_fields_count >= 8

    def test_extract_empty_text(self):
        """Extracting from empty text returns empty result."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract("")

        assert result.extracted_fields_count == 0
        assert result.confidence == 0.0
        assert result.avoir_vieillesse_total is None

    def test_extract_non_lpp_text(self):
        """Extracting from non-LPP text returns minimal results."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract(
            "This is a random document about cooking recipes. "
            "Mix flour and sugar, bake at 180 degrees for 30 minutes."
        )

        assert result.extracted_fields_count == 0
        assert result.confidence == 0.0

    def test_confidence_calculation(self):
        """Verify confidence score is based on field coverage."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()

        # Full certificate should have high confidence
        full = extractor.extract(SAMPLE_LPP_TEXT_FR)
        assert full.confidence > 0.7

        # Partial text should have lower confidence
        partial = extractor.extract("Avoir de vieillesse total: CHF 100'000.00")
        assert partial.confidence < full.confidence
        assert partial.confidence > 0.0

    def test_confidence_consistency_bonus(self):
        """Confidence gets a bonus when total = obligatoire + surobligatoire."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract(SAMPLE_LPP_TEXT_FR)

        # Values are consistent (120500 + 45800 = 166300)
        assert result.avoir_vieillesse_obligatoire is not None
        assert result.avoir_vieillesse_surobligatoire is not None
        assert result.avoir_vieillesse_total is not None

        expected = (
            result.avoir_vieillesse_obligatoire
            + result.avoir_vieillesse_surobligatoire
        )
        assert abs(result.avoir_vieillesse_total - expected) < 1.0

    def test_extract_from_table_data(self):
        """Extract fields when data is presented in table format."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()

        tables = [
            [
                ["Prestations", "Obligatoire", "Surobligatoire", "Total"],
                ["Avoir de vieillesse", "CHF 80'000", "CHF 30'000", "CHF 110'000"],
                ["Rente d'invalidité", "CHF 30'000", "CHF 12'000", "CHF 42'000"],
            ]
        ]

        result = extractor.extract("Caisse de pension: Retraites Populaires", tables=tables)

        # Should extract from table data
        assert result.extracted_fields_count > 0

    def test_extract_chf_amount_formats(self):
        """Test various CHF amount formats."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()

        # Swiss apostrophe format
        result1 = extractor.extract("Avoir de vieillesse total: CHF 150'000.00")
        assert result1.avoir_vieillesse_total == 150000.0

        # No apostrophe
        result2 = extractor.extract("Avoir de vieillesse total: CHF 150000.00")
        assert result2.avoir_vieillesse_total == 150000.0

        # With Fr. prefix
        result3 = extractor.extract("Avoir de vieillesse total: Fr. 150'000.00")
        assert result3.avoir_vieillesse_total == 150000.0

    def test_extract_rate_formats(self):
        """Test percentage rate extraction."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()

        result = extractor.extract("Taux de conversion obligatoire: 6.8%")
        assert result.taux_conversion_obligatoire == 6.8

        result2 = extractor.extract("Taux de conversion obligatoire: 6,80 %")
        assert result2.taux_conversion_obligatoire == 6.8

    def test_language_detection(self):
        """Test language detection from certificate text."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()

        assert extractor._detect_language(SAMPLE_LPP_TEXT_FR) == "fr"
        assert extractor._detect_language(SAMPLE_LPP_TEXT_DE) == "de"
        assert extractor._detect_language(SAMPLE_LPP_TEXT_IT) == "it"
        assert extractor._detect_language("random english text") == "fr"  # default

    def test_to_dict(self):
        """Test LPPCertificateData.to_dict() returns a proper dictionary."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract(SAMPLE_LPP_TEXT_FR)
        d = result.to_dict()

        assert isinstance(d, dict)
        assert "avoir_vieillesse_total" in d
        assert "confidence" in d
        assert d["avoir_vieillesse_total"] == 166300.0


# ──────────────────────────────────────────────────────────────────────────────
# FastAPI Endpoint Tests
# ──────────────────────────────────────────────────────────────────────────────


@requires_pdfplumber
class TestDocumentEndpoints:
    """Tests for document upload/list/get/delete endpoints."""

    def test_upload_pdf(self, client, sample_pdf_bytes):
        """POST /api/v1/documents/upload with a valid PDF."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("certificate.pdf", sample_pdf_bytes, "application/pdf")},
        )
        assert response.status_code == 200

        data = response.json()
        assert "document_id" in data
        assert data["document_type"] in ("lpp_certificate", "unknown")
        assert "extracted_fields" in data
        assert "confidence" in data
        assert "fields_found" in data
        assert "fields_total" in data
        assert "raw_text_preview" in data
        assert "warnings" in data
        assert isinstance(data["warnings"], list)

    def test_upload_non_pdf_rejected(self, client):
        """POST /api/v1/documents/upload with non-PDF file is rejected."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("document.txt", b"Hello world", "text/plain")},
        )
        assert response.status_code == 400
        assert "Unsupported file type" in response.json()["detail"]

    def test_upload_wrong_extension_rejected(self, client):
        """POST /api/v1/documents/upload with wrong extension is rejected."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("image.png", b"%PDF-1.4 fake", "application/pdf")},
        )
        assert response.status_code == 400
        assert ".pdf" in response.json()["detail"]

    def test_upload_empty_file_rejected(self, client):
        """POST /api/v1/documents/upload with empty file is rejected."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("empty.pdf", b"", "application/pdf")},
        )
        assert response.status_code == 400

    def test_upload_corrupted_pdf(self, client):
        """POST /api/v1/documents/upload with corrupted PDF returns 400."""
        response = client.post(
            "/api/v1/documents/upload",
            files={
                "file": (
                    "corrupted.pdf",
                    b"%PDF-1.4\ngarbage content that is not valid",
                    "application/pdf",
                )
            },
        )
        assert response.status_code == 400

    def test_list_documents_empty(self, client):
        """GET /api/v1/documents/ returns empty list initially."""
        response = client.get("/api/v1/documents/")
        assert response.status_code == 200
        data = response.json()
        assert data["documents"] == []

    def test_list_documents_after_upload(self, client, sample_pdf_bytes):
        """GET /api/v1/documents/ returns uploaded documents."""
        # Upload first
        upload_resp = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", sample_pdf_bytes, "application/pdf")},
        )
        assert upload_resp.status_code == 200
        doc_id = upload_resp.json()["document_id"]

        # List
        list_resp = client.get("/api/v1/documents/")
        assert list_resp.status_code == 200
        data = list_resp.json()
        assert len(data["documents"]) == 1
        assert data["documents"][0]["id"] == doc_id

    def test_get_document(self, client, sample_pdf_bytes):
        """GET /api/v1/documents/{doc_id} returns document detail."""
        # Upload first
        upload_resp = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", sample_pdf_bytes, "application/pdf")},
        )
        doc_id = upload_resp.json()["document_id"]

        # Get
        get_resp = client.get(f"/api/v1/documents/{doc_id}")
        assert get_resp.status_code == 200
        data = get_resp.json()
        assert data["id"] == doc_id
        assert "extracted_fields" in data
        assert "document_type" in data

    def test_get_document_not_found(self, client):
        """GET /api/v1/documents/{doc_id} returns 404 for unknown ID."""
        response = client.get("/api/v1/documents/nonexistent-id")
        assert response.status_code == 404

    def test_delete_document(self, client, sample_pdf_bytes):
        """DELETE /api/v1/documents/{doc_id} removes the document."""
        # Upload first
        upload_resp = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", sample_pdf_bytes, "application/pdf")},
        )
        doc_id = upload_resp.json()["document_id"]

        # Delete
        del_resp = client.delete(f"/api/v1/documents/{doc_id}")
        assert del_resp.status_code == 200
        assert del_resp.json()["deleted"] is True
        assert del_resp.json()["id"] == doc_id

        # Verify it's gone
        get_resp = client.get(f"/api/v1/documents/{doc_id}")
        assert get_resp.status_code == 404

    def test_delete_document_not_found(self, client):
        """DELETE /api/v1/documents/{doc_id} returns 404 for unknown ID."""
        response = client.delete("/api/v1/documents/nonexistent-id")
        assert response.status_code == 404

    def test_upload_returns_preview(self, client, sample_pdf_bytes):
        """Upload response includes raw_text_preview."""
        response = client.post(
            "/api/v1/documents/upload",
            files={"file": ("cert.pdf", sample_pdf_bytes, "application/pdf")},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data["raw_text_preview"], str)
        # Preview should be at most 500 chars
        assert len(data["raw_text_preview"]) <= 500

    def test_upload_multiple_documents(self, client, sample_pdf_bytes):
        """Upload multiple documents and verify list returns all."""
        for i in range(3):
            resp = client.post(
                "/api/v1/documents/upload",
                files={"file": (f"cert_{i}.pdf", sample_pdf_bytes, "application/pdf")},
            )
            assert resp.status_code == 200

        list_resp = client.get("/api/v1/documents/")
        assert list_resp.status_code == 200
        assert len(list_resp.json()["documents"]) == 3


# ──────────────────────────────────────────────────────────────────────────────
# Document Type Detection Tests
# ──────────────────────────────────────────────────────────────────────────────


@requires_pdfplumber
class TestDocumentTypeDetection:
    """Tests for document type detection."""

    def test_detect_lpp_certificate_fr(self):
        """Detect French LPP certificate."""
        from app.api.v1.endpoints.documents import _detect_document_type

        assert _detect_document_type(SAMPLE_LPP_TEXT_FR) == "lpp_certificate"

    def test_detect_lpp_certificate_de(self):
        """Detect German LPP certificate."""
        from app.api.v1.endpoints.documents import _detect_document_type

        assert _detect_document_type(SAMPLE_LPP_TEXT_DE) == "lpp_certificate"

    def test_detect_lpp_certificate_it(self):
        """Detect Italian LPP certificate."""
        from app.api.v1.endpoints.documents import _detect_document_type

        assert _detect_document_type(SAMPLE_LPP_TEXT_IT) == "lpp_certificate"

    def test_detect_salary_slip(self):
        """Detect salary slip."""
        from app.api.v1.endpoints.documents import _detect_document_type

        salary_text = (
            "Fiche de salaire - Janvier 2025\n"
            "Décompte de salaire\n"
            "Salaire brut: CHF 8'500.00\n"
            "Net à payer: CHF 6'800.00"
        )
        assert _detect_document_type(salary_text) == "salary_slip"

    def test_detect_unknown(self):
        """Unknown document type."""
        from app.api.v1.endpoints.documents import _detect_document_type

        assert _detect_document_type("Random shopping list") == "unknown"


# ──────────────────────────────────────────────────────────────────────────────
# RAG Integration Tests
# ──────────────────────────────────────────────────────────────────────────────


@requires_pdfplumber
@requires_chromadb
class TestDoclingRAGIntegration:
    """Tests for RAG indexation of extracted document data."""

    def test_rag_indexation_function(self):
        """Test the _index_in_rag helper function."""
        from app.api.v1.endpoints.documents import _index_in_rag

        # This should not crash even if RAG is not available
        result = _index_in_rag(
            doc_id="test-doc-123",
            extracted_fields={
                "avoir_vieillesse_total": 166300.0,
                "salaire_assure": 68540.0,
                "rachat_maximum": 85000.0,
            },
            document_type="lpp_certificate",
        )
        # Result depends on whether RAG is installed
        assert isinstance(result, bool)

    def test_upload_with_rag_indexation(self, client, sample_pdf_bytes):
        """Upload with index_in_rag=true does not crash."""
        response = client.post(
            "/api/v1/documents/upload?index_in_rag=true",
            files={"file": ("cert.pdf", sample_pdf_bytes, "application/pdf")},
        )
        # Should succeed regardless of RAG availability
        assert response.status_code == 200
        data = response.json()
        assert "rag_indexed" in data
        assert isinstance(data["rag_indexed"], bool)


# ──────────────────────────────────────────────────────────────────────────────
# Module Import Tests
# ──────────────────────────────────────────────────────────────────────────────


@requires_pdfplumber
class TestDoclingModule:
    """Tests for the docling module initialization."""

    def test_docling_available(self):
        """Verify DOCLING_AVAILABLE flag is True when pdfplumber is installed."""
        from app.services.docling import DOCLING_AVAILABLE

        assert DOCLING_AVAILABLE is True

    def test_imports(self):
        """Verify all expected exports are available."""
        from app.services.docling import (
            DocumentParser,
            ParsedDocument,
            PageContent,
            LPPCertificateExtractor,
            LPPCertificateData,
        )

        assert DocumentParser is not None
        assert ParsedDocument is not None
        assert PageContent is not None
        assert LPPCertificateExtractor is not None
        assert LPPCertificateData is not None

    def test_lpp_certificate_data_defaults(self):
        """Verify LPPCertificateData default values."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateData,
        )

        data = LPPCertificateData()
        assert data.confidence == 0.0
        assert data.extracted_fields_count == 0
        assert data.total_fields_count == 18
        assert data.avoir_vieillesse_total is None
        assert data.caisse_name is None


# ──────────────────────────────────────────────────────────────────────────────
# Edge Cases
# ──────────────────────────────────────────────────────────────────────────────


@requires_pdfplumber
class TestEdgeCases:
    """Edge case tests for the Docling pipeline."""

    def test_extract_with_only_tables(self):
        """Extract when only table data is available (no free text)."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        tables = [
            [
                ["Avoir de vieillesse obligatoire", "CHF 100'000"],
                ["Avoir de vieillesse surobligatoire", "CHF 50'000"],
                ["Avoir de vieillesse total", "CHF 150'000"],
                ["Rachat maximum", "CHF 75'000"],
            ]
        ]

        result = extractor.extract("", tables=tables)
        assert result.extracted_fields_count > 0

    def test_extract_with_none_tables(self):
        """Extract with None tables does not crash."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()
        result = extractor.extract(SAMPLE_LPP_TEXT_FR, tables=None)
        assert result.extracted_fields_count > 0

    def test_extract_both_text_and_tables(self):
        """Extract from both text and table sources."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()

        text = "Salaire AVS: CHF 95'000.00\nSalaire assuré: CHF 68'540.00"
        tables = [
            [
                ["Avoir de vieillesse total", "CHF 166'300"],
                ["Rachat maximum", "CHF 85'000"],
            ]
        ]

        result = extractor.extract(text, tables=tables)
        assert result.salaire_avs == 95000.0
        assert result.salaire_assure == 68540.0

    def test_amount_parser_edge_cases(self):
        """Test CHF amount parser with edge cases."""
        from app.services.docling.extractors.lpp_certificate import (
            LPPCertificateExtractor,
        )

        extractor = LPPCertificateExtractor()

        # Zero amount
        result = extractor.extract("Rachat maximum possible: CHF 0.00")
        assert result.rachat_maximum == 0.0

        # Small amount
        result2 = extractor.extract("Cotisation employé annuelle: CHF 100.50")
        assert result2.cotisation_employe_annuelle == 100.5

    def test_schema_validation(self):
        """Test Pydantic schema validation."""
        from app.schemas.document import (
            DocumentUploadResponse,
            DocumentSummary,
            DocumentDeleteResponse,
        )

        # Valid upload response
        resp = DocumentUploadResponse(
            document_id="test-123",
            document_type="lpp_certificate",
            confidence=0.85,
            fields_found=15,
            fields_total=18,
        )
        assert resp.document_id == "test-123"

        # Valid summary
        summary = DocumentSummary(
            id="test-123",
            document_type="lpp_certificate",
            upload_date="2025-01-01T00:00:00Z",
            confidence=0.85,
            fields_found=15,
        )
        assert summary.id == "test-123"

        # Valid delete response
        delete_resp = DocumentDeleteResponse(deleted=True, id="test-123")
        assert delete_resp.deleted is True
