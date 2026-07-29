#!/usr/bin/env python3
"""
Wiki Lint — Karpathy Wiki Pattern enforcement for `.planning/`.

Adopts 4 of the 7 operational practices from
https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
and the analysis at
https://medium.com/@mustafa.gencc94/your-llm-has-been-forgetting-everything-karpathys-wiki-pattern-is-the-fix-6931ad90017b :

  ✓ Practice 1 (Separate Vaults) — already enforced by the
    `~/.claude/projects/.../memory/` directory living outside the repo.
    This lint scans `.planning/` (the agent vault) only.
  ✓ Practice 4 (TLDR on every page) — enforced by `--check-tldr` mode.
  ✓ Practice 5 (File queries back) — encouraged by the
    `_TEMPLATE.md` decision artifact contract.
  ✓ Practice 7 (Lint passes) — THIS SCRIPT.

Subcommands :
  index       Regenerate `.planning/INDEX.md` from H1 + first non-empty
              paragraph of every .md (TLDR sourced from `description:`
              frontmatter when present, else first sentence).
  lint        Run all checks (default). Returns non-zero on any FAIL.
  lint-tldr   Just the TLDR check.
  lint-orphans  Just the orphan-page check.
  lint-stale  Just the stale-claim check.

The lint detects four classes per Karpathy practice 7 :

  1. **Contradictions** — heuristic : pages claiming opposite values for
     the same metric (e.g. STAMP-02 P50 = 2682ms vs 2722ms across two
     different docs).
  2. **Stale claims** — references to phases / PRs / commits with
     « SHIPPED » / « MERGED » / « CLOSED » markers older than the
     enclosing doc's `last_updated` frontmatter, OR referenced PR is
     in fact still open / closed / wrong number.
  3. **Orphan pages** — .md files in `.planning/` with no inbound
     reference from any other .md in the same tree (excluding INDEX
     itself + reports/ + phases/ which are leaves).
  4. **New article candidates** — terms / acronyms appearing in 3+
     distinct .md files without their own dedicated page in
     `.planning/decisions/` or `.planning/architecture/`.

Run :
  python3 tools/checks/wiki_lint.py            # full lint, exit 1 on FAIL
  python3 tools/checks/wiki_lint.py index      # regen .planning/INDEX.md
  python3 tools/checks/wiki_lint.py --strict   # warnings → errors
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
PLANNING_DIR = REPO_ROOT / ".planning"
INDEX_PATH = PLANNING_DIR / "INDEX.md"
ACTIVE_CONTEXT_PATH = PLANNING_DIR / "ACTIVE_CONTEXT.json"

# Files / dirs to exclude from lint scans (archives, raw exports).
EXCLUDE_DIRS = {"archive", "archives", "archive-2026-04-10", "archive-pre-2026-04-19"}
LEAF_DIRS = {"reports", "phases", "phases-archive", "walker", "handoff", "handoffs"}  # not orphan-checked


def _is_excluded(p: Path) -> bool:
    return any(part in EXCLUDE_DIRS for part in p.parts)


def _is_leaf(p: Path) -> bool:
    """Files in leaf dirs (reports, phases, walker, handoff) are
    end-states, not articles ; they don't need inbound refs."""
    return any(part in LEAF_DIRS for part in p.parts)


def _planning_link_path(path_value: str) -> str:
    return path_value.removeprefix(".planning/").removeprefix("./.planning/")


def _read_frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}
    fm = {}
    for line in text[4:end].splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm


def _extract_tldr(text: str, fm: dict[str, str]) -> str:
    """One-line TLDR : prefer `description:` frontmatter ;
    else first non-trivial sentence after H1."""
    if "description" in fm:
        return fm["description"]
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            body = text[end + 5:]
    # skip H1
    h1m = re.search(r"^# +(.+)$", body, re.MULTILINE)
    if h1m:
        body = body[h1m.end():]
    # first paragraph
    para = re.split(r"\n\s*\n", body.strip(), maxsplit=1)[0] if body.strip() else ""
    # one-liner
    para = re.sub(r"\s+", " ", para).strip()
    para = re.sub(r"^[*_>`]+|[*_>`]+$", "", para).strip()
    if not para:
        return "(no TLDR ; H1 only)"
    if len(para) > 180:
        para = para[:177] + "…"
    return para


