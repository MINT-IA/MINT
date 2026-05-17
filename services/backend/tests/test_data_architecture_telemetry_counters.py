"""Phase mint-data-architecture-v1-01 Plan 01 Task 2 — telemetry counter declarations.

Three new Prometheus primitives appended to ``app.core.metrics`` :

  - ``mint_offline_session_total`` (Counter, no labels) — D-05 implication
  - ``mint_l1_only_session_total`` (Counter, no labels) — §'What would change
    this conclusion' implication (<2% trigger denominator)
  - ``mint_constants_staleness_at_render_seconds`` (Histogram, no labels,
    buckets aligned with D-07 7d soft / 30d hard staleness window)

Phase 01 ships the DECLARATIONS only ; Phase 02 wires the firing call-sites
once client-side offline detection exists. Tests therefore validate :

  1. The three names import without error.
  2. They have the correct prometheus_client types.
  3. The existing Plan-17 counters remain present (regression guard).
  4. ``prometheus_client.generate_latest()`` exposes the three names in the
     Prometheus text exposition format so the `/metrics` endpoint surfaces
     them once they fire in Phase 02.

LSFin (CLAUDE.md §1) : metric names + docstrings are EN identifiers, no FR
user-facing strings, no banned terms.
"""
from __future__ import annotations

import pytest

pytest.importorskip("prometheus_client")


def test_three_phase01_counters_exposed() -> None:
    """T2.1: The 3 new symbols import without error."""
    from app.core.metrics import (  # noqa: F401
        mint_constants_staleness_at_render_seconds,
        mint_l1_only_session_total,
        mint_offline_session_total,
    )


def test_counters_have_correct_prometheus_type() -> None:
    """T2.2: Two Counters + one Histogram, correctly typed."""
    from prometheus_client import Counter, Histogram

    from app.core.metrics import (
        mint_constants_staleness_at_render_seconds,
        mint_l1_only_session_total,
        mint_offline_session_total,
    )

    assert isinstance(mint_offline_session_total, Counter), type(mint_offline_session_total)
    assert isinstance(mint_l1_only_session_total, Counter), type(mint_l1_only_session_total)
    assert isinstance(
        mint_constants_staleness_at_render_seconds, Histogram
    ), type(mint_constants_staleness_at_render_seconds)


def test_existing_plan17_counters_still_present() -> None:
    """T2.3: Plan-17 counter symbols still importable (regression guard).

    Phase 01 declarations MUST be additive ; mutating or renaming the existing
    counters would break Plan 17's wiring and any in-flight Grafana dashboards.
    Names are the actual module-level binding names from Plan 17.
    """
    from app.core.metrics import (  # noqa: F401
        cache_lookup_total,
        calc_invoke_total,
        calc_latency_seconds,
        calc_warm_total,
        zero_citation_total,
    )


def test_counters_render_in_metrics_text() -> None:
    """T2.4: prometheus_client text exposition contains the 3 new metric names.

    Reads the global registry directly via generate_latest() rather than going
    through FastAPI so the test isolates the counter registration step. The
    existing Plan-17 /metrics endpoint test (test_metrics_endpoint.py) covers
    the endpoint-shape contract ; this test covers metric exposition only.
    """
    from prometheus_client import generate_latest

    # Importing the module registers the counters with the default REGISTRY.
    from app.core import metrics  # noqa: F401

    body = generate_latest().decode("utf-8")
    for name in (
        "mint_offline_session_total",
        "mint_l1_only_session_total",
        "mint_constants_staleness_at_render_seconds",
    ):
        assert name in body, (
            f"{name!r} missing from /metrics exposition.\nBody head:\n{body[:1500]}"
        )
