# `.agents/skills/` — MINT canonical skills

This is the canonical cross-tool skill source for Mint. Claude, Codex, and any
other agent runner should prefer `.agents/skills/mint-*` over generated or
vendor skill caches.

Mint canonical skills:

| Skill | Purpose |
|-------|---------|
| [mint-operating-gates](mint-operating-gates/SKILL.md) | Runtime, auth, privacy, onboarding, and release gates |
| [mint-flutter-dev](mint-flutter-dev/SKILL.md) | Flutter changes in `apps/mobile/` |
| [mint-backend-dev](mint-backend-dev/SKILL.md) | Backend changes in `services/backend/` |
| [mint-swiss-compliance](mint-swiss-compliance/SKILL.md) | Swiss finance and compliance review |

Imported skills remain available on-demand. They are not default routing.

## Currently installed

| Skill | Source | Purpose | Why imported |
|-------|--------|---------|--------------|
| [flutter-fix-layout-issues](flutter-fix-layout-issues/SKILL.md) | github.com/flutter/skills | RenderFlex / unbounded-constraint debugging | Pure complement to MINT's `frontend-developer` / `mobile-developer` agents — used on-demand when layout errors happen |
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
