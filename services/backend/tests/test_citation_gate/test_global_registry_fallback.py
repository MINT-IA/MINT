"""D-07 fallback to the global CITATION_REGISTRY (now the only path).

mint-grounded-coach-m1 Plan 07 deleted the bundle compiler (WS-C
activate-or-delete), so the citation-gate wrapper ALWAYS passes
`citation_allowlist=None` — there is no compile-time allowlist anymore.

Pins :
- The wrapper unconditionally sets `_gate_allowlist = None`
  (the bundle-compiler compile-time allowlist branch was removed).
- The gate's `gate()` body interprets `citation_allowlist=None` as a
  fall-back to `set(CITATION_REGISTRY.keys())`.
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


def test_wrapper_unconditionally_passes_none_allowlist():
    """The wrapper unconditionally sets `_gate_allowlist = None` after the
    Plan 07 bundle-compiler removal — there is no compile-time allowlist
    branch left, so the gate always falls back to the global registry.
    """
    src = _coach_chat_src()
    # The bundle-compiler allowlist ternary is gone; a plain assignment
    # to None remains.
    pattern = re.compile(r"_gate_allowlist\s*=\s*None")
    assert pattern.search(src) is not None
    # And the removed dark flag must no longer appear as a functional
    # `settings.` reference in the source.
    assert "settings.COACH_BUNDLE_COMPILER_ENABLED" not in src
    assert "settings.COACH_DUAL_LLM_ENABLED" not in src


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
