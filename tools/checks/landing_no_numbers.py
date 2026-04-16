#!/usr/bin/env python3
"""Landing no-numbers gate (Phase 7 / LAND-04).

Fails if `apps/mobile/lib/screens/landing_screen.dart` contains any digit
inside a STRING LITERAL (single or double quoted). The calm promise surface
must render zero numeric content — no ages, no CHF amounts, no percentages,
no years. Structural Dart numerics (widths, spacers, font weights, curve
intervals) are allowed; they are not visible to the user.

Also rejects a banned-term vocabulary list (retirement framing, aggressive
CTAs) that MINT's anti-shame doctrine forbids on the landing. Comments are
exempt from the banned-term check (they document the invariants).

Exit 0 on pass, exit 1 with line diagnostic on fail.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TARGET = REPO / "apps" / "mobile" / "lib" / "screens" / "landing_screen.dart"

# Banned vocabulary (case-insensitive). "LSFin" is whitelisted below.
BANNED_TERMS = [
    "commencer",
    "démarrer",
    "demarrer",
    "voir mon chiffre",
    "ton chiffre en",
    "chiffre choc",
    "chiffrechoc",
    "découvrir",
    "decouvrir",
    "explorer",
    "parler au coach",
    "retraite",
    "retirement",
    "rente",
    "pension",
    "jubilación",
    "jubilacion",
    "pensione",
    "reforma",
    " lpp",
    "lpp ",
    " avs",
    "avs ",
]

WHITELIST_SUBSTRINGS = ("lsfin",)


def main() -> int:
    if not TARGET.exists():
        print(f"::error::landing_no_numbers: target not found: {TARGET}")
        return 1

    src = TARGET.read_text(encoding="utf-8")
    lines = src.splitlines()
    failures: list[str] = []

    # Strip // line comments and /* block comments */ before scanning.
    def strip_comments(text: str) -> str:
        # remove block comments
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
        # remove line comments
        text = re.sub(r"//[^\n]*", "", text)
        return text

    # Extract string literals (single or double quoted, non-greedy, no escape handling).
    string_re = re.compile(r"""(['"])((?:\\.|(?!\1).)*)\1""")
    digit_re = re.compile(r"\d")

    code_no_comments = strip_comments(src)
    # Strip import directives — their URIs legitimately contain digits
    # (e.g. `app_localizations.dart` has no digit, but a package pin might).
    code_no_imports = re.sub(
        r"^\s*import\s+['\"][^'\"]+['\"]\s*;\s*$",
        "",
        code_no_comments,
        flags=re.MULTILINE,
    )
    for m in string_re.finditer(code_no_imports):
        literal = m.group(2)
        d = digit_re.search(literal)
        if d:
            # Find the originating line number in the stripped text.
            line_no = code_no_imports.count("\n", 0, m.start()) + 1
            failures.append(
                f"{TARGET.relative_to(REPO)}:{line_no}: "
                f"digit in string literal forbidden on landing surface: '{literal}'"
            )

    # Banned-term scan on NON-comment code only (so doc comments can reference them).
    code_lines = strip_comments(src).splitlines()
    for i, line in enumerate(code_lines, start=1):
        lline = line.lower()
        if any(w in lline for w in WHITELIST_SUBSTRINGS):
            continue
        for term in BANNED_TERMS:
            if term in lline:
                failures.append(
                    f"{TARGET.relative_to(REPO)}:{i}: banned term '{term.strip()}'\n    {line.strip()}"
                )
                break

    if failures:
        print("::error::landing_no_numbers gate failed:")
        for f in failures:
            print(f)
        return 1

    print(f"OK landing_no_numbers: {TARGET.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
