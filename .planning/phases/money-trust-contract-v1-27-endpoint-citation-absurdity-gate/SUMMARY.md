# Phase 27 — Summary

## Changed

- Added `TestCoachChatCitationGate.test_endpoint_blocks_uncited_absurd_budget_numbers`.

## Result

The endpoint-level test now proves that if the narrator emits:

- `19'272'200 CHF`
- `420'420 CHF`

without citations, the endpoint performs the retry-once flow and returns safe fallback text instead of exposing the numbers.
