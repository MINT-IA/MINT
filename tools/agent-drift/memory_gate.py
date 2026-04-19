#!/usr/bin/env python3
"""CTX-01 memory_gate — thin wrapper around tools/checks/memory_retention.py.

Delegates to the single source of truth so dashboard, lefthook, and manual
invocation all converge on the same retention semantics.

VALIDATION.md row 30.5-02-02 calls this CLI directly. Per Plan 30.5-02 Task 2
§action step 3, the Wave 0 skeleton is replaced by this thin shim.

Usage:
    python3 tools/agent-drift/memory_gate.py [--strict|--check]
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TARGET = REPO_ROOT / "tools" / "checks" / "memory_retention.py"


def main() -> int:
    if not TARGET.exists():
        print(f"error: {TARGET} missing", file=sys.stderr)
        return 1
    return subprocess.call(["python3", str(TARGET), *sys.argv[1:]])


if __name__ == "__main__":
    sys.exit(main())
