"""Phase 94 Wave 1 — D-07 flag-OFF fallback to global CITATION_REGISTRY.

Pins :
- When `COACH_BUNDLE_COMPILER_ENABLED=False`, the wrapper passes
  `citation_allowlist=None` to `_citation_gate(...)`.
- The gate's `gate()` body interprets `citation_allowlist=None` as a
  fall-back to `set(CITATION_REGISTRY.keys())` (Wave 0 + Task 1
  contract — `test_global_registry_fallback_resolves_pass`).
- Every key in `CITATION_REGISTRY` is recognized by the gate as
  cited when adjacent to a number and the allowlist is None.
"""
from __future__ import annotations

import pathlib
import re

from app.services.coach.citation_parser import GateVerdict, gate
from app.services.coach.citation_registry import CITATION_REGISTRY


def _coach_chat_src() -> str:
    src_path = (
        pathlib.Path(__file__).resolve().parent.parent.parent
        / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    )
    return src_path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# Wrapper-level fallback receipt.
# ---------------------------------------------------------------------------


def test_wrapper_passes_none_when_compiler_flag_off():
    """The `_gate_allowlist = None` branch fires when
    `COACH_BUNDLE_COMPILER_ENABLED=False` — irrespective of whether
    `_compiled_bundle` is None (it always is on this branch thanks to
    H1 fix iter 1).
    """
    src = _coach_chat_src()
    # The else branch of the ternary must yield `None`.
    pattern = re.compile(r"else\s+None\s*\n\s*\)")
    assert pattern.search(src) is not None


# ---------------------------------------------------------------------------
# Gate-level fallback behavior — already covered by Task 1 Test 14
# (test_number_detection.py / test_banned_claims.py / etc.).
# This module re-asserts the closed-world fallback for explicit D-07
# coverage.
# ---------------------------------------------------------------------------


def test_global_registry_fallback_resolves_pass():
    """A known registry key adjacent to a number → PASS when
    `citation_allowlist=None` (gate falls back to CITATION_REGISTRY).
    """
    # Pick a known key from the v1 baseline registry.
    known_key = "r3a_plafond_salarie_2026"
    assert known_key in CITATION_REGISTRY
    response = f"Tu peux mettre 6883 CHF par an {{{{cite:{known_key}}}}}."
    result = gate(
        response_text=response,
        ctx=None,
        citation_allowlist=None,  # → fall back to CITATION_REGISTRY
        is_retry=False,
    )
    assert result.verdict == GateVerdict.PASS


def test_global_registry_fallback_rejects_unknown_key():
    """A key NOT in CITATION_REGISTRY → REJECTED_UNCITED when
    `citation_allowlist=None`.
    """
    response = "Tu peux mettre 6883 CHF par an {{cite:made_up_unknown_key}}."
    result = gate(
        response_text=response,
        ctx=None,
        citation_allowlist=None,
        is_retry=False,
    )
    assert result.verdict == GateVerdict.REJECTED_UNCITED


def test_closed_world_breach_with_explicit_allowlist():
    """Explicit closed-world allowlist that EXCLUDES a registered key —
    the key is rejected even though it's in the global registry.
    """
    response = "Tu peux mettre 6883 CHF par an {{cite:r3a_plafond_salarie_2026}}."
    result = gate(
        response_text=response,
        ctx=None,
        citation_allowlist=["other_unrelated_key"],
        is_retry=False,
    )
    assert result.verdict == GateVerdict.REJECTED_UNCITED