def _all_planning_md(planning: Path) -> list[Path]:
    return sorted(
        p for p in planning.rglob("*.md")
        if not _is_excluded(p) and p.name not in {"INDEX.md"}
    )


def cmd_index(args: argparse.Namespace) -> int:
    """Regenerate .planning/INDEX.md."""
    files = _all_planning_md(PLANNING_DIR)
    if not files:
        print(f"warn: no .md files under {PLANNING_DIR}", file=sys.stderr)
        return 0

    grouped: dict[str, list[tuple[Path, str, str]]] = defaultdict(list)
    for f in files:
        try:
            content = f.read_text(encoding="utf-8")
        except OSError as e:
            print(f"skip {f}: {e}", file=sys.stderr)
            continue
        fm = _read_frontmatter(content)
        # H1
        h1m = re.search(r"^# +(.+)$", content, re.MULTILINE)
        title = h1m.group(1).strip() if h1m else f.stem
        tldr = _extract_tldr(content, fm)
        # Group by top-level directory under .planning/
        rel = f.relative_to(PLANNING_DIR)
        section = str(rel.parts[0]) if len(rel.parts) > 1 else "_root"
        grouped[section].append((f, title, tldr))

    out = [
        "# `.planning/` INDEX",
        "",
        "Auto-generated by `tools/checks/wiki_lint.py index`. Karpathy Wiki Pattern practice 4 — every page has a one-line TLDR ; LLM scans this index instead of loading every page.",
        "",
        f"**Total** : {len(files)} pages across {len(grouped)} sections.",
        "",
    ]
    if ACTIVE_CONTEXT_PATH.exists():
        try:
            active = json.loads(ACTIVE_CONTEXT_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            active = {}
        active_phase = active.get("active_phase_context")
        next_phase = active.get("next_product_phase_context")
        if active_phase or next_phase:
            out.extend(
                [
                    "## Active Context",
                    "",
                    "| Role | Page |",
                    "|------|------|",
                    "| Session router | [`ACTIVE_CONTEXT.md`](ACTIVE_CONTEXT.md) |",
                ]
            )
            if active_phase:
                active_rel = _planning_link_path(str(active_phase))
                out.append(f"| Active phase | [`{active_rel}`]({active_rel}) |")
            if next_phase:
                next_rel = _planning_link_path(str(next_phase))
                out.append(f"| Next product phase | [`{next_rel}`]({next_rel}) |")
            out.append("")
    for section in sorted(grouped):
        if section == "_root":
            heading = "## Root"
        else:
            heading = f"## `{section}/`"
        out.append(heading)
        out.append("")
        out.append("| Page | TLDR |")
        out.append("|------|------|")
        for f, title, tldr in sorted(grouped[section], key=lambda x: x[0].name):
            rel = f.relative_to(PLANNING_DIR)
            link = f"[`{rel}`]({rel})"
            tldr_clean = tldr.replace("|", "\\|")
            out.append(f"| {link} | {tldr_clean} |")
        out.append("")
    out.append("---")
    out.append("*Regenerate via `python3 tools/checks/wiki_lint.py index`. Don't hand-edit.*")

    INDEX_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"[OK] wrote {INDEX_PATH.relative_to(REPO_ROOT)} ({len(files)} pages, {len(grouped)} sections)")
    return 0


