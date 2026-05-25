#!/usr/bin/env python3
"""Reject ARB copy that labels Swiss 3a ceilings as tax savings.

CHF 7'258 / CHF 36'288 are deductible contribution ceilings. Tax impact needs
household, canton/commune and marginal-rate context, so the ceiling cannot be
displayed as the user's tax saving.

Exit codes:
  0 = clean
  1 = semantic violation found
  2 = malformed ARB
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
ARB_DIR = REPO_ROOT / "apps" / "mobile" / "lib" / "l10n"

CEILING_RE = re.compile(
    r"(?<!\d)(?:7[\s\u00a0\u202f'.,]?258|7258|36[\s\u00a0\u202f'.,]?288|36288)(?!\d)"
)

TAX_SAVING_RE_BY_LOCALE: dict[str, re.Pattern[str]] = {
    "fr": re.compile(
        r"(?:[eé]conomie(?:s)?|[eé]conomies?|[eé]pargne(?:s)?)\s+"
        r"(?:d[’']?\s*)?(?:imp[oô]t(?:s)?|fiscale(?:s)?)|"
        r"(?:imp[oô]t(?:s)?)\s+[eé]conomise(?:s)?",
        re.IGNORECASE,
    ),
    "en": re.compile(r"tax\s+savings?|tax\s+saved", re.IGNORECASE),
    "de": re.compile(r"steuerersparnis(?:se)?|steuer\s+spar(?:en|st)", re.IGNORECASE),
    "es": re.compile(r"ahorro(?:s)?\s+fiscal(?:es)?", re.IGNORECASE),
    "it": re.compile(r"risparmi?o?\s+(?:d[' ]imposta|fiscal[ei])", re.IGNORECASE),
    "pt": re.compile(r"poupan[cç]a(?:s)?\s+fisc(?:al|ais)", re.IGNORECASE),
}

SENTENCE_SPLIT_RE = re.compile(r"[.!?\n]+")


def _sentences(value: str) -> list[str]:
    return [part.strip() for part in SENTENCE_SPLIT_RE.split(value) if part.strip()]


def _tax_re_for_locale(locale: str) -> re.Pattern[str]:
    return TAX_SAVING_RE_BY_LOCALE.get(locale, TAX_SAVING_RE_BY_LOCALE["fr"])


def scan_locale(arb_path: Path, locale: str) -> list[tuple[str, str, str]]:
    """Return list of (key, value, sentence) violations for one ARB file."""
    try:
        data = json.loads(arb_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"ERROR: malformed ARB {arb_path}: {e}", file=sys.stderr)
        sys.exit(2)

    tax_re = _tax_re_for_locale(locale)
    violations: list[tuple[str, str, str]] = []
    for key, value in data.items():
        if key.startswith("@") or not isinstance(value, str):
            continue
        for sentence in _sentences(value):
            if CEILING_RE.search(sentence) and tax_re.search(sentence):
                violations.append((key, value, sentence))
                break
    return violations


def _locale_from_path(path: Path) -> str:
    match = re.match(r"app_([a-z]{2})\.arb$", path.name)
    return match.group(1) if match else "all"


def _expand_paths(raw_paths: list[str]) -> list[Path]:
    if not raw_paths:
        return sorted(ARB_DIR.glob("app_*.arb"))
    paths: list[Path] = []
    for raw_path in raw_paths:
        path = Path(raw_path)
        if path.is_dir():
            paths.extend(sorted(path.glob("app_*.arb")))
        elif path.suffix == ".arb":
            paths.append(path)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="Optional ARB files or directories")
    args = parser.parse_args()

    violations = []
    for arb_path in _expand_paths(args.paths):
        locale = _locale_from_path(arb_path)
        for key, _value, sentence in scan_locale(arb_path, locale):
            violations.append((arb_path, locale, key, sentence))

    if not violations:
        print("OK - 3a ceilings are not labelled as tax savings in ARB copy.")
        return 0

    print("3a semantic copy violations found:\n", file=sys.stderr)
    for path, locale, key, sentence in violations:
        rel = path.relative_to(REPO_ROOT) if path.is_relative_to(REPO_ROOT) else path
        snippet = sentence if len(sentence) <= 160 else sentence[:157] + "..."
        print(f"  [{locale}] {rel}:{key}", file=sys.stderr)
        print(f"      {snippet}", file=sys.stderr)
    print(
        "\nUse deductible-room wording for CHF 7'258 / CHF 36'288. "
        "If showing tax impact, compute or label a separate estimate.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
