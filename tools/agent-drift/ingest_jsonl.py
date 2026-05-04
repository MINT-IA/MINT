#!/usr/bin/env python3
"""CTX-02 metric (c) — token cost parser.

Parses Claude Code session transcripts under
~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/*.jsonl
and inserts aggregated token totals into the `sessions` table of drift.db.

Zero Anthropic API calls — reads local files only.
Schema verified 2026-04-19 on a real transcript:
  data.message.usage = {
    input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens
  }

Implementation follows 30.5-RESEARCH.md §Code Examples Example 3 (verbatim),
with a few additions:
  - main(db_path=...) signature so dashboard.py can import and call programmatically
  - malformed lines are skipped (pitfall tolerance)
  - missing usage fields default to 0 (handles older transcript format)
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime
from pathlib import Path

TRANSCRIPTS_DIR = (
    Path.home()
    / ".claude"
    / "projects"
    / "-Users-julienbattaglia-Desktop-MINT"
)
REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / ".planning" / "agent-drift" / "drift.db"


def _parse_ts(ts: str) -> int | None:
    """ISO timestamp -> Unix seconds. Returns None on parse failure."""
    try:
        return int(
            datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
        )
    except (ValueError, AttributeError):
        return None


def aggregate_session(jsonl_path: Path) -> tuple[str, int | None, dict[str, int]]:
    """Return (session_id, started_at_unix_or_None, {input/output/cache_create/cache_read})."""
    totals = {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0}
    started_at: int | None = None
    session_id = jsonl_path.stem
    try:
        with open(jsonl_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                # capture start timestamp (first event with `timestamp`)
                if started_at is None and isinstance(obj, dict):
                    ts = obj.get("timestamp")
                    if isinstance(ts, str):
                        started_at = _parse_ts(ts)
                # sum usage if present (assistant events OR raw message events)
                msg = obj.get("message") if isinstance(obj, dict) else None
                if isinstance(msg, dict):
                    usage = msg.get("usage")
                    if isinstance(usage, dict):
                        totals["input"] += int(usage.get("input_tokens", 0) or 0)
                        totals["output"] += int(usage.get("output_tokens", 0) or 0)
                        totals["cache_create"] += int(
                            usage.get("cache_creation_input_tokens", 0) or 0
                        )
                        totals["cache_read"] += int(
                            usage.get("cache_read_input_tokens", 0) or 0
                        )
    except OSError:
        pass
    return session_id, started_at, totals


def ingest_file(conn: sqlite3.Connection, jsonl_path: Path) -> bool:
    """Insert/replace one session row. Returns True if row was written."""
    sid, started, t = aggregate_session(jsonl_path)
    if started is None:
        return False
    conn.execute(
        """
        INSERT OR REPLACE INTO sessions(
          session_id, started_at, transcript,
          total_input_tokens, total_output_tokens,
          total_cache_creation, total_cache_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            sid,
            started,
            str(jsonl_path),
            t["input"],
            t["output"],
            t["cache_create"],
            t["cache_read"],
        ),
    )
    return True


def main(
    db_path: Path = DB_PATH, transcripts_dir: Path = TRANSCRIPTS_DIR
) -> int:
    """Parse all transcripts under transcripts_dir into db_path.sessions."""
    if not db_path.exists():
        # Caller should have run `dashboard.py init` first. We skip gracefully
        # instead of crashing so `ingest` stays idempotent on empty installs.
        return 0
    if not transcripts_dir.exists():
        return 0
    conn = sqlite3.connect(db_path)
    try:
        count = 0
        for jsonl in sorted(transcripts_dir.glob("*.jsonl")):
            if ingest_file(conn, jsonl):
                count += 1
        conn.commit()
    finally:
        conn.close()
    return count


if __name__ == "__main__":
    n = main()
    print(f"ingest_jsonl: {n} session(s) upserted")
