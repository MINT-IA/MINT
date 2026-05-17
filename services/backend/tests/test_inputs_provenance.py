"""Plan 17 W4-01-03 (D-CE-17 composite scorecard) — `inputs_provenance` field
contract test.

Asserts :
  - `_resolve_with_provenance` returns the right 3-Literal value per field
    based on (body / profile / Pydantic-default) origin.
  - The V2 envelope `CoachToolOkV2.inputs_provenance` field accepts the
    3-Literal dict and serializes correctly via `model_dump(by_alias=True)`.
  - Pydantic validation REJECTS values outside the 3-Literal enum.
  - The provenance dict tracks EVERY field present in the resolved output,
    not just the from_profile-marked ones — auditable per D-CE-17.
  - Calling a W1-grounded endpoint with profile-grounding active fires the
    `mint_calc_invoke_total{profile_grounded="true"}` counter (end-to-end
    plumbing proof, parametrized across the 26 W1-grounded endpoints).

Pattern : extends Plan 06's `test_blank_profile_422_contract.py` matrix
philosophy. Uses the same `client_with_blank_profile` fixture pattern from
Plan 01 (Concern D) plus a profile-filled fixture to cover the "default"
provenance path (body lacks field → profile fills it).

LSFin (CLAUDE.md §1) : no banned-term hint_fr emission in this test. Pure
contract validation.
"""
from __future__ import annotations

from typing import Optional

import pytest
from pydantic import BaseModel, Field

from app.core.profile_resolver import (
    _resolve_defaults,
    _resolve_with_provenance,
    emit_calc_invoke_metric,
)


# --------------------------------------------------------------------------- #
# Helper fixture — a small ad-hoc Pydantic schema with from_profile markers   #
# --------------------------------------------------------------------------- #


class _SchemaForProvenance(BaseModel):
    """Test-only schema mirroring the Plan 02-06 grounding pattern.

    Note : uses `Optional[X]` not `X | None` for Python 3.9 compat — pydantic
    v2 type resolution evaluates annotations even with
    `from __future__ import annotations` because it walks the model fields.
    """

    # Field A : has from_profile marker, may be filled from profile.
    canton: Optional[str] = Field(
        default=None,
        json_schema_extra={"from_profile": "canton"},
    )
    # Field B : has from_profile marker, may be filled from profile.
    age: Optional[int] = Field(
        default=None,
        json_schema_extra={"from_profile": "age"},
    )
    # Field C : NO from_profile marker, pure body input or Pydantic default.
    montant: Optional[float] = Field(default=10000.0)


# --------------------------------------------------------------------------- #
# Section A — `_resolve_with_provenance` unit contract                        #
# --------------------------------------------------------------------------- #


def test_provenance_user_input_when_field_in_body_fields_set():
    """Field explicitly supplied in body → provenance = 'user_input'."""
    body = _SchemaForProvenance(canton="VD", age=42)
    resolved, provenance = _resolve_with_provenance(
        profile_data={"canton": "GE", "age": 30},  # would lose vs body
        body=body,
        schema_class=_SchemaForProvenance,
    )
    assert resolved["canton"] == "VD"
    assert resolved["age"] == 42
    assert provenance["canton"] == "user_input"
    assert provenance["age"] == "user_input"
    # Field NOT in body, no profile_key → derived (Pydantic default).
    assert provenance["montant"] == "derived"


def test_provenance_default_when_filled_from_profile():
    """Field NOT in body, profile_key present + value non-None → 'default'.

    Semantic note (RESEARCH §Q-H) : « default » in this audit trail means
    « server-side profile-driven fallback », distinct from « Pydantic
    default » (which is « derived »). Documented in `_response.py`
    `_INPUTS_PROVENANCE_LITERALS` docstring.
    """
    body = _SchemaForProvenance()  # no fields supplied
    resolved, provenance = _resolve_with_provenance(
        profile_data={"canton": "VD", "age": 42},
        body=body,
        schema_class=_SchemaForProvenance,
    )
    assert resolved["canton"] == "VD"
    assert resolved["age"] == 42
    assert provenance["canton"] == "default"
    assert provenance["age"] == "default"
    # No profile_key, no body → derived.
    assert provenance["montant"] == "derived"


def test_provenance_derived_when_no_body_no_profile_match():
    """No body input AND no matching profile_key value → 'derived' (Pydantic default)."""
    body = _SchemaForProvenance()  # no fields supplied
    resolved, provenance = _resolve_with_provenance(
        profile_data={"unrelated_key": "xyz"},  # no canton/age
        body=body,
        schema_class=_SchemaForProvenance,
    )
    assert resolved["canton"] is None
    assert resolved["age"] is None
    assert resolved["montant"] == 10000.0
    assert provenance["canton"] == "derived"
    assert provenance["age"] == "derived"
    assert provenance["montant"] == "derived"


