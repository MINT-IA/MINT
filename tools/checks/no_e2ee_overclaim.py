#!/usr/bin/env python3
"""Lint user-facing strings for false end-to-end-encryption (E2EE) claims.

MINT v2.x runs Path A per `.planning/decisions/2026-05-02-data-residency.md`:
data is encrypted at rest with operator-held DEK on Railway. E2EE (Path C,
zero-knowledge with client-side keys) is deferred to v3.0. Therefore any
user-facing string promising « end-to-end encryption » / « chiffrement de
bout en bout » / « Ende-zu-Ende-Verschlüsselung » / « cifrado de extremo
a extremo » / « crittografia end-to-end » / « encriptação ponto a ponto »
/ « zero-knowledge » is a false claim and a regulatory transparency risk
under nFADP art. 19 / LSFin art. 8.

Origin: Phase 52.3 truth-in-crypto sweep, after the Adversarial Trust
Reviewer (T-52-08 follow-up panel) caught the claim live in 6 ARB locales
on the document-scan auth gate (`authGateDocScanMessage`).

Usage:

    python3 tools/checks/no_e2ee_overclaim.py
    python3 tools/checks/no_e2ee_overclaim.py --paths file1.arb file2.md

Exit 0 on clean. Exit 1 with `::error` line diagnostics on hit. Per-line
override: append `// ALLOW-E2EE-CLAIM: reason` (or `<!-- -->` for md) on
the offending line. Use sparingly — only for backlog/ADR/decision contexts
that explicitly mark the claim as deferred-future.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# What we lint: user-facing string surfaces.
USER_FACING_GLOBS = (
    "apps/mobile/lib/l10n/app_*.arb",
    "apps/mobile/lib/screens/**/*.dart",
    "apps/mobile/lib/widgets/**/*.dart",
)

# Docs are linted only for non-allowlisted promises (the v3.0 roadmap entry
# itself is fine; a doc that says « MINT uses E2EE today » is not).
DOC_GLOBS = (
    "docs/**/*.md",
    "README.md",
)

# E2EE / zero-knowledge claim patterns, multilingual. Case-insensitive.
# Word boundaries are loose because « end-to-end » / « bout en bout » are
# multi-token; we match the loaded phrases verbatim.
#
# Phase 52.4 expansion: VAULT_METAPHOR family. The previous Phase 52.3
# sweep caught the literal « end-to-end encryption » class but missed
# « secure vault / coffre-fort sécurisé / sicherer Tresor / cassaforte
# sicura / caja fuerte segura / cofre seguro », which carries the same
# zero-knowledge implication for users familiar with Bitwarden /
# 1Password / Threema. Any reader who associates « vault » with the
# password-manager category will infer that MINT cannot decrypt their
# data — which contradicts Path A (operator-held DEK on Railway).
# Allow-listed via `ALLOW-VAULT-METAPHOR` per-line override OR by
# co-occurring « operator-held / chiffré côté serveur / Path A » on
# the same line (handled by ALLOW_LINE_PATTERNS).
PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"\bend[- ]to[- ]end\s+encrypt", re.I), "EN E2EE claim"),
    (re.compile(r"\bchiffrement\s+de\s+bout\s+en\s+bout\b", re.I), "FR E2EE claim"),
    (re.compile(r"\bEnde[- ]zu[- ]Ende[- ]Verschl[üu]sselung\b", re.I), "DE E2EE claim"),
    (re.compile(r"\bcifrado\s+de\s+extremo\s+a\s+extremo\b", re.I), "ES E2EE claim"),
    (re.compile(r"\bcrittografia\s+end[- ]to[- ]end\b", re.I), "IT E2EE claim"),
    (re.compile(r"\bcrittografia\s+da\s+capo\s+a\s+capo\b", re.I), "IT E2EE claim (alt)"),
    (re.compile(r"\bencripta[çc][ãa]o\s+ponto\s+a\s+ponto\b", re.I), "PT E2EE claim"),
    (re.compile(r"\bE2EE\b", re.I), "E2EE acronym"),
    (re.compile(r"\bzero[- ]knowledge\b", re.I), "zero-knowledge claim"),
    # ── VAULT_METAPHOR family (Phase 52.4) ──────────────────────────
    (re.compile(r"\bsecure\s+vault\b", re.I), "EN vault metaphor"),
    (re.compile(r"\bcoffre[- ]fort\s+s[ée]curis[ée]\b", re.I), "FR vault metaphor"),
    (re.compile(r"\bsicheren?\s+Tresor\b", re.I), "DE vault metaphor"),
    (re.compile(r"\bcassaforte\s+sicura\b", re.I), "IT vault metaphor"),
    (re.compile(r"\bcaja\s+fuerte\s+segura\b", re.I), "ES vault metaphor"),
    (re.compile(r"\bcofre\s+seguro\b", re.I), "PT vault metaphor"),
]

# Allow-list patterns: legitimate references that MUST stay (roadmap /
# decision artifacts that explicitly defer the feature). Each element is a
# regex matched against the LINE; if any allow-list pattern matches the
# offending line, the hit is suppressed.
ALLOW_LINE_PATTERNS: list[re.Pattern] = [
    re.compile(r"v3\.0", re.I),
    re.compile(r"deferred", re.I),
    re.compile(r"defer\s+(?:to|until)", re.I),
    re.compile(r"reporté", re.I),
    re.compile(r"future\s+release", re.I),
    re.compile(r"backlog", re.I),
    re.compile(r"ADR-", re.I),
    re.compile(r"ALLOW-E2EE-CLAIM", re.I),
    re.compile(r"//\s*ALLOW-E2EE", re.I),
    re.compile(r"ALLOW-VAULT-METAPHOR", re.I),
    re.compile(r"//\s*ALLOW-VAULT", re.I),
    # Path A truthful framing: if the line co-mentions « operator-held »
    # or « chiffré côté serveur » or « Path A », the vault metaphor is
    # contextualized and not a zero-knowledge overclaim.
    re.compile(r"operator[- ]held", re.I),
    re.compile(r"chiffr[ée]\s+c[ôo]t[ée]\s+serveur", re.I),
    re.compile(r"\bPath\s+A\b", re.I),
]

# Files where E2EE is discussed as future-state and therefore allowed
# wholesale (decision artifacts, ROADMAP, ADRs, this lint itself).
ALLOW_FILE_PATTERNS: list[re.Pattern] = [
    re.compile(r"\.planning/decisions/.*data-residency", re.I),
    re.compile(r"\.planning/decisions/.*e2ee", re.I),
    re.compile(r"docs/ROADMAP", re.I),
    re.compile(r"docs/.*ADR", re.I),
    re.compile(r"decisions/.*ADR-", re.I),
    re.compile(r"tools/checks/no_e2ee_overclaim\.py$"),
    re.compile(r"\.planning/phases/52\.3"),
    re.compile(r"\.planning/phases/52\.4"),
    re.compile(r"\.planning/reports/SESSION-"),
    re.compile(r"\.planning/reviews/"),
]


def _iter_files(globs: tuple[str, ...]) -> list[Path]:
    out: list[Path] = []
    for pattern in globs:
        out.extend(sorted(REPO.glob(pattern)))
    return out


def _file_allowed(path: Path) -> bool:
    try:
        rel = path.relative_to(REPO).as_posix()
    except ValueError:
        rel = path.as_posix()
    return any(p.search(rel) for p in ALLOW_FILE_PATTERNS)


def _scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return [(lineno, label, line_content)] of hits not on the allow-list."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    hits: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        for pat, label in PATTERNS:
            if not pat.search(line):
                continue
            if any(allow.search(line) for allow in ALLOW_LINE_PATTERNS):
                continue
            hits.append((lineno, label, line.strip()))
            break
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paths", nargs="*", help="Specific files to scan")
    args = parser.parse_args()

    if args.paths:
        files = [Path(p).resolve() for p in args.paths]
    else:
        files = _iter_files(USER_FACING_GLOBS) + _iter_files(DOC_GLOBS)

    failures = 0
    for path in files:
        if not path.exists() or _file_allowed(path):
            continue
        for lineno, label, snippet in _scan_file(path):
            rel = path.relative_to(REPO).as_posix() if REPO in path.parents else path.name
            print(
                f"::error file={rel},line={lineno}::"
                f"E2EE over-claim ({label}). MINT v2.x is Path A per "
                f"data-residency decision; E2EE deferred to v3.0. "
                f"Either fix the copy or add `ALLOW-E2EE-CLAIM: <reason>` "
                f"on the line. Hit: {snippet}"
            )
            failures += 1

    if failures:
        print(
            f"\n{failures} E2EE over-claim hit(s). Fix the copy to reflect "
            f"actual state (encrypted at rest with per-user DEK on the "
            f"server side; cloud-sync-OFF keeps data local).",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
