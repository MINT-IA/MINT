#!/usr/bin/env python3
"""Guard runtime budget reads while MINT migrates to Data Spine.

Screens/widgets should not add fresh `BudgetInputs.fromMap` or direct
`BudgetService().computePlan` usage. The current legacy sites are explicitly
allowlisted until Phases 64-66 remove them.
"""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCAN_ROOTS = (
    ROOT / "apps/mobile/lib/screens",
    ROOT / "apps/mobile/lib/widgets",
    ROOT / "apps/mobile/lib/services",
)
PATTERNS = (
    "BudgetInputs.fromMap",
    "BudgetService().computePlan",
)

ALLOWLIST = {
    "apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart": (
        "Phase 62 legacy report fallback until Rapport reads Data Spine only.",
    ),
    "apps/mobile/lib/services/report/report_builder.dart": (
        "Legacy local report builder until SessionReport is Data Spine-backed.",
    ),
    "apps/mobile/lib/services/financial_fitness_service.dart": (
        "Legacy service-level budget scoring, not a screen/widget caller.",
    ),
    "apps/mobile/lib/services/micro_action_engine.dart": (
        "Legacy service-level micro action scoring, not a screen/widget caller.",
    ),
}


def _relative(path: pathlib.Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> int:
    violations: list[str] = []
    checked = 0
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*.dart"):
            rel = _relative(path)
            text = path.read_text(encoding="utf-8")
            hits = [pattern for pattern in PATTERNS if pattern in text]
            if not hits:
                continue
            checked += 1
            if rel in ALLOWLIST:
                continue
            line_numbers = []
            for index, line in enumerate(text.splitlines(), start=1):
                if any(pattern in line for pattern in PATTERNS):
                    line_numbers.append(str(index))
            violations.append(f"{rel}:{','.join(line_numbers)} uses {hits}")

    if violations:
        print("budget_read_contract: FAIL")
        for violation in violations:
            print(f"  - {violation}")
        print("Use DataSpineSnapshot.budget / BudgetSnapshot.present or add a")
        print("temporary allowlist entry with a removal phase.")
        return 1

    print(
        "budget_read_contract: OK "
        f"({checked} legacy budget read files explicitly allowlisted)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
