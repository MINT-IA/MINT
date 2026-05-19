"""Unit tests for app.models.encryption.encrypted_value Pydantic v2 shape.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-26 + D-29.

EncryptedValue is the wire shape for `fact_event.value_enc` JSONB column.
EnhancedConfidence is the wire shape for `fact_event.confidence` JSONB column
(D-29 + iter-2 B11 cap of 5 prompts x 200 chars).
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.models.encryption.encrypted_value import (
    EncryptedValue,
    EnhancedConfidence,
)


# ---------------------------------------------------------------------------
# EncryptedValue — D-26 wire shape
# ---------------------------------------------------------------------------


def test_encrypted_value_roundtrip_via_json():
    """D-26 happy path: build, dump JSON, re-parse, fields preserved."""
    v = EncryptedValue(
        ct="dGVzdC1jaXBoZXJ0ZXh0",  # base64('test-ciphertext')
        iv="dGVzdC1ub25jZS0xMg==",  # base64('test-nonce-12')
        dek_id="mint-master-v1",
    )
    payload = v.model_dump_json()
    parsed = EncryptedValue.model_validate_json(payload)
    assert parsed.ct == v.ct
    assert parsed.iv == v.iv
    assert parsed.dek_id == "mint-master-v1"
    assert parsed.alg == "AES-256-GCM"
    assert parsed.enc_v == 1
    assert parsed.tag == ""


def test_encrypted_value_rejects_extra_fields_extra_forbid():
    """D-26: extra:forbid blocks wire-shape drift (canonical-JSON discipline)."""
    with pytest.raises(ValidationError) as exc_info:
        EncryptedValue(
            ct="x",
            iv="y",
            dek_id="z",
            unknown_field="oops",  # extra:forbid must reject this
        )
    # Pydantic v2 mentions "extra" or "extra_forbidden" in the error
    err_str = str(exc_info.value).lower()
    assert "extra" in err_str or "forbidden" in err_str or "unknown_field" in err_str


def test_encrypted_value_rejects_wrong_alg_literal():
    """D-26: alg is Literal['AES-256-GCM'] — anything else is a write-shape regression."""
    with pytest.raises(ValidationError):
        EncryptedValue(
            ct="x",
            iv="y",
            dek_id="z",
            alg="AES-128-GCM",  # Literal mismatch
        )


def test_encrypted_value_rejects_non_empty_tag_iter2_c5():
    """iter-2 C5: tag is Literal[''] — AESGCM appends auth tag to ct, this field
    is reserved and any non-empty value would surface an envelope-format bug."""
    with pytest.raises(ValidationError):
        EncryptedValue(
            ct="x",
            iv="y",
            dek_id="z",
            tag="should-be-empty",
        )


def test_encrypted_value_enc_v_default_is_one():
    """enc_v defaults to 1 so callers don't have to specify it on every encrypt."""
    v = EncryptedValue(ct="x", iv="y", dek_id="z")
    assert v.enc_v == 1


# ---------------------------------------------------------------------------
# EnhancedConfidence — D-29 + iter-2 B11
# ---------------------------------------------------------------------------


def test_enhanced_confidence_accepts_valid_4axis():
    """D-29 happy path: 4 axes + score + optional enrichmentPrompts."""
    ec = EnhancedConfidence(
        c=0.8, a=0.9, f=1.0, u=0.7, score=0.85,
        enrichmentPrompts=["question 1", "question 2"],
    )
    assert ec.c == 0.8
    assert ec.score == 0.85
    assert len(ec.enrichmentPrompts) == 2


def test_enhanced_confidence_rejects_axis_outside_zero_one():
    """D-29: axes are in [0, 1] — values outside violate confidence semantics."""
    with pytest.raises(ValidationError):
        EnhancedConfidence(c=1.5, a=0.9, f=1.0, u=0.7, score=0.85)
    with pytest.raises(ValidationError):
        EnhancedConfidence(c=-0.1, a=0.9, f=1.0, u=0.7, score=0.85)


def test_enhanced_confidence_iter2_b11_cap_max_5_prompts():
    """iter-2 B11: enrichmentPrompts capped at 5 entries (TOAST-row-size discipline)."""
    with pytest.raises(ValidationError):
        EnhancedConfidence(
            c=0.8, a=0.9, f=1.0, u=0.7, score=0.85,
            enrichmentPrompts=["p1", "p2", "p3", "p4", "p5", "p6"],  # 6 > cap
        )


def test_enhanced_confidence_iter2_b11_cap_max_200_chars_per_prompt():
    """iter-2 B11: each prompt capped at 200 chars."""
    with pytest.raises(ValidationError):
        EnhancedConfidence(
            c=0.8, a=0.9, f=1.0, u=0.7, score=0.85,
            enrichmentPrompts=["x" * 201],  # one over the limit triggers
        )


def test_enhanced_confidence_iter2_b11_exactly_5_and_200_accepted():
    """iter-2 B11: the boundary (5 prompts each 200 chars) MUST be accepted."""
    ec = EnhancedConfidence(
        c=0.8, a=0.9, f=1.0, u=0.7, score=0.85,
        enrichmentPrompts=["x" * 200, "y" * 200, "z" * 200, "a" * 200, "b" * 200],
    )
    assert len(ec.enrichmentPrompts) == 5


def test_enhanced_confidence_rejects_extra_fields():
    """D-29 extra:forbid: confidence shape is locked, no drift allowed."""
    with pytest.raises(ValidationError):
        EnhancedConfidence(
            c=0.8, a=0.9, f=1.0, u=0.7, score=0.85,
            unknown_axis=0.5,
        )
