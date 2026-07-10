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
import subprocess
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
ROUTE_OR_URL_LITERAL_RE = re.compile(
    r"""(?P<quote>['"])(?:[a-z][a-z0-9+.-]*:)?/{1,3}[^'"\s]*(?P=quote)""",
    re.IGNORECASE,
)
NON_FRENCH_GENERATED_L10N_RE = re.compile(
    r"^app_localizations_(?!fr\b)[a-z]{2}\.dart$"
)


def _is_excluded(path: Path) -> bool:
    rel = "/" + path.as_posix() + "/"
    return any(ex in rel for ex in EXCLUDE_SUBSTRINGS)


def _line_for_lint(path: Path, line: str) -> str:
    lint_line = line
    if path.suffix == ".md":
        lint_line = re.sub(r"`[^`]*`", "", lint_line)
    if path.suffix == ".dart":
        lint_line = ROUTE_OR_URL_LITERAL_RE.sub("", lint_line)
    return lint_line


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return list of (lineno, snippet, pattern->correction) violations."""
    if path.name == "accent_lint_fr.py":
        return []
    if path.suffix == ".arb" and path.name != "app_fr.arb":
        return []
    if NON_FRENCH_GENERATED_L10N_RE.match(path.name):
        return []
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return scan_lines(path, list(enumerate(text.splitlines(), start=1)))


def scan_lines(path: Path, lines: list[tuple[int, str]]) -> list[tuple[int, str, str]]:
    """Return violations for a preselected set of numbered lines."""
    out: list[tuple[int, str, str]] = []
    for lineno, line in lines:
        lint_line = _line_for_lint(path, line)
        for pat, correct in PATTERNS:
            if re.search(pat, lint_line, re.IGNORECASE):
                snippet = line.strip()[:140]
                out.append((lineno, snippet, f"{pat} -> {correct}"))
    return out


def _clean_git_path(path: str) -> str:
    return path.removeprefix("a/").removeprefix("b/").replace("\\", "/")


def _git_diff(args: list[str]) -> str:
    result = subprocess.run(
        ["git", "diff", "--unified=0", "--no-ext-diff", *args],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        print(result.stderr.strip(), file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


def _added_lines(diff: str) -> dict[Path, list[tuple[int, str]]]:
    out: dict[Path, list[tuple[int, str]]] = {}
    path: Path | None = None
    line_no: int | None = None
    for raw in diff.splitlines():
        if raw.startswith("diff --git "):
            path = None
            line_no = None
        elif raw.startswith("+++ "):
            marker = raw[4:].strip()
            path = None if marker == "/dev/null" else Path(_clean_git_path(marker))
        elif raw.startswith("@@ "):
            match = re.search(r"\+(\d+)", raw)
            line_no = int(match.group(1)) if match else None
        elif line_no is None:
            continue
        elif raw.startswith("+") and not raw.startswith("+++"):
            if (
                path is not None
                and path.suffix in TEXT_EXTS
                and not _is_excluded(path)
            ):
                out.setdefault(path, []).append((line_no, raw[1:]))
            line_no += 1
        elif not (raw.startswith("-") and not raw.startswith("---")):
            line_no += 1
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
            if _is_excluded(p):
                continue
            paths.append(p)
    return paths


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Early-ship FR accent lint — scans for ASCII-flattened French words"
    )
    ap.add_argument("--file", help="Lint a single file (absolute or relative path)")
    ap.add_argument("--staged", action="store_true", help="Lint added staged lines only")
    ap.add_argument("--base-ref", help="Lint added lines from BASE_REF...HEAD")
    ap.add_argument(
        "--scope",
        nargs="*",
        default=["apps/mobile/lib", "services/backend/app", "tools"],
        help="Directories to scan (default: lib/app/tools)",
    )
    args = ap.parse_args()
    if sum(bool(v) for v in (args.file, args.staged, args.base_ref)) > 1:
        ap.error("use only one of --file, --staged, or --base-ref")

    if args.staged or args.base_ref:
        diff = _git_diff(["--cached"] if args.staged else [f"{args.base_ref}...HEAD"])
        paths = _added_lines(diff)
        found = 0
        for path, lines in paths.items():
            for lineno, snippet, kind in scan_lines(path, lines):
                print(f"{path}:{lineno}: {snippet} ({kind})", file=sys.stderr)
                found += 1
        if found:
            print(f"accent_lint_fr: FAIL — {found} violation(s)", file=sys.stderr)
            return 1
        return 0

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
