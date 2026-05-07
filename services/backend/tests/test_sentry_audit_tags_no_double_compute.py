"""Phase 96-03 OBS-03 — no-double-compute contract.

The helper MUST reuse the data already computed by the Phase 93-01
audit hook (``hash_for_audit`` + ``ComplianceGuardrails.filter_response``
+ archetype derivation). It MUST NOT re-import or re-invoke those
expensive paths.

Two layers of guard:

  1. **Source-level lint** — the helper file does not import
     ``audit_hash`` or ``guardrails``. (Static guarantee — survives
     refactors that monkeypatch the runtime.)

  2. **Runtime call-count guard** — when the helper runs alongside
     mocked ``hash_for_audit`` / ``ComplianceGuardrails``, those mocks
     receive zero calls from inside the helper. (Dynamic guarantee —
     catches an indirect import via, e.g., ``app.utils.__init__``.)
"""
from __future__ import annotations

import sys
import types
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

HELPER_PATH = (
    Path(__file__).resolve().parent.parent
    / "app"
    / "utils"
    / "sentry_audit_tags.py"
)


def test_helper_source_does_not_import_audit_or_guardrails():
    """Static guarantee: the helper module never depends on the heavy paths."""
    import ast

    src = HELPER_PATH.read_text(encoding="utf-8")
    tree = ast.parse(src)

    forbidden = {
        "audit_hash",
        "hash_for_audit",
        "guardrails",
        "ComplianceGuardrails",
        "filter_response",
    }
    found: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            mod = node.module or ""
            if any(token in mod for token in forbidden):
                found.append(f"from {mod} import ...")
            for alias in node.names:
                if alias.name in forbidden:
                    found.append(f"from {mod} import {alias.name}")
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if any(token in alias.name for token in forbidden):
                    found.append(f"import {alias.name}")
        elif isinstance(node, ast.Call):
            # Detect dynamic call like ``ComplianceGuardrails().filter_response(...)``
            target = node.func
            if isinstance(target, ast.Attribute) and target.attr in forbidden:
                found.append(f"call .{target.attr}(...)")

    assert not found, (
        "OBS-03 helper must NOT import or invoke audit_hash / "
        "ComplianceGuardrails / filter_response — these are upstream "
        "Phase 93-01 computations the helper must REUSE (no double-compute). "
        f"Forbidden references found: {found}"
    )


def test_helper_runtime_does_not_invoke_audit_hash_or_guardrails(monkeypatch):
    """Dynamic guarantee: zero call-count on the heavy paths during helper execution."""
    # Stub Sentry so the helper runs end-to-end without network.
    fake_sentry = types.ModuleType("sentry_sdk")
    fake_sentry.set_tag = lambda *_a, **_k: None
    fake_sentry.add_breadcrumb = lambda **_k: None
    monkeypatch.setitem(sys.modules, "sentry_sdk", fake_sentry)

    # Patch the two expensive 93-01 entry points with MagicMock recorders.
    with patch(
        "app.utils.audit_hash.hash_for_audit",
        new=MagicMock(return_value="x" * 64),
    ) as mock_hash, patch(
        "app.services.rag.guardrails.ComplianceGuardrails.filter_response",
        new=MagicMock(return_value={"banned_terms_filtered": False}),
    ) as mock_filter:

        from app.utils.sentry_audit_tags import emit_sentry_audit_tags

        emit_sentry_audit_tags(
            eclairage_kind="fiscal_margin_3a",
            banned_term_hit=False,
            eval_score="unavailable",
            archetype="swiss_native",
        )

    # The 93-01 audit hook calls hash_for_audit twice (prompt + response)
    # and filter_response once — but those calls happen UPSTREAM of the
    # helper. The helper itself must add zero invocations.
    assert mock_hash.call_count == 0, (
        "helper must NOT call hash_for_audit — it received the hashes "
        "already-computed by the 93-01 audit hook"
    )
    assert mock_filter.call_count == 0, (
        "helper must NOT call ComplianceGuardrails.filter_response — it "
        "received banned_term_hit already-computed by the 93-01 audit hook"
    )
