# Agent Architecture — Specialists vs Generalists vs Orchestrator

> The question every team building with Claude Code hits in month 2: "we have 100+ tools — should we let agents discover them dynamically and pick experts, or pre-equip specialist agents with fixed toolsets?"
>
> **Answer:** both, in three layers. Pure dynamic = expensive + non-deterministic. Pure specialist = brittle + maintenance burden. The right architecture is layered.

## The three layers

```
┌────────────────────────────────────────────────────────────────┐
│ LAYER 3 — Tool-aware Orchestrator (the main agent, you)        │
│ Sees: full tool census                                         │
│ Decides: spawn specialist OR generalist OR work directly       │
│ Invariant: this layer ALWAYS runs the discipline-kit checks    │
└─────────────────────────┬──────────────────────────────────────┘
                          │
              ┌───────────┴────────────┐
              ▼                        ▼
┌──────────────────────────┐  ┌──────────────────────────────────┐
│ LAYER 1 — Specialists    │  │ LAYER 2 — Generalists            │
│ (Pre-equipped agents)    │  │ (Dynamic-tool agents)            │
│                          │  │                                  │
│ • Fixed system prompt    │  │ • System prompt = role + tool    │
│ • Fixed toolset          │  │   census + "pick what you need"  │
│ • Cacheable (KV hit)     │  │ • Adapts to new/unknown tools    │
│ • Versioned, PR-reviewed │  │ • Used for exploration / novel   │
│ • Used for ~60% of work  │  │   problems                       │
│ • Patterns:              │  │ • Patterns:                      │
│   - mint-security-audit  │  │   - general-purpose (Anthropic)  │
│   - mint-i18n-extract    │  │   - Explore (read-only research) │
│   - gsd-security-auditor │  │   - Plan (architect)             │
│   - gsd-ui-checker       │  │ • Used for ~30% of work          │
└──────────────────────────┘  └──────────────────────────────────┘
```

The remaining 10% = main agent works directly because dispatch overhead > task size.

## Layer 1 — Specialist agents (pre-equipped)

**When to use:** repeated, well-understood patterns where the playbook is stable.

**Examples already in the wild:**
- `gsd-security-auditor` — fixed scope (threat model verification), fixed tools (Read, Grep, Bash), fixed output (`SECURITY.md`)
- `gsd-ui-checker` — fixed 6-pillar audit, structured BLOCK/FLAG/PASS verdicts
- `mint-flutter-dev` — fixed conventions (MintUI kit, GoRouter, Provider), fixed lints to satisfy
- Anthropic's `code-reviewer` (in some configurations) — fixed review rubric

**Properties:**
- **KV-cache friendly:** stable system prompt = high cache hit rate (discipline 10)
- **Predictable cost:** known token budget per invocation
- **Versioned:** the agent definition (SKILL.md or AGENT.md) lives under git, gets PR-reviewed when changed
- **Composable:** orchestrator chains them (research-agent → plan-agent → impl-agent → verify-agent)
- **Maintainable:** when a new tool arrives, you decide WHICH specialists get access (additive)

**Anti-patterns:**
- Creating a specialist for a one-off task (≤ 3 invocations expected) — overhead > value
- Specialist with bloated toolset (loses the cache + clarity benefit)
- Specialist whose definition isn't PR-reviewed — drift accumulates silently

**How to define a specialist agent (Claude Code skill format):**

```markdown
---
name: mint-security-audit
description: Run the MINT security audit checklist (FINMA + LSFin + nLPD). Returns SECURITY.md with PASS/FLAG/BLOCK per requirement.
allowed_tools: [Read, Grep, Bash, Write]
---

# Role
You are the MINT Security Auditor. Your scope is fixed: ...

# Tools you have
Read — for source files
Grep — for pattern scanning  
Bash — for running existing scripts (tools/checks/no_e2ee_overclaim.py, etc.)
Write — for SECURITY.md output ONLY

# Process (fixed playbook)
1. ...
2. ...

# Output schema
SECURITY.md with these sections: ...
```

## Layer 2 — Generalist agents (dynamic)

**When to use:** novel problems, exploration, ambiguous tasks where the playbook isn't obvious.

**Examples:**
- Anthropic's `general-purpose` agent — gets a tool list, picks what's relevant
- `Explore` — read-only research agent for codebase questions
- `Plan` — software-architect agent for designing implementation plans
- Custom `<your-domain>-explorer` you spin up when entering a new area

**Properties:**
- **Adaptive:** can use tools added since the agent was defined
- **Lower KV-cache hit:** system prompt varies (depends on tool census), worse cost at scale
- **Less predictable:** good for exploration, bad for production-critical paths
- **Easier to evolve:** no per-tool agent updates needed when toolset grows

