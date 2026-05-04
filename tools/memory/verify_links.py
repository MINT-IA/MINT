#!/usr/bin/env python3
"""CTX-01 Phase 30.5-02 — Verify MEMORY.md topics/ links resolve to real files.

Walks `~/.claude/.../memory/MEMORY.md`, extracts every markdown link of the form
`](topics/xxx.md)` or `](archive/YYYY-MM/xxx.md)`, and asserts each target
exists on disk relative to `memory/`.

Exit 0 if all links resolve. Exit 1 with stderr list of broken links.

Usage:
    python3 tools/memory/verify_links.py
"""
from __future__ import annotations

import re
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

# Match `](topics/xxx.md)` or `](archive/2026-04/xxx.md)` etc.
LINK_RE = re.compile(r"\]\(((?:topics|archive)/[A-Za-z0-9_\-/]+\.md)\)")


def main() -> int:
    if not MEMORY_MD.exists():
        print(f"error: MEMORY.md missing at {MEMORY_MD}", file=sys.stderr)
        return 1

    text = MEMORY_MD.read_text(encoding="utf-8")
    links = LINK_RE.findall(text)
    broken: list[str] = []
    for rel in links:
        if not (MEMORY_DIR / rel).exists():
            broken.append(rel)

    if broken:
        print(
            f"verify_links: FAIL — {len(broken)} broken link(s) in {MEMORY_MD}:",
            file=sys.stderr,
        )
        for b in broken:
            print(f"  broken: {b}", file=sys.stderr)
        return 1

    print(
        f"verify_links: OK — {len(links)} link(s) in {MEMORY_MD} all resolve"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
