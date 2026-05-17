#!/usr/bin/env python3
"""no_stale_regulatory_anchors.py — Fix D / obs #157.

Lint that prevents future toxic few-shot examples or hardcoded stale
regulatory values from leaking into LLM-injected prompt text. Scans
Python string literals (NOT comments) in `services/backend/app/services/
coach/` for any integer that matches a stale-year entry in the
regulatory registry (e.g. 2024 plafond 3a = 7'056 CHF — stale since 2025).

Rationale (from obs #157 root-cause analysis 2026-05-17) :
    A « REJETÉ » example string in `citation_grammar.py:564` contained
    the literal value `7'056 CHF cette année` — the 2024 OFAS 3a max.
    Even though the example was negative (« here's what NOT to do »),
    the LLM leaked it back as positive when surface form matched the
    user query. This lint blocks the class of bug at commit time.

Algorithm :
    1. Import `_PARAMETERS` from `app.services.regulatory.registry`.
    2. Build STALE_VALUES = {int(p.value) for p in _PARAMETERS where
       key matches `*.historical_limits.<year>` AND the value is NOT
       also present in any canonical (non-historical) key}.
    3. For each target .py file, parse to AST.
    4. Walk all `ast.Constant(value=str)` nodes (string literals — this
       intentionally excludes Python comments, which are not in the
       AST tree). Module docstrings ARE included.
    5. For each string literal, regex-scan for any stale value in any
       thousand-separator format (Swiss apostrophe, French space,
       narrow NBSP, anglo comma, no separator).
    6. Skip files in the allow-list (see ALLOWED_FILES below).
    7. Exit 1 with a structured report if any violation found ;
       exit 0 otherwise.

Allow-list rationale :
    - `registry.py` IS the registry — historical values legitimately
      live there as data ; that's the canonical store.
    - `retroactive_3a_service.py` has a per-year dict mapping
      historical limits ; required for the « rattrapage 3a » feature.
    - Test files need to assert against stale values to verify the
      runtime freshness gate works ; can't lint them or they'd block.
    - Files with a top-level `# noqa: stale-regulatory-anchors`
      comment as the FIRST non-shebang line are opted out (escape
      hatch for future legitimate cases — must be justified in PR).

Usage :
    # default scope = services/backend/app/services/coach/
    python3 tools/checks/no_stale_regulatory_anchors.py

    # specific files
    python3 tools/checks/no_stale_regulatory_anchors.py path/to/file.py ...

    # verbose (show STALE_VALUES set)
    python3 tools/checks/no_stale_regulatory_anchors.py --verbose

Lefthook integration : add a pre-commit step targeting
`services/backend/app/services/coach/**/*.py`.
"""
from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path


# Files exempted from this lint (legit historical values, or test
# fixtures that need to assert against stale values).
ALLOWED_FILES: set[str] = {
    "services/backend/app/services/regulatory/registry.py",
    "services/backend/app/services/pillar_3a_deep/retroactive_3a_service.py",
}

# Per-file opt-out comment (must be first non-shebang line).
OPT_OUT_MARKER: str = "# noqa: stale-regulatory-anchors"

# Default scope when no file paths are passed on CLI.
DEFAULT_SCOPE: tuple[str, ...] = (
    "services/backend/app/services/coach/",
)


def _repo_root() -> Path:
    """Return repo root assuming this file lives at tools/checks/."""
    return Path(__file__).resolve().parents[2]


def _import_stale_set() -> frozenset[int]:
    """Reuse runtime_freshness_gate's stale-set derivation.

    Importing the runtime gate keeps a single source of truth for the
    derivation algorithm. If the gate's logic changes, this lint
    automatically follows.
    """
    sys.path.insert(0, str(_repo_root() / "services" / "backend"))
    try:
        from app.services.coach.runtime_freshness_gate import (  # noqa: E402
            _build_stale_value_set,
        )
    finally:
        sys.path.pop(0)
    return _build_stale_value_set()


def _build_pattern(stale_values: frozenset[int]) -> re.Pattern[str]:
    """Build a single regex matching any stale value in any format.

    Formats covered :
        - bare integer : `7056`
        - Swiss apostrophe : `7'056`
        - French regular space : `7 056`
        - French NBSP / narrow NBSP : `7 056` (U+00A0), `7 056` (U+202F)
        - anglo comma : `7,056`

    Word boundaries on both sides prevent matching `27056` or `70560`.
    """
    alternatives: list[str] = []
    for v in sorted(stale_values):
        s = str(v)
        # No separator : exact integer.
        alternatives.append(re.escape(s))
        # Thousand-separated variants. For each separator class, insert
        # the separator before each group of 3 trailing digits.
        if len(s) > 3:
            grouped = s[:-3] + s[-3:]  # split tail
            # Sep class : Swiss apostrophe, regular space, NBSP, narrow NBSP, comma.
            sep_class = "['   ,]"
            with_sep = re.escape(s[:-3]) + sep_class + re.escape(s[-3:])
            alternatives.append(with_sep)
    pattern_str = r"(?<![\d])(?:" + "|".join(alternatives) + r")(?![\d])"
    return re.compile(pattern_str)


