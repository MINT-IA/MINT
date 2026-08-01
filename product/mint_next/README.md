# MINT Next — Batch 0 foundation

This directory is the small canonical contract for the proposed MINT rebuild.
It does not claim that the rebuild, the new mobile app, or the infrastructure
migration exists. Batch 0's foundation contract is `proven`; the bounded
promotion receipt does not promote any product runtime or Engram live cutover.

## Zero-trust rule

Agent summaries, plans, memories, screenshots, and author explanations are
leads, not completion evidence. Read current files and diffs, run deterministic
checks, obtain a non-author adversarial review, and execute the relevant user
journey before changing a batch from `unproven`.

## Batch order

1. Foundation contract, guards, memory recovery, agents, and skills.
2. Design Handoff audit and three tested creative directions.
3. First-value journey contract and prototype.
4. Only then create the sibling Flutter application.

## Engram and FUN2

The live database remains local. FUN2 currently holds an AES-256 encrypted
backup vault because direct SQLite operation inside the external sparsebundle
failed the first restore drill. The historical unencrypted recovery directory
on FUN2 is invalid and must not be reused. A live cutover is forbidden until
local restore, external backup, rollback, mount-loss, and independent-review
gates all pass.

## Guard

```bash
python3 tools/checks/mint_next_foundation_guard.py
python3 -m pytest tools/checks/tests/test_mint_next_foundation_guard.py -q
```
