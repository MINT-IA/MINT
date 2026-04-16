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

from typing import Optional

from fastapi import APIRouter, HTTPException, Query

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
