"""Phase 30.7 TOOL-03: validate_arb_parity.

Subprocess-wraps ``tools/checks/arb_parity.py`` (a Phase 34 GUARD-05 deliverable
that does not yet exist at Phase 30.7 ship time).

Graceful fallback: when the script is missing, return a payload with
``status="lint_not_available"`` that is DISTINCT from ``"ok"``. Agents must
NOT conflate the two — see RESEARCH.md Pitfall 5.

Design notes:
- Subprocess command uses ``sys.executable`` (not literal ``"python3"``),
  per RESEARCH.md Pitfall 2 — host default python3 is 3.9.6 on macOS Tahoe
  and cannot run scripts that require 3.10+ syntax.
- stdout/stderr truncated to last ``MAX_OUTPUT_CHARS`` bytes so multi-MB
  drift reports do not blow up the MCP JSON-RPC envelope (Pitfall 1-adjacent:
  the tool never prints to stdout; it returns a capped payload).
- 30 s timeout prevents a hung lint from wedging the whole agent session.
- Repeated calls with identical filesystem state return equal payloads
  (stateless; no caching, no global mutation).
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Literal, Optional

from pydantic import BaseModel, Field

TOOL_VERSION = "30.7.0"
SUBPROCESS_TIMEOUT_S = 30
MAX_OUTPUT_CHARS = 4_000

# Resolve relative to the repo root. This module lives at
# tools/mcp/mint-tools/tools/arb_parity.py, so parents[4] == repo root
# (same off-by-one convention as constants.py / banned_terms.py — see
# 30.7-00-SUMMARY.md §Deviations item 1).
_REPO_ROOT = Path(__file__).resolve().parents[4]
ARB_PARITY_SCRIPT = _REPO_ROOT / "tools" / "checks" / "arb_parity.py"


Status = Literal["ok", "drift_detected", "lint_not_available", "timeout", "error"]


class ArbParityResult(BaseModel):
    version: str = Field(default=TOOL_VERSION)
    status: Status
    exit_code: Optional[int] = None
    reason: str = ""
    stdout: str = ""
    stderr: str = ""
    script_expected_at: str = ""


def _truncate(s: Optional[str]) -> str:
    """Keep the tail of long outputs — drift reports put errors at the bottom."""
    if not s:
        return ""
    if len(s) <= MAX_OUTPUT_CHARS:
        return s
    return "...[truncated]...\n" + s[-MAX_OUTPUT_CHARS:]


def validate_arb_parity() -> ArbParityResult:
    """Run the ARB parity lint if present, otherwise return structured fallback.

    IMPORTANT for agents: when ``status == "lint_not_available"``, ARB parity
    has NOT been verified. Do not conclude parity is OK. The fallback status
    exists so the MCP tool surface stays stable even before Phase 34 ships
    ``tools/checks/arb_parity.py``.
    """
    if not ARB_PARITY_SCRIPT.exists():
        return ArbParityResult(
            status="lint_not_available",
            reason=(
                "Phase 34 GUARD-05 (tools/checks/arb_parity.py) not yet shipped; "
                "re-run this tool after Phase 34 lands."
            ),
            script_expected_at=str(ARB_PARITY_SCRIPT),
        )

    try:
        proc = subprocess.run(
            [sys.executable, str(ARB_PARITY_SCRIPT)],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_S,
            cwd=str(_REPO_ROOT),
        )
    except subprocess.TimeoutExpired:
        return ArbParityResult(
            status="timeout",
            reason=f"subprocess exceeded {SUBPROCESS_TIMEOUT_S}s timeout",
            script_expected_at=str(ARB_PARITY_SCRIPT),
        )
    except (OSError, ValueError) as exc:
        return ArbParityResult(
            status="error",
            reason=f"subprocess failed: {exc}",
            script_expected_at=str(ARB_PARITY_SCRIPT),
        )

    status: Status = "ok" if proc.returncode == 0 else "drift_detected"
    return ArbParityResult(
        status=status,
        exit_code=proc.returncode,
        stdout=_truncate(proc.stdout),
        stderr=_truncate(proc.stderr),
        script_expected_at=str(ARB_PARITY_SCRIPT),
    )
