#!/usr/bin/env python3
"""GUARD-03 -- hardcoded-FR lint (Phase 34 D-08/D-09/D-10).

Extended from Phase 30.5 CTX-02 early-ship. Flags French strings embedded
directly in Dart widget code instead of routed through AppLocalizations.

Scope (D-08 via lefthook glob, NOT enforced here -- the script keeps the
broader early-ship DEFAULT_SCOPE for manual full-repo audits; see
RESEARCH.md Open Question 3 resolution):
  apps/mobile/lib/widgets/
  apps/mobile/lib/screens/
  apps/mobile/lib/features/
Excluded via EXCLUDE_SUBSTRINGS when walked manually:
  /lib/l10n/, /lib/models/, /lib/services/, /test/, /integration_test/,
  /tests/checks/fixtures/.

Patterns (D-09):
  - Text('Xxxxxx...')  capitalised word >=6 chars
  - Text('...accented...')  any FR diacritic
  - title:  'Xxxx'  /  label:  'Xxxx'  (named-arg form)
  - Fallback: quoted literal with 2 FR function words touching (early-ship)

Whitelist (D-09):
  - Short acronyms 2..5 chars ALL CAPS
  - Numeric strings

Override (D-10, mirrors Plan 34-02 no_bare_catch preceding-line semantics):
  `// lefthook-allow:hardcoded-fr: <reason-of-3-or-more-words>` on the line
  IMMEDIATELY PRECEDING the flagged line. Reason length >=3
  whitespace-separated words enforced.

Exit codes: 0 clean / 1 violations.
Technical English diagnostics -- dev-facing, no i18n (Pitfall 8).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Tuple

# D-09 accent characters (FR diacritics).
ACCENT_CHARS = r"àâçéèêëîïôùûüÀÂÇÉÈÊËÎÏÔÙÛÜ"

# D-09 primary patterns (ordered most specific -> least).
_TEXT_CAPITALISED = re.compile(
    r"""\bText\(\s*['"]([A-Z][a-z]+.{5,}?)['"]\s*[),]"""
)
_TEXT_ACCENT = re.compile(
    rf"""\bText\(\s*['"]([^'"]*[{ACCENT_CHARS}][^'"]*)['"]\s*[),]"""
)
_TITLE_PARAM = re.compile(
    r"""\btitle:\s*['"]([A-Z][a-z]+[^'"]*?)['"]"""
)
_LABEL_PARAM = re.compile(
    r"""\blabel:\s*['"]([A-Z][a-z]+[^'"]*?)['"]"""
)
# Fallback -- original early-ship function-word heuristic, kept as a last
# line. 2 FR function words touching each other inside a quoted literal.
_QUOTED_FR_WORDS = re.compile(
    r"""['"]([^'"]*?\b(?:le|la|les|de|des|du|et|pour|avec|sur|dans|une|un|"""
    r"""mon|ma|mes|ton|ta|tes|son|sa|ses|mais|donc|ou|car)\s+\w+[^'"]*?)['"]""",
    re.IGNORECASE,
)
# Generic accented quoted literal (not just inside Text()) -- catches
# `final x = 'Créer'` or `const title = 'Sécurité'`.
_QUOTED_ACCENT = re.compile(
    rf"""['"]([^'"]*[{ACCENT_CHARS}][^'"]*)['"]"""
)

# D-09 whitelist -- short technical strings that should not flag.
_ACRONYM = re.compile(r"""['"][A-Z]{2,5}['"]""")
_NUMERIC = re.compile(r"""['"]\d+['"]""")

# D-10 inline override (reason >=3 words -- matches Plan 34-02 D-06 semantics).
_OVERRIDE = re.compile(
    r"""//\s*lefthook-allow:hardcoded-fr:\s*(\S+(?:\s+\S+){2,})"""
)

IGNORE_MARKERS = (
    "AppLocalizations",
    "l10n",
    "tr(",
    "// lint-ignore",
    "// ignore:",
    "debugPrint(",
    "print(",
    "assert(",
)

TEXT_EXTS = {".dart"}
DEFAULT_SCOPE = ["apps/mobile/lib"]
# D-08 manual-scan exclusions. Lefthook glob does the authoritative scope
# restriction for pre-commit hook invocation; these substrings only apply
# when the CLI is used without --file (full-repo walk via --scope).
EXCLUDE_SUBSTRINGS = (
    "/lib/l10n/",
    "/lib/models/",
    "/lib/services/",
    "/.dart_tool/",
    "/build/",
    "/.git/",
    "/test/",
    "/integration_test/",
    "/tests/checks/fixtures/",
)


def _line_is_exempt(line: str) -> bool:
    """Same-line exemption -- matches IGNORE_MARKERS or carries override itself."""
    if any(marker in line for marker in IGNORE_MARKERS):
        return True
    if _OVERRIDE.search(line):
        return True
    return False


def _is_whitelisted_string(line: str) -> bool:
    """Return True if the only quoted candidates on the line are whitelisted.

    Whitelist fires only when there is no FR accent anywhere on the line
    AND no FR function-word signal. Prevents 'ERR: erreur grave' from
    bypassing via its acronym prefix.
    """
    has_fr_accent = bool(re.search(rf"[{ACCENT_CHARS}]", line))
    has_fr_words = bool(_QUOTED_FR_WORDS.search(line))
    if has_fr_accent or has_fr_words:
        return False
    if _ACRONYM.search(line) or _NUMERIC.search(line):
        return True
    return False


def _override_in_preceding_line(lines: List[str], idx: int) -> bool:
    """Check the PRECEDING line (idx-1, 0-indexed) for a D-10 override.

    Mirrors Plan 34-02 `_override_in_preceding` API shape for Phase 34
    consistency. Reason >=3 whitespace-separated words enforced by
    `_OVERRIDE` regex at module load.
    """
    if idx == 0:
        return False
    prev = lines[idx - 1]
    return bool(_OVERRIDE.search(prev))


def scan_file(path: Path) -> List[Tuple[int, str, str]]:
    """Return list of (lineno, snippet, pattern_type) violations.

    `lineno` is 1-indexed. Ordered: accent in Text() -> capitalised in
    Text() -> title: -> label: -> generic accented literal -> FR words.
    The first match on a given line wins (single row per line).
    """
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    out: List[Tuple[int, str, str]] = []
    lines = text.splitlines()
    for idx, line in enumerate(lines):
        if _line_is_exempt(line):
            continue
        if _override_in_preceding_line(lines, idx):
            continue
        if _is_whitelisted_string(line):
            continue
        lineno = idx + 1
        m1 = _TEXT_ACCENT.search(line)
        if m1:
            out.append((lineno, line.strip()[:140],
                        f"hardcoded-fr-accent: {m1.group(1)[:60]}"))
            continue
        m2 = _TEXT_CAPITALISED.search(line)
        if m2:
            out.append((lineno, line.strip()[:140],
                        f"hardcoded-fr-text: {m2.group(1)[:60]}"))
            continue
        m3 = _TITLE_PARAM.search(line)
        if m3:
            out.append((lineno, line.strip()[:140],
                        f"hardcoded-fr-title: {m3.group(1)[:60]}"))
            continue
        m4 = _LABEL_PARAM.search(line)
        if m4:
            out.append((lineno, line.strip()[:140],
                        f"hardcoded-fr-label: {m4.group(1)[:60]}"))
            continue
        m5 = _QUOTED_ACCENT.search(line)
        if m5:
            out.append((lineno, line.strip()[:140],
                        f"hardcoded-fr-accent: {m5.group(1)[:60]}"))
            continue
        m6 = _QUOTED_FR_WORDS.search(line)
        if m6:
            out.append((lineno, line.strip()[:140],
                        f"hardcoded-fr-words: {m6.group(1)[:60]}"))
    return out


def _collect_paths(scope: List[str]) -> List[Path]:
    paths: List[Path] = []
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
            "GUARD-03 hardcoded-FR lint for Dart widgets. "
            "Phase 34 D-08 scope (widgets/screens/features) enforced via "
            "lefthook glob. Pass --file <paths> or --scope <dirs>."
        )
    )
    ap.add_argument("--file", nargs="*", default=[],
                    help="Lint specific files")
    ap.add_argument(
        "--scope",
        nargs="*",
        default=DEFAULT_SCOPE,
        help="Directories to scan (default: apps/mobile/lib)",
    )
    args = ap.parse_args()

    if args.file:
        paths = [Path(f) for f in args.file if Path(f).exists()]
    else:
        paths = _collect_paths(args.scope)

    found = 0
    for path in paths:
        for lineno, snippet, kind in scan_file(path):
            print(f"[no_hardcoded_fr] {path}:{lineno}: {snippet} ({kind})",
                  file=sys.stderr)
            found += 1

    if found:
        print(
            f"[no_hardcoded_fr] FAIL -- {found} hardcoded FR literal(s). "
            f"Use AppLocalizations.of(context)!.key or add "
            f"`// lefthook-allow:hardcoded-fr: <reason-of-3-or-more-words>` "
            f"above the line.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
