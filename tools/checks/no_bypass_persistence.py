#!/usr/bin/env python3
"""Reject direct SharedPreferences writes of MINT ledger keys.

Domain answers must be persisted through ReportPersistenceService. Other local
caches may still use SharedPreferences, but they must not write `q_*`,
`_coach_*`, `fp:*`, or `wizard_answers_v2` directly.

This is a lexical pre-commit guard, not a whole-program Dart analyzer. It
catches direct key literals and same-file key constants, which covers the
historic bypass pattern this gate is meant to stop.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCOPE = [ROOT / "apps/mobile/lib"]
ALLOWED_WRITERS = {
    ROOT / "apps/mobile/lib/services/report_persistence_service.dart",
}

WRITE_CALL = re.compile(r"\.set(?:String|Double|Int|Bool|StringList)\s*\(")
STRING_LITERAL = re.compile(r"""['"]([^'"]+)['"]""")
STRING_ASSIGNMENT = re.compile(
    r"""(?:static\s+)?(?:const|final)\s+String\s+([A-Za-z_]\w*)\s*=\s*['"]([^'"]+)['"]"""
)


def _is_domain_key(value: str) -> bool:
    return (
        value == "wizard_answers_v2"
        or value.startswith("q_")
        or value.startswith("_coach_")
        or value.startswith("fp:")
    )


def _collect_paths(inputs: list[str]) -> list[Path]:
    roots = [Path(item) for item in inputs] if inputs else DEFAULT_SCOPE
    paths: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        if root.is_file():
            if root.suffix == ".dart":
                paths.append(root)
            continue
        for path in root.rglob("*.dart"):
            if "/.dart_tool/" in path.as_posix() or "/build/" in path.as_posix():
                continue
            paths.append(path)
    return sorted({path.resolve() for path in paths})


def _constants(text: str) -> dict[str, str]:
    return {
        match.group(1): match.group(2)
        for match in STRING_ASSIGNMENT.finditer(text)
        if _is_domain_key(match.group(2))
    }


def _call_window(lines: list[str], index: int) -> str:
    window: list[str] = []
    for line in lines[index : min(index + 8, len(lines))]:
        window.append(line)
        if ");" in line:
            break
    return "\n".join(window)


def scan_file(path: Path) -> list[str]:
    if path.resolve() in ALLOWED_WRITERS:
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return []

    constants = _constants(text)
    violations: list[str] = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if not WRITE_CALL.search(line):
            continue
        window = _call_window(lines, index)
        direct_keys = {value for value in STRING_LITERAL.findall(window) if _is_domain_key(value)}
        constant_keys = {value for name, value in constants.items() if re.search(rf"\b{name}\b", window)}
        bad = sorted(direct_keys | constant_keys)
        if bad:
            try:
                rel = path.relative_to(ROOT)
            except ValueError:
                rel = path
            violations.append(f"{rel}:{index + 1} writes {', '.join(bad)}")
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        help="Optional Dart files/directories. Defaults to apps/mobile/lib.",
    )
    args = parser.parse_args()

    violations: list[str] = []
    for path in _collect_paths(args.paths):
        violations.extend(scan_file(path))

    if violations:
        print(
            "no_bypass_persistence: domain ledger keys must be persisted through "
            "ReportPersistenceService only.",
            file=sys.stderr,
        )
        for violation in violations:
            print(violation, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
