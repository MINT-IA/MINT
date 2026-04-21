#!/usr/bin/env python3
"""Early-ship hardcoded-FR lint (CTX-02 metric a ingestion).

Scans `.dart` widgets under `apps/mobile/lib/` (EXCLUDING `lib/l10n/`) for
French strings embedded inline instead of routed through AppLocalizations.
Heuristic : lines with a quoted literal containing accented FR chars OR
common FR function words, that do NOT reference `AppLocalizations`, `tr(`,
`l10n`, or `// lint-ignore`.

Exit codes:
  0 — clean
  1 — violations found (stderr has `path:line: snippet` rows)

Use --file <path> to lint a single file (pattern used by ingest_git.py).
Phase 34 GUARD-04 will refine the heuristic and wire CI. Plan 01 only needs
the early-ship version to feed the violations table.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Quoted FR-ish literals. We match either (a) accented chars inside the quotes
# or (b) at least two common French function words touching each other.
ACCENT_CHARS = r"àâçéèêëîïôùûüÀÂÇÉÈÊËÎÏÔÙÛÜ"
_QUOTED_ACCENT = re.compile(rf"['\"]([^'\"]*[{ACCENT_CHARS}][^'\"]*)['\"]")
_QUOTED_FR_WORDS = re.compile(
    r"""['"]([^'"]*?\b(?:le|la|les|de|des|du|et|pour|avec|sur|dans|une|un|mon|ma|mes|ton|ta|tes|son|sa|ses|mais|donc|ou|car)\s+\w+[^'"]*?)['"]""",
    re.IGNORECASE,
)

IGNORE_MARKERS = (
    "AppLocalizations",
    "l10n",
    "tr(",
    "// lint-ignore",
    "// ignore:",
    "debugPrint(",
    "print(",  # dev logs — noise; real CI gate in Phase 34
    "assert(",
)

TEXT_EXTS = {".dart"}
DEFAULT_SCOPE = ["apps/mobile/lib"]
EXCLUDE_SUBSTRINGS = (
    "/lib/l10n/",
    "/.dart_tool/",
    "/build/",
    "/.git/",
    "/test/",  # tests often need literal strings
)


def _line_is_exempt(line: str) -> bool:
    return any(marker in line for marker in IGNORE_MARKERS)


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    out: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        if _line_is_exempt(line):
            continue
        m1 = _QUOTED_ACCENT.search(line)
        if m1:
            out.append((lineno, line.strip()[:140], f"hardcoded-fr-accent: {m1.group(1)[:60]}"))
            continue
        m2 = _QUOTED_FR_WORDS.search(line)
        if m2:
            out.append((lineno, line.strip()[:140], f"hardcoded-fr-words: {m2.group(1)[:60]}"))
    return out


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
        description=(
            "Early-ship hardcoded-FR lint for .dart widgets. "
            "Excludes lib/l10n/ and test/. "
            "Full version lands in Phase 34 GUARD-04."
        )
    )
    ap.add_argument("--file", help="Lint a single file")
    ap.add_argument(
        "--scope",
        nargs="*",
        default=DEFAULT_SCOPE,
        help="Directories to scan (default: apps/mobile/lib)",
    )
    args = ap.parse_args()

    if args.file:
        target = Path(args.file)
        if not target.exists():
            print(f"no_hardcoded_fr: file not found: {target}", file=sys.stderr)
            return 1
        paths = [target]
    else:
        paths = _collect_paths(args.scope)

    found = 0
    for path in paths:
        for lineno, snippet, kind in scan_file(path):
            print(f"{path}:{lineno}: {snippet} ({kind})", file=sys.stderr)
            found += 1

    if found:
        print(f"no_hardcoded_fr: FAIL — {found} hardcoded FR literal(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
