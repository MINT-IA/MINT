#!/usr/bin/env python3
"""CI drift guard for regional_microcopy.py — Phase 6 / REGIONAL-05.

Re-runs `tools/regional/regional_microcopy_codegen.py` and verifies the
committed `services/backend/app/services/coach/regional_microcopy.py`
matches its codegen output exactly. Exits non-zero on drift.

Run locally:
    python3 tools/checks/regional_microcopy_drift.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CODEGEN = REPO_ROOT / "tools" / "regional" / "regional_microcopy_codegen.py"
GENERATED = (
    REPO_ROOT
    / "services"
    / "backend"
    / "app"
    / "services"
    / "coach"
    / "regional_microcopy.py"
)


def main() -> int:
    if not GENERATED.exists():
        print(f"::error::{GENERATED} is missing", file=sys.stderr)
        return 2
    before = GENERATED.read_bytes()
    subprocess.run([sys.executable, str(CODEGEN)], check=True)
    after = GENERATED.read_bytes()
    if before != after:
        print(
            "::error::regional_microcopy.py drifted from codegen output. "
            "Run `python3 tools/regional/regional_microcopy_codegen.py` and commit.",
            file=sys.stderr,
        )
        # Restore committed version so the workspace stays clean if the
        # caller wants to re-run after fixing the codegen.
        GENERATED.write_bytes(before)
        return 1
    print("regional_microcopy.py is in sync with codegen ✔")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
