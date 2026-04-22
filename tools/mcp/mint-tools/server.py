"""Phase 30.7 MCP stdio server — mint-tools.

Registers 4 tools over stdio transport. No per-call business logic here;
everything delegates to tools/{constants,banned_terms,arb_parity,accent}.py.

Do NOT print() or log to stdout — stdout is the JSON-RPC channel. All logs
go to stderr. See RESEARCH.md Pitfall 1.
"""
from __future__ import annotations

import logging
import sys
from pathlib import Path

# --- CRITICAL: logging to stderr BEFORE any other import that might log ---
# Keep stream=sys.stderr on the same line as basicConfig( so the acceptance
# grep ('logging.basicConfig(stream=sys.stderr') matches.
logging.basicConfig(stream=sys.stderr, level=logging.WARNING, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

# Defensive PYTHONPATH injection. .mcp.json should set this via env, but if the
# server is launched standalone (dev) we still want TOOL-01/02 backend imports to resolve.
# server.py lives at tools/mcp/mint-tools/server.py, so parents[3] == repo root
# (parents[0]=mint-tools, [1]=mcp, [2]=tools, [3]=repo root).
_REPO_ROOT = Path(__file__).resolve().parents[3]
_BACKEND = _REPO_ROOT / "services" / "backend"
_MCP_TOOLS = _REPO_ROOT / "tools" / "mcp" / "mint-tools"
for p in (_BACKEND, _MCP_TOOLS, _REPO_ROOT):
    ps = str(p)
    if p.exists() and ps not in sys.path:
        sys.path.insert(0, ps)

from mcp.server.fastmcp import FastMCP  # noqa: E402

from tools.constants import ConstantsResult, get_swiss_constants as _get_swiss_constants  # noqa: E402
from tools.banned_terms import BannedTermsResult, check_banned_terms as _check_banned_terms  # noqa: E402
from tools.arb_parity import ArbParityResult, validate_arb_parity as _validate_arb_parity  # noqa: E402
from tools.accent import AccentResult, check_accent_patterns as _check_accent_patterns  # noqa: E402

mcp = FastMCP("mint-tools")


@mcp.tool()
def get_swiss_constants(category: str) -> ConstantsResult:
    """Return Swiss regulatory constants for a given category.

    category: one of 'pillar3a', 'lpp', 'avs', 'mortgage', 'tax'.
    Unknown categories return an empty 'constants' list with the original
    category echoed — no exception is raised.

    Single source of truth: services/backend/app/services/regulatory/registry.py.
    Phase 30.7 TOOL-01.
    """
    return _get_swiss_constants(category)


@mcp.tool()
def check_banned_terms(text: str) -> BannedTermsResult:
    """Detect LSFin banned terms in a French text and return suggestions.

    Wraps ComplianceGuard (services/backend/app/services/coach/compliance_guard.py).
    Layer 1 only (banned terms). Layer 2/2b deferred to v2.9.

    Inputs longer than 10 000 chars are scanned on the prefix only; the
    response reports the original length in 'text_length'.

    Phase 30.7 TOOL-02.
    """
    return _check_banned_terms(text)


@mcp.tool()
def validate_arb_parity() -> ArbParityResult:
    """Run the ARB parity lint (tools/checks/arb_parity.py) across 6 ARB files.

    IMPORTANT: if status == 'lint_not_available' (pre-Phase-34 state), ARB
    parity is NOT verified. Do not conclude parity is OK. Invoke 'flutter
    gen-l10n' manually and grep for keyset equality across fr/en/de/es/it/pt.

    Phase 30.7 TOOL-03.
    """
    return _validate_arb_parity()


@mcp.tool()
def check_accent_patterns(text: str) -> AccentResult:
    """Detect ASCII-flattened French accent patterns in text.

    14 patterns sourced from tools/checks/accent_lint_fr.py (Phase 30.5
    early-ship). Phase 34 will extend the list; this tool inherits the
    extension for free.

    Phase 30.7 TOOL-04.
    """
    return _check_accent_patterns(text)


if __name__ == "__main__":
    mcp.run(transport="stdio")
