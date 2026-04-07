#!/usr/bin/env python3
"""Generate services/backend/app/schemas/voice_cursor.py from voice_cursor.json.

Strategy: hand-rolled emitter (NOT datamodel-code-generator). Rationale: the contract
is a frozen enum + matrix; emitting Pydantic v2 models directly keeps the toolchain
hermetic (no extra runtime dep), produces deterministic output, and avoids upstream
formatting churn that breaks the drift gate.

datamodel-code-generator is still pinned in requirements-dev.txt for ad-hoc schema
exploration but is NOT invoked by the codegen pipeline.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools" / "contracts" / "voice_cursor.json"
OUT = ROOT / "services" / "backend" / "app" / "schemas" / "voice_cursor.py"

BANNER = '''"""GENERATED — DO NOT EDIT — source: tools/contracts/voice_cursor.json

Run ``bash tools/contracts/regenerate.sh`` to refresh.
Edits to this file will be reverted by the contracts-drift CI gate.
"""
'''


def _enum(name: str, values: list[str]) -> str:
    lines = [f"class {name}(str, Enum):"]
    for v in values:
        lines.append(f'    {v} = "{v}"')
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    data = json.loads(SRC.read_text(encoding="utf-8"))

    levels = data["levels"]
    gravities = data["gravities"]
    relations = data["relations"]
    preferences = data["preferences"]
    matrix = data["matrix"]
    caps = data["caps"]

    out: list[str] = [BANNER, "from __future__ import annotations\n\n"]
    out.append("from enum import Enum\n")
    out.append("from typing import Final\n\n")

    out.append(f'VOICE_CURSOR_CONTRACT_VERSION: Final[str] = "{data["version"]}"\n\n')

    out.append(_enum("VoiceLevel", levels))
    out.append("\n")
    out.append(_enum("Gravity", gravities))
    out.append("\n")
    out.append(_enum("Relation", relations))
    out.append("\n")
    out.append(_enum("VoicePreference", preferences))
    out.append("\n")

    # Matrix as nested dict
    out.append("VOICE_CURSOR_MATRIX: Final[dict[Gravity, dict[Relation, dict[VoicePreference, VoiceLevel]]]] = {\n")
    for g in sorted(matrix.keys()):
        out.append(f"    Gravity.{g}: {{\n")
        for r in sorted(matrix[g].keys()):
            out.append(f"        Relation.{r}: {{\n")
            for p in sorted(matrix[g][r].keys()):
                lvl = matrix[g][r][p]
                out.append(f"            VoicePreference.{p}: VoiceLevel.{lvl},\n")
            out.append("        },\n")
        out.append("    },\n")
    out.append("}\n\n")

    def _list(name: str, items: list[str]) -> str:
        body = ", ".join(f'"{v}"' for v in items)
        return f"{name}: Final[tuple[str, ...]] = ({body},)\n"

    out.append(_list("SENSITIVE_TOPICS", data["sensitiveTopics"]))
    out.append(_list("NARRATOR_WALL_EXEMPTIONS", data["narratorWallExemptions"]))
    out.append(_list("VOICE_CURSOR_PRECEDENCE_CASCADE", data["precedenceCascade"]))
    out.append("\n")

    out.append(f"N5_PER_WEEK_MAX: Final[int] = {caps['n5PerWeekMax']}\n")
    out.append(f"FRAGILE_MODE_DURATION_DAYS: Final[int] = {caps['fragileModeDurationDays']}\n")
    out.append(f"FRAGILE_MODE_CAP_LEVEL: Final[VoiceLevel] = VoiceLevel.{caps['fragileModeCapLevel']}\n")
    out.append(f"SENSITIVE_TOPIC_CAP_LEVEL: Final[VoiceLevel] = VoiceLevel.{caps['sensitiveTopicCapLevel']}\n")
    out.append(f"G3_FLOOR_LEVEL: Final[VoiceLevel] = VoiceLevel.{caps['g3FloorLevel']}\n")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("".join(out), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
