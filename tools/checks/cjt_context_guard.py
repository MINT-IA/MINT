#!/usr/bin/env python3
"""Guard the active Core Journey Truth operating map from context drift.

This is intentionally narrow. It does not validate all GSD state. It checks
that the files agents actually read first still point to the active CJT phase,
its Journey Truth Matrix, and its known open release gates.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

PHASE_SLUG = "mint-prod-ready-core-journey-truth-20260601"
PHASE_DIR = Path(".planning/phases") / PHASE_SLUG
MATRIX = PHASE_DIR / "JOURNEY-TRUTH-MATRIX.md"
BUG_TRACKER = PHASE_DIR / "BUG-TRACKER.md"
OPEN_GATES = ("CJT-013", "CJT-015")
UNIVERSAL_LINK_GATE = "CJT-015"
UNIVERSAL_LINK_PRODUCT_DOMAIN = "mint-ai.ch"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _contains_all(text: str, needles: tuple[str, ...] | list[str]) -> list[str]:
    return [needle for needle in needles if needle not in text]


def _bug_tracker_has_open_gate(text: str, gate: str) -> bool:
    for line in text.splitlines():
        if gate in line and "| open |" in line:
            return True
    return False


def _active_cjt015_lines(matrix_text: str, bug_text: str) -> list[str]:
    matrix_lines = [
        line
        for line in matrix_text.splitlines()
        if line.strip().startswith("| 1 |") and UNIVERSAL_LINK_GATE in line
    ]
    bug_lines = [
        line
        for line in bug_text.splitlines()
        if line.strip().startswith(f"| {UNIVERSAL_LINK_GATE} |")
    ]
    return matrix_lines + bug_lines


def check(root: Path) -> list[str]:
    errors: list[str] = []

    state = root / ".planning/STATE.md"
    roadmap = root / ".planning/ROADMAP.md"
    matrix = root / MATRIX
    bug_tracker = root / BUG_TRACKER

    for path in (state, roadmap, matrix, bug_tracker):
        if not path.exists():
            errors.append(f"missing required CJT context file: {path.relative_to(root)}")

    if errors:
        return errors

    state_text = _read(state)
    roadmap_text = _read(roadmap)
    matrix_text = _read(matrix)
    bug_text = _read(bug_tracker)

    state_missing = _contains_all(
        state_text,
        [
            "Core Journey Truth",
            PHASE_SLUG,
            "JOURNEY-TRUTH-MATRIX.md",
            "BUG-TRACKER.md",
        ],
    )
    if state_missing:
        errors.append(
            ".planning/STATE.md does not point to active CJT context: "
            + ", ".join(state_missing)
        )

    roadmap_missing = _contains_all(
        roadmap_text,
        [
            "Active GSD: Core Journey Truth / Prod Ready",
            "JOURNEY-TRUTH-MATRIX.md",
            "BUG-TRACKER.md",
        ],
    )
    if roadmap_missing:
        errors.append(
            ".planning/ROADMAP.md active CJT entry is incomplete: "
            + ", ".join(roadmap_missing)
        )

    matrix_missing = _contains_all(
        matrix_text,
        ["LIVE-PROVEN", "PARTIAL", "UNPROVEN", "OPEN", *OPEN_GATES],
    )
    if matrix_missing:
        errors.append(
            f"{MATRIX} is missing proof statuses or open gates: "
            + ", ".join(matrix_missing)
        )

    open_missing = [
        gate for gate in OPEN_GATES if not _bug_tracker_has_open_gate(bug_text, gate)
    ]
    if open_missing:
        errors.append(
            f"{BUG_TRACKER} no longer exposes known open gates: "
            + ", ".join(open_missing)
        )

    cjt015_lines = _active_cjt015_lines(matrix_text, bug_text)
    stale_domain_lines = [
        line for line in cjt015_lines if UNIVERSAL_LINK_PRODUCT_DOMAIN not in line
    ]
    if stale_domain_lines:
        errors.append(
            f"{UNIVERSAL_LINK_GATE} active context must reference product "
            f"Universal Link domain {UNIVERSAL_LINK_PRODUCT_DOMAIN}"
        )

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Repository root to check. Defaults to current working directory.",
    )
    args = parser.parse_args(argv)

    errors = check(args.root.resolve())
    if not errors:
        print("OK cjt_context_guard: active CJT context is coherent.", file=sys.stderr)
        return 0

    print("FAIL cjt_context_guard: active CJT context drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
