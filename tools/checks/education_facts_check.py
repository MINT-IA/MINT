#!/usr/bin/env python3
"""GATE: forbid re-introducing superseded fiscal/social values into the SERVED
content (RAG education corpus + legal docs + user-facing ARB strings).

Campagne-A « contenu officiel garanti » (2026-07-24) corrected, against official
2026 sources (ESTV/AFC, OFAS/BSV), the fiscal deductions, LIFD article numbers
and cantonal family-allowance amounts served to users:
  - IFD déduction par enfant 6'700 / 6'600 -> 6'800 (art. 35 al. 1 let. a) [#1014]
  - IFD frais de garde 25'500 -> 25'800 ; « art. 33 al. 1 let. hbis » /
    « LIFD art. 213/212 » -> art. 33 al. 3 [#1014]
  - Allocations familiales cantonales « 200-300/mois », « 250-400 »,
    « 200 à 305 » -> montants OFAS 2026 (215-330 / 268-477) [#1015]
  - LPP/AVS millésimes périmés (88'200 -> 90'720 ; 61'740 chimère ; 22'050 ;
    44'100 -> 45'360) [#1010]

Backend/mobile CONSTANTS are covered by unit tests (test_family.py pins
6'800 / 25'800 / the OFAS allocations, run by ci-gate's backend+flutter jobs).
This gate protects the TEXT surfaces no unit test reads: the served RAG markdown
corpus, the ingested legal docs, and the localized ARB strings.

Precision (Codex review #1017): a superseded amount is flagged ONLY when a
semantic CONTEXT keyword of the same fact is present on the line (e.g. 6'600 is
flagged near « déduction / enfant » but NOT in the legitimate APG value
« CHF 6'600/mois max » ; « art. 212/213 » only near LIFD/DBG, never CO art. 212).
Full-phrase facts with no ambiguity (« 33 al. 1 let. hbis ») need no context.

Anti-façade: the served corpus is GREEN by construction (the beads removed every
superseded token). Teeth are proven deterministically by `--self-test`, which is
TABLE-DRIVEN per superseded alternative (each pattern has a positive sample
asserted caught with its fact_id, plus negative samples for the correct 2026
values and the legitimate look-alikes). A single broken/removed regex fails the
self-test. stdlib only (no yaml/deps) — runs in the lefthook environment.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# Served-content globs (relative to repo root). Constants/code are covered by
# unit tests; here we guard the human-facing text the tests never read. Includes
# legal/*.md (ingested by services/backend/scripts/ingest_corpus.py).
SCOPE_GLOBS = (
    "education/inserts/**/*.md",
    "services/backend/education_inserts/**/*.md",
    "legal/**/*.md",
    "apps/mobile/lib/l10n/app_*.arb",
)

# ['’] covers ASCII + typographic apostrophes used across the corpus / 6 ARBs.
_AP = r"['’]"

# Each fact: the CORRECT 2026 statement, the CONTEXT keywords (any one must be
# on the same line for an amount to count — None = unambiguous, no context), and
# the superseded TOKEN patterns that must not reappear. A hit = context (or None)
# AND a superseded token, on the same line.
FACTS: list[dict] = [
    {
        "id": "ifd_deduction_enfant",
        "correct": "IFD déduction par enfant = CHF 6'800 (LIFD art. 35 al. 1 let. a, ESTV 2026)",
        "context": [r"enfant", r"d[ée]duction", r"child\s*deduction", r"kinderabzug", r"art\.?\s*35"],
        "superseded": [rf"6{_AP}[67]00", r"6,[67]00"],
    },
    {
        "id": "ifd_frais_garde_montant",
        "correct": "IFD frais de garde par des tiers = CHF 25'800 (LIFD art. 33 al. 3, ESTV 2026)",
        "context": [r"garde", r"childcare", r"custod", r"betreuung"],
        "superseded": [rf"25{_AP}500", r"25,500"],
    },
    {
        "id": "ifd_frais_garde_article",
        "correct": "Frais de garde = LIFD art. 33 al. 3 (jamais « art. 33 al. 1 let. hbis »)",
        "context": None,  # unambiguous full phrase
        "superseded": [r"33\s*al\.?\s*1\s*let\.?\s*hbis"],
    },
    {
        "id": "lifd_pre_2014_numbering",
        "correct": "LIFD numérotation post-2014 : enfant art. 35 al. 1 let. a, garde art. 33 al. 3 (jamais art. 212/213)",
        "context": [r"LIFD", r"DBG"],  # require the LIFD/DBG law, never CO art. 212
        "superseded": [r"art\.?\s*21[23]\b"],
    },
    {
        "id": "allocations_familiales_range",
        "correct": "Allocations familiales cantonales OFAS 2026 : enfant CHF 215-330/mois, formation CHF 268-477/mois",
        "context": [r"allocation", r"familiale", r"zulage", r"lafam", r"/mois\s*par\s*enfant", r"/month\s*per\s*child"],
        "superseded": [r"200-300\s*/?\s*mois", r"250-400", rf"200\s*(?:à|a|bis|to|-)\s*(?:CHF\s*)?305"],
    },
    {
        "id": "lpp_avs_millesimes_perimes",
        "correct": "LPP/AVS 2026 : 90'720 (LPP max), 22'680 / 45'360 (AVS) — cf. registre réglementaire",
        "context": [r"lpp", r"avs", r"ahv", r"rente", r"coordination", r"coordonn", r"bonification",
                    r"ramd", r"pilier", r"survivant", r"veuf", r"veuve", r"éducative", r"educative"],
        "superseded": [rf"88{_AP}200", r"88,200", rf"61{_AP}740", rf"44{_AP}100", rf"22{_AP}050"],
    },
]


def _compile(fact: dict) -> tuple[dict, list, list | None]:
    sup = [re.compile(p, re.IGNORECASE) for p in fact["superseded"]]
    ctx = None if fact["context"] is None else [
        re.compile(p, re.IGNORECASE) for p in fact["context"]
    ]
    return fact, sup, ctx


_COMPILED = [_compile(f) for f in FACTS]


def _iter_files() -> list[Path]:
    files: list[Path] = []
    for glob in SCOPE_GLOBS:
        files.extend(sorted(REPO_ROOT.glob(glob)))
    return files


def scan_text(text: str) -> list[tuple[str, int, str]]:
    """Return (fact_id, line_no, correct_statement) for each superseded hit.

    A hit requires a superseded token on the CURRENT line AND (the fact has no
    context requirement OR a context keyword within a 2-line window: the current
    line or the previous one). The window closes the Markdown split-line blind
    spot (Codex #1017) where a label/heading (« Déduction pour enfant : ») sits
    on its own line above the value (« CHF 6'700 »).
    """
    lines = text.splitlines()
    hits: list[tuple[str, int, str]] = []
    for i, line in enumerate(lines):
        window = line if i == 0 else lines[i - 1] + "\n" + line
        for fact, sup, ctx in _COMPILED:
            if not any(p.search(line) for p in sup):
                continue
            if ctx is not None and not any(p.search(window) for p in ctx):
                continue
            hits.append((fact["id"], i + 1, fact["correct"]))
    return hits


# (sample line, expected fact_id) — every superseded alternative has a positive
# case; a broken/removed regex makes its case miss and fails the self-test.
_MUST_CATCH: list[tuple[str, str]] = [
    ("déduction de CHF 6'700 par enfant", "ifd_deduction_enfant"),
    ("déduction pour enfant de CHF 6'600/an", "ifd_deduction_enfant"),   # 6'600 WITH enfant context
    ("child deduction of CHF 6,700 (LIFD art. 35)", "ifd_deduction_enfant"),
    ("déduction enfant CHF 6,600", "ifd_deduction_enfant"),
    ("déduction pour enfant CHF 6’700", "ifd_deduction_enfant"),     # typographic apostrophe
    ("frais de garde plafonnés à CHF 25'500", "ifd_frais_garde_montant"),
    ("childcare deduction max CHF 25,500", "ifd_frais_garde_montant"),
    ("frais de garde CHF 25’500", "ifd_frais_garde_montant"),        # typographic apostrophe
    ("LIFD art. 33 al. 1 let. hbis", "ifd_frais_garde_article"),
    ("art. 33 al. 1 let hbis (frais de garde)", "ifd_frais_garde_article"),
    ("Source : LIFD art. 213 (déductions enfants)", "lifd_pre_2014_numbering"),
    ("selon la LIFD art. 212", "lifd_pre_2014_numbering"),
    ("allocations familiales (CHF 200-300/mois)", "allocations_familiales_range"),
    ("Allocation de formation : CHF 250-400/mois", "allocations_familiales_range"),
    ("allocation : de CHF 200 à CHF 305 par enfant", "allocations_familiales_range"),
    ("allocation de 200 a 305 francs", "allocations_familiales_range"),
    ("family allowance CHF 200 to 305/month per child", "allocations_familiales_range"),
    ("allocation enfant de CHF 200-305", "allocations_familiales_range"),          # « - » branch
    ("Familienzulage: CHF 200 bis CHF 305 pro Kind", "allocations_familiales_range"),  # « bis » branch
    # Cross-line Markdown split (Codex #1017 P1): label above the value.
    ("Déduction pour enfant selon la LIFD:\nCHF 6'700 par année", "ifd_deduction_enfant"),
    ("Frais de garde des enfants:\nplafond CHF 25'500", "ifd_frais_garde_montant"),
    ("Allocation familiale mensuelle:\nCHF 200-300/mois", "allocations_familiales_range"),
    ("salaire coordonné LPP plafonné à 88'200", "lpp_avs_millesimes_perimes"),
    ("coordination LPP CHF 88,200", "lpp_avs_millesimes_perimes"),
    ("rente AVS chimère 61'740", "lpp_avs_millesimes_perimes"),
    ("bonification éducative 3× la rente = 44'100", "lpp_avs_millesimes_perimes"),
    ("RAMD AVS 22'050", "lpp_avs_millesimes_perimes"),
]
# Correct 2026 values + legitimate look-alikes that must NEVER be flagged.
_MUST_NOT_CATCH: list[str] = [
    "déduction de CHF 6'800 par enfant (LIFD art. 35 al. 1 let. a)",
    "frais de garde max CHF 25'800 (LIFD art. 33 al. 3)",
    "APG plafonnée à CHF 220/jour (soit CHF 6'600/mois max)",   # legit APG amount, no enfant/déduction
    "indemnité maternité CHF 6'700 par mois",                    # 6'700 without enfant/déduction context (APG-like)
    "allocations familiales cantonales CHF 215-330/mois",
    "Allocation de formation : CHF 268-477/mois",
    "LPP maximum CHF 90'720 en 2026",
    "CO art. 212 (déduction contractuelle)",                     # art. 212 of the CO, not LIFD
    "Budget mobilier CHF 250-400 selon le ménage",               # 250-400 without allocation context
    "un capital de 88'200 CHF sur ton compte 3a",                # bare amount, no LPP/AVS/rente context
    "Coût de la vie estimé:\nCHF 250-400 par semaine",           # cross-line, no allocation context
]


def _self_test() -> int:
    failures: list[str] = []
    for sample, expected in _MUST_CATCH:
        hits = scan_text(sample)
        ids = {h[0] for h in hits}
        if expected not in ids:
            failures.append(f"MISS (expected {expected}): {sample!r} → caught {sorted(ids) or 'nothing'}")
    for sample in _MUST_NOT_CATCH:
        hits = scan_text(sample)
        if hits:
            failures.append(f"FALSE POSITIVE ({sorted({h[0] for h in hits})}): {sample!r}")
    if failures:
        print("education_facts_check --self-test FAILED:")
        for f in failures:
            print(f"  ✗ {f}")
        return 1
    print(f"education_facts_check --self-test OK "
          f"({len(_MUST_CATCH)} caught, {len(_MUST_NOT_CATCH)} correctly clean).")
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
            "\nThese text surfaces are served to users (RAG corpus / legal docs / "
            "ARB) and are NOT covered by unit tests. Use the official 2026 value "
            "cited above (ESTV/AFC, OFAS/BSV)."
        )
        return 1

    print(f"OK: no superseded fiscal/social value in served content "
          f"({len(targets)} file(s) scanned).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
