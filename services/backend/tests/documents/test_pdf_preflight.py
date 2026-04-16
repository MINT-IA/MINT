"""Phase 28-01 / Task 2: PDF preflight branch tests."""
from __future__ import annotations

import pytest

pymupdf = pytest.importorskip("pymupdf")

from app.services.document_pdf_preflight import (  # noqa: E402
    preflight_pdf,
    select_pages_for_vision,
)


def _make_digital_pdf(text_per_page: list[str]) -> bytes:
    """Build a small in-memory PDF with text content per page."""
    doc = pymupdf.open()
    for txt in text_per_page:
        page = doc.new_page()
        page.insert_text((72, 72), txt, fontsize=12)
    buf = doc.tobytes()
    doc.close()
    return buf


def _make_image_only_pdf(num_pages: int = 1) -> bytes:
    """Build an image-only (no extractable text) PDF using a tiny pixmap."""
    doc = pymupdf.open()
    for _ in range(num_pages):
        # A4 page with no text → text_extractable will be 0
        doc.new_page(width=595, height=842)
    buf = doc.tobytes()
    doc.close()
    return buf


def _make_encrypted_pdf() -> bytes:
    """Build a password-protected PDF with a non-empty password."""
    doc = pymupdf.open()
    page = doc.new_page()
    page.insert_text((72, 72), "secret content", fontsize=12)
    buf = doc.tobytes(
        encryption=pymupdf.PDF_ENCRYPT_AES_256,
        owner_pw="owner-secret",
        user_pw="user-secret",
        permissions=int(pymupdf.PDF_PERM_PRINT),
    )
    doc.close()
    return buf


def test_digital_pdf_routes_to_digital():
    long_text = (
        "Salaire assuré: CHF 91'967.- avoir total 70'377 "
        "bonification vieillesse 24% rachat maximum 539'414 CHF "
        "rente projetée 33'892 CHF taux conversion 6.0%"
    )
    pdf = _make_digital_pdf([long_text])
    res = preflight_pdf(pdf)
    assert res["status"] == "digital"
    assert res["page_count"] == 1
    assert res["has_acroform"] is False
    assert res["text_extractable"] > 0


def test_scanned_pdf_routes_to_scanned():
    pdf = _make_image_only_pdf(num_pages=1)
    res = preflight_pdf(pdf)
    assert res["status"] == "scanned"
    assert res["page_count"] == 1
    assert res["text_extractable"] < 50


def test_encrypted_pdf_returns_password_status():
    pdf = _make_encrypted_pdf()
    res = preflight_pdf(pdf)
    assert res["status"] == "encrypted_needs_password"
    # Encrypted PDFs still expose page count
    assert res["page_count"] >= 1


def test_select_pages_returns_top_keyword_pages():
    pages = [
        "Page de garde — table des matières",  # 0 hit
        "Détails contractuels et nom du caissier",  # 0 hit
        "Salaire assuré: CHF 91'967.- avoir total CHF 70'377.- bonification 24%",  # many hits
        "Annexe légale sans chiffres",  # 0 hit
        "Rachat maximum: CHF 539'414.- rente projetée: CHF 33'892.- impôt marginal estimé",  # many hits
    ]
    pdf = _make_digital_pdf(pages)
    chosen = select_pages_for_vision(pdf, max_pages=2)
    assert len(chosen) == 2
    # Pages 2 and 4 carry the keyword density
    assert set(chosen) == {2, 4}


def test_select_pages_returns_all_when_under_max():
    pdf = _make_digital_pdf(["page one with avoir total", "page two with rente"])
    chosen = select_pages_for_vision(pdf, max_pages=5)
    assert chosen == [0, 1]


def test_acroform_pdf_routes_to_acroform(tmp_path):
    """AcroForm PDF → status='acroform', form fields surfaced."""
    doc = pymupdf.open()
    page = doc.new_page()
    widget = pymupdf.Widget()
    widget.field_name = "salaireAssure"
    widget.field_type = pymupdf.PDF_WIDGET_TYPE_TEXT
    widget.field_value = "91967"
    widget.rect = pymupdf.Rect(72, 72, 200, 100)
    page.add_widget(widget)
    out = tmp_path / "acroform.pdf"
    doc.save(str(out))
    doc.close()
    pdf = out.read_bytes()

    res = preflight_pdf(pdf)
    assert res["has_acroform"] is True
    assert res["status"] == "acroform"
    assert "salaireAssure" in res["acroform_fields"]
    assert res["acroform_fields"]["salaireAssure"] == "91967"
