"""Phase 30.7 TOOL-01: get_swiss_constants.

Wraps the backend RegulatoryRegistry singleton. Read-only. Stateless per call
(the singleton is module-level memoization, acceptable per RESEARCH.md).

Source of truth: services/backend/app/services/regulatory/registry.py.
Do NOT duplicate any constant value in this file. If a value looks wrong,
fix it in the backend registry — never patch it here.

Defensive PYTHONPATH injection at import time: when the MCP server spawns
this module via stdio, services/backend may not be on sys.path yet. We add
it here so `from app.services.regulatory.registry import RegulatoryRegistry`
resolves without the caller having to pip-install the backend as a package.
"""
from __future__ import annotations

import sys
import types
from datetime import date
from pathlib import Path
from typing import Any, Optional

from pydantic import BaseModel, Field

# ── Defensive PYTHONPATH ───────────────────────────────────────────────────
# tools/mcp/mint-tools/tools/constants.py → parents[4] == repo root.
# (parents[0]=tools, [1]=mint-tools, [2]=mcp, [3]=tools, [4]=repo root — same
# off-by-one fix as Wave 0 SUMMARY §Deviations item 1.)
_REPO_ROOT = Path(__file__).resolve().parents[4]
_BACKEND = _REPO_ROOT / "services" / "backend"
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

# ── Light-package shim for app.models ──────────────────────────────────────
# app/models/__init__.py eagerly imports ORM classes (sqlalchemy required).
# The MCP venv is intentionally minimal (no sqlalchemy). The registry only
# needs app.models.regulatory_parameter, which is a pure dataclass with zero
# DB deps. We pre-register `app` and `app.models` as namespace packages in
# sys.modules so Python skips running the heavy __init__ and falls back to
# loading leaf modules on demand.
def _ensure_lightweight_app_namespace() -> None:
    if "app" not in sys.modules:
        pkg = types.ModuleType("app")
        pkg.__path__ = [str(_BACKEND / "app")]  # type: ignore[attr-defined]
        sys.modules["app"] = pkg
    if "app.models" not in sys.modules:
        sub = types.ModuleType("app.models")
        sub.__path__ = [str(_BACKEND / "app" / "models")]  # type: ignore[attr-defined]
        sys.modules["app.models"] = sub


_ensure_lightweight_app_namespace()

# ── Public contract ────────────────────────────────────────────────────────
TOOL_VERSION = "30.7.0"

# Canonical public categories (CONTEXT.md Area 2). The registry uses a
# different internal prefix for tax (`capital_tax.*`) so we map the public
# name to the internal prefix before delegating.
_CATEGORY_TO_REGISTRY_PREFIX = {
    "pillar3a": "pillar3a",
    "lpp": "lpp",
    "avs": "avs",
    "mortgage": "mortgage",
    # Public "tax" maps to the registry's capital_tax.* namespace.
    "tax": "capital_tax",
}


class ConstantEntry(BaseModel):
    key: str
    value: float
    unit: str
    source_title: str = ""
    effective_from: str = ""
    tax_year: Optional[int] = None


class ConstantsResult(BaseModel):
    version: str = Field(default=TOOL_VERSION)
    category: str
    jurisdiction: str = "CH"
    constants: list[ConstantEntry]


def _coerce_effective_from(raw: Any) -> str:
    """Normalize effective_from to an ISO-format string.

    RegulatoryParameter.effective_from is a `datetime.date` object; the MCP
    envelope (Wave 2) serialises to JSON, so we convert here. Returns an
    empty string for None / missing values rather than raising.
    """
    if raw is None:
        return ""
    if isinstance(raw, date):
        return raw.isoformat()
    return str(raw)


def get_swiss_constants(category: str) -> ConstantsResult:
    """Return Swiss regulatory constants for one of the canonical categories.

    Unknown categories return ``constants=[]`` (no raise) so the MCP envelope
    can surface a structured empty response rather than a JSON-RPC fault.
    """
    # Lazy import — if backend fails to import, the MCP server still starts
    # and other tools keep working. Per RESEARCH.md Pitfall 3 (PYTHONPATH)
    # + Security T-30.7-01-02 (tampering: backend import failure).
    try:
        from app.services.regulatory.registry import (  # type: ignore[import-not-found]
            RegulatoryRegistry,
        )
    except ImportError:
        return ConstantsResult(
            category=category,
            constants=[],
            jurisdiction="CH",
        )

    registry_prefix = _CATEGORY_TO_REGISTRY_PREFIX.get(category)
    if registry_prefix is None:
        # Unknown public category — return structured empty payload.
        return ConstantsResult(
            category=category,
            constants=[],
            jurisdiction="CH",
        )

    params = RegulatoryRegistry.instance().get_all(category=registry_prefix)
    entries: list[ConstantEntry] = []
    for p in params:
        raw_value = getattr(p, "value", 0.0)
        # Some registry entries store tabular values (e.g. avs.echelle44 is a
        # 26-row table). Those cannot be represented as a single float; skip
        # them here — exposing tables is CONTEXT.md "deferred" scope and
        # will ship as a follow-up tool. Scalar entries only.
        if isinstance(raw_value, (int, float, bool)):
            scalar_value = float(raw_value)
        else:
            continue
        entries.append(
            ConstantEntry(
                key=getattr(p, "key", ""),
                value=scalar_value,
                unit=getattr(p, "unit", ""),
                source_title=getattr(p, "source_title", None) or "",
                effective_from=_coerce_effective_from(getattr(p, "effective_from", None)),
                tax_year=getattr(p, "tax_year", None),
            )
        )
    return ConstantsResult(category=category, constants=entries)
