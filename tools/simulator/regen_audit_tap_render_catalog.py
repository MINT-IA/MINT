#!/usr/bin/env python3
"""Phase 54-01 — regenerate the AUDIT_TAP_RENDER walker catalog (TSV).

Parses `.planning/milestones/v2.1-phases/07-stabilisation-v2-0/
AUDIT_TAP_RENDER.md` (the canonical scaffold contract — 48 primary-depth
interactive elements across 3 tabs + drawer) and emits a machine-readable
TSV at `tools/simulator/audit_tap_render_rows.tsv` consumable by
`walker_audit_tap_render.sh`.

The TSV columns:
  id              row id (1.1, 2.3, etc.)
  section         Tab 1 / Tab 2 / Tab 3 / ProfileDrawer
  surface_file    e.g. mint_home_screen.dart
  surface_line    e.g. 151 (or empty for « unspecified » rows like 2.1)
  element         human-readable element name (the Element column)
  expected        what tapping should do (the Expected column)
  tap_strategy    centered_tap | scroll_tap | text_match (default centered_tap)
  tap_x           sim x coordinate placeholder (default 195)
  tap_y           sim y coordinate placeholder (default 400)
  wait_max        max polls to wait for UI quiescence (default 6)
  skip_reason     non-empty → walker SKIPs the row with this reason
  notes           free-form notes column

Output is sorted by id. Stable diff target — committed to the repo.

The regeneration is idempotent: running the script twice produces the
same TSV. CI gate `tools/checks/audit_tap_render_catalog_drift.py` (TBD
in Plan 54-01 PR-2) will assert the TSV matches the markdown.

Usage:
    python3 tools/simulator/regen_audit_tap_render_catalog.py
    python3 tools/simulator/regen_audit_tap_render_catalog.py --check
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCAFFOLD = (
    REPO
    / ".planning"
    / "milestones"
    / "v2.1-phases"
    / "07-stabilisation-v2-0"
    / "AUDIT_TAP_RENDER.md"
)
OUTPUT = REPO / "tools" / "simulator" / "audit_tap_render_rows.tsv"

# Default placeholder coordinates (centered tap on iPhone 17 Pro 1206x2622).
# Walker calibration in Plan 54-01 PR-2 will refine per-row coordinates
# from a clean « landing » screenshot baseline.
DEFAULT_TAP_X = 195
DEFAULT_TAP_Y = 400
DEFAULT_WAIT_MAX = 6

SECTIONS = {
    "Tab 1: Aujourd'hui": ("Tab1_Aujourdhui", "mint_home_screen.dart"),
    "Tab 2: Coach": ("Tab2_Coach", "coach_chat_screen.dart"),
    "Tab 3: Explorer": ("Tab3_Explorer", "explore_tab.dart"),
    "ProfileDrawer": ("ProfileDrawer", "profile_drawer.dart"),
}

# Rows known to require special handling — encoded as skip rationale or
# a non-default tap strategy. Edit here when the scaffold contract evolves.
SPECIAL_ROWS: dict[str, dict[str, str]] = {
    # Coach tab tool-result rows depend on LLM emitting the right tool —
    # cannot reliably auto-tap without LLM fixture injection. SKIP for
    # PR-1; PR-2 wires a fixture-driven path.
    "2.5": {"skip_reason": "LLM-dependent: requires route_to_screen fixture"},
    "2.6": {"skip_reason": "LLM-dependent: requires generate_document fixture"},
    "2.7": {"skip_reason": "LLM-dependent: requires generate_financial_plan fixture"},
    "2.8": {"skip_reason": "LLM-dependent: requires record_check_in fixture"},
    # Profile-state-dependent rows: only render when profile carries a
    # specific shape. The walker's swiss_native archetype seed covers
    # most but not all; mark for manual verification in walker run.
    "1.11": {"notes": "Renders only when profile has no check-ins yet"},
    "1.12": {"notes": "Renders only when AnticipationEngine has fresh signals"},
    "3.10": {"notes": "Renders only when a hub is in 'blocked' readiness state"},
    "4.3": {"notes": "Visible only when profile.isCouple == true"},
    # Known stub per the scaffold's « Known issue » block at line 113.
    "4.9": {"skip_reason": "Known stub per scaffold line 113 — TODO inline language picker"},
}

# Markdown table row pattern.
# Format: | 1.1 | Element name | file.dart:151 | Expected description | TODO ... | TODO |
_ROW_RE = re.compile(
    r"^\|\s*(?P<id>\d+\.\d+)\s*"
    r"\|\s*(?P<element>[^|]+?)\s*"
    r"\|\s*(?P<file_line>[^|]+?)\s*"
    r"\|\s*(?P<expected>[^|]+?)\s*"
    r"\|\s*[^|]+?\s*"  # actual column
    r"\|\s*[^|]+?\s*\|"  # verdict column
)


def parse_scaffold(text: str) -> list[dict]:
    """Walk the scaffold text section by section, emit row dicts."""
    rows: list[dict] = []
    current_section: tuple[str, str] | None = None
    for line in text.splitlines():
        # Section header detection (« ## Tab 1: Aujourd'hui ... »).
        if line.startswith("## "):
            for header, sec_tuple in SECTIONS.items():
                if header in line:
                    current_section = sec_tuple
                    break
            else:
                current_section = None
            continue
        if current_section is None:
            continue
        m = _ROW_RE.match(line)
        if not m:
            continue
        section_name, default_file = current_section
        row_id = m.group("id").strip()
        file_line_raw = m.group("file_line").strip()
        # Parse « file.dart:151 » or « file.dart » or « file.dart:151 (note) »
        file_part = file_line_raw
        line_part = ""
        # Strip optional parenthetical
        paren_idx = file_part.find("(")
        if paren_idx > 0:
            file_part = file_part[:paren_idx].strip()
        # Split on colon for line number
        if ":" in file_part:
            file_only, _, line_only = file_part.partition(":")
            file_part = file_only.strip()
            # Line may have arrow chains (« :576 → :380 ») — take first.
            line_first = line_only.split()[0] if line_only.split() else ""
            line_part = line_first.lstrip(":").strip()
        # Fallback to section default file if file part is empty / unparseable.
        if not file_part or file_part.lower() == "rendered via widget_renderer.dart":
            file_part = default_file
        special = SPECIAL_ROWS.get(row_id, {})
        rows.append({
            "id": row_id,
            "section": section_name,
            "surface_file": file_part,
            "surface_line": line_part,
            "element": m.group("element").strip(),
            "expected": m.group("expected").strip(),
            "tap_strategy": "centered_tap",
            "tap_x": str(DEFAULT_TAP_X),
            "tap_y": str(DEFAULT_TAP_Y),
            "wait_max": str(DEFAULT_WAIT_MAX),
            "skip_reason": special.get("skip_reason", ""),
            "notes": special.get("notes", ""),
        })
    return rows


_TSV_HEADER = [
    "id", "section", "surface_file", "surface_line", "element",
    "expected", "tap_strategy", "tap_x", "tap_y", "wait_max",
    "skip_reason", "notes",
]


def render_tsv(rows: list[dict]) -> str:
    """Stable TSV: sorted by (section, id-as-tuple)."""
    def key(r: dict) -> tuple:
        major, minor = r["id"].split(".")
        return (r["section"], int(major), int(minor))

    sorted_rows = sorted(rows, key=key)
    lines = ["\t".join(_TSV_HEADER)]
    for row in sorted_rows:
        cells = [row[col].replace("\t", " ").replace("\n", " ") for col in _TSV_HEADER]
        lines.append("\t".join(cells))
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Exit 1 if the TSV would change. No write.")
    args = parser.parse_args()

    if not SCAFFOLD.exists():
        sys.stderr.write(f"[FAIL] scaffold not found at {SCAFFOLD}\n")
        return 2

    text = SCAFFOLD.read_text(encoding="utf-8")
    rows = parse_scaffold(text)
    sys.stderr.write(
        f"[info] parsed {len(rows)} rows across {len(SECTIONS)} sections\n"
    )
    if not rows:
        sys.stderr.write("[FAIL] zero rows parsed — scaffold format changed?\n")
        return 2

    new_content = render_tsv(rows)
    existing = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""

    if existing == new_content:
        print(f"[OK] {OUTPUT.relative_to(REPO).as_posix()} up to date "
              f"({len(rows)} rows)")
        return 0

    if args.check:
        sys.stderr.write(
            f"::error file={OUTPUT.relative_to(REPO).as_posix()}::"
            f"would change — run python3 "
            f"tools/simulator/regen_audit_tap_render_catalog.py\n"
        )
        return 1

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(new_content, encoding="utf-8")
    print(f"[wrote] {OUTPUT.relative_to(REPO).as_posix()} ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
