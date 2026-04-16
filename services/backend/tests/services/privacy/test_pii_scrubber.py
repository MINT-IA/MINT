"""Tests for PII scrubber.

PRIV-03 — Presidio + custom CH recognizers + regex fallback.
Tests target the regex fallback path which is always available; Presidio
path is exercised only when the lib is installed (Python ≥ 3.10 prod env).
"""
from __future__ import annotations

import logging
import re

import pytest

from app.services.privacy import pii_scrubber
from app.services.privacy.log_filter import PIILogFilter

pytestmark = pytest.mark.skipif(
    pii_scrubber is None, reason="pii_scrubber not installed (optional extra)"
)


@pytest.fixture(autouse=True)
def _set_fpe_keys(monkeypatch):
    monkeypatch.setenv("MINT_FPE_KEY", "test-master-key-deterministic-32b")
    monkeypatch.setenv("MINT_FPE_AUDIT_KEY", "test-audit-key-deterministic-32by")
    from app.services.privacy import fpe
    fpe._reset_key_cache()
    yield


# ---------------------------------------------------------------------------
# Mask mode (regex fallback) — always works
# ---------------------------------------------------------------------------

def test_scrub_iban_mask_mode():
    text = "Mon IBAN est CH93 0076 2011 6238 5295 7 voilà"
    out = pii_scrubber.scrub(text, mode="mask")
    assert "CH93" not in out
    assert "<IBAN>" in out


def test_scrub_avs_mask_mode():
    text = "Mon AVS: 756.1234.5678.97"
    out = pii_scrubber.scrub(text, mode="mask")
    assert "756.1234" not in out
    assert "<AVS>" in out


def test_scrub_avs_natural_language_partial_pattern():
    """Even partial AVS-like patterns get masked when the 756 prefix appears."""
    text = "Mon numéro AVS commence par 756.1234.5678.90"
    out = pii_scrubber.scrub(text, mode="mask")
    assert "756.1234" not in out


def test_scrub_swiss_phone_mask():
    text = "Appelle-moi au +41 79 123 45 67"
    out = pii_scrubber.scrub(text, mode="mask")
    assert "+41 79 123" not in out
    assert "<PHONE>" in out


def test_scrub_employer_gazetteer():
    """Top CH employers gazetteer-matched and replaced."""
    text = "Je travaille chez UBS depuis 5 ans."
    out = pii_scrubber.scrub(text, mode="mask")
    assert "UBS" not in out
    assert "<EMPLOYER>" in out


def test_scrub_employer_case_insensitive():
    text = "Mon employeur c'est nestlé"
    out = pii_scrubber.scrub(text, mode="mask")
    assert "nestlé" not in out.lower() or "<EMPLOYER>" in out


def test_scrub_mixed_pii():
    text = (
        "Mon IBAN CH93 0076 2011 6238 5295 7, AVS 756.1234.5678.97, "
        "tel +41 79 123 45 67, employeur Roche."
    )
    out = pii_scrubber.scrub(text, mode="mask")
    assert "CH93" not in out
    assert "756.1234" not in out
    assert "+41" not in out
    assert "Roche" not in out


def test_scrub_fpe_mode_iban():
    """FPE mode produces structurally-valid IBAN replacement."""
    text = "IBAN CH9300762011623852957 confirmed"
    out = pii_scrubber.scrub(text, mode="fpe")
    # Original IBAN is gone
    assert "CH9300762011623852957" not in out
    # A CH IBAN-shaped string remains
    assert re.search(r"CH\d{19}", out) is not None


def test_scrub_idempotent_on_clean_text():
    text = "Le coach a vu une projection LPP de 70'377 CHF."
    out = pii_scrubber.scrub(text, mode="mask")
    # No IBAN/AVS pattern → no change
    assert out == text


def test_scrub_handles_none_and_empty():
    assert pii_scrubber.scrub(None) == ""
    assert pii_scrubber.scrub("") == ""


def test_scrub_clamps_long_input():
    huge = "x" * 100_000
    out = pii_scrubber.scrub(huge)
    # No crash, output bounded
    assert isinstance(out, str)
    assert len(out) <= 100_000


# ---------------------------------------------------------------------------
# PIILogFilter
# ---------------------------------------------------------------------------

def test_log_filter_scrubs_message():
    log_filter = PIILogFilter()
    record = logging.LogRecord(
        name="test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="user iban=CH9300762011623852957 logged in",
        args=(),
        exc_info=None,
    )
    assert log_filter.filter(record) is True
    msg = record.getMessage()
    assert "CH9300762011623852957" not in msg


def test_log_filter_scrubs_args():
    log_filter = PIILogFilter()
    record = logging.LogRecord(
        name="test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="user iban=%s avs=%s",
        args=("CH9300762011623852957", "756.1234.5678.97"),
        exc_info=None,
    )
    assert log_filter.filter(record) is True
    msg = record.getMessage()
    assert "CH9300762011623852957" not in msg
    assert "756.1234" not in msg


def test_log_filter_preserves_safe_logs():
    log_filter = PIILogFilter()
    record = logging.LogRecord(
        name="test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="document fingerprint computed count=%d",
        args=(5,),
        exc_info=None,
    )
    assert log_filter.filter(record) is True
    assert "count=5" in record.getMessage()
