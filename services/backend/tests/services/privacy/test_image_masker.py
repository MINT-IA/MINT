"""Tests for the two-stage image PII masker (Phase 29-06 / PRIV-07).

Strategy: instead of bundling real Tesseract binaries into the test env
(which would be flaky / slow), we inject a fake OCR provider that returns
the word boxes we care about. This keeps tests deterministic and fast
while covering the actual masking logic (span detection → bbox mapping →
rectangle draw → MaskReport).
"""
from __future__ import annotations

from io import BytesIO

import pytest

PIL = pytest.importorskip("PIL")
from PIL import Image  # noqa: E402

from app.services.privacy.image_masker import (  # noqa: E402
    MaskReport,
    WordBox,
    mask_pii_regions,
)


def _white_image(w: int = 800, h: int = 200) -> bytes:
    img = Image.new("RGB", (w, h), color=(255, 255, 255))
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _black_box(w: int = 40, h: int = 40) -> bytes:
    img = Image.new("RGB", (w, h), color=(255, 255, 255))
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _pixel_black_count(image_bytes: bytes) -> int:
    img = Image.open(BytesIO(image_bytes)).convert("RGB")
    return sum(1 for px in img.getdata() if px == (0, 0, 0))


def test_mask_iban_draws_rectangle():
    image_bytes = _white_image()
    # Fake OCR: one line reading "IBAN CH93 0076 2011 6238 5295 7" split into
    # word boxes. Offsets are the char offset within the reconstructed line.
    words = [
        WordBox("IBAN",     5,   10, 60, 30, line_id=0, char_offset=0),
        WordBox("CH93",     70,  10, 60, 30, line_id=0, char_offset=5),
        WordBox("0076",     135, 10, 60, 30, line_id=0, char_offset=10),
        WordBox("2011",     200, 10, 60, 30, line_id=0, char_offset=15),
        WordBox("6238",     265, 10, 60, 30, line_id=0, char_offset=20),
        WordBox("5295",     330, 10, 60, 30, line_id=0, char_offset=25),
        WordBox("7",        395, 10, 20, 30, line_id=0, char_offset=30),
    ]
    out_bytes, report = mask_pii_regions(image_bytes, _fake_ocr=lambda b: words)
    assert isinstance(report, MaskReport)
    assert report.masked_region_count >= 1
    assert "IBAN" in report.categories
    # The masked output should contain significantly more black pixels.
    before_black = _pixel_black_count(image_bytes)
    after_black = _pixel_black_count(out_bytes)
    assert after_black > before_black + 500


def test_mask_avs_draws_rectangle():
    image_bytes = _white_image()
    # "AVS: 756.1234.5678.97" on one line
    words = [
        WordBox("AVS:",              10, 10, 50, 30, line_id=0, char_offset=0),
        WordBox("756.1234.5678.97",  70, 10, 200, 30, line_id=0, char_offset=5),
    ]
    out_bytes, report = mask_pii_regions(image_bytes, _fake_ocr=lambda b: words)
    assert report.masked_region_count >= 1
    assert "AVS" in report.categories


def test_mask_clean_document_no_changes():
    image_bytes = _white_image()
    # Only innocuous text — no IBAN/AVS patterns
    words = [
        WordBox("LPP",             10, 10, 40, 30, line_id=0, char_offset=0),
        WordBox("avoir",           60, 10, 60, 30, line_id=0, char_offset=4),
        WordBox("accumule",        130, 10, 80, 30, line_id=0, char_offset=10),
    ]
    out_bytes, report = mask_pii_regions(image_bytes, _fake_ocr=lambda b: words)
    assert report.masked_region_count == 0
    assert report.categories == set()
    # Image shouldn't have new black pixels
    assert _pixel_black_count(out_bytes) == _pixel_black_count(image_bytes)


def test_mask_report_category_names_are_stable():
    image_bytes = _white_image()
    words = [
        WordBox("CH9300762011623852957", 10, 10, 300, 30, line_id=0, char_offset=0),
    ]
    _, report = mask_pii_regions(image_bytes, _fake_ocr=lambda b: words)
    # The report exposes stable category names for downstream metrics/DPA.
    assert report.categories.issubset({"IBAN", "AVS", "EMPLOYER", "PHONE"})


def test_mask_handles_empty_ocr_gracefully():
    image_bytes = _white_image()
    out_bytes, report = mask_pii_regions(image_bytes, _fake_ocr=lambda b: [])
    assert out_bytes == image_bytes or _pixel_black_count(out_bytes) == _pixel_black_count(image_bytes)
    assert report.masked_region_count == 0


def test_mask_invalid_image_returns_original():
    bogus = b"not-an-image-\x00\x01\x02"
    out_bytes, report = mask_pii_regions(bogus, _fake_ocr=lambda b: [])
    assert out_bytes == bogus
    assert report.masked_region_count == 0
