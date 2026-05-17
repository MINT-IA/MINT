"""Plan mint-data-architecture-v1-01-03 — Task 2.

Tests for ``GET /api/v1/regulatory/constants/snapshot`` — the full active
26-canton regulatory snapshot D-15 specifies for the D-08 runtime fetch
when the bundle-baked hash differs from the published one.

The 8 tests enforce :
    1. Non-shadowing by ``/constants/{key:path}`` catch-all.
    2. Payload shape matches Plan 01 measurement script.
    3. 27-jurisdiction coverage (CH + 26 cantons).
    4. ETag header matches ``W/"<version_hash>"`` from the body.
    5. Cache-Control: public, max-age=300, must-revalidate.
    6. If-None-Match conditional GET → 304 Not Modified (RFC 7232).
    7. Byte parity with Plan 01 measurement script ``_build_payload()``
       (allows for the documented ``version_hash`` legacy-key cohabitation
       — see test docstring).
    8. version_hash equal to the /version endpoint hash.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.regulatory.registry import RegulatoryRegistry


# Plan 01 measurement script lives at <repo>/tools/measurement/.
# Add it to sys.path so we can import the byte-stable _build_payload helper.
_REPO_ROOT = Path(__file__).resolve().parents[3]
_MEASUREMENT_DIR = _REPO_ROOT / "tools" / "measurement"
sys.path.insert(0, str(_MEASUREMENT_DIR))

import regulatory_snapshot_bundle_size as _measurement  # noqa: E402


_SHA256_HEX = re.compile(r"^[0-9a-f]{64}$")
_EXPECTED_27_JURISDICTIONS = {
    "CH", "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG",
    "FR", "SO", "BS", "BL", "SH", "AR", "AI", "SG", "GR", "AG",
    "TG", "TI", "VD", "VS", "NE", "GE", "JU",
}


@pytest.fixture(autouse=True)
def _reset_registry():
    RegulatoryRegistry._reset()
    yield
    RegulatoryRegistry._reset()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_snapshot_endpoint_returns_200_not_shadowed_by_catchall(client: TestClient) -> None:
    """Canonical insertion rule enforcement — proves /constants/snapshot is
    NOT shadowed by /constants/{key:path}."""
    response = client.get("/api/v1/regulatory/constants/snapshot")
    assert response.status_code == 200, (
        f"Expected 200, got {response.status_code}. Body: {response.text[:200]}. "
        "If body says 'snapshot not found', the catch-all is shadowing the route."
    )


def test_snapshot_endpoint_shape(client: TestClient) -> None:
    """Body has the Plan 01 measurement-script payload shape plus the
    canonical D-15 ``version_hash`` key (legacy ``active_version_hash``
    kept for byte-parity with measurement)."""
    response = client.get("/api/v1/regulatory/constants/snapshot")
    body = response.json()
    expected_keys = {"active_version_hash", "version_hash", "effective_on", "param_count", "parameters"}
    assert set(body.keys()) == expected_keys, (
        f"Expected keys {sorted(expected_keys)}, got {sorted(body.keys())}"
    )
    assert _SHA256_HEX.match(body["version_hash"])
    assert _SHA256_HEX.match(body["active_version_hash"])
    assert body["version_hash"] == body["active_version_hash"], (
        "Both hash keys MUST be the same value — legacy alias for measurement byte-parity."
    )
    assert isinstance(body["param_count"], int) and body["param_count"] > 0
    assert isinstance(body["parameters"], list) and len(body["parameters"]) == body["param_count"]
    # effective_on parseable as ISO date.
    date.fromisoformat(body["effective_on"])


def test_snapshot_endpoint_covers_27_jurisdictions(client: TestClient) -> None:
    """All 26 cantons + CH federal must be present (D-14 bake-all posture)."""
    response = client.get("/api/v1/regulatory/constants/snapshot")
    body = response.json()
    jurisdictions = {p["jurisdiction"] for p in body["parameters"]}
    assert jurisdictions == _EXPECTED_27_JURISDICTIONS, (
        f"Missing: {sorted(_EXPECTED_27_JURISDICTIONS - jurisdictions)}. "
        f"Extra: {sorted(jurisdictions - _EXPECTED_27_JURISDICTIONS)}."
    )


def test_snapshot_endpoint_etag_matches_version_hash(client: TestClient) -> None:
    """ETag MUST be ``W/"<version_hash>"`` where <version_hash> is the body's
    version_hash field."""
    response = client.get("/api/v1/regulatory/constants/snapshot")
    body = response.json()
    expected_etag = f'W/"{body["version_hash"]}"'
    assert response.headers.get("ETag") == expected_etag


def test_snapshot_endpoint_cache_control_header(client: TestClient) -> None:
    """Cache-Control contains 'public' AND 'max-age=300' (longer than /version
    because snapshot is heavier to fetch — RFC 7234 cache-friendly)."""
    response = client.get("/api/v1/regulatory/constants/snapshot")
    cache_control = response.headers.get("Cache-Control", "")
    assert "public" in cache_control, f"Expected 'public' in Cache-Control, got {cache_control!r}"
    assert "max-age=300" in cache_control, (
        f"Expected 'max-age=300' in Cache-Control, got {cache_control!r}"
    )


def test_snapshot_endpoint_returns_304_on_matching_etag(client: TestClient) -> None:
    """RFC 7232 §3.2 conditional GET — second request with matching ETag
    returns 304 Not Modified with empty body + ETag header still present."""
    first = client.get("/api/v1/regulatory/constants/snapshot")
    assert first.status_code == 200
    etag = first.headers["ETag"]

    second = client.get(
        "/api/v1/regulatory/constants/snapshot",
        headers={"If-None-Match": etag},
    )
    assert second.status_code == 304, (
        f"Expected 304 on matching If-None-Match, got {second.status_code}. "
        f"Body: {second.text[:200]}"
    )
    assert second.content == b"", "304 response body must be empty per RFC 7232."
    assert second.headers.get("ETag") == etag, (
        "ETag MUST still be returned on 304 so the cache stays current."
    )


def test_snapshot_endpoint_byte_parity_with_measurement_script(client: TestClient) -> None:
    """The endpoint body MUST be byte-equal to the Plan 01 measurement-script
    payload after re-serialising via the SAME ``json.dumps`` rules
    (``separators=(",", ":"), sort_keys=True, ensure_ascii=False``).

    The endpoint adds a ``version_hash`` key alongside the legacy
    ``active_version_hash`` key (both same value) — this is the D-15
    canonical key. The measurement script does NOT have this key. So we
    re-build the measurement payload, add the same ``version_hash`` key,
    serialise both via the same rules, and assert equal bytes.
    """
    response = client.get("/api/v1/regulatory/constants/snapshot")
    today = date.today()
    measurement_payload = _measurement._build_payload(today)
    # Mirror the endpoint's D-15 canonical-key addition for byte parity.
    measurement_payload["version_hash"] = measurement_payload["active_version_hash"]

    expected_body = json.dumps(
        measurement_payload,
        separators=(",", ":"),
        sort_keys=True,
        ensure_ascii=False,
    ).encode("utf-8")

    assert response.content == expected_body, (
        f"Byte parity broken — endpoint body diverges from measurement script payload. "
        f"endpoint len={len(response.content)}, expected len={len(expected_body)}"
    )


def test_snapshot_endpoint_hash_matches_version_endpoint(client: TestClient) -> None:
    """/snapshot and /version MUST publish the same version_hash — that is the
    contract that lets the mobile client delta-check via /version and trust
    that /snapshot will yield the same hash on fetch."""
    snap = client.get("/api/v1/regulatory/constants/snapshot").json()
    ver = client.get("/api/v1/regulatory/constants/version").json()
    assert snap["version_hash"] == ver["version_hash"]
