# Phase 28 — Summary

## Changed

- `tests/test_narrator_refuses_uncited_numbers.py` is no longer a skipped placeholder.
- It now exercises `/api/v1/coach/chat` with `COACH_CITATION_GATE_ENABLED=True`.
- The mocked narrator emits `19'272'200 CHF` without citation on the first answer and retry.

## Why

Mint trust cannot rely only on parser-level tests. The user-facing endpoint must prove that an absurd uncited CHF amount is blocked before it reaches Flutter.

## Result

The endpoint retries once, then returns `FALLBACK_TEMPLATED_TEXT`. The absurd CHF amount is absent from the response.
