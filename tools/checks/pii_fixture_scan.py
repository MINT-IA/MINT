#!/usr/bin/env python3
"""Phase 95 D-14 — scan tests/fixtures/*.jsonl for PII patterns (AHV13 + Swiss phone).

Exit 1 on any match. Registered in lefthook pre-commit + CI.
Patterns sourced from RESEARCH.md §D-14:
- AHV13: \\b756\\.\\d{4}\\.\\d{4}\\.\\d{2}\\b
- Swiss phone: \\+41[\\s\\-]?\\d{2}[\\s\\-]?\\d{3}[\\s\\-]?\\d{2}[\\s\\-]?\\d{2}\\b
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

_AHV13 = re.compile(r"\b756\.\d{4}\.\d{4}\.\d{2}\b")
_SWISS_PHONE = re.compile(r"\+41[\s\-]?\d{2}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}\b")


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return [(line_no, pattern_name, match_text)] for every PII hit."""
    hits: list[tuple[int, str, str]] = []
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line_no, line in enumerate(f, start=1):
            for name, regex in (("AHV13", _AHV13), ("SWISS_PHONE", _SWISS_PHONE)):
                for m in regex.finditer(line):
                    hits.append((line_no, name, m.group(0)))
    return hits


def main(argv: list[str]) -> int:
    targets = [Path(p) for p in argv[1:]]
    if not targets:
        root = Path("services/backend/tests/fixtures")
        targets = list(root.rglob("*.jsonl"))
    exit_code = 0
    for path in targets:
        if not path.exists():
            continue
        hits = scan_file(path)
        for line_no, name, match in hits:
            print(f"{path}:{line_no}: PII pattern {name} matched: {match!r}", file=sys.stderr)
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
