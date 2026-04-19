#!/usr/bin/env python3
"""CTX-02 metric (a) — git log + lints ingester.

Parses `git log --since='7 days ago'` (or `--days N`), classifies each
commit as `claude-agent` when its body contains `Co-Authored-By: Claude`,
then re-runs `tools/checks/accent_lint_fr.py` and
`tools/checks/no_hardcoded_fr.py` on each Claude commit's currently-existing
changed files. Violations are upserted into the `violations` table.

Per D-11 (a): drift rate = % claude-agent commits (last 7d) with >=1 violation.
"""
from __future__ import annotations

import subprocess
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / ".planning" / "agent-drift" / "drift.db"

LINTS: list[tuple[str, Path]] = [
    ("accent_lint_fr", REPO_ROOT / "tools" / "checks" / "accent_lint_fr.py"),
    ("no_hardcoded_fr", REPO_ROOT / "tools" / "checks" / "no_hardcoded_fr.py"),
]


def parse_git_log(days: int = 7) -> list[tuple[str, str, int, str]]:
    """Return list of (sha, author_label, committed_at_unix, subject).

    author_label = 'claude-agent' if body contains 'Co-Authored-By: Claude',
    else 'human'.
    """
    since_dt = datetime.now(timezone.utc) - timedelta(days=days)
    since = since_dt.isoformat()
    # Use ASCII record separators to safely embed subject + body.
    # 0x1f (unit) between fields, 0x1e (record) between commits.
    fmt = "%H%x1f%ct%x1f%s%x1f%b%x1e"
    try:
        result = subprocess.run(
            ["git", "log", f"--since={since}", f"--format={fmt}"],
            capture_output=True,
            text=True,
            check=True,
            cwd=str(REPO_ROOT),
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []
    commits: list[tuple[str, str, int, str]] = []
    for entry in result.stdout.split("\x1e"):
        entry = entry.strip()
        if not entry:
            continue
        parts = entry.split("\x1f")
        if len(parts) < 3:
            continue
        sha = parts[0].strip()
        try:
            ct = int(parts[1])
        except ValueError:
            continue
        subject = parts[2]
        body = parts[3] if len(parts) > 3 else ""
        is_claude = "Co-Authored-By: Claude" in body or "Co-Authored-By: claude" in body
        author = "claude-agent" if is_claude else "human"
        commits.append((sha, author, ct, subject))
    return commits


def files_changed(sha: str) -> list[str]:
    """Return file paths modified in commit `sha` (empty on error)."""
    try:
        r = subprocess.run(
            ["git", "show", "--name-only", "--format=", sha],
            capture_output=True,
            text=True,
            check=True,
            cwd=str(REPO_ROOT),
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []
    return [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]


def run_lint_on_file(lint_path: Path, target_file: str) -> list[tuple[int, str]]:
    """Return list of (line_number, snippet) violations from a single lint run."""
    abs_target = (REPO_ROOT / target_file).resolve()
    if not abs_target.exists():
        return []
    # Only lint text-like extensions the lint knows about. Delegate the
    # decision to the lint itself — it exits 0 on unknown extensions.
    try:
        r = subprocess.run(
            [sys.executable, str(lint_path), "--file", str(abs_target)],
            capture_output=True,
            text=True,
            check=False,
            cwd=str(REPO_ROOT),
        )
    except FileNotFoundError:
        return []
    if r.returncode == 0:
        return []
    violations: list[tuple[int, str]] = []
    # Parse lint stderr "path:line: snippet (...)"
    for line in r.stderr.splitlines():
        if ":" not in line:
            continue
        parts = line.split(":", 2)
        if len(parts) != 3:
            continue
        lineno_str, snippet = parts[1].strip(), parts[2].strip()
        try:
            lineno = int(lineno_str)
        except ValueError:
            continue
        violations.append((lineno, snippet[:200]))
    return violations


def main(days: int = 7, db_path: Path = DB_PATH) -> int:
    """Ingest last `days` of git log into drift.db. Returns # commits processed."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if not db_path.exists():
        return 0
    conn = sqlite3.connect(db_path)
    try:
        detected_at = int(datetime.now(timezone.utc).timestamp())
        commits = parse_git_log(days=days)
        for sha, author, ct, subject in commits:
            conn.execute(
                "INSERT OR REPLACE INTO commits (sha, author, committed_at, subject) VALUES (?, ?, ?, ?)",
                (sha, author, ct, subject[:500]),
            )
            if author != "claude-agent":
                continue
            for f in files_changed(sha):
                for lint_name, lint_path in LINTS:
                    if not lint_path.exists():
                        continue
                    for lineno, snippet in run_lint_on_file(lint_path, f):
                        conn.execute(
                            """
                            INSERT INTO violations
                              (sha, lint, file_path, line_number, snippet, detected_at)
                            VALUES (?, ?, ?, ?, ?, ?)
                            """,
                            (sha, lint_name, f, lineno, snippet, detected_at),
                        )
        conn.commit()
        return len(commits)
    finally:
        conn.close()


if __name__ == "__main__":
    n = main()
    print(f"ingest_git: {n} commit(s) processed (last 7d)")
