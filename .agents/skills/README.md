# `.agents/skills/` — universal-agent skills

Imported skills that work across multiple agent CLIs (Claude Code, Cursor, Copilot, etc.).

Distinct from `.claude/skills/` which holds Claude-Code-specific skills (`mint-flutter-dev`, `mint-backend-dev`, etc.).

## Currently installed

| Skill | Source | Purpose | Why imported |
|-------|--------|---------|--------------|
| [flutter-fix-layout-issues](flutter-fix-layout-issues/SKILL.md) | github.com/flutter/skills | RenderFlex / unbounded-constraint debugging | Pure complement to MINT's mint-flutter-dev — used on-demand when layout errors happen |
| [flutter-add-integration-test](flutter-add-integration-test/SKILL.md) | github.com/flutter/skills | integration_test package setup + Flutter Driver | Maestro complement — in-process integration tests for fast inner loops |

## NOT imported (deliberate)

Per audit `.planning/audit/codebase-audit-2026-05-10/flutter-skills-evaluation.md`, these flutter/skills entries are NOT adopted:

| Skill | Why not |
|-------|---------|
| `flutter-apply-architecture-best-practices` | Conflicts with locked MINT decisions: pushes MVVM/`lib/data,domain,ui/` ≠ MINT's `screens/widgets/services` |
| `flutter-setup-declarative-routing` | go_router already setup at `apps/mobile/lib/router/` (locked) |
| `flutter-setup-localization` | l10n already setup at `apps/mobile/lib/l10n/` (6 ARBs locked) |
| 5 others | Off-stack or redundant with MINT's existing skills |

## Update procedure

```bash
# Refresh from upstream
gh api repos/flutter/skills/contents/skills/<skill-name>/SKILL.md --jq '.download_url' | xargs curl -fsSL > .agents/skills/<skill-name>/SKILL.md
```
