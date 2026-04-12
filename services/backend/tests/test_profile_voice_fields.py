"""Smoke tests for Profile voice cursor fields (Phase 02-03).

Covers:
- Defaults (direct / 0 / None)
- camelCase round-trip via model_dump()
- Enum validation (invalid preference rejected)
- Counter increment persists
- Fragile mode timestamp round-trip
- Legacy payload (without voice fields) deserializes with defaults
- ProfileUpdate accepts partial voice updates
- ge=0 constraint on n5IssuedThisWeek
"""
from __future__ import annotations

from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.schemas.profile import HouseholdType, ProfileBase, ProfileUpdate
from app.schemas.voice_cursor import VoicePreference


def _base_kwargs(**extra):
    """Minimal valid ProfileBase payload."""
    base = {"householdType": HouseholdType.single}
    base.update(extra)
    return base


class TestVoiceCursorDefaults:
    def test_default_preference_is_direct(self):
        p = ProfileBase(**_base_kwargs())
        assert p.voiceCursorPreference == VoicePreference.direct

    def test_default_n5_counter_is_zero(self):
        p = ProfileBase(**_base_kwargs())
        assert p.n5IssuedThisWeek == 0

    def test_default_fragile_mode_is_none(self):
        p = ProfileBase(**_base_kwargs())
        assert p.fragileModeEnteredAt is None


class TestVoiceCursorRoundTrip:
    def test_explicit_soft_preference_roundtrips(self):
        p = ProfileBase(**_base_kwargs(voiceCursorPreference="soft"))
        assert p.voiceCursorPreference == VoicePreference.soft
        dumped = p.model_dump()
        assert dumped["voiceCursorPreference"] == VoicePreference.soft

    def test_unfiltered_preference_roundtrips(self):
        p = ProfileBase(**_base_kwargs(voiceCursorPreference="unfiltered"))
        assert p.voiceCursorPreference == VoicePreference.unfiltered

    def test_n5_counter_increment_persists(self):
        p = ProfileBase(**_base_kwargs(n5IssuedThisWeek=3))
        assert p.n5IssuedThisWeek == 3
        assert p.model_dump()["n5IssuedThisWeek"] == 3

    def test_fragile_mode_timestamp_roundtrips(self):
        ts = datetime(2026, 4, 7, 12, 0, 0, tzinfo=timezone.utc)
        p = ProfileBase(**_base_kwargs(fragileModeEnteredAt=ts))
        assert p.fragileModeEnteredAt == ts


class TestVoiceCursorValidation:
    def test_invalid_preference_rejected(self):
        with pytest.raises(ValidationError):
            ProfileBase(**_base_kwargs(voiceCursorPreference="agressive"))

    def test_negative_n5_counter_rejected(self):
        with pytest.raises(ValidationError):
            ProfileBase(**_base_kwargs(n5IssuedThisWeek=-1))


class TestLegacyPayload:
    def test_payload_without_voice_fields_uses_defaults(self):
        # Simulates a row written before Phase 02-03.
        legacy = {"householdType": "single"}
        p = ProfileBase(**legacy)
        assert p.voiceCursorPreference == VoicePreference.direct
        assert p.n5IssuedThisWeek == 0
        assert p.fragileModeEnteredAt is None


class TestProfileUpdate:
    def test_partial_voice_update(self):
        upd = ProfileUpdate(voiceCursorPreference="soft")
        assert upd.voiceCursorPreference == VoicePreference.soft
        assert upd.n5IssuedThisWeek is None
        assert upd.fragileModeEnteredAt is None

    def test_n5_counter_update(self):
        upd = ProfileUpdate(n5IssuedThisWeek=1)
        assert upd.n5IssuedThisWeek == 1
