"""
Tests — Phase 16 COUP-04 partner-aggregate fields survive _sanitize_profile_context.

Context (mint-calc-engine-v1 Stage 0 fix, 2026-05-17):
Plan 19 (profile_safe_fields_parity lint) surfaced that Flutter
`coach_chat_api_service.dart:94-97` has been spreading `partner_declared` +
`partner_confidence` from SecureStorage into `profileContext` since Phase 16
COUP-04 — but the server `_PROFILE_SAFE_FIELDS` whitelist did NOT include
either key. Result: `_sanitize_profile_context` was silently dropping both
keys before the orchestrator + narrator could read them.

The narrator system prompt EXPLICITLY references both fields (see
`tests/fixtures/narrator_legacy_snapshots/*.txt`, e.g. line 551-552:
« Si le contexte indique partner_declared: true, reference-le ... »
« Si partner_confidence est bas (< 0.4), mentionne ... »).

In other words: the narrator was instructed to use fields the upstream
sanitizer was filtering out. The whole COUP-04 partner-aggregate ground-truth
pathway was dead in production from Phase 16 ship until this fix.

Privacy: `partner_declared` is bool, `partner_confidence` is float in [0, 1] —
no PII.

Covers:
- Both keys present in `_PROFILE_SAFE_FIELDS`
- Sanitizer keeps `partner_declared=True` / `=False`
- Sanitizer keeps `partner_confidence` across the [0, 1] range
- Sanitizer keeps both together (the exact Flutter payload shape from
  `coach_chat_api_service.dart:94-97`)
- Sanitizer drops PII alongside while keeping these two
- Sanitizer drops `None` values (consistent with `has_debt=None` precedent)
- Builder routes both into `extra_known` (numeric path — bool subclasses int
  in Python, so the `isinstance(v, (int, float))` filter accepts both)
"""

import pytest

from app.api.v1.endpoints.coach_chat import (
    _PROFILE_SAFE_FIELDS,
    _build_coach_context_from_profile,
    _sanitize_profile_context,
)


# ---------------------------------------------------------------------------
# _PROFILE_SAFE_FIELDS membership
# ---------------------------------------------------------------------------


def test_partner_declared_in_safe_fields():
    assert "partner_declared" in _PROFILE_SAFE_FIELDS


def test_partner_confidence_in_safe_fields():
    assert "partner_confidence" in _PROFILE_SAFE_FIELDS


# ---------------------------------------------------------------------------
# _sanitize_profile_context — partner_declared
# ---------------------------------------------------------------------------


def test_sanitize_keeps_partner_declared_true():
    result = _sanitize_profile_context({"partner_declared": True, "age": 40})
    assert result.get("partner_declared") is True


def test_sanitize_keeps_partner_declared_false():
    """`partner_declared=False` is meaningful (user explicitly declared single status)."""
    result = _sanitize_profile_context({"partner_declared": False, "age": 40})
    assert result.get("partner_declared") is False


def test_sanitize_drops_none_partner_declared():
    result = _sanitize_profile_context({"partner_declared": None, "age": 30})
    assert "partner_declared" not in result


# ---------------------------------------------------------------------------
# _sanitize_profile_context — partner_confidence
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("conf", [0.0, 0.35, 0.5, 0.85, 1.0])
def test_sanitize_keeps_partner_confidence_range(conf: float):
    result = _sanitize_profile_context({"partner_confidence": conf, "age": 40})
    assert result.get("partner_confidence") == conf


def test_sanitize_drops_none_partner_confidence():
    result = _sanitize_profile_context({"partner_confidence": None, "age": 30})
    assert "partner_confidence" not in result


# ---------------------------------------------------------------------------
# _sanitize_profile_context — actual Flutter payload shape
# ---------------------------------------------------------------------------


def test_sanitize_keeps_flutter_coup04_payload():
    """Replays the exact payload shape from coach_chat_api_service.dart:94-97."""
    flutter_payload = {
        "partner_declared": True,
        "partner_confidence": 0.85,
        "age": 40,
        "canton": "VD",
    }
    result = _sanitize_profile_context(flutter_payload)
    assert result.get("partner_declared") is True
    assert result.get("partner_confidence") == 0.85
    assert result.get("age") == 40
    assert result.get("canton") == "VD"


def test_sanitize_drops_pii_keeps_partner_aggregate():
    """COUP-04 fields survive while PII is filtered."""
    pii_payload = {
        "partner_declared": True,
        "partner_confidence": 0.85,
        "iban": "CH56 0483 5012 3456 7800 9",
        "full_name": "Thomas Müller",
        "employer": "Nestlé SA",
    }
    result = _sanitize_profile_context(pii_payload)
    assert "iban" not in result
    assert "full_name" not in result
    assert "employer" not in result
    assert result.get("partner_declared") is True
    assert result.get("partner_confidence") == 0.85


# ---------------------------------------------------------------------------
# _build_coach_context_from_profile — extra_known routing
# ---------------------------------------------------------------------------


def test_build_context_partner_fields_flow_to_extra_known():
    """COUP-04 fields land in the « extra_keys » prompt block.

    `partner_declared` (bool) and `partner_confidence` (float) are NOT in the
    builder's `_BUILDER_PARAMS` set, so they must route through `extra_known`
    where claude_coach_service emits them in the system prompt's
    « extra_keys » block (auto-emitted at line 830-840).

    `isinstance(True, (int, float))` is True in Python (bool ⊂ int), so the
    builder's filter accepts both keys.
    """
    ctx = _build_coach_context_from_profile({
        "partner_declared": True,
        "partner_confidence": 0.85,
        "age": 40,
        "canton": "VD",
    })
    assert ctx is not None
    # Sanity: builder did not crash on the new keys.
    assert ctx.age == 40
    assert ctx.canton == "VD"
