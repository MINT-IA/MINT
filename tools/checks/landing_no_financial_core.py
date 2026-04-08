#!/usr/bin/env python3
"""Landing no-financial-core gate (Phase 7 / LAND-01, CONTEXT D-11).

Fails if `apps/mobile/lib/screens/landing_screen.dart` imports anything from
`financial_core`, `services/`, `providers/`, or `models/profile`. The landing
is a stateless promise surface with zero domain coupling.

Allowed imports (whitelist):
  - package:flutter/…
  - package:go_router/…
  - package:mint_mobile/l10n/app_localizations.dart
  - package:mint_mobile/theme/colors.dart

Any import NOT matching the whitelist is reported as a hard failure.

Exit 0 on pass, exit 1 with line diagnostic on fail.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TARGET = REPO / "apps" / "mobile" / "lib" / "screens" / "landing_screen.dart"

WHITELIST = (
    "package:flutter/",
    "package:go_router/",
    "package:mint_mobile/l10n/app_localizations.dart",
    "package:mint_mobile/theme/colors.dart",
)

FORBIDDEN_SUBSTRINGS = (
    "financial_core",
    "mint_mobile/services/",
    "mint_mobile/providers/",
    "mint_mobile/models/profile",
    "mint_mobile/constants/social_insurance",
)

IMPORT_RE = re.compile(r"""^\s*import\s+['"]([^'"]+)['"]""")


def main() -> int:
    if not TARGET.exists():
        print(f"::error::landing_no_financial_core: target not found: {TARGET}")
        return 1

    failures: list[str] = []
    for i, line in enumerate(TARGET.read_text(encoding="utf-8").splitlines(), start=1):
        m = IMPORT_RE.match(line)
        if not m:
            continue
        uri = m.group(1)
        # Hard-forbidden substrings
        for bad in FORBIDDEN_SUBSTRINGS:
            if bad in uri:
                failures.append(
                    f"{TARGET.relative_to(REPO)}:{i}: forbidden import '{uri}' (contains '{bad}')"
                )
                break
        else:
            if not any(uri.startswith(w) or uri == w for w in WHITELIST):
                failures.append(
                    f"{TARGET.relative_to(REPO)}:{i}: non-whitelisted import '{uri}'"
                )

    if failures:
        print("::error::landing_no_financial_core gate failed:")
        for f in failures:
            print(f)
        return 1

    print(f"OK landing_no_financial_core: {TARGET.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
