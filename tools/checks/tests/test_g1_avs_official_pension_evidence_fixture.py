from __future__ import annotations

from collections import Counter
from datetime import date
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
FIXTURE = ROOT / "tests/fixtures/avs_official_pension_evidence_cases.json"
FACT_FIELDS = {
    "canonical_key",
    "value_chf_month",
    "source",
    "source_date",
    "evidence_kind",
}
EXPECTED_FIELDS = FACT_FIELDS | {"rejection_reason"}
POSITIVE_IDS = [f"P{index:02d}" for index in range(1, 13)]
NEGATIVE_IDS = [f"N{index:02d}" for index in range(1, 29)]
EXPECTED_EVIDENCE_KINDS = {
    "P01": "official_decision",
    "P02": "official_forecast",
    "P03": "official_statement",
    "P04": "official_decision",
    "P05": "official_forecast",
    "P06": "official_statement",
    "P07": "official_decision",
    "P08": "official_forecast",
    "P09": "official_statement",
    "P10": "official_forecast",
    "P11": "official_forecast",
    "P12": "official_forecast",
}


def _load_fixture() -> dict[str, object]:
    assert FIXTURE.is_file(), f"missing shared AVS evidence fixture: {FIXTURE}"
    with FIXTURE.open(encoding="utf-8") as stream:
        payload = json.load(stream)
    assert isinstance(payload, dict)
    return payload


def _case_map() -> dict[str, dict[str, object]]:
    payload = _load_fixture()
    cases = payload["cases"]
    assert isinstance(cases, list)
    return {case["id"]: case for case in cases}


def test_fixture_schema_and_case_inventory_are_exact() -> None:
    payload = _load_fixture()

    assert set(payload) == {"schema_version", "data_classification", "cases"}
    assert payload["schema_version"] == 2
    assert payload["data_classification"] == "synthetic_no_pii"

    cases = payload["cases"]
    assert isinstance(cases, list)
    assert len(cases) == 40
    assert [case["id"] for case in cases] == POSITIVE_IDS + NEGATIVE_IDS

    for case in cases:
        assert set(case) == {"id", "language", "category", "input", "expected"}
        assert case["language"] in {"fr", "de", "it"}
        assert isinstance(case["category"], str) and case["category"]
        assert isinstance(case["input"], str) and case["input"].strip()
        assert "\n" not in case["input"]
        assert set(case["expected"]) == EXPECTED_FIELDS


def test_twelve_multilingual_positives_are_certificate_facts() -> None:
    cases = _case_map()
    positives = [cases[case_id] for case_id in POSITIVE_IDS]

    assert Counter(case["language"] for case in positives) == {
        "fr": 4,
        "de": 4,
        "it": 4,
    }
    assert {
        case["id"]: (
            case["category"],
            case["expected"]["value_chf_month"],
            case["expected"]["source_date"],
        )
        for case in positives
    } == {
        "P01": ("personal_decision", 1842, "2026-02-14"),
        "P02": ("personal_min_equal", 1260, "2026-03-03"),
        "P03": ("personal_statement", 2137, "2026-04-21"),
        "P04": ("personal_decision", 2017, "2026-02-06"),
        "P05": ("personal_forecast", 1674, "2026-03-18"),
        "P06": ("personal_statement", 2284, "2026-04-30"),
        "P07": ("personal_max_equal", 2520, "2026-02-11"),
        "P08": ("personal_forecast", 1763, "2026-03-19"),
        "P09": ("personal_statement", 1996, "2026-05-07"),
        "P10": ("personal_forecast", 1900, "2026-03-12"),
        "P11": ("personal_forecast", 1910, "2026-03-13"),
        "P12": ("personal_forecast", 1920, "2026-03-14"),
    }

    for case in positives:
        expected = case["expected"]
        assert expected["canonical_key"] == "avs_official_monthly_pension"
        assert isinstance(expected["value_chf_month"], (int, float))
        assert not isinstance(expected["value_chf_month"], bool)
        assert expected["value_chf_month"] > 0
        assert expected["source"] == "certificate"
        assert expected["evidence_kind"] == EXPECTED_EVIDENCE_KINDS[case["id"]]
        assert expected["rejection_reason"] is None
        date.fromisoformat(expected["source_date"])


def test_evidence_kind_preserves_epistemic_status_independently_of_source() -> None:
    cases = _case_map()

    assert {
        case_id: cases[case_id]["expected"]["evidence_kind"]
        for case_id in POSITIVE_IDS
    } == EXPECTED_EVIDENCE_KINDS
    assert {
        cases[case_id]["expected"]["source"] for case_id in POSITIVE_IDS
    } == {"certificate"}

    known_after_review = {
        case_id
        for case_id in POSITIVE_IDS
        if cases[case_id]["expected"]["evidence_kind"]
        in {"official_decision", "official_statement"}
    }
    still_estimated_or_to_verify = set(POSITIVE_IDS) - known_after_review

    assert known_after_review == {"P01", "P03", "P04", "P06", "P07", "P09"}
    assert still_estimated_or_to_verify == {
        "P02",
        "P05",
        "P08",
        "P10",
        "P11",
        "P12",
    }


def test_expanded_forecast_markers_remain_estimated_to_verify() -> None:
    cases = _case_map()
    expanded_forecast_markers = {
        "P10": ("estimation", "prévisionnel"),
        "P11": ("rentenschätzung", "voraussichtliche"),
        "P12": ("stima", "previsto"),
    }

    for case_id, markers in expanded_forecast_markers.items():
        case = cases[case_id]
        normalized_input = case["input"].lower()

        assert all(marker in normalized_input for marker in markers)
        assert case["category"] == "personal_forecast"
        assert case["expected"]["evidence_kind"] == "official_forecast"


def test_twenty_eight_negatives_fail_closed_with_oracle_reason() -> None:
    cases = _case_map()
    negatives = [cases[case_id] for case_id in NEGATIVE_IDS]

    assert {case["language"] for case in negatives} == {"fr", "de", "it"}
    for case in negatives:
        expected = case["expected"]
        assert all(expected[field] is None for field in FACT_FIELDS)
        assert expected["rejection_reason"] == case["category"]


def test_equal_numeric_values_do_not_decide_certification() -> None:
    cases = _case_map()

    assert cases["P02"]["expected"]["value_chf_month"] == 1260
    assert "1 260" in cases["P02"]["input"]
    assert cases["P07"]["expected"]["value_chf_month"] == 2520
    assert "2’520" in cases["P07"]["input"]

    for case_id in ("N01", "N02"):
        assert "1'260" in cases[case_id]["input"]
        assert "2'520" in cases[case_id]["input"]
        assert cases[case_id]["expected"]["value_chf_month"] is None
        assert cases[case_id]["category"] == "statutory_reference_value"


def test_fixture_is_shared_by_relative_read_not_runtime_packaging() -> None:
    mobile_relative = ROOT / "apps/mobile/../../tests/fixtures" / FIXTURE.name
    backend_relative = ROOT / "services/backend/../../tests/fixtures" / FIXTURE.name

    assert mobile_relative.resolve() == FIXTURE
    assert backend_relative.resolve() == FIXTURE
