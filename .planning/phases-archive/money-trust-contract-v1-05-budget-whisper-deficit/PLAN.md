# Money Trust Contract v1 — 05 Budget Whisper Deficit

Fix the Mon Argent coach whisper so it detects signed monthly cashflow deficits
from BudgetInputs, instead of reading the non-negative allocation amount.

## Goal

Make the Mon Argent coach whisper use the same signed cashflow logic as Budget
and PresentBudget when deciding whether the month is tight.

## Scope

- `CoachWhisperService` deficit rule.
- Focused unit test for a deficit month.

## Acceptance

- A month where charges exceed income triggers the deficit whisper.
- The rule does not depend on `BudgetPlan.available` being negative.
