"""Plan mint-data-architecture-v1-01-03 — Task 1.

Tests for ``GET /api/v1/regulatory/constants/version`` — the lightweight
delta-check endpoint D-15 specifies for D-08 runtime sync.

The 6 tests below enforce :
    1. Non-shadowing by the existing ``/constants/{key:path}`` catch-all
       (canonical insertion rule — line-number-agnostic).
    2. Exact 3-key response shape.
    3. Semantic size guard (< 1 KB ; not a 500-byte hard contract).
    4. Hash parity with ``RegulatoryRegistry.version_hash(today)`` — the
       same hash Plan 01's measurement script and the future
       ``/constants/snapshot`` endpoint (Task 2) both publish.
    5. Null-safe derivation of ``effective_from`` / ``reviewed_at`` on an
       empty active set (codex MEDIUM finding closed).
    6. Weak ETag header derived from version_hash (RFC 7232).
"""

from __future__ import annotations

import re
from datetime import date

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.regulatory.registry import RegulatoryRegistry


# Ensure the singleton is fresh per test module so monkeypatches in Test 5
# do not bleed across tests.
@pytest.fixture(autouse=True)
def _reset_registry():
    RegulatoryRegistry._reset()
    yield
    RegulatoryRegistry._reset()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


_SHA256_HEX = re.compile(r"^[0-9a-f]{64}$")


def test_version_endpoint_returns_200_not_shadowed_by_catchall(client: TestClient) -> None:
    """Canonical insertion rule enforcement (codex HIGH #2).

    If the new ``/constants/version`` route is registered AFTER the existing
    ``/constants/{key:path}`` catch-all, FastAPI matches the catch-all first
    and returns 404 with detail containing « 'version' not found ». This
    test asserts the 200 path is reachable — proving non-shadowing.
    """
    response = client.get("/api/v1/regulatory/constants/version")
    assert response.status_code == 200, (
        f"Expected 200, got {response.status_code}. "
        f"Body: {response.text[:200]}. "
        "If body says 'version not found', the catch-all is shadowing the route."
    )


def test_version_endpoint_shape(client: TestClient) -> None:
    """Response body has exactly {version_hash, effective_from, reviewed_at}."""
    response = client.get("/api/v1/regulatory/constants/version")
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"version_hash", "effective_from", "reviewed_at"}, (
        f"Expected 3 keys exactly, got {sorted(body.keys())}"
    )
    assert isinstance(body["version_hash"], str)
    assert _SHA256_HEX.match(body["version_hash"]), (
        f"version_hash must be 64-char hex SHA-256, got {body['version_hash']!r}"
    )
    # effective_from + reviewed_at are ISO 8601 date strings OR null.
    for key in ("effective_from", "reviewed_at"):
        value = body[key]
        if value is not None:
            assert isinstance(value, str)
            # ISO date parse — must not raise.
            date.fromisoformat(value)


def test_version_endpoint_size_under_1kb_semantic_guard(client: TestClient) -> None:
    """< 1 KB ceiling = lightweight delta-check intentionally fits in a single
    TCP segment ; not a hard contract — see Plan 03 deviations §3 (semantic
    size guard replaces the 500-byte hard target from the original plan).
    """
    response = client.get("/api/v1/regulatory/constants/version")
    assert response.status_code == 200
    assert len(response.content) < 1024, (
        f"Expected response body < 1024 bytes (semantic guard for single-TCP-segment "
        f"delta-check), got {len(response.content)} bytes."
    )


def test_version_endpoint_hash_matches_measurement_script(client: TestClient) -> None:
    """version_hash from /version endpoint == RegulatoryRegistry.version_hash(today).

    This proves the endpoint and Plan 01's measurement script share the same
    hash, which is the contract that lets a Flutter client delta-check
    against the bundle-baked hash without ever fetching the full snapshot.
    """
    response = client.get("/api/v1/regulatory/constants/version")
    assert response.status_code == 200
    body = response.json()
    expected = RegulatoryRegistry.instance().version_hash(date.today())
    assert body["version_hash"] == expected, (
        f"Endpoint hash {body['version_hash']!r} != registry hash {expected!r}. "
        "The two MUST be identical for the delta-check contract to hold."
    )


def test_version_endpoint_handles_empty_active_set(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """When the active set is empty, ``effective_from`` / ``reviewed_at``
    derivation must NOT raise ``ValueError: min() arg is an empty sequence``
    (codex MEDIUM finding). The endpoint returns 200 with null values
    for both derivations, version_hash still computed (whatever the
    registry returns for an empty active set).
    """
    # Replace get_all to return an empty list so the endpoint sees zero
    # active params. version_hash(today) is computed by the registry over
    # its own internal _params (not the get_all() result), so it still
    # produces a hash — we do NOT assert its value, only that it's a hex
    # string and no exception is raised.
    registry = RegulatoryRegistry.instance()
    monkeypatch.setattr(registry, "get_all", lambda *a, **kw: [])

    response = client.get("/api/v1/regulatory/constants/version")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["effective_from"] is None, (
        f"Empty active set must yield effective_from=null, got {body['effective_from']!r}"
    )
    assert body["reviewed_at"] is None, (
        f"Empty active set must yield reviewed_at=null, got {body['reviewed_at']!r}"
    )
    assert _SHA256_HEX.match(body["version_hash"]), (
        "version_hash still expected to be a valid hex string even when active set is empty."
    )


def test_version_endpoint_etag_header_present(client: TestClient) -> None:
    """ETag header MUST be ``W/"<version_hash>"`` (weak ETag, RFC 7232)."""
    response = client.get("/api/v1/regulatory/constants/version")
    assert response.status_code == 200
    etag = response.headers.get("ETag")
    assert etag is not None, "ETag header missing — required for cache-friendliness."
    body = response.json()
    expected_etag = f'W/"{body["version_hash"]}"'
    assert etag == expected_etag, (
        f"Expected ETag {expected_etag!r}, got {etag!r}"
    )
