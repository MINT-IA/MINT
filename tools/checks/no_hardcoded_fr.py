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

Use --file <path> to lint a whole single file (pattern used by ingest_git.py),
--staged-file <path> to lint only added/modified lines in the Git index, or
--changed-file <path> with --base-ref <ref> to lint only lines introduced
between that Git ref and HEAD (the CI mode).
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Iterable, Iterator

# Quoted FR-ish literals. We match either (a) accented chars inside the quotes
# or (b) at least two common French function words touching each other.
ACCENT_CHARS = r"àâçéèêëîïôùûüÀÂÇÉÈÊËÎÏÔÙÛÜ"
_QUOTED_ACCENT = re.compile(rf"['\"]([^'\"]*[{ACCENT_CHARS}][^'\"]*)['\"]")
_QUOTED_FR_WORDS = re.compile(
    r"""['"]([^'"]*?\b(?:le|la|les|de|des|du|et|pour|avec|sur|dans|une|un|mon|ma|mes|ton|ta|tes|son|sa|ses|mais|donc|ou|car)\s+\w+[^'"]*?)['"]""",
    re.IGNORECASE,
)
_UNIFIED_DIFF_HUNK = re.compile(
    r"^@@ -\d+(?:,\d+)? \+(?P<new_start>\d+)(?:,\d+)? @@"
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

# Legacy domain catalogs that predate the ARB migration. Keep this list tiny:
# touching one of these files should either remove the entry through a focused
# localization pass or leave a clear audit trail here rather than bypass hooks.
LEGACY_FILE_ALLOWLIST = (
    "apps/mobile/lib/services/debt_prevention_service.dart",
)


def _is_excluded(path: Path) -> bool:
    rel = "/" + path.as_posix() + "/"
    return any(ex in rel for ex in EXCLUDE_SUBSTRINGS)


def _is_legacy_allowed(path: Path) -> bool:
    normalized = path.as_posix()
    return any(normalized.endswith(entry) for entry in LEGACY_FILE_ALLOWLIST)


def _line_is_exempt(line: str) -> bool:
    return any(marker in line for marker in IGNORE_MARKERS)


def _next_code_character(text: str, start: int) -> int:
    """Return the next non-whitespace, non-comment character position."""
    cursor = start
    while cursor < len(text):
        if text[cursor].isspace():
            cursor += 1
            continue
        if text.startswith("//", cursor):
            newline = text.find("\n", cursor + 2)
            return len(text) if newline == -1 else _next_code_character(text, newline + 1)
        if text.startswith("/*", cursor):
            end = text.find("*/", cursor + 2)
            return len(text) if end == -1 else _next_code_character(text, end + 2)
        return cursor
    return cursor


def _dart_string_end(text: str, quote_start: int) -> int:
    """Return the exclusive end of a single- or triple-quoted Dart string."""
    quote = text[quote_start]
    triple = text.startswith(quote * 3, quote_start)
    delimiter_length = 3 if triple else 1
    cursor = quote_start + delimiter_length
    raw = (
        quote_start > 0
        and text[quote_start - 1] in {"r", "R"}
        and (
            quote_start < 2
            or not (text[quote_start - 2].isalnum() or text[quote_start - 2] == "_")
        )
    )

    while cursor < len(text):
        if triple:
            if text.startswith(quote * 3, cursor):
                return cursor + 3
        elif text[cursor] == quote:
            return cursor + 1

        if not raw and text[cursor] == "\\":
            cursor += 2
            continue
        if not triple and text[cursor] == "\n":
            return cursor
        cursor += 1
    return len(text)


def _mask_regexp_literals(text: str) -> str:
    """Blank only Dart string literals structurally inside `RegExp(...)`.

    Parenthesis tracking is lexical: strings and comments cannot forge or close
    a constructor. Newlines are preserved so diagnostics keep real line numbers.
    """
    masked = list(text)
    regexp_open_parens: set[int] = set()
    paren_stack: list[bool] = []
    regexp_depth = 0
    cursor = 0

    while cursor < len(text):
        if text.startswith("//", cursor):
            newline = text.find("\n", cursor + 2)
            cursor = len(text) if newline == -1 else newline
            continue
        if text.startswith("/*", cursor):
            end = text.find("*/", cursor + 2)
            cursor = len(text) if end == -1 else end + 2
            continue

        char = text[cursor]
        if char in {'"', "'"}:
            end = _dart_string_end(text, cursor)
            if regexp_depth:
                for index in range(cursor, end):
                    if masked[index] != "\n":
                        masked[index] = " "
            cursor = end
            continue

        if char.isalpha() or char == "_":
            end = cursor + 1
            while end < len(text) and (text[end].isalnum() or text[end] == "_"):
                end += 1
            if text[cursor:end] == "RegExp":
                open_paren = _next_code_character(text, end)
                if open_paren < len(text) and text[open_paren] == "(":
                    regexp_open_parens.add(open_paren)
            cursor = end
            continue

        if char == "(":
            is_regexp = cursor in regexp_open_parens
            paren_stack.append(is_regexp)
            if is_regexp:
                regexp_depth += 1
        elif char == ")" and paren_stack:
            if paren_stack.pop():
                regexp_depth -= 1
        cursor += 1

    return "".join(masked)


def scan_lines(
    lines: Iterable[tuple[int, str]],
    *,
    report_line_numbers: set[int] | None = None,
) -> list[tuple[int, str, str]]:
    source_lines = list(lines)
    source_text = "\n".join(line for _, line in source_lines)
    masked_lines = _mask_regexp_literals(source_text).split("\n")
    out: list[tuple[int, str, str]] = []
    for (lineno, line), masked_line in zip(source_lines, masked_lines):
        if report_line_numbers is not None and lineno not in report_line_numbers:
            continue
        if _line_is_exempt(line):
            continue
        m1 = _QUOTED_ACCENT.search(masked_line)
        if m1:
            out.append((lineno, line.strip()[:140], f"hardcoded-fr-accent: {m1.group(1)[:60]}"))
            continue
        m2 = _QUOTED_FR_WORDS.search(masked_line)
        if m2:
            out.append((lineno, line.strip()[:140], f"hardcoded-fr-words: {m2.group(1)[:60]}"))
    return out


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    if _is_legacy_allowed(path):
        return []
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return scan_lines(enumerate(text.splitlines(), start=1))


def added_lines_from_unified_diff(diff: str) -> Iterator[tuple[int, str]]:
    """Yield added content with its real line number in the staged file."""
    new_lineno: int | None = None
    for line in diff.splitlines():
        hunk = _UNIFIED_DIFF_HUNK.match(line)
        if hunk:
            new_lineno = int(hunk.group("new_start"))
            continue
        if new_lineno is None:
            continue
        if line.startswith("+++"):
            continue
        if line.startswith("+"):
            yield new_lineno, line[1:]
            new_lineno += 1
            continue
        if line.startswith("-") or line.startswith("\\"):
            continue
        if line.startswith(" "):
            new_lineno += 1


def _repo_relative_path(path: Path) -> tuple[Path, Path]:
    root_result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
        capture_output=True,
        check=False,
    )
    if root_result.returncode != 0:
        raise RuntimeError(root_result.stderr.strip() or "not inside a Git repository")
    repo_root = Path(root_result.stdout.strip()).resolve()
    absolute = path.resolve() if path.is_absolute() else (repo_root / path).resolve()
    try:
        return repo_root, absolute.relative_to(repo_root)
    except ValueError as exc:
        raise RuntimeError(f"file is outside the Git repository: {path}") from exc


