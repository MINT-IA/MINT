---
name: mint-commit
description: Standardized git commit workflow for MINT. Use when committing changes, creating PRs, or pushing code. Enforces conventional commits, test verification, and Co-Authored-By attribution.
compatibility: Requires git.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Commit Workflow

## Before Committing

1. Run both test suites:
```bash
cd apps/mobile && flutter test
cd services/backend && pytest -q
```
2. Run linters:
```bash
cd apps/mobile && flutter analyze
cd services/backend && ruff check .
```
3. All must be green before committing.

## Commit Message Format

Use conventional commits:

```
type(scope): short description

Optional body with details.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Types
| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `test` | Test additions/fixes |
| `refactor` | Code restructuring (no behavior change) |
| `docs` | Documentation only |
| `chore` | Build, tooling, maintenance |
| `style` | Formatting, no logic change |

### Scopes
| Scope | When |
|-------|------|
| `fiscal` | Tax calculations, cantons, baremes |
| `lpp` | 2nd pillar, pension fund |
| `3a` | 3rd pillar |
| `wizard` | Wizard flow, questions |
| `budget` | Budget module |
| `tests` | Test-only changes |
| `ui` | UI components, screens |
| `backend` | Backend API, schemas |
| `compliance` | Legal/compliance wording |

### Examples

```bash
# Feature
git commit -m "$(cat <<'EOF'
feat(lpp): add rente vs capital simulator

Implement compute_rente_vs_capital() with break-even calculation.
5 test cases with hardcoded values from swiss-brain specs.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

# Bug fix
git commit -m "$(cat <<'EOF'
fix(fiscal): correct BS/GE cumulative threshold handling

Basel-Stadt and Geneva use cumulative thresholds instead of bracket
widths. Convert to widths at load time in TaxScalesLoader.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

# Tests
git commit -m "$(cat <<'EOF'
fix(tests): green suite 114/114 - fix GoRouter and wizard flow

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

## Git Rules

- **NEVER** force push to main
- **NEVER** amend published commits
- **NEVER** skip hooks (--no-verify)
- **NEVER** commit .env, credentials, or secrets
- **ALWAYS** stage specific files (not `git add .`)
- **ALWAYS** include Co-Authored-By
- Remote: `git@github.com:Julienbatt/MINT.git`
- Branch: `main` (single branch for now)

## PR Format (when branching)

```bash
gh pr create --title "feat(scope): short title" --body "$(cat <<'EOF'
## Summary
- Bullet 1
- Bullet 2

## Test plan
- [ ] Flutter: 114/114
- [ ] Backend: 59/59
- [ ] Manual smoke test

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
