---
created: 2026-05-05T11:34:01.177Z
title: Audit MINT skills against Rezvani 5-step prompt-to-skill conversion pattern
area: tooling
files:
  - .claude/skills/mint-swiss-compliance/
  - .claude/skills/mint-flutter-dev/
  - .claude/skills/mint-backend-dev/
  - .claude/skills/mint-test-suite/
  - .claude/skills/mint-review-pr/
  - .claude/skills/mint-office-hours/
  - .claude/skills/mint-retro/
  - .claude/skills/mint-audit-complet/
  - .claude/skills/mint-commit/
  - .claude/skills/mint-phase-audit/
  - .claude/skills/autoresearch-*/
---

## Problem

Rezvani's article (Photo.pdf shared 2026-05-05) audited 40 popular prompts against three production-skill criteria:

1. **Enforceable constraints** — every "do NOT" / "must" must be a hard instruction the agent follows, not a suggestion.
2. **Repeatable structure** — input/output contract is consistent; downstream workflows depend on it.
3. **Context independence** — works without the user re-explaining the situation each time. "Describe your situation" / "specify your goal" is the hallmark of a prompt that should stay a prompt.

Only 12 of the 40 survived. MINT has ~60 skills under `.claude/skills/` — `mint-*` (9), `autoresearch-*` (11), `gsd-*` (~40). We've never audited them against this filter. Likely failure modes:

- Skills that read like prose checklists with "check for X" suggestions instead of hard instructions ("Flag any raw SQL query without parameterized inputs, classify severity as Critical/High/Medium/Low, show the exact fix" pattern).
- Skills that lack output-format enforcement — they hope for structure rather than enforce explicit field names.
- Skills that depend on the user pasting the error / code / context, instead of autonomously gathering it via Read/Grep/Glob.
- Drift hotspots where the agent diagnoses correctly through Steps 1–3 then forgets the constraint at Step 4 (Rezvani's debug-diagnostician fix: duplicate the constraint at the decision point).

## Solution

5-step conversion pattern to apply to each skill:

1. **Extract enforceable constraints** — every "do NOT" / "must" → frontmatter or explicit instruction block. Duplicate the rule at the decision point where drift happens (Rezvani's anti-drift trick).
2. **Define input contract** — what happens when stack trace / code / context is missing? Search codebase, ask, or fail explicitly. No silent assumption.
3. **Enforce output format** — explicit field names (`**Category:**`, `**Severity:**`, `**Location:**`, `**Problem:**`, `**Fix:**`), not prose description.
4. **Remove context dependencies** — replace "describe your situation" with autonomous gathering (Read/Grep/Glob calls baked into the skill body).
5. **Test against edge cases** — does the skill produce consistent output when inputs are partial / missing / ambiguous?

Article surfaces 12 high-leverage skill candidates (production-grade): code-reviewer, debug-diagnostician, test-generator, architecture-advisor, documentation-writer, refactoring-planner, root-cause-analyzer, api-designer, database-schema-designer, decision-matrix, risk-assessor, retrospective-facilitator. Cross-check MINT inventory against these — we already have analogues for several (`mint-review-pr` ≈ code-reviewer, `mint-test-suite` ≈ test-generator, `mint-audit-complet` ≈ retrospective-facilitator, `mint-retro` ≈ retrospective-facilitator).

**Anti-pattern flag** — the article is explicit that 18 of the 40 prompts should NEVER become skills (headline generators, apology crafters, email drafting, "specify your goal" SWOT). The test: if it requires live human context (emotional nuance, situational judgment, subjective quality assessment), keep it a prompt. Reject any conversion proposal that violates this.

**Output of the audit (deliverable):**
- `.planning/decisions/2026-MM-DD-skill-hardening-audit.md` — per-skill verdict (HARDEN / KEEP-AS-IS / DELETE-OR-DOWNGRADE-TO-PROMPT) with reasoning.
- PR list ordered by leverage: which skills to harden first based on (a) frequency of use × (b) drift severity × (c) blast radius if it produces wrong output.
- Skill template applying the 5-step pattern + Rezvani's "duplicate constraint at decision point" anti-drift trick.

**When to do this:** post TestFlight ship. Don't pre-empt active work (current branch `fix/sim-walkthrough-crash-loop` and the post-handoff2 sweep panel). Surface this todo when next at a quiet point in the GSD loop or when a skill misbehaves and the root cause is "the constraint wasn't enforceable."
