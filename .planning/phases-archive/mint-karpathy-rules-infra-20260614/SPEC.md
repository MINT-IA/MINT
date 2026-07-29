# Mint Karpathy Rules Infra Spec

## User Promise

When a future Mint session starts, the agent should know the current authority,
the phase contract, the verification rules, and the hard boundaries without
Julien having to re-explain them.

## Required Behavior

1. The active phase has four files:
   - `CONTEXT.md`
   - `SPEC.md`
   - `PLAN.md`
   - `VERIFICATION.md`
2. `rules.md` is structured into:
   - `ALWAYS DO`
   - `ASK FIRST`
   - `NEVER DO`
3. Claude bootstrap explicitly reads:
   - `AGENTS.md`
   - `CLAUDE.md`
   - `docs/MINT_AGENT_WORKFLOW.md`
   - `.planning/ACTIVE_CONTEXT.md`
   - `.planning/ACTIVE_CONTEXT.json`
4. Hooks block drift:
   - stale active context;
   - missing active phase contract;
   - missing rule registry sections;
   - bootstrap that skips the active router.
5. CI runs the same lightweight planning guards on PRs.

## Forbidden Behavior

- Product code changes in this phase.
- A rule that exists only as prose if it can be cheaply checked.
- A future phase without `SPEC.md`.
- Claude bootstrap that starts from old `decisions/` or stale phase docs before
  the active router.
- Claims that this proves product UX or runtime behavior.

## Acceptance Criteria

- `python3 tools/checks/active_context_guard.py`
- `python3 tools/checks/phase_contract_guard.py`
- `python3 tools/checks/mint_rules_guard.py`
- `python3 tools/checks/agent_reference_guard.py`
- `python3 tools/checks/claude_hooks_guard.py`
- `python3 tools/checks/verify_phase_acceptance.py`
- `python3 -m pytest tools/checks/tests/test_active_context_guard.py tools/checks/tests/test_phase_contract_guard.py tools/checks/tests/test_mint_rules_guard.py tools/checks/tests/test_agent_reference_guard.py tools/checks/tests/test_claude_hooks_guard.py tools/checks/tests/test_verify_phase_acceptance.py -q`
- `python3 tools/checks/wiki_lint.py index`
- `python3 tools/checks/wiki_lint.py`
- `git diff --check`

```verify
# tier: deterministic
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
mint-rules: python3 tools/checks/mint_rules_guard.py
agent-reference: python3 tools/checks/agent_reference_guard.py
claude-hooks: python3 tools/checks/claude_hooks_guard.py
guard-tests: python3 -m pytest tools/checks/tests/test_active_context_guard.py tools/checks/tests/test_phase_contract_guard.py tools/checks/tests/test_mint_rules_guard.py tools/checks/tests/test_agent_reference_guard.py tools/checks/tests/test_claude_hooks_guard.py tools/checks/tests/test_verify_phase_acceptance.py -q
# tier: device
simulator-not-required: true
```

## Golden Fixtures

The guard tests are the golden fixtures for this infra phase:

- valid active phase contract passes;
- missing `SPEC.md` fails;
- missing manifest context fails;
- valid rules registry and bootstrap pass;
- missing `ASK FIRST` fails;
- missing financial provenance rule fails;
- bootstrap without active context fails.

## Out-of-Scope Verification

No iPhone simulator gate is required because this phase changes no mobile
runtime behavior. The next product phase must still use simulator proof.
