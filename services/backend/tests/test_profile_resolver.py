"""Unit tests for `app.core.profile_resolver` shared helpers.

Plan: mint-calc-engine-v1-01-w1-shared-helpers Task 1
Verifies the three primitives `_resolve_defaults`, `_required_profile_fields_missing`,
and `raise_incomplete_as_422` per the W1-01-01 behavior contract (10 tests):

  - Body > profile > default precedence honoring `model_fields_set` (explicit-None
    vs unset distinction — D-CE-07).
  - Missing-field detection caps at 3 (D-A3-01 envelope cap inherited via D-CE-04).
  - Strict-mode HTTPException(422) carries the `CoachToolIncomplete` envelope
    verbatim (camelCase, D-CE-08).
  - Non-strict mode logs a warning + returns the resolved body for graceful
    Flutter rollout (D-CE-08 feature flag).

All hint_fr fixtures use « j'ai besoin de … pour estimer … » vocabulary — no
LSFin banned terms (CLAUDE.md §1 + threat T-mint-calc-01-07).
"""
from __future__ import annotations

import importlib
import logging
from typing import Optional

import pytest
from fastapi import HTTPException
from pydantic import BaseModel, Field


# Inline schema used across precedence tests. The `canton` field declares
# `from_profile` in `json_schema_extra` so the resolver knows the canonical
# profile key. The `random_field` does NOT carry the marker so we can assert
# Test 6 (fields without the marker are NOT considered required-via-profile).
class _TestRequest(BaseModel):
    canton: Optional[str] = Field(
        default=None,
        json_schema_extra={"from_profile": "canton"},
    )
    random_field: Optional[str] = Field(default=None)


def _reload_resolver(monkeypatch: pytest.MonkeyPatch, strict: bool):
    """Reload the module so the module-level `PROFILE_GROUNDING_STRICT_MODE`
    re-evaluates against the patched env var."""
    monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "true" if strict else "false")
    from app.core import profile_resolver as pr

    return importlib.reload(pr)


# --------------------------------------------------------------------------- #
# Test 1-4 — _resolve_defaults precedence semantics                           #
# --------------------------------------------------------------------------- #


def test_body_explicit_none_wins_over_profile():
    """Test 1 — body explicitly sets canton=None → body wins (explicit clear)."""
    from app.core.profile_resolver import _resolve_defaults

    resolved = _resolve_defaults(
        profile_data={"canton": "GE"},
        body=_TestRequest(canton=None),
        schema_class=_TestRequest,
    )
    assert resolved == {"canton": None, "random_field": None}


def test_profile_fills_when_body_unset():
    """Test 2 — body did NOT set canton → profile fills via from_profile marker."""
    from app.core.profile_resolver import _resolve_defaults

    resolved = _resolve_defaults(
        profile_data={"canton": "GE"},
        body=_TestRequest(),
        schema_class=_TestRequest,
    )
    assert resolved["canton"] == "GE"


def test_falls_through_to_default_when_profile_empty():
    """Test 3 — profile empty and body unset → falls through to Pydantic default."""
    from app.core.profile_resolver import _resolve_defaults

    resolved = _resolve_defaults(
        profile_data={},
        body=_TestRequest(),
        schema_class=_TestRequest,
    )
    assert resolved == {"canton": None, "random_field": None}


def test_none_profile_treated_as_empty():
    """Test 4 — profile_data=None is treated as empty dict; body value wins."""
    from app.core.profile_resolver import _resolve_defaults

    resolved = _resolve_defaults(
        profile_data=None,
        body=_TestRequest(canton="VD"),
        schema_class=_TestRequest,
    )
    assert resolved["canton"] == "VD"


# --------------------------------------------------------------------------- #
# Test 5-6 — _required_profile_fields_missing semantics                       #
# --------------------------------------------------------------------------- #


def test_required_missing_returns_profile_keys_capped_at_3():
    """Test 5 — reports profile-key list (NOT body field names) capped at 3."""

    class _Wide(BaseModel):
        a: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "key_a"})
        b: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "key_b"})
        c: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "key_c"})
        d: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "key_d"})

    from app.core.profile_resolver import _required_profile_fields_missing

    resolved = {"a": None, "b": None, "c": None, "d": None}
    missing = _required_profile_fields_missing(resolved, _Wide)
    # All 4 are missing → expect profile keys (not field names), capped at 3
    assert len(missing) == 3
    assert set(missing).issubset({"key_a", "key_b", "key_c", "key_d"})
    # Confirm profile keys (not body field names like "a", "b", ...)
    for entry in missing:
        assert entry.startswith("key_")


def test_required_missing_only_flags_from_profile_fields():
    """Test 6 — fields without `from_profile` marker are NOT considered required."""
    from app.core.profile_resolver import _required_profile_fields_missing

    resolved = {"canton": None, "random_field": None}
    missing = _required_profile_fields_missing(resolved, _TestRequest)
    # `random_field` has no from_profile marker → must not appear
    assert missing == ["canton"]


