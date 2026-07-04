#!/usr/bin/env python3
"""D-04 atomicity gate — Phase mint-data-architecture-v1-01 Plan 02 Task 4.

Mechanically enforces the « same PR » constraint declared in CONTEXT D-04 :
the 6 doctrine files must co-modify (either ALL touched or NONE touched in
a given diff range). A « partial » co-modification (some but not all) is the
exact failure mode this gate exists to prevent — that is the state where
agents reading post-merge doctrine would see an inconsistent L1/L2 split.

Codex HIGH #1 closed : D-04 is no longer process-only.

Usage :
    python3 tools/checks/doctrine_atomicity_gate.py [--base BASE] [--head HEAD]
                                                    [--skip-if-untouched] [--json]

Defaults : `--base origin/dev`, `--head HEAD`.

Exit codes :
    0 — all 6 doctrine files touched OR 0 doctrine files touched (atomicity respected).
    1 — partial co-modification (1..5 doctrine files touched ; missing files listed).
    2 — git / argparse / I/O hard failure.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from typing import List, Set, Tuple

# The 6-file atomic doctrine set. Matches CONTEXT.md D-04 verbatim.
_DOCTRINE_FILES: Tuple[str, ...] = (
    "CLAUDE.md",
    "docs/AGENTS/backend.md",
    "docs/AGENTS/flutter.md",
    ".claude/skills/mint-flutter-dev/SKILL.md",
    ".claude/skills/mint-backend-dev/SKILL.md",
    ".planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md",
)


def _resolve_rev(rev: str) -> str:
    """Resolve a git rev (branch / tag / sha) to a 40-char sha."""
    result = subprocess.run(
        ["git", "rev-parse", rev],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"git rev-parse {rev!r} failed (exit {result.returncode}) : {result.stderr.strip()}"
        )
    return result.stdout.strip()


def _diff_files(base: str, head: str) -> List[str]:
    """Return the list of file paths changed between base..head, relative to repo root."""
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}..{head}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"git diff --name-only {base}..{head} failed (exit {result.returncode}) : "
            f"{result.stderr.strip()}"
        )
    lines = [ln.strip() for ln in result.stdout.splitlines() if ln.strip()]
    return lines


def _parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="D-04 atomicity gate for the 6 doctrine files.",
    )
    p.add_argument("--base", default="origin/dev", help="Base rev (default : origin/dev).")
    p.add_argument("--head", default="HEAD", help="Head rev (default : HEAD).")
    p.add_argument(
        "--skip-if-untouched",
        action="store_true",
        help=(
            "When zero doctrine files are touched, exit 0 (default behaviour also does this, "
            "but the explicit flag documents the intent for CI configs)."
        ),
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON to stdout (for CI integration).",
    )
    return p.parse_args(argv)


def main(argv: List[str]) -> int:
    args = _parse_args(argv)

    try:
        base_sha = _resolve_rev(args.base)
        head_sha = _resolve_rev(args.head)
    except RuntimeError as exc:
        print(f"ERROR : {exc}", file=sys.stderr)
        return 2

    try:
        changed = _diff_files(base_sha, head_sha)
    except RuntimeError as exc:
        print(f"ERROR : {exc}", file=sys.stderr)
        return 2

    changed_set: Set[str] = set(changed)
    doctrine_set: Set[str] = set(_DOCTRINE_FILES)
    touched: Set[str] = changed_set & doctrine_set
    missing: Set[str] = doctrine_set - touched

    payload = {
        "touched": sorted(touched),
        "missing": sorted(missing),
        "doctrine_total": len(_DOCTRINE_FILES),
        "base": base_sha,
        "head": head_sha,
        "exit": 0,
    }

    # Atomicity « all-or-nothing » : 0 touched OR all 6 touched = PASS.
    if not touched:
        if args.json:
            print(json.dumps(payload))
        else:
            print(
                "doctrine_atomicity_gate : 0/6 doctrine files touched (unrelated PR) — PASS",
                file=sys.stderr,
            )
        return 0
    if not missing:
        if args.json:
            print(json.dumps(payload))
        else:
            print(
                "doctrine_atomicity_gate : 6/6 doctrine files touched (atomic doctrine PR) — PASS",
                file=sys.stderr,
            )
        return 0

    # Partial co-modification = FAIL.
    payload["exit"] = 1
    if args.json:
        print(json.dumps(payload))
    else:
        print(
            "doctrine_atomicity_gate : D-04 VIOLATED — partial doctrine co-modification.",
            file=sys.stderr,
        )
        print(
            f"  touched ({len(touched)}/{len(_DOCTRINE_FILES)}) : {sorted(touched)}",
            file=sys.stderr,
        )
        print(
            f"  missing ({len(missing)}/{len(_DOCTRINE_FILES)}) : {sorted(missing)}",
            file=sys.stderr,
        )
        print(
            "  Fix : `git add " + " ".join(sorted(missing)) + "` and re-push, OR "
            "revert the doctrine touches in this PR if it's not the atomic doctrine PR.",
            file=sys.stderr,
        )
        print(
            "  See : CONTEXT.md §D-04, "
            ".planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/.",
            file=sys.stderr,
        )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
