#!/usr/bin/env python3
"""GATE: forbid re-introducing superseded fiscal/social values into the SERVED
content (RAG education corpus + user-facing ARB strings).

Campagne-A « contenu officiel garanti » (2026-07-24) corrected, against official
2026 sources (ESTV/AFC, OFAS/BSV), the fiscal deductions, LIFD article numbers
and cantonal family-allowance amounts served to users:
  - IFD déduction par enfant 6'700/6'600 -> 6'800 (art. 35 al. 1 let. a) [#1014]
  - IFD frais de garde 25'500 -> 25'800 ; « art. 33 al. 1 let. hbis » /
    « LIFD art. 213/212 » -> art. 33 al. 3 [#1014]
  - Allocations familiales cantonales « 200-300/mois », « 250-400 »,
    « 200 à 305 » -> montants OFAS 2026 (215-330 / 268-477) [#1015]
  - LPP/AVS millésimes périmés (88'200 -> 90'720 ; 61'740 chimère ; 22'050 ;
    44'100 -> 45'360) [#1010]

The backend/mobile CONSTANTS are protected by unit tests (test_family.py pins
6'800 / 25'800 / the OFAS allocations, run by ci-gate's backend+flutter jobs).
This gate protects the TEXT surfaces that no unit test covers: the served RAG
markdown corpus and the localized ARB strings. A superseded token there is an
uncaught regression of the campagne-A truth work.

Design (anti-façade): the current served corpus is GREEN by construction (the
beads removed every superseded token). Teeth are proven deterministically by
`--self-test` (every superseded pattern is caught; every correct 2026 value and
the legitimate APG « 6'600/mois » value are NOT) — not by relying on a stale
token still existing. Run `education_facts_check.py --self-test` in CI/lefthook.

stdlib only (no yaml/deps) — runs in the lefthook environment.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# Served-content globs (relative to repo root). Constants/code are covered by
# unit tests; here we guard the human-facing text the tests never read.
SCOPE_GLOBS = (
    "education/inserts/**/*.md",
    "services/backend/education_inserts/**/*.md",
    "apps/mobile/lib/l10n/app_*.arb",
)

# Each fact: the CORRECT 2026 statement + the superseded token patterns that must
# NOT reappear in served content. Patterns are deliberately specific (apostrophe
# / comma-grouped amounts, exact article strings, exact ranges) so a legitimate
# occurrence of a bare number elsewhere does not false-positive. The apostrophe
# class ['’] covers both ASCII and typographic apostrophes used across the corpus
# and the 6 ARB locales.
_AP = r"['’]"
FACTS: list[dict] = [
    {
        "id": "ifd_deduction_enfant",
        "correct": "IFD déduction par enfant = CHF 6'800 (LIFD art. 35 al. 1 let. a, ESTV 2026)",
        "superseded": [rf"6{_AP}700", r"6,700"],
    },
    {
        "id": "ifd_frais_garde_montant",
        "correct": "IFD frais de garde par des tiers = CHF 25'800 (LIFD art. 33 al. 3, ESTV 2026)",
        "superseded": [rf"25{_AP}500", r"25,500"],
    },
    {
        "id": "ifd_frais_garde_article",
        "correct": "Frais de garde = LIFD art. 33 al. 3 (jamais « art. 33 al. 1 let. hbis »)",
        "superseded": [r"33\s*al\.?\s*1\s*let\.?\s*hbis"],
    },
    {
        "id": "lifd_pre_2014_numbering",
        "correct": "LIFD numérotation post-2014 : enfant art. 35 al. 1 let. a, garde art. 33 al. 3 (jamais art. 212/213)",
        "superseded": [r"LIFD\s*art\.?\s*21[23]", r"art\.?\s*21[23]\s*\(déduction"],
    },
    {
        "id": "allocations_familiales_range",
        "correct": "Allocations familiales cantonales OFAS 2026 : enfant CHF 215-330/mois, formation CHF 268-477/mois",
        "superseded": [
            r"200-300\s*/?\s*mois",
            r"250-400",
            rf"200\s*(?:à|a|bis|to|-)\s*(?:CHF\s*)?305",
            r"CHF\s*200/mois\s*\(minimum",
        ],
    },
    {
        "id": "lpp_avs_millesimes_perimes",
        "correct": "LPP/AVS 2026 : 90'720 (LPP max), 22'680 / 45'360 (AVS) — cf. registre réglementaire",
        "superseded": [rf"88{_AP}200", r"88,200", rf"61{_AP}740", rf"44{_AP}100", rf"22{_AP}050"],
    },
]

_COMPILED = [
    (fact, [re.compile(p, re.IGNORECASE) for p in fact["superseded"]])
    for fact in FACTS
]


def _iter_files() -> list[Path]:
    files: list[Path] = []
    for glob in SCOPE_GLOBS:
        files.extend(sorted(REPO_ROOT.glob(glob)))
    return files


def scan_text(text: str) -> list[tuple[str, int, str]]:
    """Return (fact_id, line_no, correct_statement) for each superseded hit."""
    hits: list[tuple[str, int, str]] = []
    for i, line in enumerate(text.splitlines(), start=1):
        for fact, patterns in _COMPILED:
            if any(p.search(line) for p in patterns):
                hits.append((fact["id"], i, fact["correct"]))
    return hits


def _self_test() -> int:
    """Prove teeth deterministically, independent of corpus state."""
    failures: list[str] = []
    # 1. Every superseded pattern MUST be caught.
    must_catch = [
        "déduction de CHF 6'700 par enfant",
        "child deduction of CHF 6,700",
        "frais de garde max CHF 25'500",
        "LIFD art. 33 al. 1 let. hbis",
        "Source : LIFD art. 213 (déductions enfants)",
        "allocations familiales (CHF 200-300/mois)",
        "Allocation de formation : CHF 250-400/mois",
        "de CHF 200 à CHF 305 par enfant",
        "CHF 200/mois (minimum legal)",
        "88'200",
        "chimère 61'740",
        "3 × la rente = 44'100",
    ]
    for sample in must_catch:
        if not scan_text(sample):
            failures.append(f"MISS (should have flagged): {sample!r}")
    # 2. Correct 2026 values and the legitimate APG 6'600/mois MUST NOT be caught.
    must_not_catch = [
        "déduction de CHF 6'800 par enfant (LIFD art. 35 al. 1 let. a)",
        "frais de garde max CHF 25'800 (LIFD art. 33 al. 3)",
        "APG plafonnée à CHF 220/jour (soit CHF 6'600/mois max)",  # legit APG value
        "allocations familiales cantonales CHF 215-330/mois",
        "Allocation de formation : CHF 268-477/mois",
        "LPP maximum CHF 90'720 en 2026",
    ]
    for sample in must_not_catch:
        if scan_text(sample):
            failures.append(f"FALSE POSITIVE (should be clean): {sample!r}")
    if failures:
        print("education_facts_check --self-test FAILED:")
        for f in failures:
            print(f"  ✗ {f}")
        return 1
    print("education_facts_check --self-test OK (teeth verified, no false positives).")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--self-test", action="store_true",
        help="Verify the checker catches superseded values and not correct ones.",
    )
    parser.add_argument("paths", nargs="*", help="Optional explicit files to scan.")
    args = parser.parse_args(argv)

    if args.self_test:
        return _self_test()

    targets = [Path(p) for p in args.paths] if args.paths else _iter_files()
    all_hits: list[str] = []
    for path in targets:
        if not path.exists():
            continue
        try:
            rel = path.resolve().relative_to(REPO_ROOT)
        except ValueError:
            rel = path  # path outside the repo (e.g. explicit arg) — show as-is
        for fact_id, line_no, correct in scan_text(
            path.read_text(encoding="utf-8", errors="replace")
        ):
            all_hits.append(f"{rel}:{line_no}: [{fact_id}] → {correct}")

    if all_hits:
        print(
            "EDUCATION FACTS — superseded fiscal/social value(s) re-introduced in "
            "served content (campagne-A regression). Replace with the 2026 value:\n"
        )
        for h in all_hits:
            print(f"  ✗ {h}")
        print(
            "\nThese text surfaces are served to users (RAG corpus / ARB) and are "
            "NOT covered by unit tests. Use the official 2026 value cited above."
        )
        return 1

    print(f"OK: no superseded fiscal/social value in served content "
          f"({len(targets)} file(s) scanned).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
