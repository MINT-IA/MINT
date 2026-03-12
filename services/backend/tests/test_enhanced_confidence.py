"""
Tests for Enhanced Confidence Scoring (Sprint S46).

Covers:
    - scoring primitives (completeness, accuracy, freshness)
    - enrichment ranking and gate behavior
    - API endpoints /confidence/score, /confidence/enrichments, /confidence/gates
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.services.confidence.enhanced_confidence_models import FieldSource
from app.services.confidence.enhanced_confidence_service import (
    PROFILE_FIELD_WEIGHTS,
    WEIGHT_ACCURACY,
    WEIGHT_COMPLETENESS,
    WEIGHT_FRESHNESS,
    compute_confidence,
    rank_enrichment_prompts,
    score_accuracy,
    score_completeness,
    score_freshness,
    score_understanding,
)
from app.services.document_parser.document_models import DataSource


def _dt(days_ago: int) -> str:
    now = datetime.now(timezone.utc)
    return (now - timedelta(days=days_ago)).isoformat()


def _source(
    field_name: str,
    source: DataSource = DataSource.user_entry,
    days_ago: int = 5,
    value: float | str = 1.0,
) -> FieldSource:
    return FieldSource(
        field_name=field_name,
        source=source,
        updated_at=_dt(days_ago),
        value=value,
    )


class TestCompleteness:
    def test_empty_profile_is_zero(self):
        assert score_completeness({}) == 0.0

    def test_full_profile_is_hundred(self):
        profile = {k: 1 for k in PROFILE_FIELD_WEIGHTS}
        assert score_completeness(profile) == 100.0

    def test_boolean_false_counts_as_filled(self):
        assert score_completeness({"is_married": False}) > 0.0

    def test_numeric_zero_counts_as_filled(self):
        assert score_completeness({"nb_children": 0}) > 0.0

    def test_empty_string_not_filled(self):
        assert score_completeness({"canton": ""}) == 0.0


class TestAccuracy:
    def test_no_sources_is_zero(self):
        assert score_accuracy([]) == 0.0

    def test_open_banking_is_hundred(self):
        score = score_accuracy([_source("salaire_brut", DataSource.open_banking)])
        assert score == 100.0

    def test_user_estimate_is_low(self):
        score = score_accuracy([_source("salaire_brut", DataSource.user_estimate)])
        assert score == 25.0

    def test_mixed_sources_weighted(self):
        sources = [
            _source("salaire_brut", DataSource.open_banking),
            _source("lpp_total", DataSource.user_entry),
        ]
        score = score_accuracy(sources)
        assert 70.0 <= score <= 80.0


class TestFreshness:
    def test_no_sources_is_zero(self):
        assert score_freshness([]) == 0.0

    def test_under_one_month_is_hundred(self):
        score = score_freshness([_source("salaire_brut", days_ago=10)])
        assert score == 100.0

    def test_three_to_six_months(self):
        score = score_freshness([_source("salaire_brut", days_ago=130)])
        assert score == 75.0

    def test_over_twelve_months_floor(self):
        score = score_freshness([_source("salaire_brut", days_ago=500)])
        assert score == 25.0

    def test_invalid_date_uses_floor(self):
        sources = [
            FieldSource(
                field_name="salaire_brut",
                source=DataSource.user_entry,
                updated_at="not-a-date",
                value=5000.0,
            )
        ]
        assert score_freshness(sources) == 25.0


class TestUnderstanding:
    def test_beginner_no_sessions(self):
        score = score_understanding({})
        assert score == 15.0  # 30 * 0.50

    def test_intermediate_no_sessions(self):
        score = score_understanding({"financial_literacy_level": "intermediate"})
        assert score == 27.5  # 55 * 0.50

    def test_advanced_no_sessions(self):
        score = score_understanding({"financial_literacy_level": "advanced"})
        assert score == 42.5  # 85 * 0.50

    def test_session_bonus_capped(self):
        score = score_understanding({"check_in_count": 50})
        assert score == 27.0  # 30*0.50 + 40*0.30

    def test_advanced_max_sessions(self):
        score = score_understanding({
            "financial_literacy_level": "advanced",
            "check_in_count": 25,
        })
        assert score == 54.5  # 85*0.50 + 40*0.30

    def test_invalid_literacy_defaults_beginner(self):
        score = score_understanding({"financial_literacy_level": "unknown"})
        assert score == 15.0

    def test_non_numeric_check_in_ignored(self):
        score = score_understanding({"check_in_count": "many"})
        assert score == 15.0


class TestComputeConfidence:
    def test_compute_confidence_overall_formula(self):
        profile = {"salaire_brut": 8000, "age": 35, "canton": "VD"}
        sources = [
            _source("salaire_brut", DataSource.open_banking, days_ago=10, value=8000.0),
            _source("age", DataSource.user_entry_cross_validated, days_ago=30, value=35.0),
            _source("canton", DataSource.user_entry, days_ago=20, value="VD"),
        ]
        result = compute_confidence(profile, sources)
        b = result.breakdown
        # Verify geometric mean formula
        vals = [(x + 1.0) / 101.0 for x in [b.completeness, b.accuracy, b.freshness, b.understanding]]
        expected = round((vals[0] * vals[1] * vals[2] * vals[3]) ** 0.25 * 101.0 - 1.0, 1)
        assert abs(b.overall - expected) < 0.2

    def test_gate_thresholds_low_profile(self):
        result = compute_confidence({}, [])
        assert result.feature_gates["basic_chiffre_choc_only"] is True
        assert result.feature_gates["standard_projections"] is False
        assert result.feature_gates["arbitrage_comparisons"] is False

    def test_gate_thresholds_high_profile(self):
        profile = {k: 1 for k in PROFILE_FIELD_WEIGHTS}
        profile["financial_literacy_level"] = "advanced"
        profile["check_in_count"] = 20
        sources = [
            _source(k, DataSource.open_banking, days_ago=1, value=1.0)
            for k in PROFILE_FIELD_WEIGHTS
        ]
        result = compute_confidence(profile, sources)
        assert result.breakdown.overall >= 85.0
        assert result.feature_gates["full_precision"] is True
        assert result.feature_gates["longitudinal_tracking"] is True

    def test_enrichment_sorted_by_impact(self):
        prompts = rank_enrichment_prompts({}, [])
        assert len(prompts) > 0
        impacts = [p.impact_points for p in prompts]
        assert impacts == sorted(impacts, reverse=True)
        priorities = [p.priority for p in prompts]
        assert priorities == list(range(1, len(prompts) + 1))

    def test_enrichment_skips_well_sourced_primary_field(self):
        profile = {"lpp_total": 200000}
        sources = [
            _source("lpp_total", DataSource.document_scan_verified, days_ago=5, value=200000.0)
        ]
        prompts = rank_enrichment_prompts(profile, sources)
        assert all(p.field_name != "lpp_total" for p in prompts)


class TestConfidenceEndpoints:
    def test_score_endpoint_returns_breakdown(self, client):
        payload = {
            "profile": {"salaireBrut": 8000, "age": 35, "canton": "VD", "isMarried": False},
            "fieldSources": [
                {
                    "fieldName": "salaire_brut",
                    "source": "open_banking",
                    "updatedAt": _dt(10),
                    "value": 8000,
                },
                {
                    "fieldName": "is_married",
                    "source": "user_entry",
                    "updatedAt": _dt(20),
                    "value": False,
                },
            ],
        }
        response = client.post("/api/v1/confidence/score", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "breakdown" in data
        assert "enrichmentPrompts" in data
        assert "featureGates" in data
        assert data["breakdown"]["overall"] >= 0
        assert "LSFin" in data["disclaimer"]

    def test_score_endpoint_unknown_source_fallback(self, client):
        payload = {
            "profile": {"salaireBrut": 8000},
            "fieldSources": [
                {
                    "fieldName": "salaire_brut",
                    "source": "unknown_source",
                    "updatedAt": _dt(10),
                    "value": 8000,
                }
            ],
        }
        response = client.post("/api/v1/confidence/score", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["breakdown"]["accuracy"] == 25.0

    def test_enrichments_endpoint_respects_max_prompts(self, client):
        payload = {
            "profile": {},
            "fieldSources": [],
            "maxPrompts": 3,
        }
        response = client.post("/api/v1/confidence/enrichments", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert len(data["enrichmentPrompts"]) == 3

    def test_enrichments_endpoint_validation(self, client):
        payload = {"profile": {}, "fieldSources": [], "maxPrompts": 50}
        response = client.post("/api/v1/confidence/enrichments", json=payload)
        assert response.status_code == 422

    def test_gates_endpoint_low_profile(self, client):
        payload = {"profile": {}, "fieldSources": []}
        response = client.post("/api/v1/confidence/gates", json=payload)
        assert response.status_code == 200
        data = response.json()
        # Geometric mean with shift gives a small non-zero floor for empty profiles
        assert data["overallConfidence"] < 30.0
        assert data["nextGateName"] == "standard_projections"

    def test_gates_endpoint_high_profile_has_no_next_gate(self, client):
        profile = {k: 1 for k in PROFILE_FIELD_WEIGHTS}
        profile["financial_literacy_level"] = "advanced"
        profile["check_in_count"] = 20
        field_sources = [
            {
                "fieldName": k,
                "source": "open_banking",
                "updatedAt": _dt(1),
                "value": 1,
            }
            for k in PROFILE_FIELD_WEIGHTS
        ]
        response = client.post(
            "/api/v1/confidence/gates",
            json={"profile": profile, "fieldSources": field_sources},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["overallConfidence"] >= 85.0
        assert data["nextGateName"] is None
        assert data["pointsToNextGate"] is None
