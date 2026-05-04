#!/usr/bin/env python3
"""LSFin banned-terms ARB lint.

V1 scope (this PR) : the « garanti / guaranteed / garantiert / garantizado
/ garantito / garantido » family is the most-prosecuted LSFin Rule #1
violation per CLAUDE.md TOP rule #1. It's also the lowest false-positive-
rate term — it appears in finance writing only as a promise.

Negation contexts (« pas de... garanti », « not guaranteed »,
« kein garantierter »…) are allowlisted because LSFin permits
*disclaiming* a guarantee — it bans *claiming* one.

Other LSFin-adjacent vocabulary (« optimal », « meilleur », « parfait »,
« sans risque », « assuré (rendement) ») has too many colloquial uses
in everyday FR/EN/DE/ES/IT/PT to mechanically lint here without semantic
context. Track those via a separate advisory sweep + manual review.

Per `feedback_public_repo_discipline.md`, the public MINT-IA/MINT repo
cannot ship strings that violate this rule. A reporter `grep`-ing the
public mirror would find the contradiction in 10 seconds.

Exit codes :
   0 = clean (no positive « garanti* » uses)
   1 = violation found (CI must fail)
   2 = malformed ARB (CI must fail)

Usage : python3 tools/checks/banned_terms_arb.py [--locale fr|en|de|es|it|pt]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
ARB_DIR = REPO_ROOT / "apps" / "mobile" / "lib" / "l10n"

# Per-locale banned-token regex and the negation-window guard pattern.
# Each entry is (regex_for_banned_root, regex_for_negation_within_30_chars_before).
# Negation-before window: any of the negation lemmas listed must appear in
# the 30 characters preceding the banned root. If yes, the banned use is a
# permitted disclaimer ("not guaranteed") — skip. Otherwise, flag.
LOCALE_RULES: dict[str, list[tuple[str, str]]] = {
    "fr": [
        (
            r"garanti(?:t|e|es|s)?\b",
            r"\b(?:pas|aucun(?:e)?|jamais|sans|n[' ]est pas|non|aucune)\b[^.!?]{0,30}$",
        ),
    ],
    "en": [
        (
            r"\bguarantee(?:s|d)?\b",
            r"\b(?:not|no|never|without|isn[' ]t|aren[' ]t|won[' ]t|nothing)\b[^.!?]{0,30}$",
        ),
    ],
    "de": [
        (
            r"garantier(?:t|en|te|ter|tes)?\b",
            r"\b(?:nicht|kein(?:e|en|er)?|ohne|niemals)\b[^.!?]{0,30}$",
        ),
    ],
    "es": [
        (
            r"garantiz(?:a|an|ada|adas|ado|ados)?\b",
            r"\b(?:no|sin|ning[uú]n(?:a|os|as)?|nunca|jam[áa]s)\b[^.!?]{0,30}$",
        ),
    ],
    "it": [
        (
            r"garant(?:isce|iscono|ito|ita|iti|ite)\b",
            r"\b(?:non|nessun(?:o|a|i|e)?|senza|mai)\b[^.!?]{0,30}$",
        ),
    ],
    "pt": [
        (
            r"garant(?:e|em|ido|ida|idos|idas)\b",
            r"\b(?:n[ãa]o|sem|nenhum(?:a|s|as)?|nunca|jamais)\b[^.!?]{0,30}$",
        ),
    ],
}


def scan_locale(arb_path: Path, locale: str) -> list[tuple[str, str, str]]:
    """Return list of (key, value, matched_term) violations for one ARB file."""
    rules = LOCALE_RULES.get(locale, [])
    if not rules:
        return []
    try:
        data = json.loads(arb_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"ERROR: malformed ARB {arb_path}: {e}", file=sys.stderr)
        sys.exit(2)
    violations: list[tuple[str, str, str]] = []
    for key, value in data.items():
        if key.startswith("@"):
            continue  # @meta blocks
        if not isinstance(value, str):
            continue
        for banned_re, negation_re in rules:
            for m in re.finditer(banned_re, value, flags=re.IGNORECASE):
                pre = value[: m.start()]
                # Allowlist 1 : disclaimer-style negation in the 30 chars before.
                if re.search(negation_re, pre, flags=re.IGNORECASE):
                    continue
                # Allowlist 2 : "ne ... pas" two-clause French negation
                # ("ne sont pas garantis"). Negation_re only covers one half,
                # but if "ne " appears anywhere in the same sentence before,
                # treat it as covered. Same logic for "n'est pas".
                if locale == "fr" and re.search(r"\bn(?:e|')\b[^.!?]{0,40}\bpas\b", pre, flags=re.IGNORECASE):
                    continue
                # Allowlist 3 : explicit negation later in the same value
                # ("X n'est pas garanti" — caught above) but also short forms.
                violations.append((key, value, m.group(0)))
                break  # one violation per key per rule is enough
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locale", choices=list(LOCALE_RULES) + ["all"], default="all")
    args = parser.parse_args()

    locales = list(LOCALE_RULES) if args.locale == "all" else [args.locale]
    total_violations: list[tuple[str, str, str, str]] = []
    for locale in locales:
        arb_path = ARB_DIR / f"app_{locale}.arb"
        if not arb_path.exists():
            print(f"WARN: missing ARB {arb_path}", file=sys.stderr)
            continue
        for key, value, term in scan_locale(arb_path, locale):
            total_violations.append((locale, key, value, term))

    if not total_violations:
        print(f"OK — {len(locales)} locale(s) clean (no positive LSFin banned-term uses).")
        return 0

    print("LSFin banned-term violations found in ARB files:\n", file=sys.stderr)
    for locale, key, value, term in total_violations:
        snippet = value if len(value) <= 140 else value[:137] + "..."
        print(f"  [{locale}] {key} → matched « {term} »", file=sys.stderr)
        print(f"      {snippet}", file=sys.stderr)
    print(
        f"\n{len(total_violations)} violation(s). Per CLAUDE.md TOP rule #1, "
        "rewrite using permitted vocabulary (« vise à fournir », "
        "« est conçue pour », « has the role of providing », …).",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
