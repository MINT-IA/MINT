# Tool Discovery

> The tools you don't know you have are the tools you can't use. The tools you don't track aren't really installed.

## The problem

Long-lived projects accumulate tooling layer-by-layer:

- Claude Code skills (built-in + installed marketplaces)
- Project-specific skills (`.claude/skills/your-project-*`)
- Lint scripts (`tools/checks/`, `scripts/`)
- MCP servers (`.mcp.json`)
- Pre-commit hooks (`lefthook.yml`)
- CI gates (`.github/workflows/`)
- Walker / E2E harnesses
- Documentation generators

A typical 18-month-old project: 100-200 discoverable tools. The active operator uses ~10%. The other 90% rot, then someone reinvents a worse version of an existing tool because they didn't know it existed.

This is the silent killer of AI-assisted productivity. You install superpowers (14 high-value skills), GSD (~80 skills), the kit (14 disciplines + skills), gstack (~23 skills), and within a month you've forgotten that `gsd-debug` exists when a bug strikes — so you grep manually for an hour.

## The discipline

**Discipline 14 (Tool census + utilization tracking):** every project must inventory its discoverable tools AND track which ones get invoked. Surface underused tools at session start, weighted by relevance to the current goal.

## How `tool-census.sh` works

```bash
bin/tool-census.sh                     # Print full inventory + usage stats
bin/tool-census.sh --underused         # Print tools never used or used > 30d ago
bin/tool-census.sh --suggest "<task>"  # Suggest 3 most-relevant underused tools for a task
bin/tool-census.sh --json              # Machine-readable for CI / dashboards
```

The script:
1. Enumerates `.claude/skills/`, `tools/`, `scripts/`, `.mcp.json`, `lefthook.yml`, `.github/workflows/`
2. For each tool, extracts: name, description (from SKILL.md frontmatter or top-of-file comment), last-modified date
3. Cross-references against `.claude/usage/invocations.log` (if present) for last-invocation date
4. Categorizes: `active` (used < 7d), `recent` (7-30d), `underused` (30-90d), `dormant` (> 90d), `never` (no record)
5. Prints sorted by category

## Wiring it into your workflow

### At session start (manual)

In your `CLAUDE.md`, add:

```markdown
## Session start checklist

1. Run `bin/tool-census.sh --suggest "$INITIAL_TASK"` — review 3 suggested underused tools relevant to the task
2. Decide: use one of them, or proceed with manual approach (and justify)
```

### As a slash command (semi-automated)

Create `.claude/commands/census.md`:

```markdown
---
description: Surface 3 underused tools relevant to the user's next task
---

Run `bin/tool-census.sh --suggest "{{user_task}}"` and present the top 3 results to the user before starting work.
```

Then `/census <task>` at the start of any non-trivial task.

### As a CI gate (high-discipline)

Add to `.github/workflows/discipline-gates.yml` (V0.2 will ship this template):

```yaml
- name: Tool census check
  run: |
    bash bin/tool-census.sh --json > tool_census.json
    NEVER_USED=$(jq '[.[] | select(.category == "never")] | length' tool_census.json)
    if [ "$NEVER_USED" -gt 10 ]; then
      echo "::warning::$NEVER_USED tools have never been used. Consider pruning or surfacing them."
    fi
```

## Logging tool invocations

The kit doesn't write the usage log — your shell + Claude session integrations do. Recommended:

```bash
# In your shell rc:
log_tool_use() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$PROJECT_ROOT/.claude/usage/invocations.log"
}
```

Or use Claude Code hooks (V0.3 will ship a sample `PostToolUse` hook that auto-logs).

## What "underused" really means

- **Underused tool, high value, never invoked** → either rename for discoverability, or write a one-line "when to use me" hint in the description, or delete it
- **Underused tool, low current value** → delete it. Tool cemeteries are worse than no tools.
- **Underused tool used once, valuable** → surface periodically; it's a "in case of emergency, break glass" pattern

The goal is **honest inventory**, not maximum tool count.

## Anti-patterns

- ❌ Install 5 skill marketplaces, never read their indexes — cargo cult
- ❌ Build a custom lint that duplicates an existing one because you didn't grep `tools/checks/`
- ❌ Spend 1 hour grepping when `gsd-debug` would have run a 4-phase systematic investigation in 5 minutes
- ❌ "We have a skill for that, somewhere" — somewhere = nowhere

## The MINT example

Julien's MINT project has installed:
- `obra/superpowers` (~14 skills)
- `gstack` (~23 skills)
- GSD (~80 skills, prefix `gsd-*`)
- MINT-specific (`mint-*`, ~10 skills)
- Autoresearch (`autoresearch-*`, ~10 skills)
- Plus this kit (~3 skills)

Total: ~140 skills. Realistic active usage without discipline: 10-15. Discipline target after one tool-census audit: 40-50 active, 30 recent, 20 underused with intentional flagging, ~50 retired.

Do the audit. The result is sobering. The cleanup is liberating.
