"""Phase mint-calc-engine-v1 W4 Plan 17 — D-CE-17 composite scorecard metrics.

Prometheus counter + histogram declarations + `/metrics` exposition endpoint.

**Open Q1 resolved (orchestrator decision)** : Prometheus (preferred per
RESEARCH §Q-H Option 1). `prometheus-client>=0.20,<1.0` added as a `pyproject.toml`
dependency. The Sentry-only fallback (§Q-H Option 2) was rejected because it
gives no PromQL + no Grafana panel + no alerting on histogram buckets.

Metrics shipped (truth table per PLAN.md frontmatter) :

  | Symbol                      | Type      | Labels                          | Purpose                                            |
  | --------------------------- | --------- | ------------------------------- | -------------------------------------------------- |
  | `mint_calc_invoke_total`    | Counter   | `kind`, `profile_grounded`      | D-CE-17 PRIMARY metric — `profile_grounded_calc_rate` |
  | `mint_cache_lookup_total`   | Counter   | `kind`, `hit`                   | D-CE-12 SLI — cache hit rate                       |
  | `mint_calc_warm_total`      | Counter   | `kind`, `hit`                   | D-CE-14 SLI — warm precision/recall                |
  | `mint_zero_citation_total`  | Counter   | (none)                          | Counter-metric — hard floor at 0, alerts on > 0    |
  | `mint_calc_latency_seconds` | Histogram | `kind`                          | Calc compute latency, partitioned by kind          |

Label cardinality math (per RESEARCH §Q-H) :
  - `kind` : ~57 distinct calculator names → bounded.
  - `profile_grounded` : 2 values ("true" / "false").
  - `hit` : 2 values ("true" / "false").
  - Total time-series per Counter : ~114 (57 × 2). Trivial for Prometheus.
  - Histogram time-series : ~57 × 11 buckets = 627. Trivial.

PromQL queries (per RESEARCH §Q-H, copy-paste for Grafana dashboards) :

  # D-CE-17 PRIMARY — profile-grounded calc rate (5min window)
  sum(rate(mint_calc_invoke_total{profile_grounded="true"}[5m]))
    /
  sum(rate(mint_calc_invoke_total[5m]))

  # D-CE-12 cache hit rate
  sum(rate(mint_cache_lookup_total{hit="true"}[5m])) by (kind)
    /
  sum(rate(mint_cache_lookup_total[5m])) by (kind)

  # D-CE-14 warm precision SLI
  sum(rate(mint_calc_warm_total{hit="true"}[1h]))
    /
  sum(rate(mint_calc_warm_total[1h]))

Railway scraping config DEFERRED to phase close-out (Julien decision —
Grafana Cloud vs Datadog vs Railway built-in observability). See SUMMARY
"## Deferred — Phase close-out gates".

LSFin (CLAUDE.md §1) : metric names + label values are EN identifiers (tool
names + boolean flags). No FR user-facing strings, no banned terms.
"""
from __future__ import annotations

from fastapi import APIRouter, Response
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)


# --------------------------------------------------------------------------- #
# Counter + Histogram declarations (D-CE-17 composite scorecard)              #
# --------------------------------------------------------------------------- #


calc_invoke_total = Counter(
    "mint_calc_invoke_total",
    "Calc invocations partitioned by kind and profile-grounding flag (D-CE-17 PRIMARY).",
    labelnames=("kind", "profile_grounded"),
)
"""D-CE-17 PRIMARY metric. Fires once per calc invocation. `profile_grounded`
is "true" when any `from_profile`-marked field was filled from the user's
profile (vs body-supplied or default). PromQL :
`sum(rate(mint_calc_invoke_total{profile_grounded="true"}[5m])) / sum(rate(...))`
drives the D-CE-17 PM-reserved threshold revision."""


cache_lookup_total = Counter(
    "mint_cache_lookup_total",
    "Cache lookups partitioned by kind and hit/miss (D-CE-12 SLI).",
    labelnames=("kind", "hit"),
)
"""D-CE-12 SLI. Fires once per `cache_reader.lookup` call. `hit` is "true"
when a live row was returned, "false" on cache miss."""


calc_warm_total = Counter(
    "mint_calc_warm_total",
    "Pre-compute warms partitioned by kind and whether next turn used it (D-CE-14 SLI).",
    labelnames=("kind", "hit"),
)
"""D-CE-14 SLI. Fires once per `_warm_calc` invocation. `hit` is "true"
when a downstream user-turn read this warm row (Plan 16 GC compacts the
warm-vs-live duplication so a real hit needs to come from a same-inputs_hash
consumer call)."""


zero_citation_total = Counter(
    "mint_zero_citation_total",
    "Counter-metric — hard floor at 0; alerts on > 0 (D-CE-17 Goodhart counter).",
)
"""Counter-metric per D-CE-17 panel discipline. Should NEVER increment in
production. Any non-zero rate is a Goodhart-protection alert : the system
shipped a chip-emitter response without a citation. PromQL alert :
`rate(mint_zero_citation_total[5m]) > 0`."""


calc_latency_seconds = Histogram(
    "mint_calc_latency_seconds",
    "Calc compute latency in seconds, partitioned by kind.",
    labelnames=("kind",),
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)
"""Per-calc latency histogram. Buckets cover sub-5ms (cache hit) through
10s (cold cross-pillar narrator turn). Drives Grafana p95 / p99 panels per
calc kind."""


# --------------------------------------------------------------------------- #
# /metrics endpoint (Prometheus scrape target)                                 #
# --------------------------------------------------------------------------- #


metrics_router = APIRouter()


@metrics_router.get("/metrics", include_in_schema=False)
def prometheus_metrics() -> Response:
    """Prometheus scrape endpoint.

    Returns the full process-wide metric registry in the Prometheus text
    exposition format (per `CONTENT_TYPE_LATEST` = `text/plain; version=0.0.4`).

    **Security note** : exposed at the FastAPI app root (NOT under
    `/api/v1/...`). For production, Railway's network policy should restrict
    access to internal scrapers only (Grafana Cloud agent / Datadog agent
    via Railway private networking). Bearer-token auth is OPTIONAL — the
    metric content is non-PII (tool names + boolean flags + numeric counts).

    `include_in_schema=False` keeps it out of the OpenAPI doc — scrapers
    know the path, end users don't need to.
    """
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


__all__ = [
    "calc_invoke_total",
    "cache_lookup_total",
    "calc_warm_total",
    "zero_citation_total",
    "calc_latency_seconds",
    "metrics_router",
]
