"""MoneyTruthReceipt v1 — tests de contrat + producteur (Tranche firstJob PR-B).

Couvre la doctrine de type (extra=forbid, frozen, bornes, littéraux, champs
requis pour le claim firstjob.net_salary.v1) et le producteur backend
(onboarding_service). La parité cross-language (py<->dart) est verrouillée
séparément par test_money_truth_receipt_parity.py.
"""
from __future__ import annotations

import math

import pytest
from pydantic import ValidationError

from app.models.lucidity.money_truth_receipt import (
    FIRST_JOB_NET_SALARY_CLAIM_ID,
    MoneyTruthRange,
    MoneyTruthReceipt,
    MoneyTruthSource,
)
from app.schemas.enhanced_confidence import EnhancedConfidence
from app.services.coach.inputs_hash import compute_inputs_hash
from app.services.first_job.onboarding_service import (
    build_first_job_net_salary_receipt,
)

_HASH64 = "0" * 64


def _valid_kwargs(**overrides):
    base = dict(
        claim_id="generic.value.v1",
        receipt_id="rid-1",
        inputs={"a": 1.0},
        inputs_hash=_HASH64,
        jurisdiction="CH-VD",
        tax_year=2026,
        base="net",
        civil_status="celibataire",
        assumptions=["h1"],
        engine="test.engine",
        engine_version="v1",
        rounding="CHF arrondi au 1 franc",
        sources=[MoneyTruthSource(id="s", label="Source", vintage=2026)],
        value=1000.0,
        range=None,
        confidence=None,
        computed_at="2026-07-29T00:00:00+00:00",
    )
    base.update(overrides)
    return base


# ── Doctrine de type ────────────────────────────────────────────────


def test_valid_generic_receipt_constructs():
    r = MoneyTruthReceipt(**_valid_kwargs())
    assert r.value == 1000.0
    assert r.range is None  # nullable pour un claim générique


def test_extra_field_forbidden():
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(**_valid_kwargs(unexpected_field="x"))


def test_ranking_field_impossible():
    # extra=forbid -> aucun nom de champ de classement à peupler (LSFin).
    for banned in ("recommended_option", "best_choice", "optimal_choice", "top_pick"):
        with pytest.raises(ValidationError):
            MoneyTruthReceipt(**_valid_kwargs(**{banned: "A"}))


def test_frozen_rejects_mutation():
    r = MoneyTruthReceipt(**_valid_kwargs())
    with pytest.raises(ValidationError):
        r.value = 2000.0


def test_tax_year_out_of_bounds_rejected():
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(**_valid_kwargs(tax_year=1899))
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(**_valid_kwargs(tax_year=2101))


def test_sources_min_length_enforced():
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(**_valid_kwargs(sources=[]))


def test_base_literal_closed():
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(**_valid_kwargs(base="mixte"))


def test_inputs_hash_must_be_64_chars():
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(**_valid_kwargs(inputs_hash="deadbeef"))


def test_range_low_must_be_le_high():
    with pytest.raises(ValidationError):
        MoneyTruthRange(low=100.0, high=50.0)


def test_net_salary_claim_requires_range():
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(
            **_valid_kwargs(
                claim_id=FIRST_JOB_NET_SALARY_CLAIM_ID,
                range=None,
                confidence=EnhancedConfidence(
                    completeness=1.0, accuracy=0.9, freshness=1.0,
                    understanding=0.5, score=0.8,
                ),
            )
        )


def test_net_salary_claim_requires_confidence():
    with pytest.raises(ValidationError):
        MoneyTruthReceipt(
            **_valid_kwargs(
                claim_id=FIRST_JOB_NET_SALARY_CLAIM_ID,
                range=MoneyTruthRange(low=900.0, high=1100.0),
                confidence=None,
            )
        )


def test_generic_claim_allows_null_range_and_confidence():
    # Le validateur n'exige range/confidence que pour firstjob.net_salary.v1.
    r = MoneyTruthReceipt(**_valid_kwargs(claim_id="other.claim.v1"))
    assert r.range is None and r.confidence is None


def test_camelcase_serialization():
    r = MoneyTruthReceipt(**_valid_kwargs())
    d = r.model_dump(by_alias=True)
    for k in ("claimId", "receiptId", "inputsHash", "taxYear", "civilStatus",
              "engineVersion", "computedAt"):
        assert k in d, f"clé camelCase manquante : {k}"


# ── Producteur backend (claim firstjob.net_salary.v1) ───────────────


def test_producer_emits_net_salary_claim():
    r = build_first_job_net_salary_receipt(6500, "vd", 30)
    assert r.claim_id == FIRST_JOB_NET_SALARY_CLAIM_ID
    assert r.base == "net"
    assert r.jurisdiction == "CH-VD"  # canton normalisé en majuscules
    assert r.tax_year == 2026
    assert r.range is not None and r.confidence is not None


def test_producer_inputs_hash_reuses_compute_inputs_hash():
    r = build_first_job_net_salary_receipt(6500, "ZH", 30, "celibataire", 100.0)
    expected = compute_inputs_hash(r.inputs)
    assert r.inputs_hash == expected
    assert len(r.inputs_hash) == 64


def test_producer_value_within_band():
    r = build_first_job_net_salary_receipt(6788, "GE", 30)
    assert r.range.low <= r.value <= r.range.high
    assert r.range.low < r.range.high  # bande non dégénérée


def test_producer_confidence_is_geometric_mean():
    r = build_first_job_net_salary_receipt(6500, "VD", 30)
    c = r.confidence
    for axis in (c.completeness, c.accuracy, c.freshness, c.understanding, c.score):
        assert 0.0 <= axis <= 1.0
    expected = (c.completeness * c.accuracy * c.freshness * c.understanding) ** 0.25
    assert math.isclose(c.score, expected, rel_tol=1e-9)


def test_producer_inputs_normalized_keys():
    r = build_first_job_net_salary_receipt(6500, "vd", 30, "Celibataire", 80.0)
    assert set(r.inputs.keys()) == {
        "salaireBrutMensuel", "age", "canton", "tauxActivite", "etatCivil",
    }
    assert r.inputs["canton"] == "VD"
    assert r.inputs["etatCivil"] == "celibataire"


def test_producer_no_ranking_language_in_sources():
    r = build_first_job_net_salary_receipt(6500, "VD", 30)
    joined = " ".join(s.label.lower() for s in r.sources)
    for banned in ("optimal", "meilleur", "garanti", "recommand"):
        assert banned not in joined
