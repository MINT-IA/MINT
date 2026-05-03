---
name: claude-code-discipline
description: Load the 14 disciplines (engineering + context engineering + tool discoverability) for AI-assisted development. Manual trigger via /claude-code-discipline. Composes with obra/superpowers (does not replace). Use at session start for any non-trivial project work.
---

# claude-code-discipline

This skill installs **awareness** of the 14 disciplines from the [Claude Code Discipline Kit](https://github.com/julienbatt/claude-code-discipline-kit). It is a manual-trigger skill: invoke at session start, then operate under the disciplines for the rest of the session.

## Why this is manual-trigger (not auto)

Auto-trigger would collide with `obra/superpowers/using-superpowers` (also auto-trigger) → nondeterministic order and double-loading. Manual trigger means YOU control when discipline awareness loads, and the act of invoking is itself a recitation (discipline 11).

## When to invoke

- At the start of any session that will touch code (1 invocation per session is enough)
- Before starting a new phase or major task
- After a long compaction event when context has been summarized
- Whenever a sub-agent dispatched returns and you want to re-anchor

## What the skill does when invoked

1. State the 14 disciplines in compact form (not the full doc — that lives in `docs/DISCIPLINES.md`)
2. Detect the project's active tooling (superpowers, GSD, gstack, kit) and announce the composition map
3. Run `bin/tool-census.sh --underused` (if the kit is installed in the project) and surface the top 3 underused tools
4. Confirm: "Disciplines loaded. Operating under R/P/I + Iron Law + < 40% utilization. Type /tool-census to re-surface tools mid-session."

## The 14 disciplines (compact recitation)

**Engineering (1-7):**
1. Plan-mode before code (≥ 3 decisions or ≥ 2 files)
2. Iron Law: no fix without root cause + 3-Fix Rule
3. Subagents (≥ 10 files or ≥ 3 work pieces)
4. TDD inverted: RED-GREEN-REFACTOR
5. Verification-before-completion (evidence > assertions)
6. Design / code-review panel before merge
7. HTML evidence per phase (durable cross-session memory)

**Context engineering (8-13):**
8. Context utilization < 40% in permanence
9. Research / Plan / Implement as 3 separate artifacts
10. KV-cache stability (stable prefix, append-only, deterministic, mask-not-remove, TTL 1h, monitor)
11. Recitation pattern for long-running goals
12. Keep errors in context (counter-intuitive — let the model learn)
13. Avoid few-shot drift on repetitive tasks (controlled variation)

**Discoverability (14):**
14. Tool census + utilization tracking (the meta-discipline that ensures 1-13 actually get used)

## Composition with other skills

| Detected | Defer to | Augment with |
|---|---|---|
| `obra/superpowers` | Disciplines 1-7 (TDD, plan, debug, verify) | Disciplines 8-14 + universal lints |
| GSD (`gsd-*`) | Discipline 9 R/P/I → gsd-discuss-phase / gsd-plan-phase / gsd-execute-phase | Disciplines 8, 10-14 |
| `gstack` | Voice triggers, lifecycle | Universal lints + bootstrap mechanics |
| Nothing else | — | All 14 from this kit |

## Anti-pattern this skill explicitly prevents

"I read the kit docs once 3 weeks ago and now operate from memory." Memory drift is the rule, not the exception. Recitation per session is the discipline. The skill is the recitation mechanism.

## Sister tools in the kit

- `bin/tool-census.sh` — surface underused tools (discipline 14)
- `bin/doctor.sh` — diagnose project's discipline state
- `lints/lint_status_audit.py` — every lint must be classified (CI / pre-commit / manual)
- `templates/CLAUDE.md.en.template` — base CLAUDE.md with marker blocks for project-specific rules
- `templates/lefthook.discipline.yml` — additive lefthook overlay (never overwrites)
