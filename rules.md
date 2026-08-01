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

## Autonomous Tooling Authority

Agents may use the normal Mint toolchain without asking for per-tool
permission when it materially advances the current authorized objective:

- read repo-local, user-level, and plugin skill repositories when paths are
  present and readable;
- use Engram MCP tools (`mem_context`, `mem_search`, `mem_save`,
  `mem_session_summary`) for memory recovery and durable observations;
- run local checks, tests, lints, route guards, banned-term/accent/i18n guards,
  and read-only Git/GitHub inspection commands;
- use Maestro, `simctl`, `idb`, xcodebuildmcp / Build iOS Apps, screenshots,
  and runtime logs to produce simulator evidence;
- spawn available specialist subagents or review panels when the user asks for
  review, premerge, audit, or a task whose checked-in workflow requires a panel;
- create feature branches, commits, pushes to feature branches, and PR updates
  for the current authorized objective after diff review and required checks.

Do not stop merely because a tool was not mentioned in the latest prompt. If a
tool or skill is unavailable, cite the exact missing command/path/capability and
use the closest deterministic fallback.

Claude Max and external expert audits are advisory unless Julien explicitly
makes them a gate for the current task. Use them when a local CLI/session or
fresh audit artifact is available and the work is high-stakes; otherwise report
that they were unavailable and rely on the local panel, tests, and runtime
evidence. Never claim Claude Max, Maestro, Engram, or a panel was used unless
there is an actual tool call, command output, or artifact path.

## ALWAYS DO

- Read `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json` before
  product or code work.
- Run `python3 tools/checks/active_context_guard.py` at session start.
- Run `python3 tools/checks/phase_contract_guard.py` before executing a phase.
- Run `python3 tools/checks/mint_rules_guard.py` before committing workflow
  changes.
- Run `python3 tools/checks/journey_os_check.py` before Journey OS, vertical,
  issue-tracker, runtime-evidence, or workflow-guard changes.
- Run `python3 tools/checks/workflow_contract_guard.py` before workflow,
  agent-bootstrap, hook, or CI guard changes.
- Write the active phase `SPEC.md` before implementation.
- Use test-driven development for feature, bugfix, guard, and behavior changes.
- Verify the diff, not the explanation: `git diff --stat`, `git diff --check`,
  and focused tests before commit.
- Treat PR size as a dynamic review budget, not a fixed line cap. Always run
  `git diff --shortstat origin/dev...HEAD`; keep routine bugfix/doc/guard PRs
  around the small-PR budget, and when a coherent vertical legitimately exceeds
  it, isolate generated/evidence files and state in the PR why splitting would
  make review or rollback worse.
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
python3 tools/checks/journey_os_check.py
python3 tools/checks/workflow_contract_guard.py
python3 tools/checks/mint_next_foundation_guard.py
python3 tools/checks/mint_next_batch1_guard.py
python3 tools/checks/agent_reference_guard.py
python3 tools/checks/claude_hooks_guard.py
```
