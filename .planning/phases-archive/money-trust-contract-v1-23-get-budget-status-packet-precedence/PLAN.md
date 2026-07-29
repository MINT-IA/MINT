# Phase 23 — get_budget_status Packet Precedence

## Goal
Remove the remaining split-brain risk where backend `get_budget_status` fallback could cite legacy flat budget values while the mobile packet carried trust-aware budget facts.

## Scope
- Prefer `profile_context.coach_context_packet` budget facts in `_format_budget_status`.
- Preserve legacy flat `monthly_income` / `monthly_expenses` behavior when no packet budget facts exist.
- Surface packet missing budget fields so the coach asks for confirmation instead of pretending completeness.

## Verification
- Targeted pytest on budget snapshot dispatcher, parity, sanitizer, and budget citation gate.
- Python compile checks.

