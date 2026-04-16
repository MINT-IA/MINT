"""
force_level override safety test — Phase 11 / VOICE-06.

The reverse-Krippendorff runner forces N4 register via a thin wrapper
(`tools/krippendorff/reverse_generation_test.force_level_n4_directive`).
This test enforces three properties of the wrapper (T-11-07 mitigation):

  1. The directive IS injected — the returned prompt contains an explicit
     N4 directive marker.
  2. The base prompt is preserved (additive, not destructive) — every line
     of the base prompt still appears in the augmented version.
  3. The wrapper is keyword-only — it cannot be called positionally from
     a request handler that might forward user-controlled args.
  4. The wrapper does NOT import or invoke ComplianceGuard, the N5 weekly
     gate, or the fragility detector — it CANNOT bypass them because it
     is a pure string transform with no side effects.

This is the only "force_level" surface in the codebase. If the runner ever
grows a new override path, it must be tested here.
"""

from __future__ import annotations

import importlib.util
import inspect
import sys
from pathlib import Path

import pytest


# ── Load the runner module by file path (lives in tools/, not in package) ──
REPO_ROOT = Path(__file__).resolve().parents[4]
RUNNER_PATH = REPO_ROOT / "tools" / "krippendorff" / "reverse_generation_test.py"


@pytest.fixture(scope="module")
def runner_module():
    spec = importlib.util.spec_from_file_location(
        "reverse_generation_test_module", RUNNER_PATH
    )
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules["reverse_generation_test_module"] = mod
    spec.loader.exec_module(mod)
    return mod


# ════════════════════════════════════════════════════════════════════════════
# Property 1 — directive is injected
# ════════════════════════════════════════════════════════════════════════════

def test_force_level_appends_n4_directive(runner_module):
    base = "## SYSTEM\nYou are MINT. Answer in French."
    augmented = runner_module.force_level_n4_directive(base_system_prompt=base)
    assert "VOIX — NIVEAU FORCÉ : N4" in augmented
    assert "N4" in augmented
    assert "compliance" in augmented.lower()  # explicit reminder to keep gates


# ════════════════════════════════════════════════════════════════════════════
# Property 2 — base prompt is preserved (additive)
# ════════════════════════════════════════════════════════════════════════════

def test_force_level_is_additive(runner_module):
    base = "## SYSTEM\nLine A\nLine B\nLine C"
    augmented = runner_module.force_level_n4_directive(base_system_prompt=base)
    assert augmented.startswith(base), (
        "force_level must be additive — base prompt must remain at the head, "
        "untouched. Otherwise it could silently strip compliance instructions."
    )
    for line in ("Line A", "Line B", "Line C"):
        assert line in augmented


# ════════════════════════════════════════════════════════════════════════════
# Property 3 — keyword-only signature
# ════════════════════════════════════════════════════════════════════════════

def test_force_level_is_keyword_only(runner_module):
    sig = inspect.signature(runner_module.force_level_n4_directive)
    params = list(sig.parameters.values())
    assert len(params) == 1
    assert params[0].name == "base_system_prompt"
    assert params[0].kind == inspect.Parameter.KEYWORD_ONLY, (
        "force_level_n4_directive must be keyword-only to prevent positional "
        "misuse from request handlers (T-11-07)."
    )


def test_force_level_rejects_positional_call(runner_module):
    with pytest.raises(TypeError):
        runner_module.force_level_n4_directive("base prompt")  # type: ignore


# ════════════════════════════════════════════════════════════════════════════
# Property 4 — no compliance/gate bypass (pure string transform)
# ════════════════════════════════════════════════════════════════════════════

def test_force_level_does_not_import_compliance_or_gates(runner_module):
    """The wrapper module imports must NOT include ComplianceGuard, the N5
    weekly gate, or the fragility detector. If they appear, someone tried to
    smuggle a bypass — fail loud.
    """
    src = RUNNER_PATH.read_text(encoding="utf-8")
    # The wrapper itself + the function body must not reference these.
    fn_src = inspect.getsource(runner_module.force_level_n4_directive)
    forbidden = [
        "ComplianceGuard",
        "n5_weekly_gate",
        "fragility_detector",
        "n5IssuedThisWeek",
    ]
    for token in forbidden:
        assert token not in fn_src, (
            f"force_level_n4_directive must not reference {token!r} — "
            "it would risk bypassing the gate."
        )


def test_force_level_rejects_empty_base(runner_module):
    with pytest.raises(ValueError):
        runner_module.force_level_n4_directive(base_system_prompt="")
    with pytest.raises(ValueError):
        runner_module.force_level_n4_directive(base_system_prompt=None)  # type: ignore


def test_force_level_returns_str(runner_module):
    out = runner_module.force_level_n4_directive(base_system_prompt="hello")
    assert isinstance(out, str)
    assert len(out) > len("hello")
