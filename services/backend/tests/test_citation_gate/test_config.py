"""COACH_CITATION_GATE_ENABLED flag — ACTIVATED in mint-grounded-coach-m1
Plan 07 (WS-C activate-or-delete resolution).

Pins :
- Default ON in code (`Settings().COACH_CITATION_GATE_ENABLED is True`) — the
  closed-world citation gate is now the live narrator-stage guard.
- Env binding still works in both directions (rollback to OFF via
  `COACH_CITATION_GATE_ENABLED=false` is the documented kill-switch).

The COACH_DUAL_LLM_ENABLED + COACH_BUNDLE_COMPILER_ENABLED flags this file
once mirrored were DELETED in Plan 07 (no flag-OFF façade remains, NEVER #6).
"""
from __future__ import annotations

import pytest

from app.core.config import Settings, settings


def test_default_is_true():
    """Module-level singleton — flag default ON (Plan 07 activation)."""
    assert settings.COACH_CITATION_GATE_ENABLED is True


def test_default_is_true_on_fresh_settings():
    """Fresh `Settings()` instantiation also defaults ON (no env override)."""
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is True


def test_env_binding_true(monkeypatch: pytest.MonkeyPatch):
    """COACH_CITATION_GATE_ENABLED=true env var → flag True."""
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "true")
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is True


def test_env_binding_false_is_the_rollback_switch(monkeypatch: pytest.MonkeyPatch):
    """COACH_CITATION_GATE_ENABLED=false env var → flag False — the
    documented rollback path that restores the byte-identical OFF narrator
    output (Plan 07 kill-switch)."""
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "false")
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is False
