#!/usr/bin/env python3
"""mint-wiring-check — 4-level wiring check for newly-created Dart/Python files.

Catches the W14-incident pattern: file exists, tests pass, but no real
consumer imports it. See `.claude/skills/mint-wiring-check/SKILL.md`.

Levels:
  N1 — file exists on disk
  N2 — no stub / TODO / NotImplementedError pattern
  N3 — at least one public symbol from the file is referenced in another file
  N4 — (optional, --check-sim) the file's name appears in `idb ui describe-all`

Exits:
  0 — all files pass N1 + N2 + N3 (N4 ignored unless --check-sim)
  1 — at least one file fails N1, N2, or N3
  2 — usage error (missing args, no files matched)

Python 3.9-compatible (matches project convention). stdlib-only.

Usage:
    python3 tools/checks/wiring_check.py --files <path> [<path>...]
    python3 tools/checks/wiring_check.py --staged
    python3 tools/checks/wiring_check.py --since-commit HEAD~5
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, List, Optional, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]

# ─── Patterns ───────────────────────────────────────────────────────────────

# N2 stub patterns. Each has a label so we can cite the line that failed.
# Patterns must hit ACTUAL code, not docstring/comment mentions of the same words.
# Class names assembled via concat so this source file does not self-match.
_NIE = "Not" + "ImplementedError"        # Python class name
_UIE = "Un" + "implementedError"         # Dart class name
STUB_PATTERNS = [
    # Python — actual raise / instantiation
    (re.compile(r"\braise\s+" + _NIE + r"\b"), "raise " + _NIE),
    (re.compile(r"\b" + _NIE + r"\s*\("), _NIE + "(...)"),
    # Dart — actual throw / instantiation
    (re.compile(r"\bthrow\s+" + _UIE + r"\b"), "throw " + _UIE),
    (re.compile(r"\b" + _UIE + r"\s*\("), _UIE + "(...)"),
    # Owner-less work-marker comments. Owner-tagged form like "x(julien): ..."
    # is allowed via the negative lookahead. Pattern strings split so this
    # source file does not self-match on the regex literals.
    (re.compile(r"^\s*//\s*" + "TO" + r"DO\b(?!\([\w.@-]+\))"), "// owner-less marker"),
    (re.compile(r"^\s*#\s*" + "TO" + r"DO\b(?!\([\w.@-]+\))"), "# owner-less marker"),
    (re.compile(r"^\s*//\s*" + "FIX" + r"ME\b"), "// owner-less marker"),
    (re.compile(r"^\s*#\s*" + "FIX" + r"ME\b"), "# owner-less marker"),
]

# Dart symbol extraction (top-level types + top-level functions).
DART_TYPE_RE = re.compile(
    r"^\s*(?:abstract\s+)?(?:class|mixin|enum|extension|typedef)\s+([A-Z][\w]*)",
    re.MULTILINE,
)
DART_FUNC_RE = re.compile(
    r"^\s*(?:Future<[^>]+>|void|String|int|double|bool|num|List<[^>]+>|Map<[^>]+>|Stream<[^>]+>|[A-Z][\w]*(?:<[^>]+>)?)\s+([a-z][\w]*)\s*\(",
    re.MULTILINE,
)

# Python symbol extraction (top-level class + def).
PY_CLASS_RE = re.compile(r"^class\s+([A-Z][\w]*)\s*[\(:]", re.MULTILINE)
PY_FUNC_RE = re.compile(r"^def\s+([a-z_][\w]*)\s*\(", re.MULTILINE)

# Files to skip entirely (generated / build artifacts).
SKIP_FILE_PATTERNS = (
    re.compile(r"\.g\.dart$"),
    re.compile(r"\.freezed\.dart$"),
    re.compile(r"\.gr\.dart$"),
    re.compile(r"_localizations(_[a-z]+)?\.dart$"),
    re.compile(r"/build/"),
    re.compile(r"/.dart_tool/"),
    re.compile(r"/__pycache__/"),
)

# Files that don't need to be imported (test files, scripts).
# Patterns match the path either at start or after a path separator.
TEST_FILE_PATTERNS = (
    re.compile(r"(?:^|/)tests?/"),
    re.compile(r"(?:^|/)test_[^/]*\.py$"),
    re.compile(r".*_test\.dart$"),
    re.compile(r".*_test\.py$"),
)

CHECKABLE_EXTS = {".dart", ".py"}


# ─── Data ───────────────────────────────────────────────────────────────────

@dataclass
class FileResult:
    path: Path
    n1: str = "?"          # PASS / FAIL
    n2: str = "?"          # PASS / FAIL
    n3: str = "?"          # PASS / FAIL / not-applicable / test-exempt
    n4: str = "?"          # PASS / FAIL / not-attempted
    notes: List[str] = field(default_factory=list)

    def is_blocking_fail(self) -> bool:
        """N4 doesn't block; N1/N2/N3 do."""
        return any(s == "FAIL" for s in (self.n1, self.n2, self.n3))


