"""NumericSanity tests — Phase 29-04 / PRIV-05.

Verifies the deterministic bounds reject impossible Vision-extracted
values and flag rare-but-legal ones for human review.
"""
from __future__ import annotations

from decimal import Decimal

import pytest

from app.services.compliance import numeric_sanity as ns


class _Field:
    """Duck-typed stand-in for ExtractedField (works the same way)."""

    def __init__(self, field_name, value):
        self.field_name = field_name
        self.value = value


# ---------------------------------------------------------------------------
# Reject bounds.
# ---------------------------------------------------------------------------


def test_rendement_15pct_rejected():
    v = ns.check([_Field("rendement", 0.15)])
    assert v.has_reject
    assert v.fields["rendement"] == "reject"
    assert v.rejects[0].value == Decimal("0.15")
    assert "rendement" in v.rejects[0].bound.lower()


def test_rendement_7_99pct_boundary_ok():
    v = ns.check([_Field("rendement", 0.0799)])
    assert not v.has_reject
    assert v.fields["rendement"] == "ok"


def test_rendement_exactly_8pct_ok():
    # Predicate is strict > 0.08, so 0.08 itself stays ok (OFAS max).
    v = ns.check([_Field("rendement", 0.08)])
    assert not v.has_reject


def test_salaire_3M_rejected():
    v = ns.check([_Field("salaireAssure", 3_000_000)])
    assert v.has_reject
    assert v.rejects[0].field_name == "salaireAssure"


def test_salaire_1_99M_boundary_ok():
    v = ns.check([_Field("salaireBrutAnnuel", 1_990_000)])
    assert not v.has_reject


def test_taux_conversion_8pct_rejected():
    v = ns.check([_Field("tauxConversion", 0.08)])
    assert v.has_reject


def test_taux_conversion_legal_68pct_ok():
    v = ns.check([_Field("tauxConversion", 0.068)])
    assert not v.has_reject


# ---------------------------------------------------------------------------
# Human-review bounds.
# ---------------------------------------------------------------------------


def test_avoir_lpp_6M_human_review_not_reject():
    v = ns.check([_Field("avoirLppTotal", 6_000_000)])
    assert not v.has_reject
    assert v.has_human_review
    assert v.fields["avoirLppTotal"] == "human_review"


def test_avoir_lpp_4_99M_ok():
    v = ns.check([_Field("avoirLppTotal", 4_990_000)])
    assert not v.has_reject
    assert not v.has_human_review


# ---------------------------------------------------------------------------
# Non-numeric / non-bounded fields pass through.
# ---------------------------------------------------------------------------


def test_non_numeric_value_ok():
    v = ns.check([_Field("rendement", "n/a")])
    assert not v.has_reject
    assert v.fields["rendement"] == "ok"


def test_unbounded_field_ok():
    v = ns.check([_Field("dureeContrat", "12 mois")])
    assert not v.has_reject


def test_swiss_thousands_separator_parsed():
    v = ns.check([_Field("salaireAssure", "3'000'000 CHF")])
    assert v.has_reject, "Swiss 3'000'000 must be parsed and rejected"


# ---------------------------------------------------------------------------
# Batch behaviour.
# ---------------------------------------------------------------------------


def test_mixed_batch_reports_all_violations():
    v = ns.check([
        _Field("rendement", 0.15),          # reject
        _Field("salaireAssure", 150_000),   # ok
        _Field("avoirLppTotal", 7_000_000), # human_review
        _Field("tauxConversion", 0.09),     # reject
    ])
    assert len(v.rejects) == 2
    assert len(v.human_reviews) == 1
    reject_names = {r.field_name for r in v.rejects}
    assert reject_names == {"rendement", "tauxConversion"}
