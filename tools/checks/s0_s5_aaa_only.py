#!/usr/bin/env python3
"""S0-S5 AAA-only token gate (Phase 8b Plan 01 / AESTH-05, AESTH-06, ACCESS-04).

Enforces D-03 swap map + D-04 one-color-one-meaning on the 6 frozen S0-S5
source files. Any occurrence of a legacy semantic/secondary token
(`MintColors.textSecondary`, `textMuted`, `success`, `warning`, `error`,
`info` — NOT their `*Aaa` counterparts) is a hard failure.

Background-only pastels (`saugeClaire`, `bleuAir`, `pecheDouce`,
`corailDiscret`, `porcelaine`) are NOT checked here — they remain legal
as surface fills per D-03.

Task 1 scaffold: this script is expected to FAIL initially (RED). After
Task 2 swaps land, it must return exit 0 (GREEN).

Exit 0 on pass, exit 1 with line diagnostic on fail.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

S0_S5_FILES = [
    "apps/mobile/lib/screens/landing_screen.dart",
    "apps/mobile/lib/screens/onboarding/intent_screen.dart",
    "apps/mobile/lib/screens/main_tabs/mint_home_screen.dart",
    "apps/mobile/lib/widgets/coach/coach_message_bubble.dart",
    "apps/mobile/lib/widgets/coach/response_card_widget.dart",
    "apps/mobile/lib/widgets/report/debt_alert_banner.dart",
]

# Matches MintColors.<legacyToken> where <legacyToken> is NOT suffixed by "Aaa"
# and is immediately followed by a non-identifier character (boundary).
LEGACY_RE = re.compile(
    r"MintColors\.(textSecondary|textMuted|success|warning|error|info)(?![A-Za-z0-9_])"
)


def main() -> int:
    failures: list[str] = []
    for rel in S0_S5_FILES:
        target = REPO / rel
        if not target.exists():
            print(f"::error::s0_s5_aaa_only: file not found: {rel}")
            return 1
        for i, line in enumerate(target.read_text(encoding="utf-8").splitlines(), start=1):
            for m in LEGACY_RE.finditer(line):
                token = m.group(1)
                failures.append(
                    f"{rel}:{i}: legacy token 'MintColors.{token}' — "
                    f"migrate to 'MintColors.{token}Aaa' "
                    f"(or neutralize per D-04 one-color-one-meaning)"
                )

    if failures:
        print("::error::s0_s5_aaa_only gate failed "
              f"({len(failures)} legacy token occurrences):")
        for f in failures:
            print(f)
        return 1

    print(f"OK s0_s5_aaa_only: {len(S0_S5_FILES)} files clean of legacy tokens")
    return 0


if __name__ == "__main__":
    sys.exit(main())
