#!/usr/bin/env python3
"""Early-ship FR accent lint (CTX-02 metric a ingestion).

Scope: detect ASCII-flattened French words that should carry diacritics.
Scans `.dart`, `.py`, `.arb`, `.md` files by default. Writes offending
`path:line: snippet (pattern)` lines to stderr when violations are found.

Exit codes:
  0 — clean
  1 — violations found (stderr has machine-readable `path:line: snippet` rows)

Phase 34 GUARD-04 will extend the pattern list and wire CI. Phase 30.5
Plan 01 only needs the early-ship version to make `ingest_git.py` run lints
on each Claude commit's diff and populate the `violations` table.

Pattern list sourced from MEMORY.md feedback files + 30.5-CONTEXT.md D-14.
Use --file <path> to lint a single file (pattern used by ingest_git.py).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Each pattern = (word_regex, suggested_correction). Patterns use \b word
# boundaries and (?i) case-insensitive via re.IGNORECASE at call-site.
PATTERNS: list[tuple[str, str]] = [
    (r"\bcreer\b", "créer"),
    (r"\bdecouvrir\b", "découvrir"),
    (r"\beclairage\b", "éclairage"),
    (r"\bsecurite\b", "sécurité"),
    (r"\bliberer\b", "libérer"),
    (r"\bpreter\b", "prêter"),
    (r"\brealiser\b", "réaliser"),
    (r"\bdeja\b", "déjà"),
    (r"\brecu\b", "reçu"),
    (r"\belaborer\b", "élaborer"),
    (r"\bregler\b", "régler"),
    (r"\bspecialistes?\b", "spécialiste(s)"),
    (r"\bgerer\b", "gérer"),
    (r"\bprogres\b", "progrès"),
]

TEXT_EXTS = {".dart", ".py", ".arb", ".md"}
EXCLUDE_SUBSTRINGS = (
    "/.git/",
    "/node_modules/",
    "/.dart_tool/",
    "/build/",
    "/__pycache__/",
    "/docs/archive/",
    "/.planning/archives/",
)


def scan_text(text: str) -> list[tuple[int, str, str]]:
    """Scan a raw text buffer for ASCII-flattened French accent patterns.

    Returns list of (lineno, snippet, pattern->correction) violations. 1-indexed lines.
    Backward-compatible with scan_file — shares the PATTERNS list.
    Added in Phase 30.7 TOOL-04 MCP wrapper. Do NOT duplicate PATTERNS here.
    """
    out: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for pat, correct in PATTERNS:
            if re.search(pat, line, re.IGNORECASE):
                snippet = line.strip()[:140]
                out.append((lineno, snippet, f"{pat} -> {correct}"))
    return out


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return list of (lineno, snippet, pattern->correction) violations."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return scan_text(text)


def _collect_paths(scope: list[str]) -> list[Path]:
    paths: list[Path] = []
    for s in scope:
        root = Path(s)
        if not root.exists():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            if p.suffix not in TEXT_EXTS:
                continue
            rel = "/" + p.as_posix() + "/"
            if any(ex in rel for ex in EXCLUDE_SUBSTRINGS):
                continue
            paths.append(p)
    return paths


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Early-ship FR accent lint — scans for ASCII-flattened French words"
    )
    ap.add_argument("--file", help="Lint a single file (absolute or relative path)")
    ap.add_argument(
        "--scope",
        nargs="*",
        default=["apps/mobile/lib", "services/backend/app", "tools"],
        help="Directories to scan (default: lib/app/tools)",
    )
    args = ap.parse_args()

    if args.file:
        target = Path(args.file)
        if not target.exists():
            print(f"accent_lint_fr: file not found: {target}", file=sys.stderr)
            return 1
        paths = [target]
    else:
        paths = _collect_paths(args.scope)

    found = 0
    for path in paths:
        for lineno, snippet, pat in scan_file(path):
            print(f"{path}:{lineno}: {snippet} ({pat})", file=sys.stderr)
            found += 1

    if found:
        print(f"accent_lint_fr: FAIL — {found} violation(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
