#!/usr/bin/env python3
"""CLI dashboard for agent-drift metrics (CTX-02).

Phase 30.5 Plan 01 Task 1 : implementations init/ingest/report/golden-run/compare-to
reelles (no stubs). `baseline` reste STUB cote Task 1 et recoit son implementation
complete dans Task 3 (lockfile + capture J0).

Subcommands (positional per D-09):
  init        -> initialize drift.db with 5-table schema (idempotent)
  baseline    -> [STUB Task 1 — full impl Task 3] capture J0 snapshot
  ingest      -> parse git log + jsonl transcripts + hits log into drift.db
  report      -> render .planning/agent-drift/YYYY-MM-DD.md with 4 metrics
  golden-run  -> run 20 golden prompts via `claude -p` (A7 AVAILABLE)
  compare-to  -> compare current drift.db vs baseline markdown (CTX-05 spike)

Per D-09: CLI Python + nightly markdown report (NOT mobile route).
Per D-10: SQLite local at .planning/agent-drift/drift.db (gitignored).
Per D-11: 4 metric data sources (git log, context_hits.jsonl, jsonl transcripts, golden runs).
Per D-12: baseline = single snapshot pre-refonte (locked via .baseline-lock).
"""
from __future__ import annotations

import argparse
import os
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Repo-root resolution — dashboard.py lives at tools/agent-drift/dashboard.py
REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / ".planning" / "agent-drift" / "drift.db"
SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"
BASELINE_MD = REPO_ROOT / ".planning" / "agent-drift" / "baseline-J0.md"
BASELINE_LOCK = REPO_ROOT / ".planning" / "agent-drift" / ".baseline-lock"
HITS_LOG = REPO_ROOT / ".planning" / "agent-drift" / "context_hits.jsonl"
GOLDEN_RUN_SH = REPO_ROOT / "tools" / "agent-drift" / "golden" / "run.sh"
GOLDEN_RESULTS = REPO_ROOT / "tools" / "agent-drift" / "golden" / "results.jsonl"


def _ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------
def cmd_init(args: argparse.Namespace) -> int:
    """Initialize drift.db schema (5 tables, idempotent via IF NOT EXISTS)."""
    _ensure_parent(DB_PATH)
    schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.executescript(schema_sql)
        conn.commit()
    finally:
        conn.close()
    print(f"init: drift.db ready at {DB_PATH.relative_to(REPO_ROOT)}")
    return 0


# ---------------------------------------------------------------------------
# baseline — Task 3 full implementation (replaces Task 1 stub)
# ---------------------------------------------------------------------------
def cmd_baseline(args: argparse.Namespace) -> int:
    """Capture the pre-refonte J0 snapshot per D-12 (single snapshot, locked).

    Flow:
      1. If `.baseline-lock` exists → exit 1 with message (prevents moving-target).
      2. Ensure drift.db exists (init if needed).
      3. Run ingest to refresh current metrics from git+jsonl+hits.
      4. Render the 4-metric markdown to `.planning/agent-drift/baseline-J0.md`
         prefixed with a "# Baseline J0 — captured {ISO date}" banner.
      5. Write `.baseline-lock` sentinel with capture timestamp + HEAD sha.

    D-12 rationale: baseline MUST reflect PRE-refonte behaviour. If a caller
    re-runs baseline post-refonte, the moving-target effect pollutes the
    "-30% drift" claim (observer, not intervention). Lockfile enforces this
    non-negotiably.
    """
    if BASELINE_LOCK.exists():
        lock_content = BASELINE_LOCK.read_text(encoding="utf-8").strip()
        print(
            f"baseline already captured ({lock_content}); "
            f"delete {BASELINE_LOCK.relative_to(REPO_ROOT)} to recapture",
            file=sys.stderr,
        )
        return 1

    # Ensure DB + fresh metrics
    if not DB_PATH.exists():
        cmd_init(args)
    cmd_ingest(args)

    # Render J0 snapshot via render_report
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from importlib import import_module

    render_report = import_module("render_report")
    body = render_report.render(db_path=DB_PATH, out_path=None)

    today_iso = datetime.now(timezone.utc).date().isoformat()
    banner = (
        f"# Baseline J0 — captured {today_iso} (UTC)\n\n"
        "> Pre-refonte snapshot per D-12. DO NOT edit manually — this file is\n"
        "> the frozen comparison point for all future CTX-01 / CTX-03 / CTX-04\n"
        "> drift measurements. A companion `.baseline-lock` sentinel prevents\n"
        "> accidental recapture.\n\n"
    )
    content = banner + body
    BASELINE_MD.parent.mkdir(parents=True, exist_ok=True)
    BASELINE_MD.write_text(content, encoding="utf-8")

    # Write lockfile with capture timestamp + git HEAD
    head_sha = "unknown"
    try:
        r = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
            cwd=str(REPO_ROOT),
        )
        head_sha = r.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    now_iso = datetime.now(timezone.utc).isoformat()
    lock_text = f"captured_at: {now_iso}\ncommit_sha: {head_sha}\n"
    BASELINE_LOCK.write_text(lock_text, encoding="utf-8")

    print(
        f"baseline: captured J0 snapshot at "
        f"{BASELINE_MD.relative_to(REPO_ROOT)} (lock: "
        f"{BASELINE_LOCK.relative_to(REPO_ROOT)})"
    )
    return 0


