"""Phase 30.7 TOOL-04: check_accent_patterns.

Wraps ``tools/checks/accent_lint_fr.scan_text`` (additive helper shipped in
Wave 0 Task 2). Shares the 14-pattern list via import — the tool module does
NOT duplicate PATTERNS. Phase 34 will extend the list; this tool inherits
the extension for free.

Design notes:
- DoS cap at MAX_TEXT_LEN (10 000 chars) mirrors TOOL-02; the scan runs on
  the capped prefix but ``text_length`` reports the original length so the
  caller can detect truncation.
- Empty / None input returns a clean result rather than raising, so the MCP
  envelope serves a structured success payload even for degenerate input.
- No ``mcp`` import here — Wave 2 adds the ``@mcp.tool()`` decorator.
- Stateless: repeated calls with identical input return equal payloads.
"""
from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field

# ── Defensive PYTHONPATH ───────────────────────────────────────────────────
# tools/mcp/mint-tools/tools/accent.py → parents[4] == repo root.
# (parents[0]=tools, [1]=mint-tools, [2]=mcp, [3]=tools, [4]=repo root — same
# off-by-one convention as constants.py / banned_terms.py / arb_parity.py.)
_REPO_ROOT = Path(__file__).resolve().parents[4]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

# Import the Wave 0 additive helper — single source of truth for the 14
# PATTERNS list. Phase 34 extensions propagate here automatically.
from tools.checks.accent_lint_fr import scan_text as _scan_text  # noqa: E402

# ── Public contract ────────────────────────────────────────────────────────
TOOL_VERSION = "30.7.0"
MAX_TEXT_LEN = 10_000  # DoS cap — mirrors TOOL-02


class AccentHit(BaseModel):
    line: int
    snippet: str
    pattern: str
    suggestion: str


class AccentResult(BaseModel):
    version: str = Field(default=TOOL_VERSION)
    clean: bool
    violations: list[AccentHit]
    text_length: int


def _parse_correction(raw: str) -> tuple[str, str]:
    """Split the ``"pattern -> correction"`` string produced by scan_text."""
    if " -> " not in raw:
        return raw, ""
    pat, _, correction = raw.partition(" -> ")
    return pat, correction


def check_accent_patterns(text: Optional[str]) -> AccentResult:
    """Scan French text for ASCII-flattened accents.

    Inputs longer than MAX_TEXT_LEN are scanned on the capped prefix; the
    returned ``text_length`` reports the ORIGINAL length so the caller can
    detect truncation. Empty / None inputs return a clean result without
    raising.
    """
    original_len = len(text) if isinstance(text, str) else 0
    if not isinstance(text, str) or not text:
        return AccentResult(clean=True, violations=[], text_length=original_len)

    # Enforce DoS cap — scan the prefix only.
    scanned = text[:MAX_TEXT_LEN]
    raw_hits = _scan_text(scanned)
    violations: list[AccentHit] = []
    for lineno, snippet, raw_pattern in raw_hits:
        pattern, suggestion = _parse_correction(raw_pattern)
        violations.append(
            AccentHit(
                line=lineno,
                snippet=snippet,
                pattern=pattern,
                suggestion=suggestion,
            )
        )

    return AccentResult(
        clean=(not violations),
        violations=violations,
        text_length=original_len,
    )
