#!/usr/bin/env python3
"""Lint committed Markdown for forensic / loaded language.

Scans `.md` files under `.planning/`, `decisions/`, `docs/` for phrases that
read as adverse admissions when quoted out of context (explicit "violates X",
personal-liability framing, panel-panic adjectives). Citation-only references
(e.g. "art. 6 nFADP") and descriptive findings ("contradiction", "gap") are
left alone.

Usage:

    python3 tools/checks/no_legal_admission_in_public_docs.py
    python3 tools/checks/no_legal_admission_in_public_docs.py --paths file1.md file2.md

Exit 0 on clean. Exit 1 with `::error` line diagnostics on hit. Per-line
override: append `<!-- ALLOW-LEGAL-ADMISSION: reason -->` on the offending
line.

Notes:
  - `--paths` bypasses the directory allowlist; pass it deliberately.
  - Pattern list is conservative — extend via PR if a real-world hit slips
    through.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCAN_ROOTS = (
    REPO / ".planning",
    REPO / "decisions",
    REPO / "docs",
)

# Patterns are case-insensitive. `\b` boundaries avoid greedy hits on
# unrelated tokens ("applied", "lied about", etc.).
PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"\bcriminal\s+exposure\b", re.I), "criminal exposure framing"),
    (re.compile(r"\brisque\s+p[ée]nal\b", re.I), "risque pénal explicit framing"),
    (re.compile(r"\bviolates?\s+(?:nFADP|LSFin|FINMA|LAVS|nLPD)\b", re.I), "explicit violation language"),
    (re.compile(r"\b(?:FDPIC|nFADP|nLPD|LSFin|FinSA)\s+violation\b", re.I), "regulator-violation framing"),
    (re.compile(r"\b(?:art\.?|article)\s*\.?\s*60\s+(?:nFADP|nLPD|FADP)\b", re.I), "art. 60 nFADP citation (criminal article)"),
    (re.compile(r"\bCHF\s*250\s*[\.\s'’]?\s*000\b", re.I), "CHF 250'000 personal-fine reference"),
    (re.compile(r"\bfounder\s+(?:personally|criminally)\b", re.I), "founder personal-liability framing"),
    (re.compile(r"\bgegen\s+den\s+Gr[üu]nder\s+pers[öo]nlich\b", re.I), "DE founder personal-liability framing"),
    (re.compile(r"\b(?:contre|condamnation\s+de)\s+le\s+fondateur\b", re.I), "FR founder liability framing"),
    (re.compile(r"\blegally\s+survivable\b", re.I), "panel panic phrase"),
    (re.compile(r"\breputationally\s+radioactive\b", re.I), "panel panic phrase"),
    (re.compile(r"\bnon[\-\s]?survivable\b", re.I), "panel panic phrase"),
    (re.compile(r"\bcompany[\-\s]?killing\b", re.I), "panel panic phrase"),
    (re.compile(r"\bMINT\s+(?:lied|lies)\b", re.I), "explicit accusation MINT lied"),
    (re.compile(r"\bSwiss\s+app\s+that\s+lied\b", re.I), "Kuketz-style explicit accusation"),
    (re.compile(r"\btextbook\s+(?:nFADP|nLPD|LSFin|FinSA|FDPIC)\b", re.I), "« textbook violation » framing"),
]

OVERRIDE_MARKER = "<!-- ALLOW-LEGAL-ADMISSION:"

# Strip Markdown emphasis (`*`, `_`) before matching so that `**violates
# nFADP**` is not bypassed by the `\b` boundary landing on `*`.
_EMPHASIS = re.compile(r"[*_`]+")


def _normalize(line: str) -> str:
    return _EMPHASIS.sub(" ", line)


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return list of (line_no, label, line_excerpt) for matches."""
    findings: list[tuple[int, str, str]] = []
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return findings
    for i, line in enumerate(text.splitlines(), start=1):
        if OVERRIDE_MARKER in line:
            continue
        normalized = _normalize(line)
        for pat, label in PATTERNS:
            if pat.search(normalized):
                excerpt = line.strip()[:180]
                findings.append((i, label, excerpt))
                break  # one finding per line is enough
    return findings


# File-path allowlist — these directories/files legitimately discuss risk
# patterns as instruction, examples, or historical archive. They are NOT
# forward-looking decision/audit artifacts that could be quoted as adverse
# admission. Excluded from scanning.
ALLOWLIST_PATTERNS: tuple[str, ...] = (
    # Research notes — defensive coding instructions, threat models,
    # risk tables. NOT admissions.
    "/research/",
    # Architecture design docs — describe system constraints, including
    # « if you do X, it's a violation » as instruction.
    "/architecture/",
    # Deep audits — legitimately discuss risk patterns + remediation.
    "/deep-audit-",
    # Archived milestones — historical state, not current claims.
    "/milestones/v2.0",
    "/_v2.7-archive/",
    "/archive/",
    "/archive-",
    # Coaching prompts that include « bad example » copy as a teaching
    # device. These should ideally be sanitized but are spec docs not
    # claims-against-MINT.
    "docs/W11_FIX_PROMPTS.md",
    "docs/VOICE_CURSOR_SPEC.md",
    # Pre-v2.2 archive
    "/_pre-v2.2-archive/",
)


def is_allowed(path: Path) -> bool:
    s = str(path).replace("\\", "/")
    return any(pat in s for pat in ALLOWLIST_PATTERNS)


def gather_targets(explicit: list[str] | None) -> list[Path]:
    if explicit:
        return [Path(p).resolve() for p in explicit if Path(p).exists()]
    out: list[Path] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for p in root.rglob("*.md"):
            if is_allowed(p):
                continue
            out.append(p)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--paths",
        nargs="*",
        help="Specific files to scan (default: all .md in .planning/, decisions/, docs/)",
    )
    args = ap.parse_args()

    targets = gather_targets(args.paths)
    if not targets:
        print("no_legal_admission: no targets to scan (clean by default)")
        return 0

    total_failures = 0
    for path in targets:
        findings = scan_file(path)
        if not findings:
            continue
        rel = path.relative_to(REPO) if path.is_absolute() else path
        for line_no, label, excerpt in findings:
            print(f"::error file={rel},line={line_no}::no_legal_admission: {label} — {excerpt}")
            total_failures += 1

    if total_failures:
        print()
        print(f"no_legal_admission: {total_failures} hit(s). Suggested rewrites:")
        print("  - « violates X » -> « tension à résoudre avec X »")
        print("  - drop specific monetary amounts -> « material risk »")
        print("  - « founder personally » -> « company »")
        print("  - drop panel-panic adjectives (« legally survivable », etc.)")
        print(
            "  - if a hit must stay (quoting an external source), append "
            "`<!-- ALLOW-LEGAL-ADMISSION: <reason> -->` on the line."
        )
        return 1

    print(f"no_legal_admission: scanned {len(targets)} doc(s), 0 hits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