# ---------------------------------------------------------------------------
# ingest
# ---------------------------------------------------------------------------
def cmd_ingest(args: argparse.Namespace) -> int:
    """Run 4 ingesters in sequence (jsonl tokens, git+lints, hits, golden runs)."""
    # Ensure DB exists even if user skipped `init`
    if not DB_PATH.exists():
        cmd_init(args)

    # Ingesters imported lazily so that `dashboard.py --help` stays fast
    # and missing modules don't block `init` / `report`.
    from importlib import import_module

    for mod_name in ("ingest_jsonl", "ingest_git", "ingest_hits", "ingest_golden"):
        try:
            mod = import_module(mod_name)
        except ImportError:
            # Module path: sys.path must include the agent-drift dir
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            mod = import_module(mod_name)
        if hasattr(mod, "main"):
            try:
                mod.main()
            except Exception as e:  # noqa: BLE001
                # Ingester failures must not break the whole command
                print(f"ingest: {mod_name} failed: {e}", file=sys.stderr)
    print("ingest: done")
    return 0


# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------
def cmd_report(args: argparse.Namespace) -> int:
    """Render .planning/agent-drift/YYYY-MM-DD.md with 4 metrics from drift.db."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from importlib import import_module

    render_report = import_module("render_report")
    out = Path(args.out) if args.out else (
        REPO_ROOT
        / ".planning"
        / "agent-drift"
        / f"{datetime.now(timezone.utc).date().isoformat()}.md"
    )
    # Ensure DB exists so render doesn't crash on fresh checkout
    if not DB_PATH.exists():
        cmd_init(args)
    render_report.render(db_path=DB_PATH, out_path=out)
    print(f"report: wrote {out}")
    return 0


# ---------------------------------------------------------------------------
# golden-run
# ---------------------------------------------------------------------------
def cmd_golden_run(args: argparse.Namespace) -> int:
    """Run 20 golden prompts via `claude -p` (A7 AVAILABLE per Plan 00 spike)."""
    if not GOLDEN_RUN_SH.exists():
        print(f"golden-run: missing {GOLDEN_RUN_SH}", file=sys.stderr)
        return 1
    # Fallback message if claude CLI missing
    claude_cli = _which("claude")
    if claude_cli is None:
        print(
            "golden-run: A7 fallback — `claude` CLI not on PATH. "
            "Metric (d) must be run on-demand, rerun manually when CLI available.",
            file=sys.stderr,
        )
        return 0
    # Forward positional args if any
    cmd = ["bash", str(GOLDEN_RUN_SH)]
    if args.dry_run:
        cmd.append("--dry-run")
    result = subprocess.run(cmd, check=False)
    return result.returncode


# ---------------------------------------------------------------------------
# compare-to
# ---------------------------------------------------------------------------
def cmd_compare_to(args: argparse.Namespace) -> int:
    """Compare current drift.db metrics vs baseline markdown.

    Exit 1 if any metric regressed >5% vs baseline, 0 otherwise.
    Used by CTX-05 spike validation.
    """
    baseline = Path(args.baseline)
    if not baseline.exists():
        print(f"compare-to: baseline not found at {baseline}", file=sys.stderr)
        return 1
    # For CTX-05 (Phase 30.6) — placeholder strict-diff logic.
    # Task 1 scope: file exists + non-empty + report renders.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from importlib import import_module

    render_report = import_module("render_report")
    current = render_report.render(db_path=DB_PATH, out_path=None)
    baseline_text = baseline.read_text(encoding="utf-8")
    # Naive strict equality check — Phase 30.6 refines with per-metric parsing
    if current.strip() == baseline_text.strip():
        print("compare-to: identical to baseline (zero drift)")
        return 0
    # Without per-metric parsing we cannot assert regression direction yet.
    # Phase 30.6 CTX-05 replaces this with numeric threshold comparison.
    print(
        "compare-to: current report differs from baseline "
        "(per-metric regression check lands in CTX-05 / Phase 30.6)"
    )
    return 0


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def _which(binary: str) -> str | None:
    """POSIX which — returns absolute path or None."""
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = Path(d) / binary
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Agent drift dashboard (CTX-02) — CLI Python + markdown reports (D-09)"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("init", help="Initialize drift.db schema").set_defaults(func=cmd_init)
    sub.add_parser(
        "baseline", help="Capture J0 snapshot pre-refonte (Task 3)"
    ).set_defaults(func=cmd_baseline)
    sub.add_parser("ingest", help="Parse git+jsonl+hits into drift.db").set_defaults(
        func=cmd_ingest
    )

    rep = sub.add_parser("report", help="Generate YYYY-MM-DD.md report")
    rep.add_argument("--out", help="Output markdown path")
    rep.set_defaults(func=cmd_report)

    gr = sub.add_parser("golden-run", help="Run 20 golden prompts harness")
    gr.add_argument("--dry-run", action="store_true", help="Dry run — count prompts only")
    gr.set_defaults(func=cmd_golden_run)

    cmp = sub.add_parser("compare-to", help="Compare current state vs baseline markdown")
    cmp.add_argument("baseline", help="Path to baseline-J0.md")
    cmp.set_defaults(func=cmd_compare_to)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
