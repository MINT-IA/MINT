#!/usr/bin/env python3
"""CTX-03 audit (D-08): detect duplication between CLAUDE.md §5-7 (now mostly
split into docs/AGENTS/*.md) and .claude/skills/mint-*/SKILL.md.

Approach:
  - Split each source into non-empty paragraphs.
  - Compute pairwise Jaccard 5-gram similarity on word tokens.
  - Flag pairs ≥ threshold (default 0.6 per D-08 criterion) as likely duplicates.
  - Write a markdown report with a decisions template for manual PR review.

Scope (D-08, strict):
  Primary sources   : CLAUDE.md + docs/AGENTS/*.md
  Secondary sources : .claude/skills/mint-{swiss-compliance,flutter-dev,backend-dev}/SKILL.md

Per D-08, CLAUDE.md keeps a 1-line summary per skill ("Swiss compliance →
/mint-swiss-compliance"); detail migrates into the skill. Full re-architecture
skills ↔ CLAUDE.md is deferred v2.9+ (out of scope CTX).

Exit codes:
  0 — report written successfully (default mode)
  1 — --strict mode AND ≥1 high-similarity (>0.8) unresolved duplicate, or
      an input path is missing.
"""
from __future__ import annotations

import argparse
import re
import sys
from itertools import product
from pathlib import Path

REPORT_PATH = Path(
    ".planning/phases/30.6-context-sanity-advanced/audits/redundancy-audit.md"
)
CLAUDE_MD = Path("CLAUDE.md")
AGENTS_DIR = Path("docs/AGENTS")
SKILLS: list[Path] = [
    Path(".claude/skills/mint-swiss-compliance/SKILL.md"),
    Path(".claude/skills/mint-flutter-dev/SKILL.md"),
    Path(".claude/skills/mint-backend-dev/SKILL.md"),
]


def tokens(text: str) -> list[str]:
    """Word tokens, lowercased, unicode-friendly."""
    return re.findall(r"\w+", text.lower(), flags=re.UNICODE)


def ngrams(toks: list[str], n: int = 5) -> set[tuple[str, ...]]:
    """5-gram set; falls back to a single tuple for short paragraphs."""
    if len(toks) < n:
        return {tuple(toks)} if toks else set()
    return {tuple(toks[i : i + n]) for i in range(len(toks) - n + 1)}


def jaccard(a: set, b: set) -> float:
    if not a and not b:
        return 0.0
    union = a | b
    if not union:
        return 0.0
    return len(a & b) / len(union)


def paragraphs(path: Path) -> list[tuple[int, str]]:
    """Return [(starting_line, text)] for each non-empty paragraph of the file."""
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[tuple[int, str]] = []
    cur_start: int | None = None
    cur: list[str] = []
    for i, line in enumerate(lines, start=1):
        if line.strip():
            if cur_start is None:
                cur_start = i
            cur.append(line)
        elif cur:
            assert cur_start is not None
            out.append((cur_start, "\n".join(cur)))
            cur_start, cur = None, []
    if cur:
        assert cur_start is not None
        out.append((cur_start, "\n".join(cur)))
    return out


def run(threshold: float, strict: bool) -> int:
    # Build source dictionaries
    primary_sources: dict[Path, list[tuple[int, str]]] = {}
    primary_sources[CLAUDE_MD] = paragraphs(CLAUDE_MD)
    if AGENTS_DIR.exists():
        for f in sorted(AGENTS_DIR.glob("*.md")):
            primary_sources[f] = paragraphs(f)

    secondary_sources: dict[Path, list[tuple[int, str]]] = {}
    for s in SKILLS:
        secondary_sources[s] = paragraphs(s)

    # Pairwise comparison
    duplicates: list[tuple[str, int, str, int, float]] = []
    for (p_path, p_pars), (s_path, s_pars) in product(
        primary_sources.items(), secondary_sources.items()
    ):
        for p_line, p_text in p_pars:
            p_grams = ngrams(tokens(p_text))
            if not p_grams:
                continue
            for s_line, s_text in s_pars:
                s_grams = ngrams(tokens(s_text))
                if not s_grams:
                    continue
                sim = jaccard(p_grams, s_grams)
                if sim >= threshold:
                    duplicates.append(
                        (str(p_path), p_line, str(s_path), s_line, sim)
                    )

    duplicates.sort(key=lambda d: -d[4])

    # Report
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out: list[str] = []
    out.append("# CLAUDE.md ↔ mint-* skills — redundancy audit (D-08)")
    out.append("")
    out.append(f"**Threshold:** Jaccard 5-gram ≥ {threshold}")
    out.append(f"**Primary sources:** {CLAUDE_MD} + {AGENTS_DIR}/*.md")
    out.append(
        f"**Secondary sources:** " + ", ".join(str(s) for s in SKILLS)
    )
    out.append(f"**Candidates found:** {len(duplicates)}")
    out.append("")
    out.append("## Duplicates (ordered by similarity)")
    out.append("")
    out.append(
        "| # | Primary (CLAUDE.md / AGENTS) | Secondary (skill) | Similarity | Proposed action |"
    )
    out.append(
        "|---|------------------------------|--------------------|-----------|------------------|"
    )
    if duplicates:
        for i, (p_path, p_line, s_path, s_line, sim) in enumerate(
            duplicates[:50], start=1
        ):
            action = (
                "MOVE to skill (keep 1-liner in CLAUDE.md)"
                if sim > 0.8
                else "REVIEW manually"
            )
            out.append(
                f"| {i} | {p_path}:{p_line} | {s_path}:{s_line} | {sim:.2f} | {action} |"
            )
    else:
        out.append("| — | none | — | — | audit CLEAN |")
    out.append("")
    out.append("## Decisions (manual review)")
    out.append("")
    out.append(
        "Per D-08: CLAUDE.md keeps a 1-line summary per skill "
        "(\"Swiss compliance → `/mint-swiss-compliance`\"), detail migrates "
        "to the skill file. Full re-architecture skills ↔ CLAUDE.md = "
        "deferred v2.9+."
    )
    out.append("")
    out.append(
        "For each high-similarity duplicate (>0.8) above, Julien decides on PR review:"
    )
    out.append("")
    high = [d for d in duplicates if d[4] > 0.8]
    if high:
        for i, (p_path, p_line, s_path, s_line, sim) in enumerate(high, start=1):
            out.append(
                f"- [ ] #{i} ({sim:.2f}) — {p_path}:{p_line} ↔ {s_path}:{s_line}"
            )
            out.append("  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)")
            out.append("  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)")
            out.append("  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)")
    else:
        out.append(
            "_No high-similarity (>0.8) duplicates detected — audit passes clean; "
            "re-run after Phase 34 skills updates._"
        )
    out.append("")
    REPORT_PATH.write_text("\n".join(out), encoding="utf-8")

    if strict and high:
        print(
            f"strict: FAIL — {len(high)} high-similarity (>0.8) duplicate(s) unresolved. "
            f"See {REPORT_PATH}",
            file=sys.stderr,
        )
        return 1

    print(f"audit: wrote {REPORT_PATH} ({len(duplicates)} candidates)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "D-08 redundancy audit: CLAUDE.md + docs/AGENTS/*.md vs mint-* skills. "
            "Jaccard 5-gram similarity, writes markdown report + manual decisions template."
        )
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.6,
        help="Jaccard similarity threshold (D-08 criterion, default 0.6)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit 1 if any duplicate with similarity >0.8 exists and is unresolved",
    )
    args = parser.parse_args()
    return run(args.threshold, args.strict)


if __name__ == "__main__":
    sys.exit(main())
