"""Smoke test for the generated VoiceCursorContract Python module.

Proves the generated `app.schemas.voice_cursor` module is importable, that
its enums and matrix structure are intact, and that key invariants
(version, levels, caps, anti-shame doctrine on sensitive topics) hold.

If this file is red, run `bash tools/contracts/regenerate.sh` and commit.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.schemas.voice_cursor import (  # type: ignore[import-not-found]
    FRAGILE_MODE_CAP_LEVEL,
    FRAGILE_MODE_DURATION_DAYS,
    G3_FLOOR_LEVEL,
    N5_PER_WEEK_MAX,
    NARRATOR_WALL_EXEMPTIONS,
    SENSITIVE_TOPIC_CAP_LEVEL,
    SENSITIVE_TOPICS,
    VOICE_CURSOR_CONTRACT_VERSION,
    VOICE_CURSOR_MATRIX,
    VOICE_CURSOR_PRECEDENCE_CASCADE,
    Gravity,
    Relation,
    VoiceLevel,
    VoicePreference,
)

CONTRACT_JSON = Path(__file__).resolve().parents[3] / "tools" / "contracts" / "voice_cursor.json"


def test_version_matches_json() -> None:
    data = json.loads(CONTRACT_JSON.read_text(encoding="utf-8"))
    assert VOICE_CURSOR_CONTRACT_VERSION == "0.5.0"
    assert data["version"] == VOICE_CURSOR_CONTRACT_VERSION


def test_enums_have_expected_members() -> None:
    assert {m.value for m in VoiceLevel} == {"N1", "N2", "N3", "N4", "N5"}
    assert {m.value for m in Gravity} == {"G1", "G2", "G3"}
    assert {m.value for m in Relation} == {"new", "established", "intimate"}
    assert {m.value for m in VoicePreference} == {"soft", "direct", "unfiltered"}


def test_matrix_is_complete() -> None:
    count = 0
    for g in Gravity:
        for r in Relation:
            for p in VoicePreference:
                lvl = VOICE_CURSOR_MATRIX[g][r][p]
                assert isinstance(lvl, VoiceLevel)
                count += 1
    assert count == 27


def test_precedence_cascade_order() -> None:
    assert VOICE_CURSOR_PRECEDENCE_CASCADE == (
        "sensitivityGuard",
        "fragilityCap",
        "n5WeeklyBudget",
        "gravityFloor",
        "preferenceCap",
        "matrixDefault",
    )


def test_sensitive_topics_include_doctrinal_anchors() -> None:
    for anchor in ("deuil", "divorce", "perteEmploi", "maladieGrave"):
        assert anchor in SENSITIVE_TOPICS


def test_narrator_wall_exemptions_present() -> None:
    assert "settings" in NARRATOR_WALL_EXEMPTIONS
    assert "compliance" in NARRATOR_WALL_EXEMPTIONS


def test_caps_are_frozen() -> None:
    assert N5_PER_WEEK_MAX == 1
    assert FRAGILE_MODE_DURATION_DAYS == 30
    assert FRAGILE_MODE_CAP_LEVEL == VoiceLevel.N3
    assert SENSITIVE_TOPIC_CAP_LEVEL == VoiceLevel.N3
    assert G3_FLOOR_LEVEL == VoiceLevel.N2


def test_g3_direct_intimate_is_n5() -> None:
    """The strongest matrix cell — G3 + intimate + direct = N5 (Cash)."""
    assert VOICE_CURSOR_MATRIX[Gravity.G3][Relation.intimate][VoicePreference.direct] == VoiceLevel.N5


def test_g1_new_soft_is_n1() -> None:
    """The softest matrix cell — G1 + new + soft = N1 (Neutre)."""
    assert VOICE_CURSOR_MATRIX[Gravity.G1][Relation.new][VoicePreference.soft] == VoiceLevel.N1
