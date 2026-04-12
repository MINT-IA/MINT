"""
Tests for anomaly detection service + endpoint.

Covers:
- 100 normal + 5 anomalous → detects anomalies
- < 10 transactions → returns []
- Z-score per category
- All identical transactions → 0 anomalies
- Insight generation
- Endpoint integration
- Edge cases (empty list, negative amounts, single category)
"""

import random


from app.services.anomaly_detection_service import AnomalyDetectionService


# ── Helpers ──────────────────────────────────────────────────────────────────


def _make_normal_transactions(n: int, base: float = 50.0, spread: float = 10.0) -> list[dict]:
    """Generate n transactions with amounts ~ Normal(base, spread)."""
    rng = random.Random(42)
    categories = ["food", "transport", "entertainment", "health", "shopping"]
    return [
        {
            "amount": round(rng.gauss(base, spread), 2),
            "category": categories[i % len(categories)],
            "date": f"2026-03-{(i % 28) + 1:02d}",
            "description": f"tx_{i}",
        }
        for i in range(n)
    ]


def _make_anomalous_transactions(n: int, amount: float = 500.0) -> list[dict]:
    """Generate n obviously anomalous transactions."""
    return [
        {
            "amount": amount,
            "category": "food",
            "date": f"2026-03-{(i % 28) + 1:02d}",
            "description": f"anomaly_{i}",
        }
        for i in range(n)
    ]


# ── Service unit tests ──────────────────────────────────────────────────────


class TestAnomalyDetectionService:
    """Unit tests for AnomalyDetectionService."""

    def test_detects_anomalies_in_mixed_data(self):
        """100 normal + 5 anomalous → at least 1 anomaly detected."""
        normal = _make_normal_transactions(100, base=50, spread=10)
        anomalous = _make_anomalous_transactions(5, amount=500)
        all_tx = normal + anomalous

        result = AnomalyDetectionService.detect_spending_anomalies(all_tx)

        assert len(result) > 0
        # All detected anomalies should have high amounts
        for r in result:
            assert r["anomaly_score"] > 0
            assert r["anomaly_type"] in ("global", "category_zscore")

    def test_returns_empty_for_few_transactions(self):
        """< 10 transactions → returns empty list."""
        tx = _make_normal_transactions(5)
        result = AnomalyDetectionService.detect_spending_anomalies(tx)
        assert result == []

    def test_returns_empty_for_empty_list(self):
        """Empty list → returns empty list."""
        result = AnomalyDetectionService.detect_spending_anomalies([])
        assert result == []

    def test_exactly_10_transactions_works(self):
        """10 transactions is the minimum; should not crash."""
        tx = _make_normal_transactions(10)
        result = AnomalyDetectionService.detect_spending_anomalies(tx)
        # May or may not find anomalies, but should not raise
        assert isinstance(result, list)

    def test_identical_transactions_no_anomalies(self):
        """All identical amounts → 0 anomalies (std=0, MAD=0)."""
        tx = [
            {"amount": 100.0, "category": "food", "date": "2026-03-01"}
            for _ in range(50)
        ]
        result = AnomalyDetectionService.detect_spending_anomalies(tx)
        assert len(result) == 0

    def test_category_zscore_detection(self):
        """One category with an outlier → detected via category Z-score."""
        # 20 normal food transactions + 1 huge food transaction
        tx = [
            {"amount": 30.0, "category": "food"} for _ in range(25)
        ]
        # Add outlier within same category
        tx.append({"amount": 300.0, "category": "food"})
        # Pad with other category to reach > 10 minimum
        tx.extend([{"amount": 50.0, "category": "transport"} for _ in range(10)])

        result = AnomalyDetectionService.detect_spending_anomalies(tx)

        # The 300 CHF food transaction should be flagged
        food_anomalies = [r for r in result if r.get("category") == "food"]
        assert len(food_anomalies) >= 1
        assert any(r["amount"] == 300.0 for r in food_anomalies)

    def test_negative_amounts_treated_as_absolute(self):
        """Negative amounts (expenses) should be treated by absolute value."""
        tx = [{"amount": -50.0, "category": "food"} for _ in range(25)]
        tx.append({"amount": -500.0, "category": "food"})
        tx.extend([{"amount": -40.0, "category": "transport"} for _ in range(10)])

        result = AnomalyDetectionService.detect_spending_anomalies(tx)

        assert len(result) >= 1

    def test_results_sorted_by_score_descending(self):
        """Anomalies should be sorted by anomaly_score, highest first."""
        normal = _make_normal_transactions(100, base=50, spread=5)
        anomalous = [
            {"amount": 300.0, "category": "food", "description": "medium"},
            {"amount": 800.0, "category": "food", "description": "extreme"},
        ]
        all_tx = normal + anomalous

        result = AnomalyDetectionService.detect_spending_anomalies(all_tx)

        if len(result) >= 2:
            scores = [r["anomaly_score"] for r in result]
            assert scores == sorted(scores, reverse=True)

    def test_anomaly_has_required_fields(self):
        """Each anomaly dict should have anomaly_score and anomaly_type."""
        normal = _make_normal_transactions(100, base=50, spread=5)
        anomalous = _make_anomalous_transactions(3, amount=500)
        all_tx = normal + anomalous

        result = AnomalyDetectionService.detect_spending_anomalies(all_tx)

        for r in result:
            assert "anomaly_score" in r
            assert "anomaly_type" in r
            assert isinstance(r["anomaly_score"], float)
            assert r["anomaly_type"] in ("global", "category_zscore")

    def test_missing_category_defaults_to_other(self):
        """Transactions without 'category' key default to 'other'."""
        tx = [{"amount": 50.0} for _ in range(25)]
        tx.append({"amount": 500.0})
        tx.extend([{"amount": 40.0, "category": "food"} for _ in range(10)])

        result = AnomalyDetectionService.detect_spending_anomalies(tx)
        # Should not crash; anomalies in 'other' category
        assert isinstance(result, list)

    def test_custom_thresholds(self):
        """Lower thresholds should detect more anomalies."""
        normal = _make_normal_transactions(100, base=50, spread=10)
        anomalous = _make_anomalous_transactions(3, amount=150)
        all_tx = normal + anomalous

        strict = AnomalyDetectionService.detect_spending_anomalies(
            all_tx, mad_threshold=5.0, zscore_threshold=4.0
        )
        loose = AnomalyDetectionService.detect_spending_anomalies(
            all_tx, mad_threshold=2.0, zscore_threshold=1.5
        )

        assert len(loose) >= len(strict)


