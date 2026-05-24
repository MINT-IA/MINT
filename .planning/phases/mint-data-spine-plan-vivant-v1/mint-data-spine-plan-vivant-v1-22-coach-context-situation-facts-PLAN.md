# Plan 22 — Coach context situation facts

## Goal
Inject core financial situation amounts into the coach context packet.

## Scope
- Add gross annual income, liquid savings, and total debt to the allowlisted facts.
- Keep sensitive/raw profile fields excluded.
- Do not change coach prompting or backend contracts in this phase.

## Acceptance
- `CoachContextPacketService` emits the three situation facts when present.
- Existing packet privacy tests still pass.
- Analyze, Data Spine/coach tests, design lints, and diff check stay green.

