#!/usr/bin/env python3
"""Block Flutter debug local-network plist keys from Release/Profile builds."""
from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RUNNER_DIR = REPO / "apps" / "mobile" / "ios" / "Runner"
PROJECT = REPO / "apps" / "mobile" / "ios" / "Runner.xcodeproj" / "project.pbxproj"
RELEASE_PLIST = RUNNER_DIR / "Info.plist"
DEBUG_PLIST = RUNNER_DIR / "Info-Debug.plist"
DEBUG_ONLY_KEYS = {
    "NSBonjourServices",
    "NSLocalNetworkUsageDescription",
}


def _load(path: Path) -> dict[str, object]:
    with path.open("rb") as fh:
        return plistlib.load(fh)


def _error(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)


def main() -> int:
    failures: list[str] = []

    if not RELEASE_PLIST.exists():
        failures.append(f"{RELEASE_PLIST} is missing")
    else:
        release_data = _load(RELEASE_PLIST)
        leaked = sorted(DEBUG_ONLY_KEYS & release_data.keys())
        if leaked:
            failures.append(
                f"{RELEASE_PLIST} contains debug-only local-network key(s): "
                + ", ".join(leaked)
            )

    if not DEBUG_PLIST.exists():
        failures.append(f"{DEBUG_PLIST} is missing")
    else:
        debug_data = _load(DEBUG_PLIST)
        missing = sorted(DEBUG_ONLY_KEYS - debug_data.keys())
        if missing:
            failures.append(
                f"{DEBUG_PLIST} is missing debug local-network key(s): "
                + ", ".join(missing)
            )

    project_text = PROJECT.read_text(encoding="utf-8", errors="ignore")
    if 'INFOPLIST_FILE = "Runner/Info-Debug.plist";' not in project_text:
        failures.append("Runner Debug build is not wired to Runner/Info-Debug.plist")

    release_refs = re.findall(r"INFOPLIST_FILE = Runner/Info\.plist;", project_text)
    if len(release_refs) < 2:
        failures.append("Runner Release/Profile builds are not both wired to Runner/Info.plist")

    for failure in failures:
        _error(failure)

    if failures:
        return 1

    print("[OK] iOS release Info.plist excludes Flutter debug local-network keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
