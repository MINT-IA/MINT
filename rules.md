# Mint Rules

These rules are the highest repo-local operating contract. They are split by
enforcement level so agents know what can run autonomously, what needs Julien's
explicit confirmation, and what must be refused.

## Authority Order

1. `rules.md`
2. `CLAUDE.md`
3. `AGENTS.md`
4. `docs/MINT_AGENT_WORKFLOW.md`
5. `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json`
6. `.planning/STATE.md`
7. Current phase `CONTEXT.md`, `SPEC.md`, `PLAN.md`, `VERIFICATION.md`
8. Domain docs, code, tests, scripts, and generated contracts
9. Engram project `mint` as memory, never as higher authority than repo files

If sources disagree, stop product work, cite both paths, and fix the stale
source instead of guessing.

## ALWAYS DO

- Read `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json` before
  product or code work.
- Run `python3 tools/checks/active_context_guard.py` at session start.
- Run `python3 tools/checks/phase_contract_guard.py` before executing a phase.
- Run `python3 tools/checks/mint_rules_guard.py` before committing workflow
  changes.
- Write the active phase `SPEC.md` before implementation.
- Use test-driven development for feature, bugfix, guard, and behavior changes.
- Verify the diff, not the explanation: `git diff --stat`, `git diff --check`,
  and focused tests before commit.
- Save Engram via `mem_save` after durable decisions, discoveries,
  conventions, and bug fixes.
- Use simulator/runtime evidence before claiming mobile user flow quality.
- Keep financial calculations in the canonical financial engine or backend
  service named by the active phase.

## ASK FIRST

- Merge or push `dev`, `staging`, or `main`.
- Promote `dev -> staging` or `staging -> main`.
- Add a new financial formula, regulatory constant, or calculation source.
- Add a new dependency with runtime, security, billing, or bundle-size impact.
- Change auth, Keychain, secure storage, reset, account deletion, or Apple
  entitlement behavior.
- Archive historical planning directories.
- Touch public legal, privacy, or compliance claims.
- Use real staging data or any non-synthetic personal data in fixtures.

## Branch Flow

```text
feature/* -> dev -> staging -> main
```

- Use `feature/S{XX}-<slug>` for normal feature branches from `dev`.
- Use `hotfix/<description>` for hotfix branches from `dev`.
- Merge `feature/* -> dev` with squash merge.
- Merge `dev -> staging` and `staging -> main` with merge commits.
- Never open a feature branch PR directly to `staging` or `main`.

## NEVER DO

- Show a financial number without provenance, assumptions, confidence/readiness,
  missing fields, and calculation or constant version.
- Recode financial calculations in UI code.
- Ship an AI/LLM path without golden fixtures or evaluator evidence.
- Use a silent fallback that hides drift.
- Create a service, widget, route, or helper without a real caller.
- Make an Apple-only auth path.
- Claim simulator proof as device proof.
- Promise financial, fiscal, legal, investment, or product outcomes.
- Force-push, run `git reset --hard`, `git checkout --`, or `git clean` unless
  Julien explicitly asks for that exact destructive operation.
- Use `claude --dangerously-skip-permissions` in the real Mint repo.

## Standard Commands

Backend:

```bash
cd services/backend
ruff check .
pytest -q
```

Mobile:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Planning guards:

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/agent_reference_guard.py
python3 tools/checks/claude_hooks_guard.py
```
