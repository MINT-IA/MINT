# Customization

The kit ships base disciplines that are language- and domain-agnostic. To add project-specific rules without losing them on kit upgrades, use **marker blocks**.

## Marker blocks in CLAUDE.md

After running `bootstrap.sh --apply`, your project root has a `CLAUDE.md` with these sentinels:

```markdown
<!-- discipline:project-specific:begin -->

## Project-specific NEVER list (your rules here)

1. NEVER do X — reason
2. NEVER use Y — reason

## Project-specific allowlist (paths, tools, conventions)

- Foo
- Bar

<!-- discipline:project-specific:end -->
```

**Everything between the begin/end markers is yours.** The kit will never overwrite or reorder it on upgrade. Anything outside the markers is kit-managed and may be replaced.

## Adding project-specific lints

Drop your lint script into `tools/checks/your_project_lint.py`, then update `tools/checks/STATUS.md`:

```markdown
| Lint | Status | Wired in |
|---|---|---|
| your_project_lint.py | enforced-pre-commit | lefthook.yml |
```

`lints/lint_status_audit.py` enforces that every script in `tools/checks/` has an entry. No silent dead lints.

## Adding project-specific skills

Add under `.claude/skills/your-project-skill/SKILL.md`. Follow Anthropic's frontmatter format:

```markdown
---
name: your-project-skill
description: One-line trigger description used by the model to decide invocation
---

# Skill body
```

Then run `bin/tool-census.sh` to register it in the project's tool inventory.

## Composing with `obra/superpowers`

If superpowers is installed:
- The kit defers disciplines 1-7 to superpowers' skills (`using-superpowers`, `test-driven-development`, `verification-before-completion`, etc.)
- Your project's `CLAUDE.md` can reference superpowers skills directly:

```markdown
## How we work

For TDD, use superpowers' test-driven-development skill.
For debugging, use superpowers' systematic-debugging skill.
For context engineering, use claude-code-discipline (this kit, manual trigger).
```

## Composing with GSD

If GSD is installed (`gsd-*` skills):
- The kit maps Research/Plan/Implement (discipline 9) to:
  - `gsd-discuss-phase` (sometimes `gsd-research-phase`) → produces RESEARCH.md
  - `gsd-plan-phase` → produces PLAN.md
  - `gsd-execute-phase` → executes
- The kit defers phase mechanics to GSD; only adds disciplines 8, 10-14 and the universal lints.

## Customizing the language

V1 ships EN-only templates. If your project's `CLAUDE.md` is in another language, write the project-specific block (between markers) in your language. The kit-managed sections stay EN.

V0.4 will add `--lang=fr|de|es` flag to bootstrap.sh.

## Per-project tool census configuration

Edit `tools/checks/tool_census.config` (created by bootstrap):

```ini
# Directories to scan for tools
scan_dirs = .claude/skills/ tools/checks/ tools/walker/ scripts/

# Skills to always show even if recently used (high-value reminders)
always_surface = mint-swiss-compliance mint-flutter-dev

# Skills to never surface (deprecated / experimental)
hide = experimental-foo legacy-bar

# Last-invocation log path (the kit doesn't write this; your sessions do)
usage_log = .claude/usage/invocations.log

# Threshold for "underused": days since last invocation
underused_after_days = 30
```

## Upgrading the kit

```bash
cd path/to/your/project
~/path/to/claude-code-discipline-kit/bin/bootstrap.sh --apply
```

Behavior:
- Files inside marker blocks: preserved
- Files outside marker blocks: replaced if checksum differs from previous template
- New kit-managed files: added
- Removed kit-managed files: dropped (with warning)
- Your custom files in `tools/checks/`, `.claude/skills/your-*`: never touched

The lock file `.claude-code-discipline.lock` records the kit version installed and the checksums of every kit-managed file at install time.
