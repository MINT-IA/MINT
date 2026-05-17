#!/usr/bin/env python3
"""Banned-terms LSFin lint for Python source files (Phase 93.5, T-93.5-02).

Scans `services/backend/app/services/coach/bundles/*.py` (and any path the
caller passes) for banned LSFin narrator-output terms.

EXEMPTION : a multi-line string literal is exempted from the scan if a
comment line containing the marker `# llm-doctrine-fragment-banned-list`
appears IMMEDIATELY ABOVE the next triple-quoted string. The exemption only
applies to the next assignment (e.g. `_PROMPT_FRAGMENT = \"\"\"...\"\"\"`).
A second exemption marker exempts the next block again.

Rationale : the compliance-narrator bundle's prompt_fragment must LIST the
banned terms verbatim to forbid them to the narrator LLM. Without
exemption, the lint would falsely flag the doctrine block. Per CONTEXT
D-09 + RESEARCH §Pitfall 4 + CLAUDE.md TOP rule #1.

Banned roots scanned (word-boundary-anchored, case-insensitive) :
    garanti, optimal, meilleur, certain, assure, parfait, sans risque

The « sans risque » bigram is a phrase, not a single token — scanned as a
distinct substring without word-boundary requirement.

Exit codes :
   0 — no banned terms outside exempted blocks
   1 — at least one banned term in non-exempted code

Usage :
   python3 tools/checks/banned_terms_python.py path1 [path2 ...]
   path may be a file or a directory (directories scanned recursively for
   *.py files).
"""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

# Word-boundary-anchored single tokens.
_WORD_BOUNDARY_BANNED: tuple[str, ...] = (
    "garanti",
    "optimal",
    "meilleur",
    "certain",
    "assure",
    "parfait",
)
# Multi-word phrases (no word boundary, just substring).
_PHRASE_BANNED: tuple[str, ...] = ("sans risque",)

# ---------------------------------------------------------------------------
# Phase mint-calc-engine-v1 W4 — D-CE-16(b) paraphrase-verb extension.
# 11 verbs verbatim from CONTEXT §D-CE-16(b). Scanned as substrings (not
# word-boundary) because most are multi-word phrases. Order preserved to
# match the doctrine table.
# Self-exemption (see _SELF_PATH below) keeps this file's own source clean
# under the lint — the strings here are the lint's vocabulary, not user-
# facing narrator output.
# ---------------------------------------------------------------------------
BANNED_PARAPHRASE_VERBS: tuple[str, ...] = (
    "le choix le plus avisé",
    "le plus pertinent",
    "plus avantageux que",
    "nettement plus",
    "clairement supérieur",
    "à mon avis",
    "je pense que tu",
    "mon conseil serait",
    "tu devrais",
    "il faut",
    "recommandé",
)

# Doctrine-level union for downstream consumers (runtime_verb_gate.py).
# Combines all word-boundary + phrase + paraphrase verbs into one tuple.
BANNED_TERMS: tuple[str, ...] = (
    *_WORD_BOUNDARY_BANNED,
    *_PHRASE_BANNED,
    *BANNED_PARAPHRASE_VERBS,
)

EXEMPTION_MARKER = "# llm-doctrine-fragment-banned-list"

# Self-path : this module is its own canonical list ; scan_file MUST NOT
# flag its own paraphrase-verb tuple as user-facing narrator output.
_SELF_PATH = Path(__file__).resolve()


