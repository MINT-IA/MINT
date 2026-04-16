"""Phase 28-01 / Task 3a: render_mode selector matrix tests."""
from __future__ import annotations

import pytest

from app.schemas.document_understanding import (
    ConfidenceLevel,
    CoherenceWarning,
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractedField,
    ExtractionStatus,
    RenderMode,
)
from app.services.document_render_mode import (
    HIGH_STAKES,
    needs_full_review,
    select_render_mode,
)


def _make(
    *,
    overall: float = 0.9,
    status: ExtractionStatus = ExtractionStatus.success,
    fields: list[ExtractedField] | None = None,
    warnings: list[CoherenceWarning] | None = None,
    plan_type: str | None = None,
) -> DocumentUnderstandingResult:
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.9,
        extracted_fields=fields or [],
        overall_confidence=overall,
        extraction_status=status,
        coherence_warnings=warnings or [],
        plan_type=plan_type,
        render_mode=RenderMode.confirm,  # placeholder, recomputed by selector
    )


def _field(name: str, value: float, conf: ConfidenceLevel = ConfidenceLevel.high) -> ExtractedField:
    return ExtractedField(field_name=name, value=value, confidence=conf, source_text=name)


# ── reject branches ─────────────────────────────────────────────────────────

def test_non_financial_rejects():
    r = _make(status=ExtractionStatus.non_financial, overall=0.0)
    assert select_render_mode(r) == RenderMode.reject


def test_rejected_local_rejects():
    r = _make(status=ExtractionStatus.rejected_local, overall=0.0)
    assert select_render_mode(r) == RenderMode.reject


def test_overall_below_floor_rejects():
    r = _make(overall=0.4, fields=[_field("a", 1)])
    assert select_render_mode(r) == RenderMode.reject


# ── narrative branches ──────────────────────────────────────────────────────

def test_parse_error_narrates():
    r = _make(status=ExtractionStatus.parse_error, overall=0.0)
    assert select_render_mode(r) == RenderMode.narrative


def test_no_fields_found_narrates():
    r = _make(status=ExtractionStatus.no_fields_found, overall=0.0)
    assert select_render_mode(r) == RenderMode.narrative


def test_encrypted_narrates():
    r = _make(status=ExtractionStatus.encrypted_needs_password, overall=0.0)
    assert select_render_mode(r) == RenderMode.narrative


def test_medium_overall_narrates():
    fields = [_field(f"f{i}", i, ConfidenceLevel.low) for i in range(5)]
    r = _make(overall=0.65, fields=fields)
    assert select_render_mode(r) == RenderMode.narrative


# ── confirm branch ──────────────────────────────────────────────────────────

def test_high_overall_all_high_conf_confirms():
    fields = [_field(f"f{i}", i, ConfidenceLevel.high) for i in range(5)]
    r = _make(overall=0.95, fields=fields)
    assert select_render_mode(r) == RenderMode.confirm


def test_confirm_blocked_by_coherence_warning():
    fields = [_field(f"f{i}", i, ConfidenceLevel.high) for i in range(5)]
    warns = [CoherenceWarning(code="lpp_total_mismatch", message="..", fields=["a"])]
    r = _make(overall=0.95, fields=fields, warnings=warns)
    assert select_render_mode(r) != RenderMode.confirm


def test_confirm_blocked_by_too_many_fields():
    fields = [_field(f"f{i}", i, ConfidenceLevel.high) for i in range(9)]
    r = _make(overall=0.95, fields=fields)
    # >8 fields → no confirm; falls through to ask path (no fields_below) — fails the 1<=below<=2 guard, becomes narrative
    assert select_render_mode(r) == RenderMode.narrative


# ── ask branch ──────────────────────────────────────────────────────────────

def test_ask_when_one_below_no_high_stakes():
    fields = [
        _field("salaireBrutMensuel", 1000, ConfidenceLevel.high),
        _field("description", 0, ConfidenceLevel.medium),  # below high, not high-stakes
    ]
    r = _make(overall=0.80, fields=fields)
    assert select_render_mode(r) == RenderMode.ask


def test_ask_blocked_by_high_stakes_low_conf():
    fields = [
        _field("avoirLppTotal", 70000, ConfidenceLevel.medium),  # HIGH_STAKES + below high
    ]
    r = _make(overall=0.80, fields=fields)
    assert select_render_mode(r) != RenderMode.ask
    # Falls through to narrative (overall>=0.60)
    assert select_render_mode(r) == RenderMode.narrative


# ── needs_full_review ───────────────────────────────────────────────────────

def test_needs_review_high_stakes_low_conf():
    fields = [_field("avoirLppTotal", 70000, ConfidenceLevel.low)]
    r = _make(overall=0.85, fields=fields)
    assert needs_full_review(r) is True


def test_needs_review_plan_1e():
    fields = [_field("salaireAssure", 91000, ConfidenceLevel.high)]
    r = _make(overall=0.95, fields=fields, plan_type="1e")
    assert needs_full_review(r) is True


def test_needs_review_low_overall():
    fields = [_field("description", 0, ConfidenceLevel.high)]
    r = _make(overall=0.70, fields=fields)
    assert needs_full_review(r) is True


def test_no_review_clean_high_conf():
    fields = [_field("description", 0, ConfidenceLevel.high)]
    r = _make(overall=0.95, fields=fields)
    assert needs_full_review(r) is False


def test_high_stakes_constants_match_research():
    # Sanity check — HIGH_STAKES must contain the 6 fields the research §4 lists
    expected = {
        "avoirLppTotal", "tauxConversion", "rachatMaximum",
        "salaireAssure", "revenuImposable", "fortuneImposable",
    }
    assert HIGH_STAKES == expected
