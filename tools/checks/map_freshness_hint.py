#!/usr/bin/env python3
"""map_freshness_hint.py — gentle reminder that touching a subsystem means reading its map.

This is a *hint* hook, not a hard gate (Phase 34 may promote it). When a
commit touches a file listed under one of the sensitive subsystems, print
the map path on stderr so the author (or their LLM agent) gets a final
prompt to consult it before shipping blind.

Run via lefthook pre-commit. Takes staged file paths as arguments.

Exit code is always 0 — we warn, we don't block. Hard blocking belongs to
Phase 34 guards once the full lint stack is live. Until then: a visible
reminder on every touched file is already a 10× improvement over silence.
"""
from __future__ import annotations

import sys
from pathlib import Path

# Each tuple = (path prefix, doc to read). Order matters: first match wins.
# Keep this list in sync with AGENTS.md "Before you edit X, read Y" table.
SENSITIVE_AREAS: list[tuple[str, str]] = [
    ("apps/mobile/lib/screens/coach/", "docs/coach-tool-routing.md"),
    ("services/backend/app/api/v1/endpoints/coach_chat.py", "docs/coach-tool-routing.md"),
    ("services/backend/app/services/coach/coach_tools.py", "docs/coach-tool-routing.md"),
    ("apps/mobile/lib/providers/coach_profile_provider.dart", "docs/data-flow.md"),
    ("apps/mobile/lib/models/coach_profile.dart", "docs/data-flow.md"),
    ("apps/mobile/lib/services/chat/fact_extraction_fallback.dart", "docs/data-flow.md"),
    ("apps/mobile/lib/services/financial_core/", "docs/calculator-graph.md"),
    ("apps/mobile/lib/screens/document_scan/", "docs/data-flow.md (§Scan pipeline)"),
    ("apps/mobile/lib/screens/budget/", "docs/data-flow.md (§Budget flow)"),
    ("apps/mobile/lib/routes/route_metadata.dart", "AGENTS.md § Phase 32 registry"),
]


def main() -> int:
    staged = [Path(p) for p in sys.argv[1:]]
    if not staged:
        return 0

    hits: dict[str, list[Path]] = {}
    for path in staged:
        p = str(path)
        for prefix, doc in SENSITIVE_AREAS:
            if p.startswith(prefix) or p == prefix:
                hits.setdefault(doc, []).append(path)
                break

    if not hits:
        return 0

    sys.stderr.write(
        "\n\u001b[33m\u26a0  MINT map freshness hint\u001b[0m\n"
        "You're editing files in a sensitive subsystem. Before finalizing\n"
        "the commit, confirm you've read the relevant map. It exists because\n"
        "coding this area from memory creates facade-sans-cablage bugs.\n\n"
    )
    for doc, files in hits.items():
        sys.stderr.write(f"  \u2192 Read: \u001b[36m{doc}\u001b[0m\n")
        for f in files[:5]:
            sys.stderr.write(f"       touched: {f}\n")
        if len(files) > 5:
            sys.stderr.write(f"       ... and {len(files) - 5} more\n")
    sys.stderr.write(
        "\n  If the PR changes any documented invariant (keys, tool routing,\n"
        "  calculator wiring), update the doc in the SAME commit.\n\n"
    )
    return 0  # hint-only — never blocks


if __name__ == "__main__":
    sys.exit(main())
