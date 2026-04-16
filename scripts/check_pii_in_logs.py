#!/usr/bin/env python3
"""CI gate — fail the build if raw PII patterns appear in logs.

PRIV-03 — Phase 29.

Two input modes:
    --fixture <path>   : read a local file (used by tests + offline runs)
    --railway          : invoke `railway logs --json` for the last 24h
                         (requires RAILWAY_TOKEN env var)

Patterns checked:
    - Raw IBAN (CH + 19 digits, with/without spaces)
    - Raw AVS  (756.XXXX...)
    - Raw CH phone (+41 XX...)
    - Top-30 CH employer gazetteer entries

Exit codes:
    0 — no raw PII detected
    1 — at least one raw PII pattern found
    2 — script error (bad arguments, log fetch failed, etc.)

Usage in CI: run after the test suite, before merge to dev. Currently
warn-only in .github/workflows/ci.yml — flips to blocking in Phase 30.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

# Patterns mirror app/services/privacy/pii_scrubber regexes — kept narrow
# to minimize false positives on log noise (test fixtures, error traces).
_PATTERNS = [
    ("IBAN", re.compile(r"\bCH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{1,3}\b")),
    ("AVS",  re.compile(r"\b756[.\s\-]?\d{4}[.\s\-]?\d{4}[.\s\-]?\d{2,4}\b")),
    ("PHONE_CH", re.compile(r"(?:\+41|0041)\s?\d{2}\s?\d{3}\s?\d{2}\s?\d{2}")),
]

_GAZETTEER_PATH = (
    Path(__file__).resolve().parent.parent
    / "services" / "backend" / "app" / "services" / "privacy"
    / "data" / "employer_ch_gazetteer.txt"
)


def _load_employer_pattern() -> re.Pattern[str] | None:
    if not _GAZETTEER_PATH.exists():
        return None
    names = []
    for line in _GAZETTEER_PATH.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        names.append(s.lower())
    if not names:
        return None
    names = sorted(names, key=len, reverse=True)
    alt = "|".join(re.escape(n) for n in names)
    return re.compile(rf"\b(?:{alt})\b", re.IGNORECASE)


def _scan_text(text: str) -> list[tuple[str, str]]:
    """Return list of (pattern_name, match_excerpt) hits."""
    hits: list[tuple[str, str]] = []
    for name, pat in _PATTERNS:
        for m in pat.finditer(text):
            hits.append((name, m.group(0)))
    employer_pat = _load_employer_pattern()
    if employer_pat is not None:
        for m in employer_pat.finditer(text):
            hits.append(("EMPLOYER", m.group(0)))
    return hits


def _fetch_railway_logs() -> str:
    """Invoke railway CLI to fetch JSON logs. Requires RAILWAY_TOKEN."""
    try:
        proc = subprocess.run(
            ["railway", "logs", "--json", "--lines", "10000"],
            capture_output=True, text=True, timeout=120,
        )
    except FileNotFoundError:
        print("ERROR: railway CLI not installed", file=sys.stderr)
        sys.exit(2)
    except subprocess.TimeoutExpired:
        print("ERROR: railway logs timed out", file=sys.stderr)
        sys.exit(2)
    if proc.returncode != 0:
        print(f"ERROR: railway logs exit {proc.returncode}: {proc.stderr}",
              file=sys.stderr)
        sys.exit(2)
    return proc.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--fixture", type=Path, help="local log file to scan")
    src.add_argument("--railway", action="store_true",
                     help="fetch last 24h from railway CLI")
    parser.add_argument("--max-print", type=int, default=20,
                        help="cap number of hit lines printed (default: 20)")
    args = parser.parse_args()

    if args.fixture:
        if not args.fixture.exists():
            print(f"ERROR: fixture not found: {args.fixture}", file=sys.stderr)
            return 2
        text = args.fixture.read_text(encoding="utf-8", errors="replace")
    else:
        text = _fetch_railway_logs()

    hits = _scan_text(text)
    if not hits:
        print("OK: no raw PII patterns detected.")
        return 0

    # Group + dedup hits for readable output. Never print the full match
    # for IBAN/AVS — the goal is to report presence, not re-leak.
    by_kind: dict[str, int] = {}
    for kind, _ in hits:
        by_kind[kind] = by_kind.get(kind, 0) + 1

    print("FAIL: raw PII detected in logs:")
    for kind, count in sorted(by_kind.items()):
        print(f"  - {kind}: {count} hit(s)")
    print(
        "\nRaw PII (IBAN/AVS/PHONE/EMPLOYER) must never reach logs. "
        "Fix the originating logger to use privacy.pii_scrubber.scrub() "
        "or rely on the global PIILogFilter."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