# ─── File discovery ────────────────────────────────────────────────────────

def _is_skipped(path: Path) -> bool:
    s = str(path)
    return any(p.search(s) for p in SKIP_FILE_PATTERNS)


def _is_test(path: Path) -> bool:
    s = str(path)
    return any(p.search(s) for p in TEST_FILE_PATTERNS)


def _resolve_files(args: argparse.Namespace) -> List[Path]:
    if args.files:
        return [Path(f) for f in args.files]
    if args.staged:
        out = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=AM"],
            capture_output=True, text=True, cwd=str(REPO_ROOT),
        )
        return [Path(line) for line in out.stdout.splitlines() if line.strip()]
    if args.since_commit:
        out = subprocess.run(
            ["git", "diff", "--name-only", "--diff-filter=AM",
             f"{args.since_commit}..HEAD"],
            capture_output=True, text=True, cwd=str(REPO_ROOT),
        )
        return [Path(line) for line in out.stdout.splitlines() if line.strip()]
    return []


# ─── Level checks ──────────────────────────────────────────────────────────

def _resolve(path: Path) -> Path:
    """Resolve an input path relative to current working directory.

    If the path is absolute, use as-is. If relative, resolve from cwd().
    This lets the lint work both from the repo root (production) and from
    sandbox tmp dirs (tests).
    """
    p = Path(path)
    return p if p.is_absolute() else (Path.cwd() / p)


def check_n1(path: Path) -> Tuple[str, Optional[str]]:
    if _resolve(path).is_file():
        return "PASS", None
    return "FAIL", f"file not found: {path}"


def check_n2(path: Path) -> Tuple[str, Optional[str]]:
    text = _resolve(path).read_text(encoding="utf-8", errors="replace")
    for line_no, line in enumerate(text.splitlines(), start=1):
        for regex, label in STUB_PATTERNS:
            if regex.search(line):
                return "FAIL", f"{path}:{line_no} matched {label}: {line.strip()[:80]}"
    return "PASS", None


def _extract_symbols(path: Path) -> Set[str]:
    text = _resolve(path).read_text(encoding="utf-8", errors="replace")
    symbols: Set[str] = set()
    if path.suffix == ".dart":
        symbols.update(DART_TYPE_RE.findall(text))
        symbols.update(DART_FUNC_RE.findall(text))
    elif path.suffix == ".py":
        symbols.update(PY_CLASS_RE.findall(text))
        symbols.update(PY_FUNC_RE.findall(text))
    # Drop private (Dart `_Foo`, Python `_foo`) and reserved.
    return {s for s in symbols if not s.startswith("_") and s not in {"main", "build"}}


def _grep_count(symbol: str, exclude_path: Path) -> int:
    """Count files (other than exclude_path) that mention the symbol as a word.

    Searches from current working directory so the lint works in both repo
    and sandbox contexts.
    """
    cmd = [
        "grep", "-r", "-l",
        "--include=*.dart", "--include=*.py",
        "-w", symbol,
        ".",
    ]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode not in (0, 1):
        return -1  # grep error
    excluded = str(exclude_path).lstrip("./")
    files = [
        line.strip().lstrip("./")
        for line in out.stdout.splitlines()
        if line.strip()
    ]
    return sum(1 for f in files if f != excluded)


