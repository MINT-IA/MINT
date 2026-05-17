"""Plan 17 W4 — Prometheus metrics module + /metrics endpoint (D-CE-17 composite scorecard).

Tests the 4 Counter declarations + the `/metrics` Prometheus exposition endpoint
+ chip-emitter wire-up (Task 2 sister tests live here too).

Per RESEARCH §Q-H Option 1 (Prometheus chosen by orchestrator — Open Q1 resolved).

Counter contract :
  - `mint_calc_invoke_total{kind, profile_grounded}` — D-CE-17 PRIMARY
  - `mint_cache_lookup_total{kind, hit}` — D-CE-12 SLI
  - `mint_calc_warm_total{kind, hit}` — D-CE-14 SLI
  - `mint_zero_citation_total` — no labels (counter-metric, hard floor at 0)
  - `mint_calc_latency_seconds{kind}` — Histogram with explicit buckets

LSFin (CLAUDE.md §1) : metric names + label values are EN tool/file identifiers,
no FR user-facing strings. Safe.
"""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


# --------------------------------------------------------------------------- #
# Task 1 — metrics.py module + /metrics endpoint                               #
# --------------------------------------------------------------------------- #


def test_metrics_module_exports_all_four_counters_and_histogram():
    """T1.1: The 4 required counters + 1 histogram are importable from app.core.metrics."""
    from app.core.metrics import (
        calc_invoke_total,
        cache_lookup_total,
        calc_warm_total,
        zero_citation_total,
        calc_latency_seconds,
    )

    # Counter type sanity — every symbol carries the prometheus_client _metrics dict.
    assert hasattr(calc_invoke_total, "labels")
    assert hasattr(cache_lookup_total, "labels")
    assert hasattr(calc_warm_total, "labels")
    # `mint_zero_citation_total` has NO labels — `inc()` works directly.
    assert hasattr(zero_citation_total, "inc")
    # Histogram supports `.labels(...).observe(...)`.
    assert hasattr(calc_latency_seconds, "labels")


def test_metrics_endpoint_returns_prometheus_text_format():
    """T1.2: `GET /metrics` returns 200 + Prometheus content-type."""
    from app.main import app

    client = TestClient(app)
    resp = client.get("/metrics")
    assert resp.status_code == 200, f"expected 200, got {resp.status_code}: {resp.text[:300]}"
    # Prometheus exposition format mime per OpenMetrics/prometheus_client convention.
    ct = resp.headers.get("content-type", "")
    assert "text/plain" in ct, f"expected text/plain content-type, got: {ct!r}"
    # Body should be plain text (HELP/TYPE/sample lines).
    body = resp.text
    assert "# HELP" in body or "# TYPE" in body, (
        f"expected Prometheus exposition format, got: {body[:300]!r}"
    )


def test_metrics_endpoint_exposes_all_four_counter_names():
    """T1.3: After incrementing each counter, /metrics body contains all 4 names."""
    from app.core.metrics import (
        calc_invoke_total,
        cache_lookup_total,
        calc_warm_total,
        zero_citation_total,
    )
    from app.main import app

    # Increment each counter at least once so they show up in the exposition.
    calc_invoke_total.labels(kind="test_kind", profile_grounded="true").inc()
    cache_lookup_total.labels(kind="test_kind", hit="true").inc()
    calc_warm_total.labels(kind="test_kind", hit="false").inc()
    # zero_citation_total intentionally NOT incremented — it should still
    # appear in the exposition with value 0.0.

    client = TestClient(app)
    body = client.get("/metrics").text
    assert "mint_calc_invoke_total" in body, body[:500]
    assert "mint_cache_lookup_total" in body, body[:500]
    assert "mint_calc_warm_total" in body, body[:500]
    assert "mint_zero_citation_total" in body, body[:500]


def test_calc_invoke_total_emits_kind_and_profile_grounded_labels():
    """T1.4: Counter labels appear verbatim in the Prometheus exposition."""
    from app.core.metrics import calc_invoke_total
    from app.main import app

    calc_invoke_total.labels(
        kind="lpp_rachat", profile_grounded="true"
    ).inc()
    body = TestClient(app).get("/metrics").text
    # The full sample line shape per Prometheus text format :
    #   mint_calc_invoke_total{kind="lpp_rachat",profile_grounded="true"} 1.0
    # (Exact value depends on prior increments in the same process — only
    # assert presence of the label pair, not the count.)
    assert 'kind="lpp_rachat"' in body, body[:1000]
    assert 'profile_grounded="true"' in body, body[:1000]


def test_calc_latency_seconds_histogram_has_buckets():
    """T1.5: Histogram with explicit buckets (5ms..10s) — buckets visible in exposition."""
    from app.core.metrics import calc_latency_seconds
    from app.main import app

    calc_latency_seconds.labels(kind="test_kind").observe(0.123)
    body = TestClient(app).get("/metrics").text
    assert "mint_calc_latency_seconds" in body, body[:500]
    # Histograms expose `_bucket` + `_sum` + `_count` lines.
    assert "mint_calc_latency_seconds_bucket" in body, body[:1000]
    # Bucket le="0.25" should be present per the RESEARCH §Q-H bucket choice.
    assert 'le="0.25"' in body, body[:1500]


def test_zero_citation_total_no_labels_increments_cleanly():
    """T1.6: `mint_zero_citation_total` has NO labels — `.inc()` works directly."""
    from app.core.metrics import zero_citation_total
    from app.main import app

    # Should not raise (counter-metric, hard floor at 0 — alerts on > 0).
    zero_citation_total.inc()
    body = TestClient(app).get("/metrics").text
    assert "mint_zero_citation_total" in body, body[:500]
