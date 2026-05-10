"""Tests — Phase 91 Wave 1 Pydantic schema for the LLM extractor.

Pins:
  - Default empty `ExtractorOutput()` shape.
  - Happy-path validation of an `ExtractedFact`.
  - Schema rejection of: unknown key, confidence="low", source_quote
    too long / empty / whitespace-only, > 12 facts, > 4 intents,
    invalid intent value.
  - Single-source-of-truth invariant: the schema's `_ALLOWED_FACT_KEYS`
    Literal mirrors `coach_chat._SAVE_FACT_ALLOWED_KEYS` exactly.

Spec source: `.planning/phases/91-mvp-extractor-v2/91-01-PLAN.md`
Task 1.1.
"""
from __future__ import annotations

import typing

import pytest
from pydantic import ValidationError

from app.services.coach.extractor_schema import (
    ExtractedFact,
    ExtractorOutput,
    _ALLOWED_FACT_KEYS,
)


def test_extractor_output_default_empty():
    out = ExtractorOutput()
    assert out.facts == []
    assert out.intents == []


def test_extracted_fact_happy_path():
    fact = ExtractedFact(
        key="incomeGrossYearly",
        value=80000,
        confidence="high",
        source_quote="j'ai 80k de salaire",
    )
    assert fact.key == "incomeGrossYearly"
    assert fact.value == 80000
    assert fact.confidence == "high"
    assert fact.source_quote == "j'ai 80k de salaire"


def test_extracted_fact_unknown_key_rejected():
    with pytest.raises(ValidationError):
        ExtractedFact(
            key="customField",  # not in whitelist
            value=42,
            confidence="high",
            source_quote="random quote",
        )


def test_extracted_fact_low_confidence_rejected():
    with pytest.raises(ValidationError):
        ExtractedFact(
            key="canton",
            value="VD",
            confidence="low",  # forbidden per RESEARCH §3
            source_quote="à Lausanne",
        )


def test_extracted_fact_quote_too_long_rejected():
    long_quote = "x" * 81
    with pytest.raises(ValidationError):
        ExtractedFact(
            key="canton",
            value="VD",
            confidence="medium",
            source_quote=long_quote,
        )


def test_extracted_fact_empty_quote_rejected():
    with pytest.raises(ValidationError):
        ExtractedFact(
            key="canton",
            value="VD",
            confidence="medium",
            source_quote="",
        )


def test_extracted_fact_whitespace_only_quote_rejected():
    with pytest.raises(ValidationError):
        ExtractedFact(
            key="canton",
            value="VD",
            confidence="medium",
            source_quote="   \n  ",
        )


def test_extractor_output_too_many_facts_rejected():
    facts = [
        {
            "key": "canton",
            "value": "VD",
            "confidence": "high",
            "source_quote": f"quote {i}",
        }
        for i in range(13)
    ]
    with pytest.raises(ValidationError):
        ExtractorOutput(facts=facts)


def test_extractor_output_too_many_intents_rejected():
    with pytest.raises(ValidationError):
        ExtractorOutput(
            facts=[],
            intents=["debt", "housing", "family", "career", "retirement"],
        )


def test_extractor_output_intents_enum():
    with pytest.raises(ValidationError):
        ExtractorOutput(
            facts=[],
            intents=["foo"],  # not in enum
        )


def test_extracted_fact_extra_field_forbidden():
    """Pydantic `extra=forbid` rejects unknown keys to prevent silent drift."""
    with pytest.raises(ValidationError):
        ExtractedFact.model_validate(
            {
                "key": "canton",
                "value": "VD",
                "confidence": "high",
                "source_quote": "à Lausanne",
                "rationale": "extra field",  # not allowed
            }
        )


def test_canonical_keys_mirror_coach_chat():
    """The schema's Literal MUST mirror `coach_chat._SAVE_FACT_ALLOWED_KEYS`
    exactly — single source of truth invariant per CONTEXT D-09 + plan
    Task 1.1 acceptance criterion.
    """
    from app.api.v1.endpoints.coach_chat import _SAVE_FACT_ALLOWED_KEYS

    schema_keys = set(typing.get_args(_ALLOWED_FACT_KEYS))
    assert schema_keys == _SAVE_FACT_ALLOWED_KEYS, (
        "extractor_schema._ALLOWED_FACT_KEYS drifted from "
        "coach_chat._SAVE_FACT_ALLOWED_KEYS. "
        f"Missing in schema: {_SAVE_FACT_ALLOWED_KEYS - schema_keys}. "
        f"Extra in schema: {schema_keys - _SAVE_FACT_ALLOWED_KEYS}."
    )