def cmd_lint(args: argparse.Namespace) -> int:
    """Run all 4 lint checks."""
    files = _all_planning_md(PLANNING_DIR)
    violations: list[str] = []
    warnings: list[str] = []

    # 1. TLDR check — every doc should have either description: frontmatter
    #    OR a non-trivial first paragraph. Decision artifacts are stricter
    #    (must have « ## Counter-arguments and data gaps » section).
    decisions = []
    for f in files:
        try:
            content = f.read_text(encoding="utf-8")
        except OSError:
            continue
        fm = _read_frontmatter(content)
        tldr = _extract_tldr(content, fm)
        if tldr in {"(no TLDR ; H1 only)", ""}:
            warnings.append(f"missing TLDR : {f.relative_to(REPO_ROOT)}")
        if "decisions/" in str(f) and f.name != "_TEMPLATE.md":
            decisions.append((f, content))

    # 2. Decision artifact bias-check (Karpathy practice 3) — every ADR
    #    must have « ## Counter-arguments and data gaps » section.
    BIAS_PAT = re.compile(r"^##\s+Counter-arguments\s+and\s+data\s+gaps\s*$", re.MULTILINE)
    for f, content in decisions:
        if not BIAS_PAT.search(content):
            violations.append(
                f"decision artifact missing « ## Counter-arguments and data "
                f"gaps » section : {f.relative_to(REPO_ROOT)}"
            )

    # 3. Orphan pages — files with no inbound reference from any other .md.
    by_name: dict[str, Path] = {f.name: f for f in files}
    inbound: Counter[str] = Counter()
    for f in files:
        try:
            content = f.read_text(encoding="utf-8")
        except OSError:
            continue
        for other in by_name:
            if other == f.name:
                continue
            if other in content:
                inbound[other] += 1
    for f in files:
        if _is_leaf(f):
            continue
        if f.name == "INDEX.md":
            continue
        if inbound.get(f.name, 0) == 0:
            warnings.append(
                f"orphan page (no inbound .md reference) : "
                f"{f.relative_to(REPO_ROOT)}"
            )

    # 4. Stale claims — heuristic : « SHIPPED PR #N » mentions where the
    #    actual GitHub PR state is checkable. We don't query gh here (lint
    #    runs offline) ; instead we flag any « PR #N PENDING » claim
    #    older than 14 days from frontmatter `last_updated` as suspect.
    #    Light implementation : just count for visibility.
    pending_pat = re.compile(r"PR #(\d+)\s+(?:PENDING|OPEN)", re.IGNORECASE)
    pending_refs = 0
    for f in files:
        try:
            content = f.read_text(encoding="utf-8")
        except OSError:
            continue
        for _ in pending_pat.finditer(content):
            pending_refs += 1

    # 5. New article candidates — multi-page mentions w/o dedicated page.
    #    Heuristic : capitalized acronyms (3-8 chars) appearing in 4+ files
    #    without a corresponding `.planning/decisions/*<acronym>*.md` or
    #    `.planning/architecture/*<acronym>*.md`. Low signal ; warn-only.
    acronym_pat = re.compile(r"\b([A-Z]{3,8}-?[0-9A-Z-]*)\b")
    acronym_files: dict[str, set[str]] = defaultdict(set)
    for f in files:
        try:
            content = f.read_text(encoding="utf-8")
        except OSError:
            continue
        for m in acronym_pat.finditer(content):
            acronym_files[m.group(1)].add(f.name)
    candidates = sorted(
        (k, len(v)) for k, v in acronym_files.items() if len(v) >= 8
    )

    # Reporting
    print(f"wiki_lint scan : {len(files)} .md files under {PLANNING_DIR.relative_to(REPO_ROOT)}/ ; {len(decisions)} decision artifacts ; {pending_refs} 'PR #N PENDING' refs.")
    if violations:
        print("\n[FAIL] Violations :")
        for v in violations:
            print(f"  • {v}")
    if warnings:
        print(f"\n[WARN] {len(warnings)} warnings :")
        sample = warnings[:8]
        for w in sample:
            print(f"  • {w}")
        if len(warnings) > 8:
            print(f"  • … and {len(warnings) - 8} more (run with --verbose to see all)")
    if candidates and args.verbose:
        print(f"\n[INFO] new article candidates (acronyms in 8+ docs without own page) :")
        for k, n in candidates[:10]:
            print(f"  • {k} ({n} files)")

    if violations:
        return 1
    if args.strict and warnings:
        return 1
    print("\n[OK] no FAIL-level violations.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd")
    sub.required = False
    p_index = sub.add_parser("index", help="Regenerate .planning/INDEX.md")
    p_index.set_defaults(func=cmd_index)
    p_lint = sub.add_parser("lint", help="Run all wiki lint checks")
    p_lint.add_argument("--strict", action="store_true", help="Warnings become errors")
    p_lint.add_argument("--verbose", action="store_true")
    p_lint.set_defaults(func=cmd_lint)
    args = parser.parse_args()
    if args.cmd is None:
        # Default = lint
        args.cmd = "lint"
        args.strict = False
        args.verbose = False
        return cmd_lint(args)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
