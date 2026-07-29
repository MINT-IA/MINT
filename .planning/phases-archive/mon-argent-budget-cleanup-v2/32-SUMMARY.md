# Phase 32 — Coach semantic budget packet

## Goal

Ensure persisted budget values survive the full chain into Coach semantic context.

## Findings

- A red test showed `q_net_income_period_chf = 5379` was reaching the Coach packet as `5588.17`, because the profile rebuilt net income from an estimated gross salary.
- Monthly-only consumer debt was visible as a budget charge, but Data Spine exposed `situation.total_debt = 0` instead of the existing 24-month estimated exposure expected by the data spine tests.

## Changes

- Added `CoachProfile.explicitMonthlyNetIncome`, persisted through JSON/copy/equality and populated from `q_net_income_period_chf`.
- Updated `BudgetInputs.monthlyNetFromCoachProfile()` so explicit net income is the household budget source of truth before gross-to-net estimation.
- Updated `DataSpineService` to expose an estimated 24-month debt exposure from monthly debt payments when no debt capital is known, with estimated metadata rather than user-input metadata.
- Added a deterministic `CoachLlmService.chat()` seam test proving persisted budget values reach `coachContextPacket`.

## Verification

- `flutter test test/services/coach_context_packet_payload_test.dart test/screens/budget_setup_screen_test.dart test/providers/budget/budget_provider_test.dart test/services/coach_profile_wizard_test.dart test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart`
- `flutter analyze lib/models/coach_profile.dart lib/domain/budget/budget_inputs.dart lib/services/data_spine/data_spine_service.dart test/services/coach_context_packet_payload_test.dart`
- `flutter analyze lib/models/coach_profile.dart lib/domain/budget/budget_inputs.dart lib/services/data_spine/data_spine_service.dart test/services/coach_context_packet_payload_test.dart test/services/data_spine_service_test.dart`
- `git diff --check`
- Claude Opus CLI review: high/medium findings addressed before commit.
