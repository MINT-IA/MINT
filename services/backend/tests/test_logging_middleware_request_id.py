"""Tests that LoggingMiddleware honours a client-supplied X-MINT-Req-Id.

Pairs with apps/mobile/lib/services/observability/mint_http_client.dart —
the mobile client stamps `X-MINT-Req-Id: <uuidv4>` on every outbound call,
and the backend reuses that value as its trace_id so that client stdout
and Railway backend logs share a single key (see tools/debug/mint-trace.sh).
"""
import re
import uuid

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.logging_config import LoggingMiddleware

_UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)


def _make_app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(LoggingMiddleware)

    @app.get("/ping")
    async def ping():
        return {"ok": True}

    return app


def test_reuses_client_supplied_request_id_as_trace_id() -> None:
    client = TestClient(_make_app())
    client_req_id = "abc12345-d6e7-4f89-9123-456789abcdef"

    response = client.get("/ping", headers={"X-MINT-Req-Id": client_req_id})

    assert response.status_code == 200
    assert response.headers["x-trace-id"] == client_req_id


def test_accepts_uppercase_request_id_and_normalizes_to_lower() -> None:
    client = TestClient(_make_app())
    client_req_id = "ABC12345-D6E7-4F89-9123-456789ABCDEF"

    response = client.get("/ping", headers={"X-MINT-Req-Id": client_req_id})

    assert response.headers["x-trace-id"] == client_req_id.lower()


def test_falls_back_to_generated_uuid_when_header_missing() -> None:
    client = TestClient(_make_app())

    response = client.get("/ping")

    trace_id = response.headers["x-trace-id"]
    assert _UUID_RE.match(trace_id)
    uuid.UUID(trace_id)  # parses


def test_rejects_malformed_request_id_to_prevent_log_poisoning() -> None:
    """A non-UUID value must NOT be reflected back as trace_id."""
    client = TestClient(_make_app())
    poisoned = 'not-a-uuid"; level=ERROR; injected'

    response = client.get("/ping", headers={"X-MINT-Req-Id": poisoned})

    trace_id = response.headers["x-trace-id"]
    assert trace_id != poisoned
    assert _UUID_RE.match(trace_id)


def test_rejects_empty_request_id() -> None:
    client = TestClient(_make_app())

    response = client.get("/ping", headers={"X-MINT-Req-Id": ""})

    assert _UUID_RE.match(response.headers["x-trace-id"])
