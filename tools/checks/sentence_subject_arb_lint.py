#!/usr/bin/env python3
"""CI gate: TRUST-02 sentence-subject lint for confidence ARB strings.

Phase 8a Plan 08a-03 — enforces the MINT-as-subject rule on user-facing
strings related to confidence/fiabilité/tramee de confiance. Per the
anti-shame doctrine (memory: feedback_anti_shame_situated_learning.md)
and TRUST-02: MINT reports its own trust in a projection; MINT never
frames confidence as a user attribute or a user deficiency.

Allowed (MINT-as-subject):
  - "MINT a confiance"
  - "MINT connaît"
  - "MINT avance"
  - "MINT ne voit pas encore assez de données"
  - "Confiance : N %" (neutral label, no subject)

Banned (user-as-subject of a confidence judgment):
  - "Ton score" (user's score, implies user-attribute framing)
  - "Ta fiabilité" (user's reliability — never MINT's vocabulary)
  - "Tu as ... confiance" (user is not the judge of projection trust)
  - "Votre score" (formal equivalent)

Scope (v1 — intentionally conservative to avoid false positives):
  Only scans `apps/mobile/lib/l10n/app_fr.arb` (the master ARB), and only
  keys whose NAME contains one of: `confidence`, `fiabilit`, `tramee`.
  The generic token `score` is NOT in the scoped set because the master
  ARB has ~60 keys mixing it with unrelated semantics (financial score,
  checkin score, coverage score) and a blanket rule would need per-key
  classification. Later phases will tighten this scope:
    - Phase 8b: add `score` keys that belong to the MTC namespace.
    - Phase 9: extend to all 6 ARB languages (EN, DE, ES, IT, PT).
    - Phase 11: custom lint on diff-vs-dev for touched keys only.

Exit codes:
  0 — clean (no banned subject found in scoped keys)
  1 — at least one scoped key contains a banned sentence-subject pattern

Usage:
  python3 tools/checks/sentence_subject_arb_lint.py
  python3 tools/checks/sentence_subject_arb_lint.py --verbose
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ARB_FILE = "apps/mobile/lib/l10n/app_fr.arb"

# Key-name scope: only keys whose identifier matches one of these tokens.
# Phase 9 / ALERT-02 extension: also cover MintAlertObject ARB keys
# (alert*, alertGeneric*, alertG2*, alertG3*) — same MINT-as-subject doctrine
# applies: alerts must never frame the user as the source of a problem.
KEY_SCOPE = re.compile(
    r"confidence|fiabilit|tramee|^alert[A-Z]|^mintAlert",
    re.IGNORECASE,
)

# Banned sentence-subject patterns (applied to the STRING VALUE of scoped keys)
BANNED_PATTERNS = [
    (
        re.compile(r"\bTon score\b", re.IGNORECASE),
        "user-as-subject: 'Ton score' frames confidence as a user attribute. "
        "Use a MINT-as-subject form (e.g. 'Confiance MINT : {score} %') or a "
        "neutral label without a possessive.",
    ),
    (
        re.compile(r"\bTa fiabilit[eé]", re.IGNORECASE),
        "user-as-subject: 'Ta fiabilité' blames the user for data quality. "
        "Use 'MINT a besoin de plus de données' or 'Fiabilité des données'.",
    ),
    (
        re.compile(r"\bTu as[^.!?]{0,40}confiance", re.IGNORECASE),
        "user-as-subject: 'Tu as ... confiance' makes the user the judge. "
        "Use 'MINT a confiance' or 'MINT avance avec prudence'.",
    ),
    (
        re.compile(r"\bTu as[^.!?]{0,40}alert", re.IGNORECASE),
        "user-as-subject: 'Tu as ... alerte' frames the user as the problem "
        "source. Use 'MINT a remarqué' or 'MINT voit une tension'.",
    ),
    (
        re.compile(r"\bVotre score\b", re.IGNORECASE),
        "user-as-subject (formal): 'Votre score' — same rule as 'Ton score'. "
        "MINT never frames confidence as a user attribute.",
    ),
]


def scan(repo_root: Path) -> list[tuple[str, str, str, str]]:
    """Return list of (key, value, banned_pattern, reason)."""
    path = repo_root / ARB_FILE
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    violations: list[tuple[str, str, str, str]] = []
    for key, value in data.items():
        if not isinstance(value, str):
            continue
        if not KEY_SCOPE.search(key):
            continue
        for pat, reason in BANNED_PATTERNS:
            m = pat.search(value)
            if m:
                violations.append((key, value, pat.pattern, reason))
                break
    return violations


def main() -> int:
    verbose = "--verbose" in sys.argv
    repo_root = Path(__file__).resolve().parents[2]
    violations = scan(repo_root)

    if verbose:
        path = repo_root / ARB_FILE
        if path.exists():
            data = json.loads(path.read_text(encoding="utf-8"))
            scoped = [k for k in data if isinstance(data[k], str) and KEY_SCOPE.search(k)]
            print(
                f"sentence_subject_arb_lint: scanned {len(scoped)} scoped key(s) "
                f"in {ARB_FILE}"
            )

    if not violations:
        print(
            "sentence_subject_arb_lint: OK — "
            "no banned user-as-subject patterns in scoped confidence keys"
        )
        return 0

    print(
        f"sentence_subject_arb_lint: FAIL — {len(violations)} TRUST-02 "
        "violation(s) in scoped confidence keys:",
        file=sys.stderr,
    )
    for key, value, pat, reason in violations:
        snippet = value if len(value) <= 140 else value[:137] + "..."
        print(f"  {ARB_FILE} :: {key}", file=sys.stderr)
        print(f"    value: {snippet}", file=sys.stderr)
        print(f"    rule:  /{pat}/", file=sys.stderr)
        print(f"    fix:   {reason}", file=sys.stderr)
    print(
        "\nTRUST-02 rule: MINT reports its own trust in a projection. "
        "Never frame confidence as a user attribute ('ton score', "
        "'ta fiabilité') or make the user the judge ('tu as confiance'). "
        "See docs/MINT_IDENTITY.md §5-principles and "
        "feedback_anti_shame_situated_learning.md.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
