#!/usr/bin/env python3
"""CLI dashboard for agent-drift metrics (CTX-02).

Wave 0: skeleton with argparse + 6 stub subcommands (init/baseline/ingest/
report/golden-run/compare-to).

Wave 1 Plan 01 implements init/baseline/ingest. Later waves fill report/
golden-run/compare-to.

Per D-09: CLI Python + nightly markdown report (NOT mobile route).
Per D-10: SQLite local at .planning/agent-drift/drift.db (gitignored).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

DB_PATH = Path(".planning/agent-drift/drift.db")


def cmd_init(args: argparse.Namespace) -> int:
    """Initialize drift.db schema (5 tables)."""
    print(
        "TODO Wave 1 Plan 01 Task 1: create drift.db with 5 tables "
        "(sessions/commits/violations/context_hits/golden_runs)"
    )
    return 0


def cmd_baseline(args: argparse.Namespace) -> int:
    """Capture J0 snapshot pre-refonte."""
    print(
        "TODO Wave 1 Plan 01 Task 3: capture baseline J0 snapshot to "
        ".planning/agent-drift/baseline-J0.md"
    )
    return 0


def cmd_ingest(args: argparse.Namespace) -> int:
    """Parse git log + jsonl transcripts + context_hits into drift.db."""
    print(
        "TODO Wave 1 Plan 01 Task 2: parse git log + .claude/projects/*.jsonl + "
        "context_hits.jsonl into drift.db"
    )
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    """Generate nightly markdown report."""
    out = Path(args.out) if args.out else Path(".planning/agent-drift/nightly.md")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        "# Agent drift nightly report\n"
        "TODO Wave 1 Plan 01 Task 4: render 4 metrics from drift.db.\n"
    )
    print(f"wrote stub report to {out}")
    return 0


def cmd_golden_run(args: argparse.Namespace) -> int:
    """Run 20 golden prompts harness."""
    print(
        "TODO Wave 1 Plan 01 Task 5: run 20 golden prompts via "
        "tools/agent-drift/golden/run.sh"
    )
    return 0


def cmd_compare_to(args: argparse.Namespace) -> int:
    """Compare current drift.db state vs baseline-J0.md."""
    print(
        f"TODO CTX-05 spike validation: compare current drift.db vs "
        f"{args.baseline} strict diff"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Agent drift dashboard (CTX-02) — CLI Python + markdown reports (D-09)"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    # Positional subcommand names per D-09: dashboard.py <cmd> [args]
    sub.add_parser("init", help="Initialize drift.db schema").set_defaults(func=cmd_init)
    sub.add_parser("baseline", help="Capture J0 snapshot pre-refonte").set_defaults(func=cmd_baseline)
    sub.add_parser("ingest", help="Parse git+jsonl+hits into drift.db").set_defaults(func=cmd_ingest)

    rep = sub.add_parser("report", help="Generate YYYY-MM-DD.md report")
    rep.add_argument("--out", help="Output markdown path")
    rep.set_defaults(func=cmd_report)

    sub.add_parser("golden-run", help="Run 20 golden prompts harness").set_defaults(func=cmd_golden_run)

    cmp = sub.add_parser("compare-to", help="Compare current state vs baseline markdown")
    cmp.add_argument("baseline", help="Path to baseline-J0.md")
    cmp.set_defaults(func=cmd_compare_to)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
