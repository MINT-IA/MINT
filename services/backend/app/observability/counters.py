"""Prometheus counters for Phase 02 event-log + projection observability.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 — D-33 (DECLARE only;
firing assertions land in Plan 02-04 close-out) + iter-2 A4/A5
(`mint_kms_backend_failure_total` + `mint_dek_cache_size_total`).

All counters use `prometheus_client` (already present in pyproject). If the
library is unavailable (test envs without it), no-op stubs are exported so
imports never fail in CI.

Counters declared (6 base D-33 + 2 iter-2 = 8 total):
    mint_fact_current_read_latency_ms     Histogram (labels: fact_type)
    mint_fact_event_insert_total          Counter   (labels: source_type)
    mint_dek_envelope_status_total        Counter   (labels: status)
    mint_anonymous_session_link_total     Counter   (labels: outcome)
    mint_projector_idempotency_skip_total Counter
    mint_constants_version_mismatch_total Counter
    mint_kms_backend_failure_total        Counter   (labels: backend, reason) [iter-2 A4]
    mint_dek_cache_size_total             Gauge                                [iter-2 A5]
"""
from __future__ import annotations

try:
    from prometheus_client import Counter, Gauge, Histogram

    _HAS_PROMETHEUS = True
except Exception:  # pragma: no cover — prometheus_client optional
    _HAS_PROMETHEUS = False

    class _NoOp:
        """No-op counter/gauge/histogram for envs without prometheus_client."""

        def labels(self, *args, **kwargs):
            return self

        def inc(self, *args, **kwargs) -> None:
            return None

        def set(self, *args, **kwargs) -> None:
            return None

        def observe(self, *args, **kwargs) -> None:
            return None

    Counter = lambda *a, **kw: _NoOp()  # type: ignore  # noqa: E731
    Gauge = lambda *a, **kw: _NoOp()  # type: ignore    # noqa: E731
    Histogram = lambda *a, **kw: _NoOp()  # type: ignore # noqa: E731


# ---------------------------------------------------------------------------
# D-33 — six base counters declared (Plan 02-04 asserts firing)
# ---------------------------------------------------------------------------

mint_fact_current_read_latency_ms = Histogram(
    "mint_fact_current_read_latency_ms",
    "Latency (ms) for fact_current read path; D-01 target p50<=5ms, p99<=20ms.",
    labelnames=("fact_type",),
)

mint_fact_event_insert_total = Counter(
    "mint_fact_event_insert_total",
    "Total fact_event INSERTs by source_type (user_input, coach_inference, mobile_l1, etc.).",
    labelnames=("source_type",),
)

mint_dek_envelope_status_total = Counter(
    "mint_dek_envelope_status_total",
    "DEK envelope wrap/unwrap status by outcome (success, revoked, error, tombstoned).",
    labelnames=("status",),
)

mint_anonymous_session_link_total = Counter(
    "mint_anonymous_session_link_total",
    "Mobile anonymous-session link batch outcomes "
    "(linked, conflict, error, rejected_no_handshake per iter-2 A6).",
    labelnames=("outcome",),
)

mint_projector_idempotency_skip_total = Counter(
    "mint_projector_idempotency_skip_total",
    "Times the projector skipped an upsert due to sequence-number monotonicity "
    "(event.event_id <= existing.latest_event_id) — D-27 idempotency proof.",
)

mint_constants_version_mismatch_total = Counter(
    "mint_constants_version_mismatch_total",
    "Times a snapshot read found a stale constants_version_hash and invalidated "
    "cache — D-17 cache-key extension proof.",
)


# ---------------------------------------------------------------------------
# iter-2 A4 + A5 — KMS fail-closed + DEK cache observability
# ---------------------------------------------------------------------------

mint_kms_backend_failure_total = Counter(
    "mint_kms_backend_failure_total",
    "KMS backend resolution failures by (backend, reason). iter-2 A4 + D-35 PROPOSED "
    "(fail-closed never silent fallback).",
    labelnames=("backend", "reason"),
)

mint_dek_cache_size_total = Gauge(
    "mint_dek_cache_size_total",
    "Current entries in KeyVaultService._dek_cache (TTLCache, maxsize=1024). iter-2 A5.",
)


__all__ = [
    "mint_fact_current_read_latency_ms",
    "mint_fact_event_insert_total",
    "mint_dek_envelope_status_total",
    "mint_anonymous_session_link_total",
    "mint_projector_idempotency_skip_total",
    "mint_constants_version_mismatch_total",
    "mint_kms_backend_failure_total",
    "mint_dek_cache_size_total",
]