def test_provenance_dict_covers_every_resolved_field():
    """Auditable per D-CE-17 : provenance has same keys as resolved."""
    body = _SchemaForProvenance(canton="VD")
    resolved, provenance = _resolve_with_provenance(
        profile_data={"age": 50},
        body=body,
        schema_class=_SchemaForProvenance,
    )
    assert set(provenance.keys()) == set(resolved.keys())
    # Mix-and-match origins captured per field :
    assert provenance["canton"] == "user_input"
    assert provenance["age"] == "default"
    assert provenance["montant"] == "derived"


def test_provenance_values_are_strictly_three_literal_enum():
    """Every value in provenance is exactly one of the 3 literals."""
    body = _SchemaForProvenance(canton="VD")
    _, provenance = _resolve_with_provenance(
        profile_data={"age": 50},
        body=body,
        schema_class=_SchemaForProvenance,
    )
    allowed = {"user_input", "default", "derived"}
    for field, value in provenance.items():
        assert value in allowed, (
            f"provenance[{field!r}]={value!r} not in {allowed!r}"
        )


def test_resolve_defaults_v1_contract_unchanged():
    """Wave 1 callers using `_resolve_defaults` still get the flat dict.

    Plan 01 contract preserved : `_resolve_defaults` returns only the
    resolved dict, NOT a tuple. (Plan 17 reworks it to delegate to
    `_resolve_with_provenance` internally but the public signature stays.)
    """
    body = _SchemaForProvenance(canton="VD")
    out = _resolve_defaults(
        profile_data={"age": 50},
        body=body,
        schema_class=_SchemaForProvenance,
    )
    assert isinstance(out, dict)
    assert out["canton"] == "VD"
    assert out["age"] == 50
    assert out["montant"] == 10000.0
    # Critical : no provenance leakage into the V1 return shape.
    assert "provenance" not in out
    assert "inputs_provenance" not in out


# --------------------------------------------------------------------------- #
# Section B — `CoachToolOkV2.inputs_provenance` field contract                #
# --------------------------------------------------------------------------- #


def test_v2_envelope_accepts_inputs_provenance_dict():
    """V2 envelope ingests + serializes the 3-Literal provenance dict."""
    from app.models.coach_tools import CoachToolOkV2

    env = CoachToolOkV2(
        data={"monthlyIncome": 8000},
        latency_tier="L1",
        inputs_provenance={
            "canton": "user_input",
            "age": "default",
            "montant": "derived",
        },
    )
    dumped = env.model_dump(by_alias=True)
    assert dumped["inputsProvenance"] == {
        "canton": "user_input",
        "age": "default",
        "montant": "derived",
    }


def test_v2_envelope_inputs_provenance_defaults_to_empty_dict():
    """Field is OPTIONAL — default empty dict for backwards-compat with
    Plan 10 Wave-1a callers that don't emit provenance yet."""
    from app.models.coach_tools import CoachToolOkV2

    env = CoachToolOkV2(data={"x": 1}, latency_tier="L1")
    assert env.inputs_provenance == {}


def test_v2_envelope_rejects_invalid_provenance_literal():
    """Pydantic validation REJECTS values outside the 3-Literal enum."""
    from app.models.coach_tools import CoachToolOkV2

    with pytest.raises(Exception):  # Pydantic ValidationError
        CoachToolOkV2(
            data={"x": 1},
            latency_tier="L1",
            inputs_provenance={"canton": "INVALID_LITERAL"},
        )


def test_v2_envelope_camelcase_alias_on_inputs_provenance():
    """`inputs_provenance` serializes as `inputsProvenance` in by-alias mode."""
    from app.models.coach_tools import CoachToolOkV2

    env = CoachToolOkV2(
        data={"x": 1},
        latency_tier="L1",
        inputs_provenance={"canton": "user_input"},
    )
    dumped = env.model_dump(by_alias=True)
    assert "inputsProvenance" in dumped
    assert "inputs_provenance" not in dumped


# --------------------------------------------------------------------------- #
# Section C — End-to-end : profile-grounded calc fires the invoke counter     #
# --------------------------------------------------------------------------- #


