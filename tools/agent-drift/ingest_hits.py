#!/usr/bin/env python3
"""CTX-02 metric (b) — context hits ingester.

Reads the append-only `.planning/agent-drift/context_hits.jsonl` file
(written by the extended `.claude/hooks/gsd-prompt-guard.js` — see Task 3)
and inserts each row into the `context_hits` table. Idempotent via a
`(session_id, detected_at, hit_type, rule_id)` uniqueness guard enforced
in-memory (SQLite schema doesn't declare the composite UNIQUE).
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / ".planning" / "agent-drift" / "drift.db"
HITS_PATH = REPO_ROOT / ".planning" / "agent-drift" / "context_hits.jsonl"


def _load_existing_keys(conn: sqlite3.Connection) -> set[tuple[str, int, str, str]]:
    cur = conn.execute(
        "SELECT session_id, detected_at, hit_type, COALESCE(rule_id, '') FROM context_hits"
    )
    return {tuple(r) for r in cur.fetchall()}


def main(db_path: Path = DB_PATH, hits_path: Path = HITS_PATH) -> int:
    """Ingest hits.jsonl into drift.db. Returns number of rows inserted."""
    if not db_path.exists() or not hits_path.exists():
        return 0
    conn = sqlite3.connect(db_path)
    try:
        existing = _load_existing_keys(conn)
        inserted = 0
        with open(hits_path, encoding="utf-8") as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    obj = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                session_id = str(obj.get("session_id", "unknown"))
                detected_at = int(obj.get("detected_at", 0) or 0)
                hit_type = str(obj.get("hit_type", "unknown"))
                rule_id = obj.get("rule_id")
                rule_key = rule_id if rule_id is not None else ""
                tool_use_index = int(obj.get("tool_use_index", 0) or 0)

                key = (session_id, detected_at, hit_type, str(rule_key))
                if key in existing:
                    continue
                existing.add(key)
                conn.execute(
                    """
                    INSERT INTO context_hits
                      (session_id, hit_type, rule_id, tool_use_index, detected_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (session_id, hit_type, rule_id, tool_use_index, detected_at),
                )
                # Ensure the session row exists (FK reference). Insert a
                # shell session row if we've never seen it yet — ingest_jsonl
                # may fill the real values on the next pass.
                conn.execute(
                    """
                    INSERT OR IGNORE INTO sessions
                      (session_id, started_at, transcript,
                       total_input_tokens, total_output_tokens,
                       total_cache_creation, total_cache_read)
                    VALUES (?, ?, ?, 0, 0, 0, 0)
                    """,
                    (session_id, detected_at, "<hit-only>"),
                )
                inserted += 1
        conn.commit()
        return inserted
    finally:
        conn.close()


if __name__ == "__main__":
    n = main()
    print(f"ingest_hits: {n} row(s) inserted")
