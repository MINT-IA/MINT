"""Round-trip tests for the Plan 08a-01 ResponseCard confidence field."""

from __future__ import annotations

import pytest

from app.schemas.enhanced_confidence import EnhancedConfidence
from app.schemas.response_card import (
    CardCtaSchema,
    PremierEclairageSchema,
    ResponseCard,
)


def _base_card_kwargs() -> dict:
    return dict(
        id="rc-1",
        type="lppBuyback",
        title="Rachat LPP",
        subtitle="Économie fiscale estimée",
        premier_eclairage=PremierEclairageSchema(
            value=12450.0, unit="CHF", explanation="Économie fiscale estimée"
        ),
        cta=CardCtaSchema(label="Simuler un rachat", route="/rachat-lpp"),
        urgency="medium",
        disclaimer="Outil éducatif — ne constitue pas un conseil (LSFin).",
        sources=["LPP art. 14"],
        alertes=[],
        impact_points=10,
        category="prevoyance",
        impact_chf=12450.0,
    )


def test_enhanced_confidence_wire_shape_camel_case():
    conf = EnhancedConfidence(
        completeness=0.8,
        accuracy=0.9,
        freshness=0.7,
        understanding=0.6,
        score=0.74,
    )
    dumped = conf.model_dump(by_alias=True)
    assert dumped == {
        "completeness": 0.8,
        "accuracy": 0.9,
        "freshness": 0.7,
        "understanding": 0.6,
        "score": 0.74,
    }


def test_enhanced_confidence_round_trip():
    payload = {
        "completeness": 0.72,
        "accuracy": 0.85,
        "freshness": 0.91,
        "understanding": 0.60,
        "score": 0.76,
    }
    conf = EnhancedConfidence.model_validate(payload)
    assert conf.model_dump(by_alias=True) == payload


def test_response_card_default_confidence_is_none():
    card = ResponseCard(**_base_card_kwargs())
    assert card.confidence is None
    dumped = card.model_dump(by_alias=True, exclude_none=True)
    assert "confidence" not in dumped


def test_response_card_with_confidence_round_trip():
    kwargs = _base_card_kwargs()
    kwargs["confidence"] = EnhancedConfidence(
        completeness=0.8,
        accuracy=0.9,
        freshness=0.7,
        understanding=0.6,
        score=0.74,
    )
    card = ResponseCard(**kwargs)
    dumped = card.model_dump(by_alias=True, exclude_none=True)
    assert dumped["confidence"] == {
        "completeness": 0.8,
        "accuracy": 0.9,
        "freshness": 0.7,
        "understanding": 0.6,
        "score": 0.74,
    }
    # Re-validate (round-trip).
    rebuilt = ResponseCard.model_validate(dumped)
    assert rebuilt.confidence is not None
    assert rebuilt.confidence.completeness == pytest.approx(0.8)
    assert rebuilt.confidence.score == pytest.approx(0.74)
    assert rebuilt.model_dump(by_alias=True, exclude_none=True) == dumped


def test_response_card_accepts_explicit_null_confidence():
    kwargs = _base_card_kwargs()
    kwargs["confidence"] = None
    card = ResponseCard(**kwargs)
    assert card.confidence is None


def test_response_card_validates_camel_case_payload():
    payload = {
        "id": "rc-2",
        "type": "pillar3a",
        "title": "Versement 3a",
        "subtitle": "Avant le 31.12",
        "premierEclairage": {
            "value": 7258.0,
            "unit": "CHF",
            "explanation": "Plafond annuel salarié LPP",
        },
        "cta": {"label": "Planifier", "route": "/3a/versement"},
        "urgency": "high",
        "disclaimer": "Outil éducatif — ne constitue pas un conseil (LSFin).",
        "sources": ["OPP3 art. 7"],
        "alertes": [],
        "impactPoints": 5,
        "category": "fiscalite",
        "impactChf": 1800.0,
        "confidence": {
            "completeness": 0.5,
            "accuracy": 0.6,
            "freshness": 0.7,
            "understanding": 0.4,
            "score": 0.55,
        },
    }
    card = ResponseCard.model_validate(payload)
    assert card.confidence is not None
    assert card.confidence.understanding == pytest.approx(0.4)
    # Re-emit and verify the confidence subtree matches the input.
    dumped = card.model_dump(by_alias=True, exclude_none=True)
    assert dumped["confidence"] == payload["confidence"]
