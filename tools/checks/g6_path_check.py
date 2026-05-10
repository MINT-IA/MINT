#!/usr/bin/env python3
"""G6 calc-correctness path decider — CALC-04 (CONTEXT 92.5 D-18 / D-21).

Deterministic CLI: given a list of changed file paths (from --files
or --diff-base ref), exit 0 if ANY path matches a G6 trigger path,
exit 1 otherwise. Used by:
  (a) .github/workflows/calc-rigor.yml as belt-and-suspenders alongside
      the GitHub Actions `paths:` filter,
  (b) GSD verifier integration (D-21): any phase whose plan touches
      the trigger paths must invoke this tool to confirm G6 applies.

Trigger paths (D-18 EXACT — no expansion without an ADR):
  - apps/mobile/lib/services/financial_core/**
  - services/backend/app/services/**
  - services/backend/app/constants/social_insurance.py

Mirrors `tools/checks/accent_lint_fr.py` in style: argparse + clean exit
codes + machine-readable stderr.
"""
from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys

# D-18 EXACT trigger paths. To extend, write an ADR + bump the doc.
TRIGGER_GLOBS: list[str] = [
    "apps/mobile/lib/services/financial_core/*",
    "apps/mobile/lib/services/financial_core/**/*",
    "services/backend/app/services/*",
    "services/backend/app/services/**/*",
    "services/backend/app/constants/social_insurance.py",
]


def matches_trigger(path: str) -> bool:
    p = path.lstrip("./")
    for glob in TRIGGER_GLOBS:
        if fnmatch.fnmatch(p, glob):
            return True
    return False


def files_from_diff(base: str) -> list[str]:
    """Return changed files between HEAD and base ref via git."""
    out = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line.strip() for line in out.stdout.splitlines() if line.strip()]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="G6 calc-correctness path decider (CALC-04 / CONTEXT 92.5 D-18).",
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--files", nargs="+", help="Explicit list of changed file paths.")
    src.add_argument(
        "--diff-base",
        help="Git ref (e.g. origin/dev); uses git diff --name-only.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress stderr summary lines.",
    )
    args = parser.parse_args()

    if args.files:
        files = list(args.files)
    else:
        files = files_from_diff(args.diff_base)

    matched = [f for f in files if matches_trigger(f)]

    if not args.quiet:
        if matched:
            print(
                f"[g6] applies — {len(matched)} trigger-path file(s):",
                file=sys.stderr,
            )
            for f in matched:
                print(f"[g6]   {f}", file=sys.stderr)
        else:
            print(
                f"[g6] does not apply — none of {len(files)} changed file(s) match D-18 trigger paths.",
                file=sys.stderr,
            )

    return 0 if matched else 1


if __name__ == "__main__":
    sys.exit(main())
