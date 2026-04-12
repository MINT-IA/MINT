#!/usr/bin/env python3
"""CI grep gate: fail if the legacy `chiffre_choc` token appears in live code.

Phase 1.5 domain rename acceptance test. After BE+MOB commits land, the
live codebase must contain zero references to the legacy identifier in
scoped paths. This script is wired into the CI pipeline and returns a
non-zero exit code (printing offending file:line pairs) if any match is
found.

Scope (D-06):
  Scans:
    - apps/mobile/lib/
    - apps/mobile/test/
    - services/backend/app/
    - services/backend/tests/
    - apps/mobile/lib/l10n/
    - tools/openapi/
    - docs/ (excluding docs/archive/)
  Excludes:
    - .planning/**
    - docs/archive/**
    - apps/mobile/archive/**
    - CLAUDE.md legacy note line (line 3)
    - this file itself (tools/checks/no_chiffre_choc.py)

Pattern:
  chiffre_?choc|chiffreChoc|ChiffreChoc|/chiffre-choc

Exit codes:
  0 — clean, no matches
  1 — matches found (prints file:line diagnostics to stderr)

Usage:
  python3 tools/checks/no_chiffre_choc.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PATTERN = re.compile(r"chiffre_?choc|chiffreChoc|ChiffreChoc|/chiffre-choc")

SCAN_ROOTS = [
    "apps/mobile/lib",
    "apps/mobile/test",
    "services/backend/app",
    "services/backend/tests",
    "tools/openapi",
    "docs",
]

EXCLUDE_DIRS = {
    ".planning",
    "docs/archive",
    "apps/mobile/archive",
    "__pycache__",
    "build",
    ".dart_tool",
    "node_modules",
    ".git",
}

EXCLUDE_FILES = {
    "tools/checks/no_chiffre_choc.py",
    "CLAUDE.md",  # legacy note line 3 is intentional
}

# Glob-like substrings: any file whose relative path contains one of these
# substrings is excluded. Used for audit / pre-audit / ship-gate docs that
# legitimately reference the legacy term in historical context.
EXCLUDE_FILE_SUBSTRINGS = (
    "PRE_AUDIT",
    "SHIP_GATE_v2.2",
)

# File extensions that we actually read as text.
TEXT_EXTS = {
    ".py",
    ".dart",
    ".arb",
    ".json",
    ".yaml",
    ".yml",
    ".md",
    ".txt",
}


def is_excluded(path: Path, repo_root: Path) -> bool:
    rel = path.relative_to(repo_root).as_posix()
    for ex in EXCLUDE_DIRS:
        if rel.startswith(ex + "/") or f"/{ex}/" in rel or rel == ex:
            return True
    if rel in EXCLUDE_FILES:
        return True
    for sub in EXCLUDE_FILE_SUBSTRINGS:
        if sub in rel:
            return True
    return False


def scan(repo_root: Path) -> list[tuple[str, int, str]]:
    matches: list[tuple[str, int, str]] = []
    for root in SCAN_ROOTS:
        base = repo_root / root
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix not in TEXT_EXTS:
                continue
            if is_excluded(path, repo_root):
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for lineno, line in enumerate(text.splitlines(), start=1):
                if PATTERN.search(line):
                    rel = path.relative_to(repo_root).as_posix()
                    matches.append((rel, lineno, line.strip()))
    return matches


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    matches = scan(repo_root)
    if not matches:
        print("no_chiffre_choc: OK — zero legacy tokens found in scoped paths")
        return 0
    print(
        f"no_chiffre_choc: FAIL — {len(matches)} legacy token(s) found:",
        file=sys.stderr,
    )
    for rel, lineno, line in matches:
        snippet = line if len(line) <= 140 else line[:137] + "..."
        print(f"  {rel}:{lineno}: {snippet}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