**Anti-patterns:**
- Using a generalist for a known repeatable task (waste — should be a specialist)
- Generalist with no access to tool-census output (then it's blind to its own toolkit)

**Augmenting with discipline:** every generalist invocation should include in its system prompt:

```
Before starting: invoke /tool-census --suggest "{your_task}" mentally and consider 
whether a specialist agent would do this faster/cheaper. If yes, return the suggestion 
as your first action instead of starting work.
```

This makes generalists self-routing: they upgrade themselves to specialists when one exists.

## Layer 3 — Orchestrator (the main agent)

**This is you (Claude in the main thread) most of the time.**

The orchestrator's job:
1. **Census awareness** — know what specialists exist, what tools exist, what's installed
2. **Routing decision** — given a task, decide: specialist? generalist? do it myself?
3. **Composition** — chain agents (R/P/I = 3 specialists in pipeline)
4. **Synthesis** — integrate agent outputs without re-reading their exploration (discipline 8: < 40% utilization)
5. **Discipline enforcement** — apply the 14 disciplines on every dispatch decision

**Routing heuristic:**

| Task properties | Route to |
|---|---|
| Known pattern + ≥ 3 invocations expected + repeated | Specialist (build one if missing) |
| Novel / one-off + needs many tools | Generalist with tool-census in prompt |
| Novel + < 5 tool calls | Main agent direct |
| Cross-cutting (security, performance, UX) | Specialist if exists, else create |
| Code review / second opinion | Specialist (independent context for unbiased view) |
| Long exploration that would saturate main context | Generalist sub-agent (returns 1-2K summary) |

## The meta-discipline: agent census (parallel of tool census)

**Discipline 14 extends to agents:** the agents you forgot you defined are agents you can't dispatch.

`bin/tool-census.sh` should also enumerate:
- `.claude/agents/*.md` — project-defined agents
- `.claude/skills/*` with `subagent_type` semantics — skills that double as agents

V0.2 of the kit will add `bin/agent-census.sh` (or extend `tool-census.sh --agents`) with:
- Last-spawned date per agent
- Average tokens consumed per spawn (from log)
- Outcome quality (if scored — manual or via downstream check)
- Suggestion: agents not spawned in 90 days = candidate for retirement

## Other architectural patterns worth considering

### Hooks as enforcement (settings.json `PreToolUse` / `PostToolUse`)

Hooks let you FORCE a check before/after any tool call. Use sparingly — they're powerful but hidden:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit",
        "command": "if [[ $TOOL_FILE_PATH == *lib/screens/* ]]; then bash bin/design-panel-required.sh; fi"
      }
    ]
  }
}
```

This is how you make discipline 6 (design panel before merge) STRUCTURAL rather than aspirational.

### MCP servers as a third tooling layer

Beyond skills/scripts/lints, MCP (Model Context Protocol) servers expose remote/dynamic tools uniformly. For MINT, the `mint-tools` MCP exposes `get_swiss_constants`, `check_banned_terms`, `validate_arb_parity`. These are **always-available, structured-input tools** — different from skills (instruction-loading) and scripts (one-off execution).

A complete tooling architecture has all four:

| Layer | Purpose | Example |
|---|---|---|
| Skills | Load instructions/playbooks into agent context | `mint-flutter-dev` |
| Scripts | One-off automated checks | `tools/checks/accent_lint_fr.py` |
| MCP servers | Always-on structured tools | `mint-tools.get_swiss_constants` |
| Agents | Isolated execution context | `gsd-security-auditor` |

Tool census should enumerate all four.

### Structured outputs (JSON schema enforcement)

Specialist agents should return structured outputs (JSON or strict markdown schema). The orchestrator parses them and acts. Without structure, every agent integration becomes free-form text parsing — fragile.

```markdown
# In the specialist's SKILL.md:
## Output schema (required)

Return EXACTLY this JSON:
{
  "verdict": "PASS" | "FLAG" | "BLOCK",
  "evidence": [{"file": "...", "line": 123, "issue": "..."}],
  "next_actions": ["..."]
}
```

### Agent memory (cross-session persistence)

Anthropic's `memory_20250818` tool lets a specialist agent maintain state across sessions:
- "What we tried that didn't work" survives → discipline 12 errors-in-context becomes cross-session
- User preferences refined over weeks
- Tool census results cached

Use sparingly: memory file growth = same context-rot risk as long conversations.

### Don't install every marketplace

The skill marketplaces have collectively > 1500 skills (Anthropic + obra + gstack + GSD + autoresearch + many more). Installing all of them produces a tool-census output of 200+ items that no one reads → discoverability collapses.

**Discipline:** review-then-install. Each marketplace gets a 30-min review before adoption. Question per skill: "would I PR this if it landed in our repo?" If no → don't install.

## Summary recommendation

**For MINT specifically (180+ skills already installed):**

1. **Run tool-census audit** (Phase 56 candidate, see below) — identify the underused 90%
2. **Retire** dormant skills (> 90 days unused) unless flagged "in case of emergency"
3. **Promote frequently used patterns to specialists** — if you reach for the same 3-tool combo 5×, build the specialist
4. **Add agent-census** when V0.2 of the kit ships
5. **Use hooks for the 5-7 most critical disciplines** (design panel, banned terms, accent lint) — make them structural, not aspirational

**For new projects bootstrapped from this kit:**

- Start with Layer 3 (orchestrator) only
- Add Layer 1 specialists as patterns repeat (don't pre-build, observe then specialize)
- Add Layer 2 generalists when entering a new domain
- Census + retire quarterly

The architecture grows with you. Don't ship 50 specialists on day 1 — most will rot.
