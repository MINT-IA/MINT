"""Phase 31 OBS-03 — global exception handler tests (Wave 2 live).

Wave 0 shipped skipped stubs declaring the contract. Wave 2 Plan 31-02
flips them live: the handler surfaces `trace_id` + `sentry_event_id` in
the 500 JSON body, emits an `X-Trace-Id` header, and reads inbound
`sentry-trace` headers when present.

D-05 (CONTEXT.md) locks a dual-header strategy — the new `sentry-trace`
propagation coexists with the legacy `X-MINT-Trace-Id` emitted by
LoggingMiddleware. The handler:
  - Preserves existing LoggingMiddleware behaviour (uuid4 trace_id
    when no inbound header). We assert the 500 body carries a non-empty
    trace_id in this case.
  - Reads an inbound `sentry-trace` header when present and uses its
    32-hex trace_id instead of the uuid4.
  - Extends the 500 JSON body with `trace_id` (str) + `sentry_event_id`
    (str | None when Sentry init is unconfigured, as in local dev).
"""
from __future__ import annotations

from typing import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.main import app


_RAISE_PATH = "/__obs03_raise_for_test__"


@pytest.fixture
def raise_route() -> Generator[FastAPI, None, None]:
    """Register a route that always raises, yield, then unregister.

    The route hits the app-level @app.exception_handler(Exception)
    defined in services/backend/app/main.py. TestClient is used with
    raise_server_exceptions=False so the handler actually runs (default
    True re-raises server-side exceptions to the client).
    """
    @app.get(_RAISE_PATH)
    async def _raise() -> None:
        raise RuntimeError("obs03 test sentinel")

    yield app

    # Teardown — pop the route so subsequent tests don't see it. FastAPI
    # stores routes in app.router.routes; we match by path + method.
    app.router.routes = [
        r
        for r in app.router.routes
        if not (getattr(r, "path", None) == _RAISE_PATH)
    ]


def _extract_500(
    client: TestClient,
    headers: dict[str, str] | None = None,
) -> tuple[int, dict, dict]:
    """Call the raise route; return (status, json_body, response_headers)."""
    resp = client.get(_RAISE_PATH, headers=headers or {})
    return resp.status_code, resp.json(), dict(resp.headers)


def test_returns_trace_id(raise_route: FastAPI) -> None:
    """500 JSON response contains `trace_id` (str) and `sentry_event_id`.

    Shape contract (Wave 2):
        {
          "detail": "<message>",
          "error_code": "internal_error",
          "trace_id": "<non-empty-str>",
          "sentry_event_id": "<hex>" | null,
        }
    AND header X-Trace-Id equals body.trace_id (cohabitation contract).
    """
    with TestClient(app, raise_server_exceptions=False) as client:
        status, body, headers = _extract_500(client)

    assert status == 500
    assert body["detail"] == "Erreur interne du serveur"
    assert body["error_code"] == "internal_error"
    assert "trace_id" in body
    assert isinstance(body["trace_id"], str)
    assert body["trace_id"]  # non-empty
    assert "sentry_event_id" in body
    # Sentry DSN is unconfigured in tests → event_id is None
    assert body["sentry_event_id"] is None

    # Header-body equality (cohabitation with LoggingMiddleware)
    assert headers.get("x-trace-id") == body["trace_id"]


def test_preserves_logging_middleware_trace_id(raise_route: FastAPI) -> None:
    """When no inbound sentry-trace, trace_id falls back to a non-empty str.

    The existing LoggingMiddleware in logging_config.py:85-103 already
    emits X-Trace-Id on every response with a uuid4 when no inbound
    header is present. The global exception handler must cohabit — the
    500 body trace_id MUST be non-empty (falling back via trace_id_var
    ContextVar to the uuid4 set by LoggingMiddleware on request entry).
    """
    with TestClient(app, raise_server_exceptions=False) as client:
        status, body, headers = _extract_500(client)

    assert status == 500
    # LoggingMiddleware sets trace_id_var to a uuid4 at request entry
    # (logging_config.py:85-86). Our handler reads trace_id_var when no
    # inbound sentry-trace is present. uuid4 str length is 36 (with dashes).
    trace_id = body["trace_id"]
    assert trace_id
    assert trace_id != "-"  # default of trace_id_var; NOT what we return
    # X-Trace-Id header present and equal to body.trace_id
    assert headers.get("x-trace-id") == trace_id


def test_reads_inbound_sentry_trace(raise_route: FastAPI) -> None:
    """Inbound sentry-trace header wins over uuid4 fallback.

    When the request carries sentry-trace: <32-hex>-<16-hex>-<sampled>,
    the response trace_id MUST equal that 32-hex trace_id (not a fresh
    uuid4). This enables the cross-project link in Sentry UI between
    the mobile error event and the backend 500 transaction — the end-
    to-end round-trip verified by OBS-04 (b).
    """
    inbound_trace_id = "abcdef0123456789abcdef0123456789"
    inbound_span_id = "0123456789abcdef"
    sentry_trace = f"{inbound_trace_id}-{inbound_span_id}-1"

    with TestClient(app, raise_server_exceptions=False) as client:
        status, body, headers = _extract_500(
            client, headers={"sentry-trace": sentry_trace}
        )

    assert status == 500
    assert body["trace_id"] == inbound_trace_id, (
        f"Expected inbound trace_id to win, got body.trace_id={body['trace_id']}"
    )
    # Same value echoed in header (cohabitation contract)
    assert headers.get("x-trace-id") == inbound_trace_id