def _compute_exempted_lines(lines: list[str]) -> set[int]:
    """Return 1-indexed line numbers covered by exemption markers.

    For each `EXEMPTION_MARKER` comment, exempt every line of the *next*
    triple-quoted string literal that opens after it (inclusive of opener
    and closer). If no triple-quoted block opens before another marker or
    EOF, the marker is a no-op.
    """
    exempted: set[int] = set()
    n = len(lines)
    i = 0
    while i < n:
        if EXEMPTION_MARKER in lines[i]:
            # Walk forward to find the next triple-quoted block opener.
            j = i + 1
            while j < n:
                line_j = lines[j]
                if '"""' in line_j or "'''" in line_j:
                    quote = '"""' if '"""' in line_j else "'''"
                    exempted.add(j + 1)  # 1-indexed
                    # Same-line close ?
                    if line_j.count(quote) >= 2:
                        break
                    # Walk to closing quote.
                    k = j + 1
                    while k < n:
                        exempted.add(k + 1)  # 1-indexed
                        if quote in lines[k]:
                            break
                        k += 1
                    j = k
                    break
                # Hit another marker before any triple-quote → previous
                # marker becomes a no-op ; restart from this marker.
                if EXEMPTION_MARKER in line_j:
                    break
                j += 1
            i = j + 1
        else:
            i += 1
    return exempted


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return [(line_no, term, line_text), ...] for non-exempted hits.

    NFKC-normalises each line before regex match so decomposed-accent /
    fullwidth / combining-mark variants of banned terms cannot evade the
    lint (CONTEXT §D-CE-16(b) — paraphrase + unicode evasion vector).

    Self-exemption : when called on this module's own file (e.g. by a
    pre-commit hook that walks the repo), the function returns an empty
    list — the paraphrase tuple here IS the lint vocabulary, not narrator
    output.
    """
    # D-CE-16(b) self-exemption.
    try:
        if path.resolve() == _SELF_PATH:
            return []
    except OSError:  # pragma: no cover — defensive on weird paths
        pass

    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    exempted = _compute_exempted_lines(lines)

    word_re = {
        term: re.compile(r"\b" + re.escape(term) + r"\b", re.IGNORECASE)
        for term in _WORD_BOUNDARY_BANNED
    }
    paraphrase_re = {
        term: re.compile(re.escape(term), re.IGNORECASE)
        for term in BANNED_PARAPHRASE_VERBS
    }
    hits: list[tuple[int, str, str]] = []

    for line_no, line in enumerate(lines, start=1):
        if line_no in exempted:
            continue
        # Skip comment-only lines that include a banned term (often
        # intentional in lint output / docstrings / TODO comments).
        stripped = line.lstrip()
        if stripped.startswith("#"):
            continue
        # D-CE-16(b) NFKC normalisation : neutralises decomposed accents,
        # fullwidth chars, and combining marks BEFORE substring/regex match.
        nfkc_line = unicodedata.normalize("NFKC", line)
        matched = False
        for term in _WORD_BOUNDARY_BANNED:
            if word_re[term].search(nfkc_line):
                hits.append((line_no, term, line.rstrip()))
                matched = True
                break
        if matched:
            continue
        for phrase in _PHRASE_BANNED:
            if phrase in nfkc_line.lower():
                hits.append((line_no, phrase, line.rstrip()))
                matched = True
                break
        if matched:
            continue
        # D-CE-16(b) — paraphrase verbs (substring, NFKC-aware, case-insensitive).
        for verb in BANNED_PARAPHRASE_VERBS:
            if paraphrase_re[verb].search(nfkc_line):
                hits.append((line_no, verb, line.rstrip()))
                break
    return hits


def _iter_python_files(paths: list[Path]):
    for p in paths:
        if p.is_dir():
            yield from sorted(p.rglob("*.py"))
        elif p.is_file():
            yield p


# ---------------------------------------------------------------------------
# Phase 95 D-12 — LSFin anti-promise annotation lint (--lsfin-annotation).
#
# When a file emits credible_low/credible_high values into user-facing
# narrative, the verbatim FR annotation « selon le modèle simplifié actuel »
# MUST appear somewhere in the same file. Paraphrases and ASCII-e variants
# are rejected (CLAUDE.md §1 LSFin + §2 accent).
#
# Heuristic : if the file contains both `credible_low` AND `credible_high`
# tokens AND no occurrence of the verbatim annotation, emit a violation.
# Files that don't emit credible intervals are exempt.
#
# The rule is OPT-IN via the `--lsfin-annotation` CLI flag so the existing
# default lint mode is preserved byte-identical for the existing lefthook
# pre-commit pipeline.
# ---------------------------------------------------------------------------

_LSFIN_ANNOTATION_FR = "selon le modèle simplifié actuel"  # verbatim, accents preserved


def check_lsfin_annotation(path: Path) -> list[tuple[int, str]]:
    """D-12 LSFin anti-promise annotation rule.

    Returns: list of (line_no, message) tuples ; empty list = clean.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    has_low = "credible_low" in text
    has_high = "credible_high" in text
    if not (has_low and has_high):
        return []  # no credible intervals → rule N/A
    if _LSFIN_ANNOTATION_FR in text:
        return []  # annotation present verbatim → clean
    # Find a representative line where credible_low is mentioned, for reporting.
    for line_no, line in enumerate(text.splitlines(), start=1):
        if "credible_low" in line:
            return [(
                line_no,
                f"LSFin D-12 : file emits credible_low/credible_high without "
                f"verbatim annotation « {_LSFIN_ANNOTATION_FR} ». "
                f"Required by CONTEXT D-12 + CLAUDE.md §1.",
            )]
    return [(1, "LSFin D-12 : annotation missing")]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Banned-terms LSFin Python lint")
    parser.add_argument("paths", nargs="+", type=Path, help="files or directories")
    parser.add_argument(
        "--lsfin-annotation",
        action="store_true",
        help=(
            "Phase 95 D-12 mode : flag files that emit credible_low/credible_high "
            "without the verbatim FR annotation "
            "« selon le modèle simplifié actuel »."
        ),
    )
    args = parser.parse_args(argv)

    if args.lsfin_annotation:
        # Opt-in D-12 mode — does NOT run the default banned-term scan.
        annotation_hits: list[tuple[Path, int, str]] = []
        for f in _iter_python_files(args.paths):
            for line_no, msg in check_lsfin_annotation(f):
                annotation_hits.append((f, line_no, msg))
        if annotation_hits:
            for path, line_no, msg in annotation_hits:
                print(f"{path}:{line_no}: {msg}", file=sys.stderr)
            return 1
        return 0

    # Default mode (Phase 93.5) — banned-term scan.
    all_hits: list[tuple[Path, int, str, str]] = []
    for f in _iter_python_files(args.paths):
        for line_no, term, line in scan_file(f):
            all_hits.append((f, line_no, term, line))

    if all_hits:
        for path, line_no, term, line in all_hits:
            print(f"{path}:{line_no}: banned term {term!r}: {line}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
