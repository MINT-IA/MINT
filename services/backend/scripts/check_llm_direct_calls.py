#!/usr/bin/env python3
"""Audit: direct Anthropic client use outside the LLM router (Phase 29-06).

Exit codes:
    0 — all direct calls live in ``services/llm/`` (or are known allowlisted).
    1 — new violations found outside the allowlist.

The allowlist documents migrations tracked for follow-up plans:
    - services/rag/llm_client.py   (coach retry wrapper — P1 migration)
    - api/v1/endpoints/documents.py (classification endpoint — P1 migration)

Run locally:
    python scripts/check_llm_direct_calls.py

Add to CI:
    - name: LLM router gate
      run: python services/backend/scripts/check_llm_direct_calls.py
"""
from __future__ import annotations

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
APP_ROOT = REPO_ROOT / "app"

# Patterns that indicate a direct Anthropic client call.
PATTERNS = [
    re.compile(r"\bAsyncAnthropic\s*\("),
    re.compile(r"\bAnthropic\s*\(api_key"),
    re.compile(r"\bclient\.messages\.create\b"),
    re.compile(r"from\s+anthropic\s+import\s+(?:Anthropic|AsyncAnthropic)"),
]

# Paths allowed to call Anthropic directly.
ALLOWLIST_PREFIXES = (
    "services/llm/",
)

# Paths acknowledged but tracked for follow-up migration. Additions to this
# list must be approved (they are regressions-in-waiting).
TRACKED_PENDING_MIGRATION = {
    "services/rag/llm_client.py",   # Coach main client. Migration plan: preserve retry/tenacity semantics.
    "api/v1/endpoints/documents.py",  # Doc classify endpoint. Migration plan: same router call.
}


def scan() -> list[tuple[str, int, str]]:
    hits: list[tuple[str, int, str]] = []
    for py in APP_ROOT.rglob("*.py"):
        rel = py.relative_to(APP_ROOT).as_posix()
        if any(rel.startswith(p) for p in ALLOWLIST_PREFIXES):
            continue
        try:
            text = py.read_text(encoding="utf-8")
        except Exception:
            continue
        for i, line in enumerate(text.splitlines(), start=1):
            # Skip comments
            stripped = line.lstrip()
            if stripped.startswith("#"):
                continue
            for pat in PATTERNS:
                if pat.search(line):
                    hits.append((rel, i, line.strip()))
                    break
    return hits


def main() -> int:
    hits = scan()
    # Partition into tracked (warning) vs new violations (error).
    new: list[tuple[str, int, str]] = []
    tracked: list[tuple[str, int, str]] = []
    for rel, lineno, line in hits:
        if rel in TRACKED_PENDING_MIGRATION:
            tracked.append((rel, lineno, line))
        else:
            new.append((rel, lineno, line))

    if tracked:
        print("::info:: Anthropic direct calls in tracked-pending files "
              "(follow-up migration):")
        for rel, lineno, line in tracked:
            print(f"  {rel}:{lineno}: {line}")

    if new:
        print("::error:: New direct Anthropic calls outside services/llm/ — "
              "route via LLMRouter:")
        for rel, lineno, line in new:
            print(f"  {rel}:{lineno}: {line}")
        return 1

    print("OK: no new direct Anthropic calls outside services/llm/.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