# ── Insight generation tests ─────────────────────────────────────────────────


class TestInsightGeneration:
    """Tests for generate_anomaly_insight."""

    def test_basic_insight_with_ratio(self):
        """Insight should mention CHF amount, category, and ratio."""
        anomaly = {"amount": 500.0, "category": "food"}
        insight = AnomalyDetectionService.generate_anomaly_insight(
            anomaly=anomaly, category_avg=50.0
        )

        assert "500" in insight
        assert "food" in insight
        assert "10.0" in insight  # 500/50 = 10.0x
        assert "\u00d7" in insight  # multiplication sign

    def test_insight_zero_category_avg(self):
        """When category_avg is 0, should not divide by zero."""
        anomaly = {"amount": 200.0, "category": "misc"}
        insight = AnomalyDetectionService.generate_anomaly_insight(
            anomaly=anomaly, category_avg=0.0
        )

        assert "200" in insight
        assert "misc" in insight
        # Should not contain ratio
        assert "\u00d7" not in insight

    def test_insight_uses_non_breaking_spaces(self):
        """French typographic rules: non-breaking space before : and with CHF."""
        anomaly = {"amount": 100.0, "category": "health"}
        insight = AnomalyDetectionService.generate_anomaly_insight(
            anomaly=anomaly, category_avg=20.0
        )

        assert "\u00a0:" in insight  # non-breaking space before colon
        assert "CHF\u00a0" in insight  # non-breaking space after CHF

    def test_insight_defaults_category_to_autre(self):
        """Missing category should default to 'autre'."""
        anomaly = {"amount": 300.0}
        insight = AnomalyDetectionService.generate_anomaly_insight(
            anomaly=anomaly, category_avg=50.0
        )

        assert "autre" in insight

    def test_insight_negative_amount_uses_absolute(self):
        """Negative amounts should appear as positive in the insight."""
        anomaly = {"amount": -150.0, "category": "transport"}
        insight = AnomalyDetectionService.generate_anomaly_insight(
            anomaly=anomaly, category_avg=30.0
        )

        assert "150" in insight
        assert "-150" not in insight


# ── Endpoint integration tests ───────────────────────────────────────────────


class TestBudgetAnomaliesEndpoint:
    """Integration tests for POST /api/v1/budget/anomalies."""

    def test_endpoint_returns_anomalies(self, client):
        """POST with mixed data returns anomaly response."""
        normal = _make_normal_transactions(100, base=50, spread=10)
        anomalous = _make_anomalous_transactions(5, amount=500)
        all_tx = normal + anomalous

        response = client.post(
            "/api/v1/budget/anomalies",
            json={"transactions": all_tx},
        )

        assert response.status_code == 200
        data = response.json()
        assert "anomalies" in data
        assert data["totalTransactions"] == 105
        assert data["anomalyCount"] == len(data["anomalies"])
        assert data["anomalyCount"] > 0
        assert "disclaimer" in data

    def test_endpoint_few_transactions(self, client):
        """POST with < 10 transactions returns 0 anomalies."""
        tx = _make_normal_transactions(5)

        response = client.post(
            "/api/v1/budget/anomalies",
            json={"transactions": tx},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["anomalyCount"] == 0
        assert data["anomalies"] == []

    def test_endpoint_has_insights(self, client):
        """Each anomaly in response should have an insight string."""
        normal = _make_normal_transactions(100, base=50, spread=5)
        anomalous = _make_anomalous_transactions(3, amount=500)
        all_tx = normal + anomalous

        response = client.post(
            "/api/v1/budget/anomalies",
            json={"transactions": all_tx},
        )

        data = response.json()
        for a in data["anomalies"]:
            assert "insight" in a
            assert a["insight"] is not None
            assert len(a["insight"]) > 10

    def test_endpoint_camel_case_aliases(self, client):
        """Response should use camelCase field names."""
        tx = _make_normal_transactions(50)
        tx.append({"amount": 999, "category": "food"})

        response = client.post(
            "/api/v1/budget/anomalies",
            json={"transactions": tx},
        )

        data = response.json()
        assert "totalTransactions" in data
        assert "anomalyCount" in data
        if data["anomalies"]:
            a = data["anomalies"][0]
            assert "anomalyScore" in a
            assert "anomalyType" in a