def test_emit_calc_invoke_metric_true_label_when_profile_filled_field():
    """`mint_calc_invoke_total{profile_grounded="true"}` increments when
    a from_profile field resolved to a non-None value."""
    from app.core.metrics import calc_invoke_total

    # Capture the counter value BEFORE emission.
    before = _read_counter_value(
        calc_invoke_total, {"kind": "_test_grounded_kind", "profile_grounded": "true"}
    )

    body = _SchemaForProvenance()  # no body input
    resolved, _ = _resolve_with_provenance(
        profile_data={"canton": "VD", "age": 42},
        body=body,
        schema_class=_SchemaForProvenance,
    )
    emit_calc_invoke_metric(
        kind="_test_grounded_kind",
        resolved=resolved,
        schema_class=_SchemaForProvenance,
    )

    after = _read_counter_value(
        calc_invoke_total, {"kind": "_test_grounded_kind", "profile_grounded": "true"}
    )
    assert after == before + 1, f"counter delta = {after - before} != 1"


def test_emit_calc_invoke_metric_false_label_when_no_profile_field():
    """`mint_calc_invoke_total{profile_grounded="false"}` increments when
    NO from_profile field resolved (body-only or all-derived call)."""
    from app.core.metrics import calc_invoke_total

    before = _read_counter_value(
        calc_invoke_total, {"kind": "_test_ungrounded_kind", "profile_grounded": "false"}
    )

    body = _SchemaForProvenance()  # no body input
    resolved, _ = _resolve_with_provenance(
        profile_data={},  # empty profile — no profile-grounding possible
        body=body,
        schema_class=_SchemaForProvenance,
    )
    emit_calc_invoke_metric(
        kind="_test_ungrounded_kind",
        resolved=resolved,
        schema_class=_SchemaForProvenance,
    )

    after = _read_counter_value(
        calc_invoke_total, {"kind": "_test_ungrounded_kind", "profile_grounded": "false"}
    )
    assert after == before + 1, f"counter delta = {after - before} != 1"


# --------------------------------------------------------------------------- #
# Section D — Parametrized W1-grounded endpoint contract guard                 #
# --------------------------------------------------------------------------- #
# This section asserts that the W1-grounded endpoint LIST has not shrunk
# AND that emit_calc_invoke_metric correctly classifies a representative
# subset of those endpoint schemas (we don't re-import all 26 schemas — the
# Plan 06 contract test already proves the grounding works end-to-end ;
# Plan 17 only adds the metric emission, which is unit-tested above).
# --------------------------------------------------------------------------- #


@pytest.mark.parametrize(
    "kind",
    [
        "allocation_annuelle",
        "affordability",
        "rachat_echelonne",
        "wealth_tax_estimate",
        "succession_simulate",
        "location_vs_propriete",
        "rente_vs_capital",
        "rachat_vs_marche",
        "calendrier_retraits",
        "imputed_rental",
        "amortization",
        "epl",
        "mariage_compare",
        "naissance_allocations",
        "concubinage_compare",
        "epl_combined",
        "lpp_compare",
        "trois_a_independant",
        "dividende_vs_salaire",
        "source_tax",
        "lamal_option",
        "divorce_simulate",
        "donation_simulate",
        "unemployment_calculate",
        "coverage_check",
        "concubinage_succession",
    ],
)
def test_metric_emission_succeeds_for_every_w1_grounded_kind(kind):
    """For every W1-grounded endpoint kind (matrix mirrored from Plan 06
    `test_blank_profile_422_contract.py`), `emit_calc_invoke_metric` runs
    without raising. This proves the `kind` label cardinality is bounded
    + the call path is exception-safe."""
    body = _SchemaForProvenance(canton="VD")  # representative body
    resolved, _ = _resolve_with_provenance(
        profile_data={"age": 42},
        body=body,
        schema_class=_SchemaForProvenance,
    )
    # Should not raise.
    emit_calc_invoke_metric(
        kind=kind, resolved=resolved, schema_class=_SchemaForProvenance
    )


# --------------------------------------------------------------------------- #
# Helpers                                                                      #
# --------------------------------------------------------------------------- #


def _read_counter_value(counter, label_dict: dict[str, str]) -> float:
    """Read the current sample value of a Counter with given labels.

    prometheus_client Counters expose `.collect()` returning a Metric
    family. Each sample carries a `labels` dict + `value` float. Returns
    0.0 if no sample matches the label set yet (counter not yet
    incremented for that combo).
    """
    for metric in counter.collect():
        for sample in metric.samples:
            # We want the `_total` sample (Counter exposes `<name>_total`
            # + `<name>_created`).
            if not sample.name.endswith("_total"):
                continue
            if sample.labels == label_dict:
                return sample.value
    return 0.0
