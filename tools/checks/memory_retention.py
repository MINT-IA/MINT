#!/usr/bin/env python3
"""CTX-01 Phase 30.5-02 — MEMORY retention gate invoked by lefthook pre-commit.

Per D-02:
  HARD: every memory/topics/*.md with mtime >30d MUST be archived.
        Exit 1 if any stale file lingers in topics/ and is not in archive/.
  SOFT: MEMORY.md INDEX < 100 lines (warning to stderr, does NOT fail).

Per D-03: topics/ is flat, mtime-based detection, no frontmatter parsing.

Patch 2: same hardcoded whitelist as tools/memory/gc.py — whitelisted files
(feedback_*, project_*, user_*) are NEVER flagged as breach even when mtime
exceeds retention; they are doctrine/handoff/preference, not compostable.

Warning 7: skip `__LEFTHOOK_SELF_TEST_*` fixtures.

Exit codes:
  0  retention green (HARD passes, SOFT may have warnings)
  1  retention red (HARD gate breached OR topics/ missing)

Usage:
    python3 tools/checks/memory_retention.py           # check
    python3 tools/checks/memory_retention.py --strict  # alias
    python3 tools/checks/memory_retention.py --check   # alias
"""
from __future__ import annotations

import argparse
import fnmatch
import sys
import time
from pathlib import Path

MEMORY_DIR = (
    Path.home()
    / ".claude"
    / "projects"
    / "-Users-julienbattaglia-Desktop-MINT"
    / "memory"
)
TOPICS_DIR = MEMORY_DIR / "topics"
MEMORY_MD = MEMORY_DIR / "MEMORY.md"
RETENTION_DAYS = 30
INDEX_WARN_LINES = 100

# Patch 2 — same whitelist as gc.py (kept in sync; refactor to shared module
# in Phase 34 GUARD-04 if retention logic grows).
WHITELIST = ["feedback_*.md", "project_*.md", "user_*.md"]


def is_whitelisted(name: str) -> bool:
    return any(fnmatch.fnmatch(name, pat) for pat in WHITELIST)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="30j MEMORY retention gate (CTX-01, D-02)"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="explicit strict mode (default behavior; kept for lefthook clarity)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="alias for --strict",
    )
    parser.parse_args()

    if not TOPICS_DIR.exists():
        print(
            "retention: FAIL — topics/ missing. Run "
            "`python3 tools/memory/migrate_links.py` first.",
            file=sys.stderr,
        )
        return 1

    now = time.time()
    threshold_seconds = RETENTION_DAYS * 86400
    breached: list[tuple[str, float]] = []

    for p in TOPICS_DIR.glob("*.md"):
        # Warning 7: skip lefthook self-test fixtures
        if p.name.startswith("__LEFTHOOK_SELF_TEST_"):
            continue
        # Patch 2: whitelisted files exempt from retention breach
        if is_whitelisted(p.name):
            continue
        age = now - p.stat().st_mtime
        if age > threshold_seconds:
            breached.append((str(p), age / 86400))

    # SOFT warning on INDEX size
    if MEMORY_MD.exists():
        lines = len(MEMORY_MD.read_text(encoding="utf-8").splitlines())
        if lines > INDEX_WARN_LINES:
            print(
                f"retention WARNING: {MEMORY_MD} has {lines} lines "
                f"(target <{INDEX_WARN_LINES}). Per D-02 this is a warning, "
                f"not a failure — but consider pruning the INDEX.",
                file=sys.stderr,
            )

    if breached:
        print(
            f"retention: FAIL — {len(breached)} non-whitelisted file(s) in "
            f"topics/ have mtime >{RETENTION_DAYS}d and are not archived:",
            file=sys.stderr,
        )
        for path, days in breached:
            print(f"  {path} ({days:.1f}d old)", file=sys.stderr)
        print(
            "  -> Run: python3 tools/memory/gc.py",
            file=sys.stderr,
        )
        return 1

    print(f"retention: OK — {RETENTION_DAYS}j gate green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
