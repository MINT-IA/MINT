"""Phase 96-03 OBS-03 — best-effort wrap unit tests.

Validates the « never break the user response » contract:
  * ``sentry_sdk`` import raising ImportError → helper returns silently.
  * ``sentry_sdk.set_tag`` raising mid-call → helper swallows the
    exception, logs a warning, and emits a breadcrumb (no propagation).
  * Repeat calls with malformed eval_score do not raise.

This is the « bare except is forbidden » CLAUDE.md §5 guarantee:
the helper catches a SPECIFIC exception, logs it, and emits a Sentry
breadcrumb so the regression is observable in production.
"""
from __future__ import annotations

import logging
import sys
import types

import pytest


def test_missing_sentry_sdk_does_not_raise(monkeypatch):
    """If sentry_sdk is unavailable the helper returns silently."""
    # Force `import sentry_sdk` inside the helper to raise ImportError
    # without polluting other tests.
    monkeypatch.setitem(sys.modules, "sentry_sdk", None)
    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    # Must not raise.
    emit_sentry_audit_tags(
        eclairage_kind="fiscal_margin_3a",
        banned_term_hit=False,
        eval_score="unavailable",
        archetype="swiss_native",
    )


def test_set_tag_raising_does_not_break_response(monkeypatch, caplog):
    """When set_tag raises, the helper swallows + logs + breadcrumbs."""
    breadcrumbs: list[dict] = []

    fake = types.ModuleType("sentry_sdk")

    def _set_tag(name: str, value: str) -> None:
        raise RuntimeError("sentry transport down")

    def _add_breadcrumb(**kwargs):
        breadcrumbs.append(kwargs)

    fake.set_tag = _set_tag
    fake.add_breadcrumb = _add_breadcrumb
    monkeypatch.setitem(sys.modules, "sentry_sdk", fake)

    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    with caplog.at_level(logging.WARNING, logger="app.utils.sentry_audit_tags"):
        emit_sentry_audit_tags(
            eclairage_kind="fatca_handoff",
            banned_term_hit=True,
            eval_score=0.42,
            archetype="expat_us",
        )

    # Helper must NOT propagate — but MUST observe the failure.
    assert any(
        "sentry tag emission failed" in rec.getMessage().lower()
        for rec in caplog.records
    ), "expected logger.warning when set_tag raises"
    # Breadcrumb is the dashboard-visible signal of a silent regression.
    assert breadcrumbs, "expected a breadcrumb when tag emission fails"
    crumb = breadcrumbs[0]
    assert crumb.get("category") == "obs.audit_tags"
    assert crumb.get("message") == "sentry_audit_tags_emit_failed"


def test_malformed_eval_score_falls_back_to_unavailable(monkeypatch):
    """A non-numeric, non-string eval_score becomes 'unavailable' rather than raising."""
    calls: list[tuple[str, str]] = []
    fake = types.ModuleType("sentry_sdk")
    fake.set_tag = lambda n, v: calls.append((n, v))
    fake.add_breadcrumb = lambda **_: None
    monkeypatch.setitem(sys.modules, "sentry_sdk", fake)

    from app.utils.sentry_audit_tags import emit_sentry_audit_tags

    class _Bogus:
        def __float__(self):
            raise ValueError("not numeric")

    emit_sentry_audit_tags(
        eclairage_kind=None,
        banned_term_hit=False,
        eval_score=_Bogus(),
        archetype="swiss_native",
    )

    assert dict(calls)["eval_score"] == "unavailable"
