#!/usr/bin/env python3
"""CTX-02 metric (d) — golden runs ingester.

Reads `tools/agent-drift/golden/results.jsonl` (produced by `run.sh` when
nightly automation lands) and inserts rows into `golden_runs`. If the file
does not exist, returns 0 silently — not every `ingest` invocation will
have fresh golden data.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / ".planning" / "agent-drift" / "drift.db"
RESULTS_PATH = (
    REPO_ROOT / "tools" / "agent-drift" / "golden" / "results.jsonl"
)


def main(db_path: Path = DB_PATH, results_path: Path = RESULTS_PATH) -> int:
    """Upsert golden run rows. Returns number of rows inserted."""
    if not db_path.exists() or not results_path.exists():
        return 0
    conn = sqlite3.connect(db_path)
    inserted = 0
    try:
        with open(results_path, encoding="utf-8") as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    obj = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                run_at = int(obj.get("run_at", 0) or 0)
                prompt_id = int(obj.get("prompt_id", -1))
                if prompt_id < 0:
                    continue
                turns = obj.get("turns_to_correct")
                passed = obj.get("passed_lints", "")
                failed = obj.get("failed_lints", "")
                excerpt = obj.get("output_excerpt", "")
                conn.execute(
                    """
                    INSERT INTO golden_runs
                      (run_at, prompt_id, turns_to_correct,
                       passed_lints, failed_lints, output_excerpt)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        run_at,
                        prompt_id,
                        turns,
                        str(passed)[:500],
                        str(failed)[:500],
                        str(excerpt)[:500],
                    ),
                )
                inserted += 1
        conn.commit()
        return inserted
    finally:
        conn.close()


if __name__ == "__main__":
    n = main()
    print(f"ingest_golden: {n} row(s) inserted")