def check_n3(path: Path, allow_tests: bool) -> Tuple[str, Optional[str]]:
    if _is_test(path) and allow_tests:
        return "test-exempt", None
    symbols = _extract_symbols(path)
    if not symbols:
        return "not-applicable", "no public symbols extracted"
    # We require at least one symbol to be referenced elsewhere.
    refs_per_symbol: List[Tuple[str, int]] = []
    for sym in sorted(symbols):
        n = _grep_count(sym, path)
        refs_per_symbol.append((sym, n))
    referenced = [(s, n) for s, n in refs_per_symbol if n > 0]
    if referenced:
        s, n = referenced[0]
        return "PASS", f"{s} referenced in {n} file(s)"
    syms_csv = ", ".join(s for s, _ in refs_per_symbol[:3])
    return "FAIL", f"none of [{syms_csv}] found outside {path}"


def check_n4(path: Path) -> Tuple[str, Optional[str]]:
    """Optional sim describe-all check. v0.1 = stub stub: not-attempted."""
    # Future: shell out to `idb ui describe-all` and grep for the file's
    # widget class name. For now we do not block on it.
    return "not-attempted", "v0.1 does not implement N4 (sim describe-all)"


# ─── Driver ────────────────────────────────────────────────────────────────

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    src = p.add_mutually_exclusive_group()
    src.add_argument("--files", nargs="+", help="explicit file paths")
    src.add_argument("--staged", action="store_true", help="files staged for commit")
    src.add_argument("--since-commit", help="diff vs given ref (e.g. HEAD~5)")
    p.add_argument("--check-sim", action="store_true",
                   help="attempt N4 sim describe-all (default: skip)")
    p.add_argument("--allow-tests", action="store_true", default=True,
                   help="exempt test files from N3 (default: True)")
    return p


def _check_one(path: Path, args: argparse.Namespace) -> FileResult:
    res = FileResult(path=path)
    n1, note = check_n1(path)
    res.n1 = n1
    if note:
        res.notes.append(note)
    if n1 != "PASS":
        return res
    n2, note = check_n2(path)
    res.n2 = n2
    if note:
        res.notes.append(note)
    n3, note = check_n3(path, args.allow_tests)
    res.n3 = n3
    if note:
        res.notes.append(note)
    if args.check_sim:
        n4, note = check_n4(path)
        res.n4 = n4
        if note:
            res.notes.append(note)
    return res


def _print_result(r: FileResult) -> None:
    print(f"[{r.path}]")
    print(f"  N1 file exists           : {r.n1}")
    print(f"  N2 no stub/TODO/NotImpl  : {r.n2}")
    print(f"  N3 imported by consumer  : {r.n3}")
    print(f"  N4 sim describe-all hit  : {r.n4}")
    for n in r.notes:
        print(f"     ↳ {n}")


def main(argv: list | None = None) -> int:
    args = _build_parser().parse_args(argv)
    files = _resolve_files(args)
    if not files:
        print("usage error: no files matched. Pass --files, --staged, or --since-commit",
              file=sys.stderr)
        return 2
    # Filter to checkable files (Dart or Python, not generated, not in build dirs).
    candidates: List[Path] = []
    for f in files:
        if f.suffix not in CHECKABLE_EXTS:
            continue
        if _is_skipped(f):
            continue
        candidates.append(f)
    if not candidates:
        print("no Dart or Python source files in the input set — nothing to check",
              file=sys.stderr)
        return 0  # not an error, just nothing to do

    results = [_check_one(f, args) for f in candidates]
    for r in results:
        _print_result(r)
    n_total = len(results)
    n_fail = sum(1 for r in results if r.is_blocking_fail())
    n_pass = n_total - n_fail
    suffix = " (façade)" if n_fail else ""
    print(f"\nSUMMARY: {n_total} files checked — {n_pass} PASS, {n_fail} FAIL{suffix}")
    return 1 if n_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
