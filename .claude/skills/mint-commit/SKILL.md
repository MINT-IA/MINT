---
name: mint-commit
description: Standardized git commit workflow for MINT. Use when committing changes, creating PRs, or pushing code. Enforces branch flow, conventional commits, test verification, and Co-Authored-By attribution.
compatibility: Requires git, gh CLI.
metadata:
  author: mint-team
  version: "2.1"
---

# MINT Commit Workflow

## Branch Flow (NON-NEGOTIABLE)

```
feature/* ──PR──> dev ──PR──> staging ──PR──> main
```

- **Feature branches**: `feature/S{XX}-<slug>` (branch from `dev`)
- **Hotfix branches**: `hotfix/<description>` (branch from `dev`)
- **Direct push to `dev`**: allowed (but feature branches preferred)
- **Direct push to `staging` or `main`**: BANNED (always via PR)
- **Force push**: BANNED everywhere

### PR base rules
| From | Base (`--base`) |
|------|-----------------|
| `feature/*` or `hotfix/*` | `dev` |
| `dev` (promotion) | `staging` |
| `staging` (promotion) | `main` |

**NEVER** create a PR from a feature branch directly to `staging` or `main`.

### Merge strategy (IMPORTANT)
| PR type | Strategy | Why |
|---------|----------|-----|
| `feature→dev` | **Squash merge** (`--squash`) | Clean history, 1 commit per feature |
| `dev→staging` | **Merge commit** (`--merge`) | Preserves SHAs, no resync needed |
| `staging→main` | **Merge commit** (`--merge`) | Same: avoids SHA divergence |

Using merge commits for promotions means `main` contains all SHAs from `staging` which contains all SHAs from `dev`. No manual resync required.

## Before Committing

1. Confirm branch: `git branch --show-current` (must be feature/* or dev, NEVER staging/main)
2. Run test suites:
```bash
cd apps/mobile && flutter analyze && flutter test
cd services/backend && pytest -q
```
3. All must be green before committing.

## Commit Message Format

```
type(scope): short description

Optional body with details.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

Always use HEREDOC for the message:
```bash
git commit -m "$(cat <<'EOF'
type(scope): short description

Body here.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### Types
| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `test` | Test additions/fixes |
| `refactor` | Code restructuring (no behavior change) |
| `docs` | Documentation only |
| `chore` | Build, tooling, CI/CD, maintenance |
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
| `web` | Web app (lib/web/) |
| `backend` | Backend API, schemas |
| `compliance` | Legal/compliance wording |
| `infra` | CI/CD, branch protection, workflows |

## Git Rules

- **NEVER** force push (`git push --force` is BANNED)
- **NEVER** amend published commits
- **NEVER** skip hooks (`--no-verify`)
- **NEVER** commit `.env`, credentials, or secrets
- **ALWAYS** stage specific files (not `git add .` or `git add -A`)
- **ALWAYS** include `Co-Authored-By`
- **ALWAYS** show `git status` before committing
- **ALWAYS** use `--rebase` on pull (no merge commits)
- **ALWAYS** delete feature branches after merge (local + remote)
- Remote: `git@github.com:MINT-IA/MINT.git`

## PR Format (feature → dev)

```bash
gh pr create --base dev --title "feat(scope): short title" --body "$(cat <<'EOF'
## Summary
- Bullet 1
- Bullet 2

## Test plan
- [ ] flutter analyze (0 issues)
- [ ] flutter test
- [ ] pytest -q

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Promotion PRs

### dev → staging
```bash
# Get last version
gh pr list --state merged --base main --limit 1 --json title -q '.[0].title'
# Create PR with incremented version
gh pr create --base staging --title "Staging to vX.Y.Z" --body "..."
# Auto-merge with MERGE COMMIT (not squash!)
gh pr merge --auto --merge
```

### staging → main
```bash
gh pr create --base main --title "Production to vX.Y.Z" --body "..."
# Do NOT auto-merge — manual merge only (production safety)
# When merging on GitHub: select "Create a merge commit" (not squash!)
```

### Version numbering
| Position | Meaning | Example |
|----------|---------|---------|
| X (Major) | Breaking change, architecture overhaul | v2.0.0 |
| Y (Minor) | New feature, new screen, new service | v1.3.0 |
| Z (Patch) | Bug fix, optimization, UI improvement | v1.3.2 |
| Suffix a,b... | Urgent hotfix post-release | v1.3.2a |
