#!/usr/bin/env python3
"""Block active agent docs from referencing quarantined worktrees."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCAN_ROOTS = (
    Path(".claude/agents"),
    Path(".claude/commands/gsd"),
    Path(".claude/get-shit-done"),
    Path(".claude/AGENT_BOOTSTRAP.md"),
)
SCAN_SUFFIXES = {".cjs", ".js", ".json", ".md", ".sh", ".txt"}
FORBIDDEN = (
    "/Users/julienbattaglia/Desktop/MINT.nosync",
    "MINT.nosync/.claude/get-shit-done",
)


def _files_to_scan(root: Path) -> list[Path]:
    files: list[Path] = []
    for scan_root in SCAN_ROOTS:
        path = root / scan_root
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            files.extend(
                sorted(
                    candidate
                    for candidate in path.rglob("*")
                    if candidate.is_file() and candidate.suffix in SCAN_SUFFIXES
                )
            )
    return files


def check(root: Path) -> list[str]:
    errors: list[str] = []
    for path in _files_to_scan(root):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for needle in FORBIDDEN:
            if needle in text:
                errors.append(
                    f"{path.relative_to(root)} references quarantined path: {needle}"
                )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = check(args.root.resolve())
    if not errors:
        print("OK agent_reference_guard: agent references are portable.", file=sys.stderr)
        return 0
    print("FAIL agent_reference_guard: stale agent references detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
