#!/usr/bin/env python3
"""CTX-01 Phase 30.5-02 — 30-day retention GC for memory/topics/.

Archives `~/.claude/.../memory/topics/*.md` with mtime > 30 days to
`~/.claude/.../memory/archive/YYYY-MM/` (bucket derived from file mtime).

Per D-02: 30j retention is the HARD gate. <100L INDEX is SOFT (warning).
Per D-03: flat topics/, mtime-based detection (NO frontmatter parsing).
Per Plan 30.5-00 A4 spike PASS: mtime reliable → no fallback needed.

Patch 2 (post-split 2026-04-19) — HARDCODED WHITELIST: filenames matching
`feedback_*.md`, `project_*.md`, or `user_*.md` are NEVER archived
regardless of mtime. They hold core doctrine and active handoff context.

Warning 7 skip guard: filenames starting with `__LEFTHOOK_SELF_TEST_` are
managed by tools/checks/lefthook_self_test.sh — this script ignores them
so a surviving self-test fixture doesn't falsely breach retention.

Usage:
    python3 tools/memory/gc.py              # apply
    python3 tools/memory/gc.py --dry-run    # preview
    python3 tools/memory/gc.py --days 60    # custom threshold
"""
from __future__ import annotations

import argparse
import fnmatch
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

MEMORY_DIR = (
    Path.home()
    / ".claude"
    / "projects"
    / "-Users-julienbattaglia-Desktop-MINT"
    / "memory"
)
TOPICS_DIR = MEMORY_DIR / "topics"
ARCHIVE_DIR = MEMORY_DIR / "archive"
RETENTION_DAYS = 30

# Patch 2 — module-level whitelist: these patterns are NEVER archived,
# even if mtime exceeds retention threshold. Use fnmatch for glob semantics.
WHITELIST = ["feedback_*.md", "project_*.md", "user_*.md"]


def is_whitelisted(name: str) -> bool:
    """True if `name` matches any WHITELIST pattern (fnmatch)."""
    return any(fnmatch.fnmatch(name, pat) for pat in WHITELIST)


def archive_bucket_for(path: Path) -> Path:
    """Return `archive/YYYY-MM/` bucket derived from file mtime."""
    dt = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)
    return ARCHIVE_DIR / f"{dt.year:04d}-{dt.month:02d}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="30d retention GC for ~/.claude/.../memory/topics/"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print planned moves without executing",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=RETENTION_DAYS,
        help=f"retention threshold in days (default: {RETENTION_DAYS})",
    )
    args = parser.parse_args()

    if not TOPICS_DIR.exists():
        print(
            f"error: topics/ missing at {TOPICS_DIR} — run migrate_links.py first",
            file=sys.stderr,
        )
        return 1

    now = time.time()
    threshold_seconds = args.days * 86400
    moved: list[tuple[str, str, float]] = []

    for p in sorted(TOPICS_DIR.glob("*.md")):
        # Warning 7: skip lefthook self-test fixtures (owned by
        # tools/checks/lefthook_self_test.sh EXIT trap)
        if p.name.startswith("__LEFTHOOK_SELF_TEST_"):
            continue

        # Patch 2: never archive doctrine / handoff / user preference files
        if is_whitelisted(p.name):
            continue

        age_seconds = now - p.stat().st_mtime
        if age_seconds <= threshold_seconds:
            continue

        bucket = archive_bucket_for(p)
        dest = bucket / p.name
        age_days = age_seconds / 86400

        if args.dry_run:
            moved.append((str(p), str(dest), age_days))
            continue

        bucket.mkdir(parents=True, exist_ok=True)
        if dest.exists():
            # Idempotency: if destination already there, dedupe by size.
            if dest.stat().st_size == p.stat().st_size:
                p.unlink()
            else:
                # Content differs → keep both with mtime-based suffix.
                dest = dest.with_name(
                    f"{p.stem}.{int(p.stat().st_mtime)}.md"
                )
                shutil.move(str(p), str(dest))
        else:
            shutil.move(str(p), str(dest))
        moved.append((str(p), str(dest), age_days))

    if args.dry_run:
        for src, dst, days in moved:
            print(f"DRY {src} -> {dst} (age={days:.1f}d)")
        print(f"DRY total: {len(moved)}")
    else:
        for src, dst, days in moved:
            print(f"archived {src} -> {dst} (age={days:.1f}d)")
        print(f"archived total: {len(moved)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