def _is_opted_out(file_path: Path) -> bool:
    """File opted out via top-line marker comment."""
    try:
        with file_path.open("r", encoding="utf-8") as f:
            for line in f:
                stripped = line.strip()
                if not stripped or stripped.startswith("#!"):
                    continue
                return OPT_OUT_MARKER in stripped
    except OSError:
        return False
    return False


def _is_allowed(file_path: Path, repo_root: Path) -> bool:
    """Check file against allow-list (relative-path match)."""
    try:
        rel = file_path.resolve().relative_to(repo_root)
    except ValueError:
        return False
    return str(rel) in ALLOWED_FILES


def _scan_file(
    file_path: Path,
    pattern: re.Pattern[str],
    repo_root: Path,
) -> list[tuple[int, str, str]]:
    """Return list of (line_no, matched_value, string_literal_snippet)."""
    if _is_allowed(file_path, repo_root):
        return []
    if _is_opted_out(file_path):
        return []

    try:
        with file_path.open("r", encoding="utf-8") as f:
            source = f.read()
    except OSError:
        return []

    try:
        tree = ast.parse(source, filename=str(file_path))
    except SyntaxError:
        return []

    findings: list[tuple[int, str, str]] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Constant) or not isinstance(node.value, str):
            continue
        s: str = node.value
        for m in pattern.finditer(s):
            line_no = getattr(node, "lineno", 0)
            snippet = s[max(0, m.start() - 30) : m.end() + 30]
            snippet = snippet.replace("\n", "\\n")
            findings.append((line_no, m.group(0), snippet))
    return findings


def _resolve_targets(cli_paths: list[str], repo_root: Path) -> list[Path]:
    """Expand CLI args (or DEFAULT_SCOPE) to a list of .py files.

    Test files are auto-excluded — tests legitimately assert against
    stale values to verify the runtime gate works. They are NEVER
    injected into LLM prompts.
    """
    if not cli_paths:
        candidates: list[Path] = []
        for scope in DEFAULT_SCOPE:
            base = repo_root / scope
            if base.is_dir():
                candidates.extend(base.rglob("*.py"))
    else:
        candidates = []
        for p in cli_paths:
            path = Path(p)
            if not path.is_absolute():
                path = repo_root / path
            if path.is_dir():
                candidates.extend(path.rglob("*.py"))
            elif path.is_file() and path.suffix == ".py":
                candidates.append(path)

    return [
        c
        for c in candidates
        if "tests" not in c.parts and "test_" not in c.name
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        help=f"Files or directories to scan (default: {DEFAULT_SCOPE})",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print the STALE_VALUES set before scanning",
    )
    args = parser.parse_args()

    repo_root = _repo_root()
    stale_set = _import_stale_set()
    if args.verbose:
        print(f"[no_stale_regulatory_anchors] stale set ({len(stale_set)}): "
              f"{sorted(stale_set)}")

    if not stale_set:
        print("[no_stale_regulatory_anchors] empty stale set ; skipping.")
        return 0

    pattern = _build_pattern(stale_set)
    targets = _resolve_targets(args.paths, repo_root)

    total_violations = 0
    for file_path in targets:
        findings = _scan_file(file_path, pattern, repo_root)
        if not findings:
            continue
        try:
            rel = file_path.resolve().relative_to(repo_root)
        except ValueError:
            rel = file_path.resolve()
        for line_no, matched, snippet in findings:
            total_violations += 1
            print(
                f"{rel}:{line_no}: stale regulatory value `{matched}` "
                f"in string literal ... « {snippet} » ..."
            )

    if total_violations:
        print(
            f"\n[no_stale_regulatory_anchors] {total_violations} violation(s) "
            f"across {len(targets)} scanned file(s).\n"
            "Fix : either replace the literal value with a placeholder "
            "(e.g. `N CHF`), use a current-year value, OR if legitimate "
            f"(historical record), add `{OPT_OUT_MARKER}` as the first "
            "non-shebang line of the file and justify in the PR description."
        )
        return 1

    print(
        f"[no_stale_regulatory_anchors] OK — {len(targets)} file(s) scanned, "
        f"0 stale regulatory-value leaks found in LLM-injected string "
        f"literals."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
