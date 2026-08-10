# Canonical Lifelong User Twin Foundation — Specification

Status: `accepted`

## Human promise

When I choose to save what MINT learned about my housing, I can find it after a
relaunch, understand its source and period, correct it, delete it, and see every
dependent result become stale rather than silently wrong.

## Acceptance

- The North Star and mini-plan dependency are a Decided repository contract.
- New or touched capture screens require a machine-checked fact lifecycle.
- One explicit confirmation saves the complete housing bundle atomically.
- Housing-only data hydrates after relaunch and unrelated profile facts survive.
- Stored facts carry source, assertion time, schema version and tax year where applicable.
- The user can see, edit and delete the owned housing bundle.
- Safe exit and kill-switch exit write nothing.
- Secure persistence failure is visible/fail-closed; no success copy or exit lies.
- No cloud transmission is introduced.
- Six-language copy parity, targeted tests and simulator proof cover the same flow.
- One independent bounded roast reports no reproducible P1/P2 before promotion.

## Exclusions

No new calculator, fiscal result, provider comparison, document extraction,
bank/API integration, general profile migration, backend event-log cutover or
mini-plan runtime.

```verify
workflow-contract: python3 tools/checks/workflow_contract_guard.py
capture-contract: python3 tools/checks/user_data_capture_contract.py --base-ref origin/dev
journey-os: python3 tools/checks/journey_os_check.py
mobile-targeted: cd apps/mobile && flutter test test/models/mint_next_housing_fact_test.dart test/providers/coach_profile_provider_housing_fact_test.dart test/screens/mint_next_housing/mint_next_housing_screen_test.dart
```
