#!/usr/bin/env python3
"""Generate apps/mobile/lib/services/voice/voice_cursor_contract.g.dart from voice_cursor.json.

Hand-rolled emitter (no build_runner). Stable key ordering. Banner mandatory.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "contracts" / "voice_cursor.json"
OUT = ROOT / "apps" / "mobile" / "lib" / "services" / "voice" / "voice_cursor_contract.g.dart"

BANNER = """// GENERATED — DO NOT EDIT — source: tools/contracts/voice_cursor.json
// Run `bash tools/contracts/regenerate.sh` to refresh.
// Edits to this file will be reverted by the contracts-drift CI gate.
"""


# Dart identifier mapping: contract strings → Dart-safe enum value names.
# `new` is a reserved word; uppercase N1/G1 violate camelCase lints.
_DART_IDENT = {
    # VoiceLevel
    "N1": "n1", "N2": "n2", "N3": "n3", "N4": "n4", "N5": "n5",
    # Gravity
    "G1": "g1", "G2": "g2", "G3": "g3",
    # Relation
    "new": "relNew", "established": "established", "intimate": "intimate",
    # VoicePreference
    "soft": "soft", "direct": "direct", "unfiltered": "unfiltered",
}


def _ident(s: str) -> str:
    return _DART_IDENT[s]


def _enum(name: str, values: list[str]) -> str:
    body = ", ".join(_ident(v) for v in values)
    return f"enum {name} {{ {body} }}\n"


def _matrix_literal(matrix: dict) -> str:
    lines = ["const Map<Gravity, Map<Relation, Map<VoicePreference, VoiceLevel>>> voiceCursorMatrix = {"]
    for g in sorted(matrix.keys()):
        lines.append(f"  Gravity.{_ident(g)}: {{")
        for r in sorted(matrix[g].keys()):
            lines.append(f"    Relation.{_ident(r)}: {{")
            for p in sorted(matrix[g][r].keys()):
                lvl = matrix[g][r][p]
                lines.append(f"      VoicePreference.{_ident(p)}: VoiceLevel.{_ident(lvl)},")
            lines.append("    },")
        lines.append("  },")
    lines.append("};\n")
    return "\n".join(lines)


def _string_list(name: str, values: list[str]) -> str:
    items = ", ".join(f'"{v}"' for v in values)
    return f"const List<String> {name} = <String>[{items}];\n"


def main() -> int:
    data = json.loads(SRC.read_text(encoding="utf-8"))

    levels = data["levels"]
    gravities = data["gravities"]
    relations = data["relations"]
    preferences = data["preferences"]
    matrix = data["matrix"]
    caps = data["caps"]

    parts: list[str] = [BANNER, "\n"]
    parts.append(f'const String voiceCursorContractVersion = "{data["version"]}";\n\n')
    parts.append(_enum("VoiceLevel", levels))
    parts.append(_enum("Gravity", gravities))
    parts.append(_enum("Relation", relations))
    parts.append(_enum("VoicePreference", preferences))
    parts.append("\n")
    parts.append(_matrix_literal(matrix))
    parts.append("\n")
    parts.append(_string_list("sensitiveTopics", data["sensitiveTopics"]))
    parts.append(_string_list("narratorWallExemptions", data["narratorWallExemptions"]))
    parts.append(_string_list("voiceCursorPrecedenceCascade", data["precedenceCascade"]))
    parts.append("\n")
    parts.append(f'const int n5PerWeekMax = {caps["n5PerWeekMax"]};\n')
    parts.append(f'const int fragileModeDurationDays = {caps["fragileModeDurationDays"]};\n')
    parts.append(f'const VoiceLevel fragileModeCapLevel = VoiceLevel.{_ident(caps["fragileModeCapLevel"])};\n')
    parts.append(f'const VoiceLevel sensitiveTopicCapLevel = VoiceLevel.{_ident(caps["sensitiveTopicCapLevel"])};\n')
    parts.append(f'const VoiceLevel g3FloorLevel = VoiceLevel.{_ident(caps["g3FloorLevel"])};\n')

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("".join(parts), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
