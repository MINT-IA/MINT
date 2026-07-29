# Phase 22 Summary

## What Changed
- Added `tests/test_citation_gate/test_budget_absurdity_numbers.py`.
- Covered uncited rent, LAMal premium, tax saving, and percentage claims.
- Covered the positive path where a budget CHF amount has an adjacent allowed citation.

## Why
The reported failures were not only UI/calculation failures; they were trust failures. Even if an LLM invents a number, the backend gate must reject uncited financial quantities before rendering.

