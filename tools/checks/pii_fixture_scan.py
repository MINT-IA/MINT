#!/usr/bin/env python3
"""Phase 95 D-14 + Phase 96 D-12 — scan fixtures for PII patterns.

Exit 1 on any match. Registered in lefthook pre-commit + CI.

Phase 95 D-14 patterns (raw text scan, any *.jsonl) :
- AHV13: \\b756\\.\\d{4}\\.\\d{4}\\.\\d{2}\\b
- Swiss phone: \\+41[\\s\\-]?\\d{2}[\\s\\-]?\\d{3}[\\s\\-]?\\d{2}[\\s\\-]?\\d{2}\\b

Phase 96 D-12 extension (structural scan, applies to *.jsonl AND *.json
when a SerializedCardContext appears at a top-level field
`source_card` / `sourceCard` and to direct shapes carrying a
`computed_facts` / `computedFacts` dict at any nesting depth) :
- Banned keys inside `computed_facts` (case-insensitive substring match) :
  email, phone, ahv, iban, npa, employer, name, surname, address.

Threat model anchor : T-96-W2-PIISmuggling — the SerializedCardContext
schema's `extra="forbid"` blocks unknown top-level keys ; this lint
provides a complementary defense for the dict-value surface (the only
surface where free-form keys are accepted by design).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable, List, Tuple

_AHV13 = re.compile(r"\b756\.\d{4}\.\d{4}\.\d{2}\b")
_SWISS_PHONE = re.compile(r"\+41[\s\-]?\d{2}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}\b")

# Phase 96 D-12 — banned key substrings inside SerializedCardContext.computed_facts.
# Case-insensitive substring match : « contactEmail », « user_email », « emailAddr »
# all flag, while neutral keys like « employmentRate » trip on « employ » only if
# the explicit prefix « employer » appears (we keep the substrings tight enough
# to avoid false positives — « employmentRate » contains « employm » not
# « employer »).
_COMPUTED_FACTS_BANNED_KEYS = (
    "email",
    "phone",
    "ahv",
    "iban",
    "npa",
    "employer",
    "name",
    "surname",
    "address",
)

# Keys at which a SerializedCardContext.computed_facts mapping may live.
_COMPUTED_FACTS_KEYS = ("computed_facts", "computedFacts")


def scan_file(path: Path) -> List[Tuple[int, str, str]]:
    """Return [(line_no, pattern_name, match_text)] for every PII hit."""
    hits: List[Tuple[int, str, str]] = []
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line_no, line in enumerate(f, start=1):
            # Phase 95 D-14 raw-text scan.
            for name, regex in (("AHV13", _AHV13), ("SWISS_PHONE", _SWISS_PHONE)):
                for m in regex.finditer(line):
                    hits.append((line_no, name, m.group(0)))
            # Phase 96 D-12 structural scan — parse the JSON line if possible
            # (JSONL convention : 1 JSON value per line). Fixtures that are
            # not JSONL but plain JSON are handled below in scan_json_file.
            line_stripped = line.strip()
            if not line_stripped or line_stripped[0] not in "{[":
                continue
            try:
                obj = json.loads(line_stripped)
            except json.JSONDecodeError:
                continue
            for banned_key in _walk_computed_facts(obj):
                hits.append((line_no, "COMPUTED_FACTS_BANNED_KEY", banned_key))
    return hits


def scan_json_file(path: Path) -> List[Tuple[int, str, str]]:
    """Phase 96 D-12 — scan a whole-file JSON document for banned keys."""
    hits: List[Tuple[int, str, str]] = []
    try:
        with path.open("r", encoding="utf-8", errors="replace") as f:
            obj = json.load(f)
    except (json.JSONDecodeError, OSError):
        return hits
    for banned_key in _walk_computed_facts(obj):
        # Whole-file scan reports line 1 (the document anchor).
        hits.append((1, "COMPUTED_FACTS_BANNED_KEY", banned_key))
    return hits


def _walk_computed_facts(obj: Any) -> Iterable[str]:
    """Yield banned keys found inside any `computed_facts` mapping.

    Recursively walks the JSON tree (lists + dicts). When a
    `computed_facts` / `computedFacts` key is hit, its dict value is
    inspected against the banned-key substring list.
    """
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in _COMPUTED_FACTS_KEYS and isinstance(value, dict):
                for facts_key in value.keys():
                    lowered = facts_key.lower()
                    for banned in _COMPUTED_FACTS_BANNED_KEYS:
                        if banned in lowered:
                            yield f"{key}.{facts_key}"
                            break
            # Recurse regardless — nested structures may also carry
            # computed_facts (e.g. inside a list of card contexts).
            yield from _walk_computed_facts(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from _walk_computed_facts(item)


def main(argv: List[str]) -> int:
    targets = [Path(p) for p in argv[1:]]
    if not targets:
        root = Path("services/backend/tests/fixtures")
        targets = list(root.rglob("*.jsonl"))
    exit_code = 0
    for path in targets:
        if not path.exists():
            continue
        if path.suffix == ".json":
            hits = scan_json_file(path)
        else:
            hits = scan_file(path)
        for line_no, name, match in hits:
            print(f"{path}:{line_no}: PII pattern {name} matched: {match!r}", file=sys.stderr)
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