def scan_staged_file(path: Path) -> list[tuple[int, str, str]]:
    if _is_legacy_allowed(path) or _is_excluded(path) or path.suffix not in TEXT_EXTS:
        return []
    repo_root, relative = _repo_relative_path(path)
    diff_result = subprocess.run(
        [
            "git",
            "diff",
            "--cached",
            "--unified=0",
            "--no-ext-diff",
            "--no-color",
            "--",
            relative.as_posix(),
        ],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    if diff_result.returncode != 0:
        raise RuntimeError(diff_result.stderr.strip() or f"git diff failed for {path}")
    added_line_numbers = {
        lineno for lineno, _ in added_lines_from_unified_diff(diff_result.stdout)
    }
    if not added_line_numbers:
        return []

    index_result = subprocess.run(
        ["git", "show", f":{relative.as_posix()}"],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    if index_result.returncode != 0:
        raise RuntimeError(
            index_result.stderr.strip() or f"cannot read staged content for {path}"
        )
    return scan_lines(
        enumerate(index_result.stdout.splitlines(), start=1),
        report_line_numbers=added_line_numbers,
    )


def scan_changed_file(path: Path, base_ref: str) -> list[tuple[int, str, str]]:
    if _is_legacy_allowed(path) or _is_excluded(path) or path.suffix not in TEXT_EXTS:
        return []
    repo_root, relative = _repo_relative_path(path)
    diff_result = subprocess.run(
        [
            "git",
            "diff",
            "--unified=0",
            "--no-ext-diff",
            "--no-color",
            base_ref,
            "HEAD",
            "--",
            relative.as_posix(),
        ],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    if diff_result.returncode != 0:
        raise RuntimeError(
            diff_result.stderr.strip() or f"git diff from {base_ref} failed for {path}"
        )
    added_line_numbers = {
        lineno for lineno, _ in added_lines_from_unified_diff(diff_result.stdout)
    }
    if not added_line_numbers:
        return []

    head_result = subprocess.run(
        ["git", "show", f"HEAD:{relative.as_posix()}"],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    if head_result.returncode != 0:
        raise RuntimeError(
            head_result.stderr.strip() or f"cannot read HEAD content for {path}"
        )
    return scan_lines(
        enumerate(head_result.stdout.splitlines(), start=1),
        report_line_numbers=added_line_numbers,
    )


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
            if _is_excluded(p):
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
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--file", help="Lint a whole single file (ingestion mode)")
    mode.add_argument(
        "--staged-file",
        help="Lint only lines added or modified in the staged diff for one file",
    )
    mode.add_argument(
        "--changed-file",
        help="Lint only lines introduced between --base-ref and HEAD for one file",
    )
    ap.add_argument("--base-ref", help="Git base ref for --changed-file mode")
    ap.add_argument(
        "--scope",
        nargs="*",
        default=DEFAULT_SCOPE,
        help="Directories to scan (default: apps/mobile/lib)",
    )
    args = ap.parse_args()

    staged_mode = args.staged_file is not None
    changed_mode = args.changed_file is not None
    if changed_mode and not args.base_ref:
        ap.error("--changed-file requires --base-ref")
    if args.base_ref and not changed_mode:
        ap.error("--base-ref requires --changed-file")

    if staged_mode:
        paths = [Path(args.staged_file)]
    elif changed_mode:
        paths = [Path(args.changed_file)]
    elif args.file:
        target = Path(args.file)
        if not target.exists():
            print(f"no_hardcoded_fr: file not found: {target}", file=sys.stderr)
            return 1
        paths = [] if _is_excluded(target) or target.suffix not in TEXT_EXTS else [target]
    else:
        paths = _collect_paths(args.scope)

    found = 0
    for path in paths:
        try:
            if staged_mode:
                violations = scan_staged_file(path)
            elif changed_mode:
                violations = scan_changed_file(path, args.base_ref)
            else:
                violations = scan_file(path)
        except RuntimeError as exc:
            print(f"no_hardcoded_fr: {exc}", file=sys.stderr)
            return 1
        for lineno, snippet, kind in violations:
            print(f"{path}:{lineno}: {snippet} ({kind})", file=sys.stderr)
            found += 1

    if found:
        print(f"no_hardcoded_fr: FAIL — {found} hardcoded FR literal(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
