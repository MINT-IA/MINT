#!/usr/bin/env python3
"""Phase 95 Plan 95-01 / TEST-01 — author-and-grade-same-session lint.

Doctrine 2026-05-06 §3: a single PR cannot modify both
`services/backend/evals/datasets/**` AND `services/backend/evals/assertions/**`.
This protects the eval gate from « same agent authored both fixture and
grader » blind spots that ate 5 months of « walker GREEN » signal.

Escape hatch: a `[doctrine-override: <reason>]` token in the most recent
commit body bypasses the lint. The reason is logged to the PR comment so
Julien can review.

Implementation: shells out to `git diff --name-only <base>...HEAD`,
inspects the path set, and exits non-zero if both directories are present.

Exit codes:
    0  parity holds (only one directory touched, or override present)
    1  doctrine §3 violation: both directories touched in same PR
    2  usage / argument / git error (sysexits.h EX_USAGE)

Usage:
    python3 tools/checks/no_same_pr_prompts_and_assertions.py
    python3 tools/checks/no_same_pr_prompts_and_assertions.py --base origin/dev
    python3 tools/checks/no_same_pr_prompts_and_assertions.py --self-test
    python3 tools/checks/no_same_pr_prompts_and_assertions.py --dry-run-fixture <files>...

Python 3.9-compatible (dev 3.9.6, CI 3.11). stdlib-only.
"""
from __future__ import annotations

import argparse
import logging
import os
import pathlib
import re
import subprocess
import sys
from typing import Iterable

logger = logging.getLogger("no_same_pr_prompts_and_assertions")

DATASET_DIR = "services/backend/evals/datasets/"
ASSERTION_DIR = "services/backend/evals/assertions/"
OVERRIDE_PATTERN = re.compile(r"\[doctrine-override:\s*([^\]]+)\]")
DOCTRINE_LINK = ".planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md"


def _git_diff_paths(base: str) -> list[str]:
    """Return the list of paths changed between `base` and HEAD."""
    try:
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{base}...HEAD"],
            capture_output=True,
            check=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        logger.error("git diff failed (base=%s): %s", base, exc.stderr.strip())
        raise
    return [p.strip() for p in out.stdout.splitlines() if p.strip()]


def _last_commit_body() -> str:
    try:
        out = subprocess.run(
            ["git", "log", "-1", "--pretty=%B"],
            capture_output=True,
            check=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        logger.error("git log failed: %s", exc.stderr.strip())
        return ""
    return out.stdout


def _classify(paths: Iterable[str]) -> tuple[list[str], list[str]]:
    datasets = [p for p in paths if p.startswith(DATASET_DIR)]
    assertions = [p for p in paths if p.startswith(ASSERTION_DIR)]
    return datasets, assertions


def _check(paths: list[str], commit_body: str) -> int:
    datasets, assertions = _classify(paths)
    if not datasets or not assertions:
        if datasets:
            print(f"[OK] doctrine §3: {len(datasets)} dataset path(s), 0 assertion paths")
        elif assertions:
            print(f"[OK] doctrine §3: {len(assertions)} assertion path(s), 0 dataset paths")
        else:
            print("[OK] doctrine §3: no evals/* paths in diff")
        return 0

    override = OVERRIDE_PATTERN.search(commit_body)
    if override:
        reason = override.group(1).strip()
        print(
            f"[OK] doctrine §3: dual-directory diff allowed by "
            f"[doctrine-override: {reason}] in last commit"
        )
        return 0

    print(
        "::error::doctrine §3 violation — author-and-grade-same-session banned"
    )
    print(
        f"  This PR modifies BOTH {DATASET_DIR}** AND {ASSERTION_DIR}** "
        f"({len(datasets)} dataset paths, {len(assertions)} assertion paths)."
    )
    print(f"  Doctrine: {DOCTRINE_LINK} §3")
    print(
        "  Fix: split the change into two PRs (datasets first, assertions in a "
        "follow-up). Or, if this is a legitimate cross-cutting refactor, add "
        "[doctrine-override: <reason>] to the commit body."
    )
    print("  Offending dataset paths:")
    for p in datasets[:6]:
        print(f"    {p}")
    if len(datasets) > 6:
        print(f"    ... ({len(datasets) - 6} more)")
    print("  Offending assertion paths:")
    for p in assertions[:6]:
        print(f"    {p}")
    if len(assertions) > 6:
        print(f"    ... ({len(assertions) - 6} more)")
    return 1


def _self_test() -> int:
    """In-memory regression: run _check on 3 synthetic diff scenarios."""
    cases = [
        ("only datasets", ["services/backend/evals/datasets/julien_swiss/eclairage.yaml"], "", 0),
        ("only assertions", ["services/backend/evals/assertions/banned_terms.yaml"], "", 0),
        (
            "both — should fail",
            [
                "services/backend/evals/datasets/julien_swiss/eclairage.yaml",
                "services/backend/evals/assertions/banned_terms.yaml",
            ],
            "feat: a regular commit message",
            1,
        ),
        (
            "both with override — should pass",
            [
                "services/backend/evals/datasets/julien_swiss/eclairage.yaml",
                "services/backend/evals/assertions/banned_terms.yaml",
            ],
            "chore: cross-cutting rename\n\n[doctrine-override: assertion key renamed to match dataset]",
            0,
        ),
        ("no evals paths", ["apps/mobile/lib/main.dart"], "", 0),
    ]
    failed = 0
    for name, paths, body, expected in cases:
        # Suppress the case-internal stdout for quiet self-test report.
        from contextlib import redirect_stdout
        from io import StringIO

        buf = StringIO()
        with redirect_stdout(buf):
            got = _check(paths, body)
        ok = got == expected
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {name}: expected={expected} got={got}")
        if not ok:
            failed += 1
    if failed:
        print(f"[FAIL] self-test {failed} case(s) failed")
        return 1
    print("[OK] self-test all 5 cases passed")
    return 0


def _make_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument(
        "--base",
        default=os.environ.get("GITHUB_BASE_REF", "origin/dev"),
        help="Base ref to diff against (default $GITHUB_BASE_REF, then origin/dev)",
    )
    p.add_argument(
        "--self-test",
        action="store_true",
        help="Run in-memory regression on synthetic diff scenarios.",
    )
    p.add_argument(
        "--dry-run-fixture",
        nargs="+",
        metavar="PATH",
        help="Treat the supplied paths as the diff (skip git invocation).",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    args = _make_argparser().parse_args(argv)

    if args.self_test:
        return _self_test()

    if args.dry_run_fixture:
        return _check(list(args.dry_run_fixture), _last_commit_body())

    base = args.base
    if base.startswith("refs/heads/"):
        base = base.removeprefix("refs/heads/")
    # GH Actions surface base_ref as a plain branch name; rewrite to origin/<name>.
    if "/" not in base and base != "HEAD":
        base = f"origin/{base}"

    try:
        paths = _git_diff_paths(base)
    except subprocess.CalledProcessError:
        return 2
    body = _last_commit_body()
    return _check(paths, body)


if __name__ == "__main__":
    sys.exit(main())