# --------------------------------------------------------------------------- #
# Test 7-8 — raise_incomplete_as_422 strict mode + cap enforcement            #
# --------------------------------------------------------------------------- #


def test_raise_incomplete_strict_mode_returns_422_with_envelope(monkeypatch):
    """Test 7 — strict mode raises HTTPException(422) carrying CoachToolIncomplete envelope (camelCase)."""
    pr = _reload_resolver(monkeypatch, strict=True)

    with pytest.raises(HTTPException) as exc_info:
        pr.raise_incomplete_as_422(
            missing_fields=["canton"],
            hint_fr="J'ai besoin de ton canton pour estimer ton imposition.",
        )

    assert exc_info.value.status_code == 422
    detail = exc_info.value.detail
    assert isinstance(detail, dict)
    # camelCase envelope per CoachToolIncomplete model_config alias_generator=to_camel
    assert detail["status"] == "incomplete"
    assert detail["missingFields"] == ["canton"]
    assert detail["hintFr"].startswith("J'ai besoin")


def test_cap_enforcement_at_envelope_level_in_both_modes(monkeypatch):
    """Test 8 — 4 missing fields > cap=3 → ValueError from envelope validator (mode-independent)."""
    # The cap belongs to CoachToolIncomplete._cap_missing_fields, NOT the helper.
    # Strict mode
    pr_strict = _reload_resolver(monkeypatch, strict=True)
    with pytest.raises(ValueError):
        pr_strict.raise_incomplete_as_422(
            missing_fields=["a", "b", "c", "d"],
            hint_fr="J'ai besoin de plusieurs champs pour estimer ton imposition.",
        )

    # Non-strict mode — same cap, same ValueError (envelope is built first)
    pr_non_strict = _reload_resolver(monkeypatch, strict=False)
    with pytest.raises(ValueError):
        pr_non_strict.raise_incomplete_as_422(
            missing_fields=["a", "b", "c", "d"],
            hint_fr="J'ai besoin de plusieurs champs pour estimer ton imposition.",
            resolved_body={"x": 1},
            endpoint="/foo",
        )


# --------------------------------------------------------------------------- #
# Test 9-10 — D-CE-08 non-strict graceful fallback + ENV default               #
# --------------------------------------------------------------------------- #


def test_non_strict_mode_logs_warning_and_returns_resolved_body(monkeypatch):
    """Test 9 — non-strict mode does NOT raise, emits warning + returns resolved_body.

    Attaches a dedicated `_RecordCollector` handler directly to the module
    logger instead of relying on pytest's `caplog` — `app.core.logging_config.
    setup_logging()` invoked by upstream integration tests calls
    `root_logger.handlers.clear()`, which evicts pytest's caplog handler
    from the root logger and causes suite-order-dependent failures (Rule 3
    auto-fix : isolate the test from observed upstream pollution).
    """
    pr = _reload_resolver(monkeypatch, strict=False)

    class _RecordCollector(logging.Handler):
        def __init__(self):
            super().__init__(level=logging.WARNING)
            self.records: list[logging.LogRecord] = []

        def emit(self, record: logging.LogRecord) -> None:
            self.records.append(record)

    collector = _RecordCollector()
    # Force-reset the module logger : stdlib `logging.getLogger(name)` returns
    # a process-global cached instance, so a prior test that called
    # `setLevel(CRITICAL)`, `disabled = True`, or removed the propagate flag
    # would silence our handler even after `importlib.reload(pr)`. Reset
    # explicitly so the test is self-contained.
    pr._logger.setLevel(logging.WARNING)
    pr._logger.disabled = False
    pr._logger.propagate = True
    pr._logger.addHandler(collector)
    try:
        out = pr.raise_incomplete_as_422(
            missing_fields=["canton"],
            hint_fr="J'ai besoin de ton canton pour estimer.",
            resolved_body={"x": 1},
            endpoint="/foo",
        )
    finally:
        pr._logger.removeHandler(collector)

    assert out == {"x": 1}
    warnings = [r for r in collector.records if r.levelno == logging.WARNING]
    assert any(r.msg == "profile_grounding_incomplete_non_strict" for r in warnings)
    rec = next(r for r in warnings if r.msg == "profile_grounding_incomplete_non_strict")
    assert rec.endpoint == "/foo"
    assert rec.missing_fields == ["canton"]
    assert rec.hint_fr.startswith("J'ai besoin")


def test_env_default_is_non_strict(monkeypatch):
    """Test 10 — running WITHOUT setting PROFILE_GROUNDING_STRICT_MODE defaults to non-strict.

    Strict mode requires explicit opt-in.
    """
    monkeypatch.delenv("PROFILE_GROUNDING_STRICT_MODE", raising=False)
    from app.core import profile_resolver as pr

    importlib.reload(pr)
    assert pr.PROFILE_GROUNDING_STRICT_MODE is False
