"""Phase 31 OBS-03 — global exception handler scaffolding (Wave 0).

Wave 2 Plan 31-02 fills in the bodies. These skipped tests declare the
contract: trace_id + sentry_event_id surface in JSON 500 response, and
X-Trace-Id header cohabits with the existing LoggingMiddleware output
(services/backend/app/logging_config.py:85-103).

D-05 (CONTEXT.md) locks a dual-header strategy — the new `sentry-trace`
propagation coexists with the legacy `X-MINT-Trace-Id` emitted by
LoggingMiddleware. The Wave 2 handler:
  - Preserves the existing LoggingMiddleware behaviour (uuid4 trace_id
    when no inbound header).
  - Reads an inbound `sentry-trace` header when present and uses its
    32-hex trace_id instead of generating a fresh uuid4.
  - Extends the 500 JSON body with `trace_id` (str) + `sentry_event_id`
    (str | None when Sentry init is unconfigured, as in local dev).

Pytest registration: these tests are collected by pytest.ini (existing).
Skipped stubs are a no-op in CI but guarantee the file parses + the
contract names exist for Wave 2 implementers to fill.
"""
from __future__ import annotations

import pytest


@pytest.mark.skip(reason="Wave 2 Plan 31-02 impl pending — OBS-03 (a)")
def test_returns_trace_id() -> None:
    """500 JSON response contains `trace_id` (str) and `sentry_event_id`.

    Shape contract (Wave 2):
        {
          "detail": "<message>",
          "trace_id": "<32-hex>",
          "sentry_event_id": "<hex>" | null,
        }
    """


@pytest.mark.skip(reason="Wave 2 Plan 31-02 impl pending — OBS-03 (b)")
def test_preserves_logging_middleware_trace_id() -> None:
    """When no inbound sentry-trace, X-Trace-Id header stays non-empty.

    The existing LoggingMiddleware in logging_config.py:85-103 already
    emits X-Trace-Id on every response with a uuid4 when no inbound
    header is present. The new global exception handler must NOT
    overwrite or drop this — it cohabits, not replaces.
    """


@pytest.mark.skip(reason="Wave 2 Plan 31-02 impl pending — OBS-03 (c)")
def test_reads_inbound_sentry_trace() -> None:
    """Inbound sentry-trace header wins over uuid4 fallback.

    When the request carries sentry-trace: <32-hex>-<16-hex>-<sampled>,
    the response trace_id MUST equal that 32-hex trace_id (not a fresh
    uuid4). This enables the cross-project link in Sentry UI between
    the mobile error event and the backend 500 transaction — the end-
    to-end round-trip verified by OBS-04 (b).
    """
