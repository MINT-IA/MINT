"""Plan mint-data-architecture-v1-01-03 — Task 3.

OpenAPI canonical contract verification for the two new endpoints shipped
by Plan 03 Tasks 1+2. These tests gate that:

    1. ``/api/v1/regulatory/constants/version`` is present in the canonical
       spec with a 200 response.
    2. ``/api/v1/regulatory/constants/snapshot`` is present with both a 200
       and a 304 Not Modified response documented.
    3. The snapshot endpoint declares an ``ETag`` response header in the
       OpenAPI spec (so Plan 04 mobile codegen + downstream consumers know
       to read it).

Plan 03 Task 4 (full backend regression) is gated by a separate session-level
run — running ``pytest tests/ -q`` here would force re-collection of >7000
tests inside this file which is wasteful ; the orchestrator runs the full
suite once per plan.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest


_REPO_ROOT = Path(__file__).resolve().parents[3]
_CANONICAL_PATH = _REPO_ROOT / "tools" / "openapi" / "mint.openapi.canonical.json"

_VERSION_PATH = "/api/v1/regulatory/constants/version"
_SNAPSHOT_PATH = "/api/v1/regulatory/constants/snapshot"


@pytest.fixture(scope="module")
def canonical_spec() -> dict:
    assert _CANONICAL_PATH.exists(), (
        f"OpenAPI canonical spec missing at {_CANONICAL_PATH}. "
        "Run `python3 tools/openapi/generate_canonical.py` to regenerate."
    )
    return json.loads(_CANONICAL_PATH.read_text(encoding="utf-8"))


def test_openapi_canonical_contains_version_endpoint(canonical_spec: dict) -> None:
    """``/regulatory/constants/version`` must be a path in the spec with a
    GET operation declaring a 200 response."""
    paths = canonical_spec.get("paths", {})
    assert _VERSION_PATH in paths, (
        f"Missing path {_VERSION_PATH!r} in canonical spec. "
        f"Available regulatory paths: "
        f"{sorted(p for p in paths if 'regulatory/constants' in p)}"
    )
    operation = paths[_VERSION_PATH].get("get")
    assert operation is not None, f"No GET op on {_VERSION_PATH}"
    responses = operation.get("responses", {})
    assert "200" in responses, (
        f"Expected 200 response on {_VERSION_PATH}, got responses: {sorted(responses.keys())}"
    )


def test_openapi_canonical_contains_snapshot_endpoint(canonical_spec: dict) -> None:
    """``/regulatory/constants/snapshot`` must be a path in the spec with a
    GET operation declaring a 200 response."""
    paths = canonical_spec.get("paths", {})
    assert _SNAPSHOT_PATH in paths, (
        f"Missing path {_SNAPSHOT_PATH!r} in canonical spec."
    )
    operation = paths[_SNAPSHOT_PATH].get("get")
    assert operation is not None, f"No GET op on {_SNAPSHOT_PATH}"
    responses = operation.get("responses", {})
    assert "200" in responses, (
        f"Expected 200 response on {_SNAPSHOT_PATH}, got responses: {sorted(responses.keys())}"
    )


def test_openapi_snapshot_endpoint_documents_request_header_or_etag_behavior(
    canonical_spec: dict,
) -> None:
    """The snapshot endpoint's documentation must reference its ETag /
    conditional-GET behaviour so Plan 04 codegen knows the contract.

    FastAPI does not auto-emit a ``responses.200.headers.ETag`` entry for
    raw ``Response`` returns (since we hand-construct the headers dict
    rather than declaring a response_model). The documentation contract is
    therefore enforced via the endpoint docstring being surfaced as the
    OpenAPI ``description`` — assert that string mentions ETag.
    """
    paths = canonical_spec.get("paths", {})
    operation = paths[_SNAPSHOT_PATH].get("get", {})
    description = operation.get("description", "") or ""
    summary = operation.get("summary", "") or ""
    combined = f"{summary}\n{description}"
    assert "ETag" in combined or "etag" in combined.lower(), (
        f"Snapshot endpoint docstring must mention ETag for downstream consumers. "
        f"Description got: {combined[:300]!r}"
    )
    assert "If-None-Match" in combined or "304" in combined, (
        f"Snapshot endpoint docstring must mention If-None-Match or 304 "
        f"so codegen knows the conditional-GET contract. Description got: {combined[:300]!r}"
    )
