"""GENERATED — DO NOT EDIT — source: tools/contracts/voice_cursor.json

Run ``bash tools/contracts/regenerate.sh`` to refresh.
Edits to this file will be reverted by the contracts-drift CI gate.
"""
from __future__ import annotations

from enum import Enum
from typing import Final

VOICE_CURSOR_CONTRACT_VERSION: Final[str] = "0.5.0"

class VoiceLevel(str, Enum):
    N1 = "N1"
    N2 = "N2"
    N3 = "N3"
    N4 = "N4"
    N5 = "N5"

class Gravity(str, Enum):
    G1 = "G1"
    G2 = "G2"
    G3 = "G3"

class Relation(str, Enum):
    new = "new"
    established = "established"
    intimate = "intimate"

class VoicePreference(str, Enum):
    soft = "soft"
    direct = "direct"
    unfiltered = "unfiltered"

VOICE_CURSOR_MATRIX: Final[dict[Gravity, dict[Relation, dict[VoicePreference, VoiceLevel]]]] = {
    Gravity.G1: {
        Relation.established: {
            VoicePreference.direct: VoiceLevel.N2,
            VoicePreference.soft: VoiceLevel.N2,
            VoicePreference.unfiltered: VoiceLevel.N2,
        },
        Relation.intimate: {
            VoicePreference.direct: VoiceLevel.N3,
            VoicePreference.soft: VoiceLevel.N2,
            VoicePreference.unfiltered: VoiceLevel.N3,
        },
        Relation.new: {
            VoicePreference.direct: VoiceLevel.N1,
            VoicePreference.soft: VoiceLevel.N1,
            VoicePreference.unfiltered: VoiceLevel.N2,
        },
    },
    Gravity.G2: {
        Relation.established: {
            VoicePreference.direct: VoiceLevel.N4,
            VoicePreference.soft: VoiceLevel.N3,
            VoicePreference.unfiltered: VoiceLevel.N4,
        },
        Relation.intimate: {
            VoicePreference.direct: VoiceLevel.N4,
            VoicePreference.soft: VoiceLevel.N3,
            VoicePreference.unfiltered: VoiceLevel.N4,
        },
        Relation.new: {
            VoicePreference.direct: VoiceLevel.N2,
            VoicePreference.soft: VoiceLevel.N2,
            VoicePreference.unfiltered: VoiceLevel.N2,
        },
    },
    Gravity.G3: {
        Relation.established: {
            VoicePreference.direct: VoiceLevel.N5,
            VoicePreference.soft: VoiceLevel.N4,
            VoicePreference.unfiltered: VoiceLevel.N5,
        },
        Relation.intimate: {
            VoicePreference.direct: VoiceLevel.N5,
            VoicePreference.soft: VoiceLevel.N4,
            VoicePreference.unfiltered: VoiceLevel.N5,
        },
        Relation.new: {
            VoicePreference.direct: VoiceLevel.N4,
            VoicePreference.soft: VoiceLevel.N4,
            VoicePreference.unfiltered: VoiceLevel.N4,
        },
    },
}

SENSITIVE_TOPICS: Final[tuple[str, ...]] = ("deuil", "divorce", "perteEmploi", "maladieGrave", "suicide", "violenceConjugale", "faillitePersonnelle", "endettementAbusif", "dependance", "handicapAcquis",)
NARRATOR_WALL_EXEMPTIONS: Final[tuple[str, ...]] = ("settings", "errorToasts", "networkFailures", "legalDisclaimers", "onboardingSystemText", "compliance", "consentDialogs", "permissionPrompts",)
VOICE_CURSOR_PRECEDENCE_CASCADE: Final[tuple[str, ...]] = ("sensitivityGuard", "fragilityCap", "n5WeeklyBudget", "gravityFloor", "preferenceCap", "matrixDefault",)

N5_PER_WEEK_MAX: Final[int] = 1
FRAGILE_MODE_DURATION_DAYS: Final[int] = 30
FRAGILE_MODE_CAP_LEVEL: Final[VoiceLevel] = VoiceLevel.N3
SENSITIVE_TOPIC_CAP_LEVEL: Final[VoiceLevel] = VoiceLevel.N3
G3_FLOOR_LEVEL: Final[VoiceLevel] = VoiceLevel.N2
