#!/usr/bin/env python3
"""Incremental LSFin banned-term gate for ARB additions.

The repo has historical ARB debt. This pre-commit gate therefore blocks new
user-facing ARB lines that introduce banned promise/prescription vocabulary,
while allowing explicit anti-promise wording such as "not guaranteed".
"""

from __future__ import annotations

import re
import sys

from _staged_diff import AddedLine, staged_added_lines


BANNED = [
    r"\bgaranti(?:e|s|es)?\b",
    r"\bgarantissant\b",
    r"\bguaranteed\b",
    r"\bgarantiert(?:e|er|es|en)?\b",
    r"\bgarantizado(?:a|s)?\b",
    r"\bgarantito(?:a|i|e)?\b",
    r"\bgarantido(?:a|s)?\b",
    r"\boptimal(?:e|s|es|aux)?\b",
    r"\bmeilleur(?:e|s|es)?\b",
    r"\bparfait(?:e|s|es)?\b",
    r"\bsans risque\b",
    r"\bconseill(?:er|ère|ers|ères)\b",
    r"\bla meilleure option\b",
    r"\bnous recommandons\b",
    r"\bnous te conseillons\b",
    r"\btu devrais\b",
    r"\btu dois\b",
]

NEGATED_GUARANTEE = [
    r"\b(?:non|pas|jamais|sans)\s+garanti(?:e|s|es)?\b",
    r"\bpas\s+de\s+garantie\b",
    r"\bsans\s+garantie\b",
    r"\brien\s+n['’]est\s+garanti(?:e|s|es)?\b",
    r"\bnot\s+guaranteed\b",
    r"\bno\s+guarantee(?:d)?\b",
    r"\bdoes\s+not\s+guarantee\b",
    r"\bnicht\s+garantiert\b",
    r"\bohne\s+garantie\b",
    r"\bsin\s+garant[ií]a\b",
    r"\bno\s+garantizado\b",
    r"\bnon\s+garantito\b",
    r"\bsem\s+garantia\b",
]


def _scan_text(text: str) -> list[str]:
    scan = text
    for pattern in NEGATED_GUARANTEE:
        scan = re.sub(pattern, "", scan, flags=re.IGNORECASE)
    return [
        pattern
        for pattern in BANNED
        if re.search(pattern, scan, flags=re.IGNORECASE)
    ]


def _is_user_facing_arb_line(line: AddedLine) -> bool:
    stripped = line.text.lstrip()
    return (
        line.path.endswith(".arb")
        and not stripped.startswith('"@')
        and '":' in stripped
    )


def main() -> int:
    violations: list[tuple[AddedLine, list[str]]] = []
    for line in staged_added_lines("apps/mobile/lib/l10n/*.arb"):
        if not _is_user_facing_arb_line(line):
            continue
        found = _scan_text(line.text)
        if found:
            violations.append((line, found))

    if not violations:
        print("banned_terms_arb: OK — no new ARB banned terms")
        return 0

    print(
        f"banned_terms_arb: FAIL — {len(violations)} staged ARB line(s) introduce banned terms",
        file=sys.stderr,
    )
    for line, found in violations:
        loc = f"{line.path}:{line.line_no or '?'}"
        print(f"  {loc}: {line.text.strip()} ({', '.join(found)})", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
