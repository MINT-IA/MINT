"""Regulatory constants API — single source of truth for Swiss financial parameters.

GET /api/v1/regulatory/constants          → list all (with optional category filter)
GET /api/v1/regulatory/constants/{key}    → get single constant
GET /api/v1/regulatory/freshness          → check stale parameters

Consumers:
    - Flutter app (sync constants at startup)
    - LLM tools (get_regulatory_constant)
    - Internal dashboards (freshness monitoring)

Compliance:
    - Read-only endpoints (no mutation).
    - No PII — only regulatory constants.

Sources:
    - CLAUDE.md §5 (Key Constants 2025/2026)
    - app/services/regulatory/registry.py
"""

from __future__ import annotations

import json
from datetime import date
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, Request, Response
from fastapi.responses import JSONResponse

from app.services.regulatory.registry import RegulatoryRegistry

router = APIRouter(prefix="/regulatory", tags=["regulatory"])


@router.get("/constants")
def list_constants(
    category: Optional[str] = Query(
        None,
        description="Filter by category prefix: avs, lpp, pillar3a, mortgage, capital_tax, ai, apg, ac, lamal",
    ),
    canton: Optional[str] = Query(
        None,
        description="Filter by canton code (e.g. ZH, GE, VS). Only returns cantonal parameters.",
    ),
) -> dict:
    """List all regulatory constants, optionally filtered by category or canton.

    Returns:
        JSON with "count" and "constants" (list of parameter dicts).
    """
    registry = RegulatoryRegistry.instance()
    params = registry.get_all(category=category)

    if canton:
        canton_upper = canton.upper()
        params = [p for p in params if p.jurisdiction == canton_upper]

    return {
        "count": len(params),
        "constants": [p.to_dict() for p in params],
    }


@router.get("/constants/version")
def get_constants_version() -> JSONResponse:
    """Lightweight delta-check endpoint (D-08 + D-15).

    Returns the active version_hash + effective_from + reviewed_at as a
    small JSON body (< 1 KB) so the mobile client can decide whether to
    fetch the full /snapshot. ETag header derived from version_hash for
    HTTP-cache friendliness.

    Phase mint-data-architecture-v1-01-calc-engine-canonical Plan 03 Task 1.
    Canonical insertion rule : MUST be registered BEFORE /constants/{key:path}
    so the catch-all does not shadow this route.
    """
    registry = RegulatoryRegistry.instance()
    today = date.today()
    active = [p for p in registry.get_all() if p.is_active(today)]

    # Null-safe derivation per codex MEDIUM finding — min/max over [] would raise.
    effective_from = min(
        (p.effective_from for p in active if p.effective_from is not None),
        default=None,
    )
    reviewed_at = max(
        (p.reviewed_at for p in active if p.reviewed_at is not None),
        default=None,
    )

    version_hash = registry.version_hash(today)
    payload = {
        "version_hash": version_hash,
        "effective_from": effective_from.isoformat() if effective_from else None,
        "reviewed_at": reviewed_at.isoformat() if reviewed_at else None,
    }
    # Byte-stable serialisation matching Plan 01 measurement pipeline.
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True, ensure_ascii=False)
    return JSONResponse(
        content=json.loads(body),
        headers={
            "ETag": f'W/"{version_hash}"',
            "Cache-Control": "public, max-age=60, must-revalidate",
        },
    )


@router.get("/constants/snapshot")
def get_constants_snapshot(request: Request) -> Response:
    """Full active 26-canton regulatory snapshot (D-08 + D-15 + D-16).

    Same serialisation pipeline as tools/measurement/regulatory_snapshot_bundle_size.py
    (Plan 01) so byte-count + version_hash stay coherent across measurement,
    codegen (Plan 04), and runtime delta-check. Response carries a weak ETag
    header ``W/"<version_hash>"`` ; supports If-None-Match conditional GET
    (304 Not Modified) per RFC 7232. Cache-Control: public, max-age=300,
    must-revalidate.

    Phase mint-data-architecture-v1-01-calc-engine-canonical Plan 03 Task 2.
    Canonical insertion rule : MUST be registered BEFORE /constants/{key:path}
    so the catch-all does not shadow this route.
    """
    registry = RegulatoryRegistry.instance()
    today = date.today()
    active = [p for p in registry.get_all() if p.is_active(today)]
    version_hash = registry.version_hash(today)
    etag = f'W/"{version_hash}"'

    # Conditional GET — RFC 7232 §3.2. Return 304 if client already has this snapshot.
    if_none_match = request.headers.get("If-None-Match")
    if if_none_match == etag:
        return Response(
            status_code=304,
            headers={
                "ETag": etag,
                "Cache-Control": "public, max-age=300, must-revalidate",
            },
        )

    payload = {
        # Legacy key kept for byte-parity with Plan 01 measurement script.
        "active_version_hash": version_hash,
        # Canonical D-15 key consumed by Plan 04 codegen + mobile delta-check.
        "version_hash": version_hash,
        "effective_on": today.isoformat(),
        "param_count": len(active),
        "parameters": [p.to_dict() for p in active],
    }
    # Byte-stable serialisation matching Plan 01 measurement script.
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True, ensure_ascii=False)
    return Response(
        content=body,
        media_type="application/json",
        headers={
            "ETag": etag,
            "Cache-Control": "public, max-age=300, must-revalidate",
        },
    )


@router.get("/constants/{key:path}")
def get_constant(
    key: str,
    canton: Optional[str] = Query(
        None,
        description="Canton code for cantonal parameters (e.g. ZH, GE).",
    ),
) -> dict:
    """Get a single regulatory constant by key.

    Args:
        key: Dotted parameter key (e.g. "pillar3a.max_with_lpp", "avs.max_monthly_pension").
        canton: Optional canton code for cantonal parameters.

    Returns:
        The parameter as a JSON dict.

    Raises:
        404 if the key is not found.
    """
    registry = RegulatoryRegistry.instance()
    jurisdiction = canton.upper() if canton else "CH"
    param = registry.get(key, jurisdiction=jurisdiction)

    if param is None:
        raise HTTPException(
            status_code=404,
            detail=f"Regulatory parameter '{key}' not found (jurisdiction={jurisdiction}).",
        )

    return param.to_dict()


@router.get("/freshness")
def check_freshness(
    max_age_days: int = Query(
        90,
        description="Maximum number of days since last review before a parameter is considered stale.",
    ),
) -> dict:
    """Check which parameters are stale and need review.

    Returns:
        JSON with "stale_count" and "stale_parameters" (list of parameter dicts).
    """
    registry = RegulatoryRegistry.instance()
    stale = registry.check_freshness(max_age_days=max_age_days)

    return {
        "stale_count": len(stale),
        "max_age_days": max_age_days,
        "stale_parameters": [p.to_dict() for p in stale],
    }
