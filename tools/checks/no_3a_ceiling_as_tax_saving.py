#!/usr/bin/env python3
"""Block new ARB copy that labels 3a legal ceilings as tax savings."""

from __future__ import annotations

import re
import sys

from _staged_diff import AddedLine, staged_added_lines


CEILING = re.compile(
    r"(?:CHF\s*)?(?:7[\s'’  ]?258|7258|36[\s'’  ]?288|36288)",
    re.IGNORECASE,
)
SAVING = re.compile(
    r"("
    r"économ(?:ie|ies|iser|ise|isé)|gain fiscal|avantage fiscal chiffré|"
    r"tax saving|tax savings|tax saved|save[s]? you|"
    r"steuer(?:ersparnis| sparen)|"
    r"ahorro fiscal|ahorros fiscales|"
    r"risparmio fiscale|"
    r"poupança fiscal"
    r")",
    re.IGNORECASE,
)


def _is_user_facing_arb_line(line: AddedLine) -> bool:
    stripped = line.text.lstrip()
    return (
        line.path.endswith(".arb")
        and not stripped.startswith('"@')
        and '":' in stripped
    )


def main() -> int:
    violations: list[AddedLine] = []
    for line in staged_added_lines("apps/mobile/lib/l10n/*.arb"):
        if not _is_user_facing_arb_line(line):
            continue
        if CEILING.search(line.text) and SAVING.search(line.text):
            violations.append(line)

    if not violations:
        print("no_3a_ceiling_as_tax_saving: OK — no new ceiling-as-saving copy")
        return 0

    print(
        f"no_3a_ceiling_as_tax_saving: FAIL — {len(violations)} staged ARB line(s)",
        file=sys.stderr,
    )
    for line in violations:
        loc = f"{line.path}:{line.line_no or '?'}"
        print(f"  {loc}: {line.text.strip()}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
