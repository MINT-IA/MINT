#!/usr/bin/env python3
"""Phase 84 LANG-03 alias for :mod:`tools.checks.arb_parity`.

The REQUIREMENTS spec referenced ``arb_key_parity.py``; the canonical script
ships at ``arb_parity.py`` (matches the path that the Phase 30.7 MCP wrapper
``tools/mcp/mint-tools/tools/arb_parity.py`` already expects). This thin
shim forwards CLI invocations so both file names work — useful for the
roadmap success criterion and any external doc that referenced the
``_key`` form.
"""
from __future__ import annotations

import sys
from pathlib import Path

# Make sibling import work whether the script is invoked from the repo root
# or directly via ``python3 tools/checks/arb_key_parity.py``.
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from arb_parity import main  # noqa: E402  (post-sys.path tweak)


if __name__ == "__main__":
    sys.exit(main())
