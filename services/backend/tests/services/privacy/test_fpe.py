"""Tests for Format-Preserving Encryption (FPE) tokenization.

PRIV-03 — IBAN/AVS tokenized to structurally-valid but factually-false values.
Reversible only with dual-control (master + audit keys).
"""
from __future__ import annotations

import os

import pytest

from app.services.privacy import fpe

# fpe is None when the [privacy] optional extra (pyffx) is not installed.
# CI runs with [dev] only — skip the entire module gracefully.
pytestmark = pytest.mark.skipif(fpe is None, reason="pyffx not installed (optional extra)")


@pytest.fixture(autouse=True)
def _set_keys(monkeypatch):
    """Provide deterministic test keys."""
    monkeypatch.setenv("MINT_FPE_KEY", "test-master-key-deterministic-32b")
    monkeypatch.setenv("MINT_FPE_AUDIT_KEY", "test-audit-key-deterministic-32by")
    yield


def test_tokenize_iban_preserves_format():
    """CH IBAN tokenized stays 21 chars, starts with CH, valid mod-97."""
    raw = "CH9300762011623852957"
    token = fpe.tokenize_iban(raw)

    assert token.startswith("CH"), f"expected CH prefix, got {token}"
    assert len(token) == 21, f"expected 21 chars, got {len(token)}: {token}"
    assert token != raw, "tokenized IBAN must differ from input"
    # Mod-97 check: rearrange + convert letters → digits → check ≡ 1
    rearranged = token[4:] + token[:4]
    numeric = "".join(
        str(ord(c) - 55) if c.isalpha() else c for c in rearranged
    )
    assert int(numeric) % 97 == 1, "tokenized IBAN must satisfy mod-97 check"


def test_tokenize_iban_deterministic_under_same_key():
    """Same input + same key → same token (idempotent)."""
    raw = "CH9300762011623852957"
    a = fpe.tokenize_iban(raw)
    b = fpe.tokenize_iban(raw)
    assert a == b


def test_tokenize_iban_round_trip_with_audit_key():
    """Dual-control: master + audit → de-tokenize works."""
    raw = "CH9300762011623852957"
    token = fpe.tokenize_iban(raw)
    recovered = fpe.detokenize_iban(token, with_audit_key=True)
    assert recovered == raw


def test_tokenize_iban_irreversible_without_audit_key():
    """Without audit key → de-tokenize raises."""
    raw = "CH9300762011623852957"
    token = fpe.tokenize_iban(raw)
    with pytest.raises(fpe.AuditKeyRequired):
        fpe.detokenize_iban(token, with_audit_key=False)


def test_tokenize_avs_preserves_format():
    """AVS 756.XXXX.XXXX.XX tokenized stays valid EAN-13 check digit."""
    raw = "7561234567897"  # 13 digits, valid EAN-13
    token = fpe.tokenize_avs(raw)

    assert len(token) == 13
    assert token.startswith("756")
    assert token != raw
    # Verify EAN-13 check digit on token
    body = token[:-1]
    expected_check = fpe._ean13_check_digit(body)
    assert int(token[-1]) == expected_check


def test_tokenize_avs_round_trip_with_audit_key():
    raw = "7561234567897"
    token = fpe.tokenize_avs(raw)
    recovered = fpe.detokenize_avs(token, with_audit_key=True)
    assert recovered == raw


def test_ean13_check_digit_known_value():
    """Sanity check on EAN-13 algorithm with known good code."""
    # 4006381333931 is a textbook valid EAN-13
    assert fpe._ean13_check_digit("400638133393") == 1


def test_missing_master_key_raises(monkeypatch):
    monkeypatch.delenv("MINT_FPE_KEY", raising=False)
    monkeypatch.delenv("MINT_FPE_AUDIT_KEY", raising=False)
    # Reset cached keys
    fpe._reset_key_cache()
    with pytest.raises(fpe.FPEKeyError):
        fpe.tokenize_iban("CH9300762011623852957")
    # Restore for subsequent tests
    fpe._reset_key_cache()
