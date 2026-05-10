"""Phase 94 Wave 0 — COACH_CITATION_GATE_ENABLED flag (D-19).

Pins :
- Default OFF in code (`Settings().COACH_CITATION_GATE_ENABLED is False`).
- Env binding works (`COACH_CITATION_GATE_ENABLED=true` → `True`).

Mirrors the COACH_DUAL_LLM_ENABLED + COACH_BUNDLE_COMPILER_ENABLED pattern
from Phase 91 / Phase 93.5.
"""
from __future__ import annotations

import pytest

from app.core.config import Settings, settings


def test_default_is_false():
    """Module-level singleton — flag default OFF (D-19)."""
    assert settings.COACH_CITATION_GATE_ENABLED is False


def test_default_is_false_on_fresh_settings():
    """Fresh `Settings()` instantiation also defaults OFF (no env override)."""
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is False


def test_env_binding_true(monkeypatch: pytest.MonkeyPatch):
    """COACH_CITATION_GATE_ENABLED=true env var → flag True."""
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "true")
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is True


def test_env_binding_false(monkeypatch: pytest.MonkeyPatch):
    """COACH_CITATION_GATE_ENABLED=false env var → flag False (explicit)."""
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "false")
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is False
