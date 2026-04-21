#!/usr/bin/env python3
"""CTX-01 Phase 30.5-02 — Rewrite MEMORY.md internal links to `topics/` prefix.

Transforms `](feedback_xxx.md)` / `](project_xxx.md)` / `](user_xxx.md)` /
`](reference_xxx.md)` style links in `~/.claude/.../memory/MEMORY.md` into
`](topics/feedback_xxx.md)` etc.

Idempotent: running twice produces no diff (links already prefixed are left
alone via regex negative lookahead). Backs up MEMORY.md to MEMORY.md.bak on
first rewrite.

Per D-03: topics/ is flat (no feedback/ project/ reference/ subdirs).

Usage:
    python3 tools/memory/migrate_links.py            # rewrite
    python3 tools/memory/migrate_links.py --dry-run  # preview count
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

MEMORY_DIR = (
    Path.home()
    / ".claude"
    / "projects"
    / "-Users-julienbattaglia-Desktop-MINT"
    / "memory"
)
MEMORY_MD = MEMORY_DIR / "MEMORY.md"

# Match `](name.md)` where name is plain (no slash, no scheme, not already
# under topics/ or archive/, not an anchor `#...`).
# Negative lookahead prevents rewriting links that are already prefixed.
LINK_PATTERN = re.compile(
    r"\]\((?!https?://|mailto:|/|\#|topics/|archive/)([A-Za-z0-9_\-]+\.md)\)"
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="CTX-01 — rewrite MEMORY.md links to topics/ prefix"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print rewrite count without modifying MEMORY.md",
    )
    args = parser.parse_args()

    if not MEMORY_MD.exists():
        print(f"error: MEMORY.md missing at {MEMORY_MD}", file=sys.stderr)
        return 1

    text = MEMORY_MD.read_text(encoding="utf-8")
    rewrites = 0

    def repl(match: re.Match[str]) -> str:
        nonlocal rewrites
        rewrites += 1
        return f"](topics/{match.group(1)})"

    new_text = LINK_PATTERN.sub(repl, text)

    if args.dry_run:
        print(f"{rewrites} link(s) would be rewritten")
        return 0

    if new_text != text:
        bak = MEMORY_MD.with_suffix(".md.bak")
        if not bak.exists():
            shutil.copy2(MEMORY_MD, bak)
            print(f"backup: {bak}")
        MEMORY_MD.write_text(new_text, encoding="utf-8")
        print(f"rewrote {rewrites} link(s) in {MEMORY_MD}")
    else:
        print("no changes (already rewritten or no matching links)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
