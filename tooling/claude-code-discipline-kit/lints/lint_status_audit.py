#!/usr/bin/env python3
"""lint_status_audit.py — Discipline-kit universal lint.

Enforces: every lint script in tools/checks/ MUST have a classification entry
in tools/checks/STATUS.md (enforced-ci | enforced-pre-commit | manual-only).

Catches the #1 source of false confidence in MINT-scale projects: lints that
exist on disk but never run because nobody wired them.

Pure stdlib Python 3.10+. No deps.

USAGE:
    python3 tools/checks/lint_status_audit.py
        # exit 0 if every lint is classified
        # exit 1 if any lint is missing from STATUS.md

    python3 tools/checks/lint_status_audit.py --report
        # print a markdown report regardless of exit code

    python3 tools/checks/lint_status_audit.py --status-file path/to/STATUS.md
        # use a custom STATUS.md location
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

LINT_EXTENSIONS = {".py", ".sh", ".dart"}
DEFAULT_LINT_DIR = Path("tools/checks")
DEFAULT_STATUS_FILE = DEFAULT_LINT_DIR / "STATUS.md"

VALID_STATUSES = {"enforced-ci", "enforced-pre-commit", "manual-only"}

# Files in tools/checks/ that are not lints (e.g. STATUS.md itself, fixtures, baselines)
EXCLUDED_FILES = {"STATUS.md", "README.md", "__init__.py"}
EXCLUDED_PATTERNS = (
    r".*-KNOWN-MISSES\.md$",
    r".*\.baseline$",
    r".*\.lock$",
    r".*test_.*",
    r".*_test\.py$",
)


def find_lints(lint_dir: Path) -> list[Path]:
    """Find all lint scripts in tools/checks/."""
    if not lint_dir.is_dir():
        return []
    out = []
    for p in sorted(lint_dir.iterdir()):
        if not p.is_file():
            continue
        if p.name in EXCLUDED_FILES:
            continue
        if any(re.match(pat, p.name) for pat in EXCLUDED_PATTERNS):
            continue
        if p.suffix in LINT_EXTENSIONS or p.name.endswith(".sh"):
            out.append(p)
    return out


def parse_status_md(status_file: Path) -> dict[str, str]:
    """Parse STATUS.md and return {lint_name: status}.

    Expects markdown table:
        | Lint | Status | Wired in |
        |---|---|---|
        | accent_lint_fr.py | enforced-pre-commit | lefthook.yml |
    """
    if not status_file.is_file():
        return {}
    out: dict[str, str] = {}
    with status_file.open() as f:
        for line in f:
            line = line.strip()
            if not line.startswith("|"):
                continue
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) < 2:
                continue
            name, status = parts[0], parts[1]
            if name in {"Lint", ":---", "---"} or status in {"Status", ":---", "---"}:
                continue
            out[name] = status
    return out


def audit(lint_dir: Path, status_file: Path) -> tuple[list[str], list[str], list[str]]:
    """Returns (missing, invalid_status, orphan_in_status)."""
    lints = find_lints(lint_dir)
    lint_names = {p.name for p in lints}
    statuses = parse_status_md(status_file)

    missing = sorted(name for name in lint_names if name not in statuses)
    invalid_status = sorted(
        name for name, status in statuses.items()
        if name in lint_names and status not in VALID_STATUSES
    )
    orphan_in_status = sorted(
        name for name in statuses if name not in lint_names
    )
    return missing, invalid_status, orphan_in_status


def report(lint_dir: Path, status_file: Path, fail_on_missing: bool = True) -> int:
    missing, invalid_status, orphan_in_status = audit(lint_dir, status_file)
    lints = find_lints(lint_dir)

    print(f"# Lint Status Audit\n")
    print(f"- Lint directory: `{lint_dir}`")
    print(f"- Status file:    `{status_file}`")
    print(f"- Lints found:    {len(lints)}")
    print(f"- Documented:     {len(parse_status_md(status_file))}")
    print()

    if missing:
        print(f"## ❌ Missing from STATUS.md ({len(missing)})\n")
        for name in missing:
            print(f"- {name}")
        print()

    if invalid_status:
        print(f"## ❌ Invalid status ({len(invalid_status)})\n")
        print(f"Allowed: {', '.join(sorted(VALID_STATUSES))}\n")
        for name in invalid_status:
            print(f"- {name}")
        print()

    if orphan_in_status:
        print(f"## ⚠ Documented but file missing ({len(orphan_in_status)})\n")
        for name in orphan_in_status:
            print(f"- {name}")
        print()

    if not missing and not invalid_status:
        print("✓ All lints classified.")
        return 0

    if fail_on_missing and (missing or invalid_status):
        return 1
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--lint-dir", type=Path, default=DEFAULT_LINT_DIR,
        help=f"Directory containing lint scripts (default: {DEFAULT_LINT_DIR})",
    )
    parser.add_argument(
        "--status-file", type=Path, default=None,
        help="Path to STATUS.md (default: <lint-dir>/STATUS.md)",
    )
    parser.add_argument(
        "--report", action="store_true",
        help="Print full report regardless of exit code",
    )
    args = parser.parse_args(argv)

    status_file = args.status_file or (args.lint_dir / "STATUS.md")
    return report(args.lint_dir, status_file, fail_on_missing=not args.report)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
