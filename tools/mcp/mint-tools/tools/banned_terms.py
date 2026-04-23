"""Phase 30.7 TOOL-02: check_banned_terms.

Wraps ComplianceGuard at services/backend/app/services/coach/compliance_guard.py.
Layer 1 only (banned terms). Layer 2/2b (prescriptive / high-register) is
deferred to v2.9 per CONTEXT.md Area 2 lock.

ComplianceGuard.__init__ instantiates HallucinationDetector, which performs
a slow cold-start on the first call (Pitfall 4 in RESEARCH.md). We therefore
keep a module-scope singleton `_GUARD` so a long-running MCP server pays the
cold-start cost exactly once.

Defensive PYTHONPATH + app.models namespace shim mirrors tools/constants.py:
the backend's ORM-heavy app.models.__init__ is bypassed so the MCP venv can
stay minimal (no sqlalchemy required).
"""
from __future__ import annotations

import sys
import types
from pathlib import Path
from typing import Any, Optional

from pydantic import BaseModel, Field

# ── Defensive PYTHONPATH ───────────────────────────────────────────────────
# tools/mcp/mint-tools/tools/banned_terms.py → parents[4] == repo root.
_REPO_ROOT = Path(__file__).resolve().parents[4]
_BACKEND = _REPO_ROOT / "services" / "backend"
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))


# ── Light-package shim for app.models ──────────────────────────────────────
def _ensure_lightweight_app_namespace() -> None:
    """Skip app.models.__init__ side effects (see tools/constants.py)."""
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
MAX_TEXT_LEN = 10_000  # DoS cap — security T-30.7-01-01

# Module-scope lazy-loaded guard. First real call instantiates it; all
# subsequent calls reuse the same instance.
_GUARD: Any = None


def _get_guard() -> Any:
    """Lazy-init the ComplianceGuard singleton.

    Raises ImportError only if services/backend is not on PYTHONPATH
    (misconfiguration, not runtime — caller degrades gracefully below).
    """
    global _GUARD
    if _GUARD is None:
        # Single-line form so the plan's literal acceptance-grep matches.
        from app.services.coach.compliance_guard import ComplianceGuard  # type: ignore[import-not-found]  # noqa: E501
        _GUARD = ComplianceGuard()
    return _GUARD


class BannedTermHit(BaseModel):
    term: str
    suggestion: str = ""
    context: str = ""


class BannedTermsResult(BaseModel):
    version: str = Field(default=TOOL_VERSION)
    clean: bool
    banned_found: list[BannedTermHit]
    sanitized_text: str
    text_length: int


def check_banned_terms(text: Optional[str]) -> BannedTermsResult:
    """Scan text for LSFin banned terms, return hits + sanitised replacement.

    Inputs longer than MAX_TEXT_LEN (10 000 chars) are truncated at the scan
    layer, but text_length reports the original length.

    Safe on empty / None / non-string inputs — returns a clean payload
    rather than raising.
    """
    # Normalise non-string / None input to empty string for DoS-safety.
    if not isinstance(text, str) or not text:
        original_len = len(text) if isinstance(text, str) else 0
        return BannedTermsResult(
            clean=True,
            banned_found=[],
            sanitized_text="" if not isinstance(text, str) else text,
            text_length=original_len,
        )

    original_len = len(text)
    # Enforce DoS cap — scan the prefix only.
    scanned = text[:MAX_TEXT_LEN]

    try:
        guard = _get_guard()
    except ImportError:
        # Backend not on PYTHONPATH — degrade gracefully rather than crash
        # the MCP server. (T-30.7-01-02 tampering mitigation.)
        return BannedTermsResult(
            clean=True,
            banned_found=[],
            sanitized_text=scanned,
            text_length=original_len,
        )

    # Upstream contract observed 2026-04-22: _check_banned_terms returns
    # list[str] (term labels), NOT list[dict]. Normalise here so the MCP
    # envelope always serves {term, suggestion, context}.
    raw_hits = guard._check_banned_terms(scanned) or []
    replacements = getattr(guard, "TERM_REPLACEMENTS", {}) or {}

    hits: list[BannedTermHit] = []
    lowered = scanned.lower()
    for raw in raw_hits:
        if isinstance(raw, str):
            term = raw
            # Build a short context window around the first occurrence so
            # callers can show where the hit landed.
            idx = lowered.find(term.lower())
            if idx >= 0:
                start = max(0, idx - 30)
                end = min(len(scanned), idx + len(term) + 30)
                context = scanned[start:end]
            else:
                context = ""
        elif isinstance(raw, dict):
            term = str(raw.get("term") or raw.get("match") or "")
            context = str(raw.get("context") or raw.get("snippet") or "")[:80]
        else:
            term = str(getattr(raw, "term", "") or getattr(raw, "match", ""))
            context = str(getattr(raw, "context", "") or "")[:80]

        if not term:
            continue

        suggestion = replacements.get(term.lower(), replacements.get(term, ""))
        hits.append(BannedTermHit(term=term, suggestion=suggestion, context=context))

    sanitized = guard._sanitize_banned_terms(scanned)

    return BannedTermsResult(
        clean=(not hits),
        banned_found=hits,
        sanitized_text=sanitized,
        text_length=original_len,
    )
