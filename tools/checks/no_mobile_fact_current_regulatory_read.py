#!/usr/bin/env python3
"""Lint : Mobile MUST NOT read fact_current(subject_type='regulatory') directly.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 iter-2 B2 (architect-review).

Regulatory constants come from the codegen-baked
`regulatoryConstantsVersionHash` per Phase 01 D-08 + D-16. The Mobile L1
contract is offline-canonical : the mobile reads constants from compiled
Dart code, NOT from a server-side `fact_current` row. Bypassing the
codegen path breaks :

  - L1 offline-canonical (the mobile loses the ability to compute L1
    chiffrer offline if it depends on a network-side fact_current read).
  - L1/L2 boundary discipline (regulatory constants are L1 substrate ;
    Plan 02-03+ L2 / L3 / L4 surfaces consume them via the L1 calc-engine,
    NEVER via a direct projection-row read).

This lint is a HARD lefthook on `apps/mobile/lib/**/*.dart`. Any pattern
matching `fact_current.*subject_type.*['"]regulatory['"]` (case-insensitive)
in a Dart file exits 1 with a clear remediation message.

Usage :
    python3 tools/checks/no_mobile_fact_current_regulatory_read.py [path1 path2 ...]

If no args : scans `apps/mobile/lib/` recursively. Self-exempts test
fixtures in `apps/mobile/test/_fixtures/`.

Exit codes :
    0 — clean
    1 — at least one violation found
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable, List


_FORBIDDEN_RE = re.compile(
    r"fact_current.*subject_type.*['\"]regulatory['\"]",
    flags=re.IGNORECASE | re.DOTALL,
)
_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
_DEFAULT_SCOPE = _REPO_ROOT / "apps" / "mobile" / "lib"
_SELF_EXEMPT_PATHS = (
    "apps/mobile/test/_fixtures/",  # bad-fixture for the lint's own tests
    "tools/checks/no_mobile_fact_current_regulatory_read.py",  # self
    "tools/checks/tests/test_no_mobile_fact_current_regulatory_read.py",  # test
)


def _is_self_exempt(path: Path) -> bool:
    try:
        rel = path.relative_to(_REPO_ROOT)
    except ValueError:
        return False
    rel_str = rel.as_posix()
    return any(rel_str.startswith(prefix) or rel_str == prefix.rstrip("/") for prefix in _SELF_EXEMPT_PATHS)


def _scan_file(path: Path) -> list[tuple[int, str]]:
    """Return list of (line_number, line_content) violations for `path`."""
    if _is_self_exempt(path):
        return []
    try:
        content = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, FileNotFoundError):
        return []
    violations: list[tuple[int, str]] = []
    for lineno, line in enumerate(content.splitlines(), 1):
        if _FORBIDDEN_RE.search(line):
            violations.append((lineno, line.strip()))
    return violations


def _expand_paths(args: Iterable[str]) -> List[Path]:
    """Materialise the list of files to scan from the CLI args."""
    if not args:
        # Default scope : recursively scan apps/mobile/lib/**/*.dart
        if _DEFAULT_SCOPE.exists():
            return sorted(_DEFAULT_SCOPE.rglob("*.dart"))
        return []
    out: List[Path] = []
    for a in args:
        p = Path(a)
        if not p.is_absolute():
            p = _REPO_ROOT / a
        if p.is_dir():
            out.extend(sorted(p.rglob("*.dart")))
        elif p.is_file():
            out.append(p)
        # else : skip non-existent paths silently (lefthook passes staged
        # paths ; if a path was deleted in the diff we should not error).
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Lint : Mobile MUST NOT read fact_current(subject_type='regulatory') directly (iter-2 B2).",
    )
    parser.add_argument("paths", nargs="*", help="Dart files or directories to scan")
    args = parser.parse_args(argv)

    files = _expand_paths(args.paths)
    if not files:
        print("OK no_mobile_fact_current_regulatory_read: no Dart files in scope")
        return 0

    found = 0
    for path in files:
        for lineno, line in _scan_file(path):
            try:
                rel = path.relative_to(_REPO_ROOT)
                location = rel.as_posix()
            except ValueError:
                location = str(path)
            print(
                f"FAIL no_mobile_fact_current_regulatory_read: "
                f"{location}:{lineno} : {line}"
            )
            found += 1

    if found:
        print(
            f"\n{found} violation(s) found. "
            f"Mobile MUST NOT read fact_current(subject_type='regulatory') directly. "
            f"Regulatory constants come from codegen-baked "
            f"`regulatoryConstantsVersionHash` per Phase 01 D-08 + D-16. "
            f"Bypassing codegen breaks L1 offline-canonical and L1/L2 boundary "
            f"discipline (iter-2 B2 architect-review)."
        )
        return 1

    print(f"OK no_mobile_fact_current_regulatory_read: scanned {len(files)} Dart file(s), clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
