#!/usr/bin/env python3
"""Render nightly markdown report with 4 metrics from drift.db (CTX-02).

SQL queries are verbatim from 30.5-RESEARCH.md §Code Examples Example 2.
Writes `.planning/agent-drift/YYYY-MM-DD.md` by default.

Per D-11:
  - metric (a) drift_rate        : % commits by claude-agent with >=1 violation (last 7d)
  - metric (b) context_hit_rate  : % sessions with >=1 rule hit at first tool_use (last 7d)
  - metric (c) token_cost        : avg total tokens per session (last 7d)
  - metric (d) turns_to_correct  : avg turns to produce lint-clean output (latest golden run)
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / ".planning" / "agent-drift" / "drift.db"


METRIC_A_SQL = """
SELECT
  COUNT(DISTINCT CASE WHEN v.sha IS NOT NULL THEN c.sha END) * 1.0 /
  NULLIF(COUNT(DISTINCT c.sha), 0) AS drift_rate
FROM commits c
LEFT JOIN violations v ON v.sha = c.sha
WHERE c.author = 'claude-agent'
  AND c.committed_at >= CAST(strftime('%s', 'now', '-7 days') AS INTEGER)
"""

METRIC_B_SQL = """
SELECT
  COUNT(DISTINCT CASE WHEN h.tool_use_index = 0 THEN s.session_id END) * 1.0 /
  NULLIF(COUNT(DISTINCT s.session_id), 0) AS context_hit_rate
FROM sessions s
LEFT JOIN context_hits h ON h.session_id = s.session_id
WHERE s.started_at >= CAST(strftime('%s', 'now', '-7 days') AS INTEGER)
"""

METRIC_C_SQL = """
SELECT AVG(
  COALESCE(total_input_tokens, 0) +
  COALESCE(total_output_tokens, 0) +
  COALESCE(total_cache_creation, 0) +
  COALESCE(total_cache_read, 0)
)
FROM sessions
WHERE started_at >= CAST(strftime('%s', 'now', '-7 days') AS INTEGER)
"""

METRIC_D_SQL = """
SELECT ROUND(AVG(turns_to_correct), 2)
FROM golden_runs
WHERE run_at = (SELECT MAX(run_at) FROM golden_runs)
"""


def _fetchone(conn: sqlite3.Connection, sql: str):
    cur = conn.execute(sql)
    row = cur.fetchone()
    if row is None:
        return None
    return row[0]


def _fmt_pct(val) -> str:
    if val is None:
        return "n/a"
    return f"{val * 100:.1f}%"


def _fmt_int(val) -> str:
    if val is None:
        return "n/a"
    return f"{int(val)}"


def _fmt_num(val) -> str:
    if val is None:
        return "n/a"
    return f"{val}"


def render(db_path: Path = DB_PATH, out_path: Path | None = None) -> str:
    """Render 4-metric markdown. Writes to out_path if provided. Returns content."""
    if not db_path.exists():
        raise RuntimeError(
            f"drift.db not found at {db_path}. Run `dashboard.py init` first."
        )
    conn = sqlite3.connect(db_path)
    try:
        m_a = _fetchone(conn, METRIC_A_SQL)
        m_b = _fetchone(conn, METRIC_B_SQL)
        m_c = _fetchone(conn, METRIC_C_SQL)
        m_d = _fetchone(conn, METRIC_D_SQL)
    finally:
        conn.close()

    today = datetime.now(timezone.utc).date().isoformat()
    lines = [
        f"# Agent drift report — {today}",
        "",
        "Source: `.planning/agent-drift/drift.db` (CTX-02). Window: last 7 days.",
        "",
        "## Metrics",
        "",
        "### (a) Drift rate — metric a",
        f"- **Value:** {_fmt_pct(m_a)}",
        "- **Definition:** % commits by `Co-Authored-By: Claude` with >=1 lint violation",
        "- **Source:** `git log --author='Co-Authored-By: Claude'` × `tools/checks/{accent_lint_fr,no_hardcoded_fr}.py`",
        "",
        "### (b) Context hit rate — metric b",
        f"- **Value:** {_fmt_pct(m_b)}",
        "- **Definition:** % sessions where `gsd-prompt-guard.js` detected >=1 rule violation at first tool_use",
        "- **Source:** `.claude/hooks/gsd-prompt-guard.js` -> `.planning/agent-drift/context_hits.jsonl`",
        "",
        "### (c) Token cost per session — metric c",
        f"- **Value:** {_fmt_int(m_c)} tokens (avg input + output + cache)",
        "- **Definition:** mean total tokens per session from Claude Code JSONL transcripts",
        "- **Source:** `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/*.jsonl` usage sums",
        "",
        "### (d) Time-to-first-correct-output — metric d",
        f"- **Value:** {_fmt_num(m_d)} turns avg (latest golden run)",
        "- **Definition:** # turns to produce lint-clean output on 20 golden prompts",
        "- **Source:** `tools/agent-drift/golden/run.sh` -> `golden_runs` table",
        "",
    ]
    content = "\n".join(lines) + "\n"
    if out_path is not None:
        out_path = Path(out_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(content, encoding="utf-8")
    return content


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--out", help="Output markdown path")
    p.add_argument("--db", default=str(DB_PATH), help="Path to drift.db")
    args = p.parse_args()
    out = Path(args.out) if args.out else (
        REPO_ROOT
        / ".planning"
        / "agent-drift"
        / f"{datetime.now(timezone.utc).date().isoformat()}.md"
    )
    render(db_path=Path(args.db), out_path=out)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
