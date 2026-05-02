#!/usr/bin/env python3
"""Public-repo discipline gate — no legal-admission language in committed docs.

While `MINT-IA/MINT` is a PUBLIC GitHub repository (decision: stay public for
GitHub Actions cost reasons until launch milestone), every committed `.md`
document inside `.planning/`, `decisions/`, `docs/` and PR descriptions is
publicly readable by anyone — including journalists (Kuketz / K-Tipp / Le Temps
tech), regulators (FDPIC / FINMA), plaintiff lawyers, and competitors.

Adverse admission patterns in such documents have been historically used as
gold-mine evidence in regulatory proceedings (cf. FDPIC Digitec Galaxus /
Ricardo precedents). This lint blocks committing forensic / panic / loaded
language that could be quoted out of context to manufacture a story or
support a complaint.

What this gate BLOCKS (forensic admission patterns):
  - « criminal exposure » / « risque pénal »
  - « violates nFADP » / « violates LSFin » / « violates FINMA »
  - « FDPIC violation » / « LSFin violation »
  - explicit founder personal-liability phrasing (e.g. « founder personally »,
    « CHF 250 000 contre le fondateur », « gegen den Gründer persönlich »)
  - panic/loaded panel language (« legally survivable »,
    « reputationally radioactive », « non-survivable », « MINT lied »,
    « company-killing »)

What this gate ALLOWS (benign regulatory citations):
  - « art. 6 nFADP » / « LSFin art. 8 » / « LAVS art. 21 » — citation only,
    no « violation » framing
  - « FDPIC », « nFADP », « FINMA » mentions in context
  - « contradiction » / « inconsistency » / « gap » as descriptive findings
  - normal compliance discussion (e.g. « to comply with art. X »)

Trigger: pre-commit (lefthook) on `.md` files under `.planning/`, `decisions/`,
`docs/`. Also runnable manually:

    python3 tools/checks/no_legal_admission_in_public_docs.py
    python3 tools/checks/no_legal_admission_in_public_docs.py --paths file1.md file2.md

Exit 0 on clean. Exit 1 with line diagnostic on fail. Override: prefix the
offending line with the comment `<!-- ALLOW-LEGAL-ADMISSION: reason -->` on
the same line — for legitimately needed forensic discussion that should
nonetheless not be public (those should be moved to a private notes vault).

Reference: `.planning/decisions/2026-05-02-data-residency.md` originally
contained these patterns and had to be sanitized post-ship by `c6b16229`.
This gate prevents that situation from recurring.
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

# Each pattern is (regex, label). Regex is case-insensitive. Use word
# boundaries where appropriate to avoid false positives ("applied", "lied
# about" → "lied" alone is too greedy without context).
PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"\bcriminal\s+exposure\b", re.I), "criminal exposure framing"),
    (re.compile(r"\brisque\s+p[ée]nal\b", re.I), "risque pénal explicit framing"),
    (re.compile(r"\bviolates?\s+(?:nFADP|LSFin|FINMA|LAVS|nLPD)\b", re.I), "explicit violation language"),
    (re.compile(r"\b(?:FDPIC|nFADP|nLPD|LSFin|FinSA)\s+violation\b", re.I), "regulator-violation framing"),
    (re.compile(r"\bart\.\s*60\s+(?:nFADP|nLPD|FADP)\b", re.I), "art. 60 nFADP citation (criminal article)"),
    (re.compile(r"\bCHF\s+250\s*[\.\s]?000\b", re.I), "CHF 250'000 personal-fine reference"),
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
        for pat, label in PATTERNS:
            if pat.search(line):
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
        print(
            f"❌ no_legal_admission: {total_failures} forensic / panic / loaded "
            f"language hit(s) found. The repo is currently PUBLIC; these phrases "
            f"would be quotable as adverse admission by a hostile journalist or "
            f"regulator. Suggested fixes:"
        )
        print(
            "  - Replace « violates X » with « tension à résoudre avec X »"
        )
        print(
            "  - Drop specific risk amounts (« CHF 250'000 ») — say « material risk »"
        )
        print(
            "  - Replace « founder personally » with « company »"
        )
        print(
            "  - Drop panel panic phrases (« legally survivable », etc.)"
        )
        print(
            "  - For legitimately-needed forensic discussion, move the file to a"
            " private notes vault (1Password / Notion private workspace) and remove"
            " from the public repo."
        )
        print(
            "  - If the phrase MUST stay (e.g. quoting an external source), prefix"
            " the line with `<!-- ALLOW-LEGAL-ADMISSION: <reason> -->` to whitelist"
            " explicitly."
        )
        return 1

    print(f"✓ no_legal_admission: scanned {len(targets)} doc(s), 0 forensic-language hits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
