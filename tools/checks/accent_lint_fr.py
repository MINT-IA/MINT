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
Use --file <path> for whole-file ingestion, --staged-file <path> for local
added lines, or --changed-file <path> with --base-ref <ref> for CI additions.
"""

from __future__ import annotations

import argparse
import ast
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple

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
ROUTE_OR_URL_LITERAL_RE = re.compile(
    r"""(?P<quote>['"])(?:[a-z][a-z0-9+.-]*:)?/{1,3}[^'"\s]*(?P=quote)""",
    re.IGNORECASE,
)
ROUTE_OR_URL_CONTENT_RE = re.compile(r"(?:[a-z][a-z0-9+.-]*:)?/{1,3}\S*", re.IGNORECASE)
NON_FRENCH_GENERATED_L10N_RE = re.compile(r"^app_localizations_(?!fr\b)[a-z]{2}\.dart$")
TECHNICAL_TOKEN_RE = re.compile(r"[a-z][a-z0-9_]*(?:[-.][a-z0-9_]+)*")
DART_INTERPOLATION_RE = re.compile(r"\$(?:[A-Za-z_]\w*|\{[^{}]*\})")
PYTHON_INTERPOLATION_RE = re.compile(r"\{[^{}]*\}")
CHECK_SELF_TEST_PARTS = ("tools", "checks", "tests")
UNIFIED_DIFF_HUNK_RE = re.compile(
    r"^@@ -\d+(?:,\d+)? \+(?P<new_start>\d+)(?:,\d+)? @@"
)


class SourceLiteral(NamedTuple):
    content: str
    start: int
    end: int
    content_line: int
    start_line: int
    start_column: int
    prefix: str


def _source_literals(text: str, suffix: str) -> list[SourceLiteral]:
    """Extract literals while lexically excluding comments and identifiers."""
    literals: list[SourceLiteral] = []
    i = 0
    length = len(text)
    while i < length:
        if suffix == ".py" and text[i] == "#":
            newline = text.find("\n", i + 1)
            i = length if newline == -1 else newline + 1
            continue
        if suffix == ".dart" and text.startswith("//", i):
            newline = text.find("\n", i + 2)
            i = length if newline == -1 else newline + 1
            continue
        if suffix == ".dart" and text.startswith("/*", i):
            depth = 1
            i += 2
            while i < length and depth:
                if text.startswith("/*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            continue

        quote = text[i]
        if quote not in {"'", '"'}:
            i += 1
            continue

        prefix_start = i
        while prefix_start > 0 and text[prefix_start - 1].isalpha():
            prefix_start -= 1
        candidate_prefix = text[prefix_start:i]
        valid_prefix_chars = "rR" if suffix == ".dart" else "rRuUbBfF"
        if not candidate_prefix or any(
            char not in valid_prefix_chars for char in candidate_prefix
        ):
            prefix_start = i
            candidate_prefix = ""

        delimiter = quote * 3 if text.startswith(quote * 3, i) else quote
        content_start = i + len(delimiter)
        cursor = content_start
        is_raw = "r" in candidate_prefix.lower()
        while cursor < length:
            if text.startswith(delimiter, cursor):
                content_end = cursor
                cursor += len(delimiter)
                break
            if not is_raw and text[cursor] == "\\":
                cursor += 2
            else:
                cursor += 1
        else:
            content_end = length

        start_line = text.count("\n", 0, prefix_start) + 1
        last_newline = text.rfind("\n", 0, prefix_start)
        start_column = (
            prefix_start if last_newline == -1 else prefix_start - last_newline - 1
        )
        literals.append(
            SourceLiteral(
                content=text[content_start:content_end],
                start=prefix_start,
                end=cursor,
                content_line=text.count("\n", 0, content_start) + 1,
                start_line=start_line,
                start_column=start_column,
                prefix=candidate_prefix,
            )
        )
        i = cursor
    return literals


def _python_docstring_positions(text: str) -> set[tuple[int, int]]:
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return set()

    positions: set[tuple[int, int]] = set()
    for node in ast.walk(tree):
        body = getattr(node, "body", None)
        if not body or not isinstance(body, list):
            continue
        first = body[0]
        if (
            isinstance(first, ast.Expr)
            and isinstance(first.value, ast.Constant)
            and isinstance(first.value.value, str)
        ):
            positions.add((first.value.lineno, first.value.col_offset))
    return positions


def _is_machine_identifier_literal(text: str, literal: SourceLiteral) -> bool:
    content = literal.content.strip()
    if not TECHNICAL_TOKEN_RE.fullmatch(content):
        return False

    before = text[max(0, literal.start - 120) : literal.start]
    slot_match = re.search(r"([A-Za-z_]\w*)\s*(?::|=)\s*$", before)
    if slot_match:
        slot = slot_match.group(1)
        if slot == "id" or slot.lower().endswith("_id") or slot.endswith("Id"):
            return True

    if re.search(r"(?:==|!=|\bcase)\s*$", before):
        return True

    after = text[literal.end : literal.end + 40]
    return bool(re.match(r"\s*=>", after))


def _mask_interpolation(content: str, pattern: re.Pattern[str]) -> str:
    def replace(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group())

    return pattern.sub(replace, content)


def _scan_source_file(path: Path, text: str) -> list[tuple[int, str, str]]:
    lines = text.splitlines()
    docstrings = _python_docstring_positions(text) if path.suffix == ".py" else set()
    out: list[tuple[int, str, str]] = []
    for literal in _source_literals(text, path.suffix):
        if (literal.start_line, literal.start_column) in docstrings:
            continue
        if ROUTE_OR_URL_CONTENT_RE.fullmatch(literal.content.strip()):
            continue
        if _is_machine_identifier_literal(text, literal):
            continue

        lint_content = literal.content
        if path.suffix == ".dart":
            lint_content = _mask_interpolation(lint_content, DART_INTERPOLATION_RE)
        elif "f" in literal.prefix.lower():
            lint_content = _mask_interpolation(lint_content, PYTHON_INTERPOLATION_RE)
        for pat, correct in PATTERNS:
            for match in re.finditer(pat, lint_content, re.IGNORECASE):
                lineno = literal.content_line + lint_content[: match.start()].count(
                    "\n"
                )
                snippet = (
                    lines[lineno - 1].strip()[:140] if lineno <= len(lines) else ""
                )
                out.append((lineno, snippet, f"{pat} -> {correct}"))
    return out


def _is_check_self_test_path(path: Path) -> bool:
    """Keep intentional negative fixtures outside the production CLI gate."""
    parts = path.parts
    width = len(CHECK_SELF_TEST_PARTS)
    return any(
        tuple(parts[index : index + width]) == CHECK_SELF_TEST_PARTS
        for index in range(len(parts) - width + 1)
    )


def _line_for_lint(path: Path, line: str) -> str:
    lint_line = line
    if path.suffix == ".md":
        lint_line = re.sub(r"`[^`]*`", "", lint_line)
    if path.suffix in {".dart", ".py"}:
        lint_line = ROUTE_OR_URL_LITERAL_RE.sub("", lint_line)
    return lint_line


def _scan_text(path: Path, text: str) -> list[tuple[int, str, str]]:
    if path.name == "accent_lint_fr.py":
        return []
    if path.suffix == ".arb" and path.name != "app_fr.arb":
        return []
    if NON_FRENCH_GENERATED_L10N_RE.match(path.name):
        return []
    if path.suffix in {".dart", ".py"}:
        return _scan_source_file(path, text)
    out: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        lint_line = _line_for_lint(path, line)
        for pat, correct in PATTERNS:
            if re.search(pat, lint_line, re.IGNORECASE):
                snippet = line.strip()[:140]
                out.append((lineno, snippet, f"{pat} -> {correct}"))
    return out


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return list of (lineno, snippet, pattern->correction) violations."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return _scan_text(path, text)


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


def _added_line_numbers(diff: str) -> set[int]:
    numbers: set[int] = set()
    new_lineno: int | None = None
    for line in diff.splitlines():
        hunk = UNIFIED_DIFF_HUNK_RE.match(line)
        if hunk:
            new_lineno = int(hunk.group("new_start"))
            continue
        if new_lineno is None or line.startswith("+++"):
            continue
        if line.startswith("+"):
            numbers.add(new_lineno)
            new_lineno += 1
        elif line.startswith(" "):
            new_lineno += 1
        elif line.startswith("-") or line.startswith("\\"):
            continue
    return numbers


def _scan_git_diff_file(
    path: Path,
    *,
    diff_args: list[str],
    content_spec: str,
) -> list[tuple[int, str, str]]:
    if _is_check_self_test_path(path) or path.suffix not in TEXT_EXTS:
        return []
    repo_root, relative = _repo_relative_path(path)
    diff_result = subprocess.run(
        [
            "git",
            "diff",
            "--unified=0",
            "--no-ext-diff",
            "--no-color",
            *diff_args,
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
    added = _added_line_numbers(diff_result.stdout)
    if not added:
        return []

    source_result = subprocess.run(
        ["git", "show", f"{content_spec}:{relative.as_posix()}"],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    if source_result.returncode != 0:
        raise RuntimeError(
            source_result.stderr.strip() or f"cannot read Git content for {path}"
        )
    return [
        violation
        for violation in _scan_text(path, source_result.stdout)
        if violation[0] in added
    ]


def scan_staged_file(path: Path) -> list[tuple[int, str, str]]:
    return _scan_git_diff_file(path, diff_args=["--cached"], content_spec="")


def scan_changed_file(path: Path, base_ref: str) -> list[tuple[int, str, str]]:
    return _scan_git_diff_file(
        path,
        diff_args=[base_ref, "HEAD"],
        content_spec="HEAD",
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
            if _is_check_self_test_path(p):
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
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--file", help="Lint a single file (absolute or relative path)")
    mode.add_argument("--staged-file", help="Lint only lines added in the Git index")
    mode.add_argument(
        "--changed-file", help="Lint only lines introduced from --base-ref to HEAD"
    )
    ap.add_argument("--base-ref", help="Git base ref for --changed-file mode")
    ap.add_argument(
        "--scope",
        nargs="*",
        default=["apps/mobile/lib", "services/backend/app", "tools"],
        help="Directories to scan (default: lib/app/tools)",
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
            print(f"accent_lint_fr: file not found: {target}", file=sys.stderr)
            return 1
        paths = [] if _is_check_self_test_path(target) else [target]
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
            print(f"accent_lint_fr: {exc}", file=sys.stderr)
            return 1
        for lineno, snippet, pat in violations:
            print(f"{path}:{lineno}: {snippet} ({pat})", file=sys.stderr)
            found += 1

    if found:
        print(f"accent_lint_fr: FAIL — {found} violation(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
