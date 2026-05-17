#!/usr/bin/env python3
"""Adopt selected VoltAgent subagents into .claude/agents/.

One-shot adoption script (delete after PR merge). Fetches 20 curated VoltAgent
files from `VoltAgent/awesome-claude-code-subagents`, normalizes frontmatter
(model: opus + memory: local, drop tools line), prepends the engram contract
body block, writes to `.claude/agents/<name>.md`.

Same pattern used for the wshobson 36 adoption (PR S99.2, 2026-05-14).
7 specialists left non-adopted (compliance-auditor, legal-advisor,
fintech-engineer, quant-analyst, risk-manager, refactoring-specialist,
accessibility-tester) — coverage already provided by wshobson security-auditor
+ architect-review + legacy-modernizer + accessibility-expert + VoltAgent
business-analyst. Adopt case-by-case if a real gap appears in the composite
PR-review panel (cf. CLAUDE.md §3.5 routing).
"""
from __future__ import annotations

import base64
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = "VoltAgent/awesome-claude-code-subagents"
AGENTS_DIR = Path(__file__).resolve().parents[2] / ".claude" / "agents"

ADOPT: list[tuple[str, str]] = [
    ("02-language-specialists", "flutter-expert"),
    ("04-quality-security", "ai-writing-auditor"),
    ("04-quality-security", "qa-expert"),
    ("04-quality-security", "ui-ux-tester"),
    ("05-data-ai", "llm-architect"),
    ("05-data-ai", "nlp-engineer"),
    ("05-data-ai", "postgres-pro"),
    ("06-developer-experience", "mcp-developer"),
    ("06-developer-experience", "git-workflow-manager"),
    ("07-specialized-domains", "payment-integration"),
    ("08-business-product", "business-analyst"),
    ("08-business-product", "product-manager"),
    ("08-business-product", "technical-writer"),
    ("08-business-product", "ux-researcher"),
    ("09-meta-orchestration", "agent-organizer"),
    ("09-meta-orchestration", "knowledge-synthesizer"),
    ("09-meta-orchestration", "multi-agent-coordinator"),
    ("10-research-analysis", "competitive-analyst"),
    ("10-research-analysis", "market-researcher"),
    ("10-research-analysis", "search-specialist"),
]

ENGRAM_BLOCK = """## Persistent memory (engram MCP)

This subagent has persistent memory across sessions via the `plugin:engram:engram` MCP server.

**Before starting** : `mem_search "<file/topic/area>" --project mint` to recall past findings on the surface you're about to touch. Note the `obs_id` of any hit and cite it via `prior_finding_refs` if your new finding builds on it.

**After each non-trivial finding** : `mem_save "<title>" "<message>" --type <decision|architecture|bugfix|pattern|discovery> --project mint --topic_key <area>:<sub-area>:<specific>` so future invocations inherit the context. Convention `topic_key` agent-agnostic so other subagents can lookup.

**Compounding observable** (Phase 1 gate 2026-05-21) : ≥3 of first 5 PRs reviewed must include ≥1 finding citing a prior `obs_id` via `prior_finding_refs`. This is how we measure that the team is learning across PRs, not re-discovering the same patterns.

**Project context** : MINT = Swiss financial lucidity app (Flutter mobile + FastAPI backend). Read `CLAUDE.md` (project root) for the 6 critical rules, 10 NEVER triplets, and architecture before applying generic patterns to MINT code.

---

"""

FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n(.*)\Z", re.DOTALL)


def fetch_raw(category: str, name: str) -> str:
    out = subprocess.run(
        ["gh", "api", f"repos/{REPO}/contents/categories/{category}/{name}.md", "--jq", ".content"],
        capture_output=True,
        text=True,
        check=True,
    )
    return base64.b64decode(out.stdout.strip()).decode("utf-8")


def normalize(raw: str, agent_name: str) -> str:
    m = FRONTMATTER_RE.match(raw)
    if not m:
        sys.exit(f"[FATAL] {agent_name}: no frontmatter detected — skipping for manual inspection")
    fm_raw, body = m.group(1), m.group(2)

    fields: list[tuple[str, str]] = []
    for line in fm_raw.split("\n"):
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip()
        if key in {"name", "description"}:
            fields.append((key, val))

    name_present = any(k == "name" for k, _ in fields)
    desc_present = any(k == "description" for k, _ in fields)
    if not (name_present and desc_present):
        sys.exit(f"[FATAL] {agent_name}: missing name or description in frontmatter")

    fields_dict = dict(fields)
    fields_dict["model"] = "opus"
    fields_dict["memory"] = "local"

    fm_lines = [
        f"name: {fields_dict['name']}",
        f"description: {fields_dict['description']}",
        f"model: {fields_dict['model']}",
        f"memory: {fields_dict['memory']}",
    ]

    return "---\n" + "\n".join(fm_lines) + "\n---\n\n" + ENGRAM_BLOCK + body.lstrip("\n")


def main() -> int:
    AGENTS_DIR.mkdir(parents=True, exist_ok=True)
    for category, name in ADOPT:
        target = AGENTS_DIR / f"{name}.md"
        if target.exists():
            print(f"[SKIP] {name} already exists at {target.relative_to(AGENTS_DIR.parents[1])}")
            continue
        raw = fetch_raw(category, name)
        adapted = normalize(raw, name)
        target.write_text(adapted, encoding="utf-8")
        size_kb = len(adapted) / 1024
        print(f"[OK]   {name:30s} ({category:25s} {size_kb:5.1f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
