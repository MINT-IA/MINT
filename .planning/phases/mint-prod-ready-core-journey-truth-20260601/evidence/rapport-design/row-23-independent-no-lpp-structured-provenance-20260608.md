# Row 23q - independent/no-LPP structured provenance

Date: 2026-06-08

## Scope

This proof tightens CJT-063 for the audited `independent_no_lpp` Coach 3a
scenario. It proves that the Coach answer can render structured per-field
source, freshness, confidence, and update date for the key financial facts
already carried by the canonical profile/data-spine path:

- `independentNetProfessionalIncomeAnnual`
- `plannedContributions.3a`
- alias `annual_3a_contribution`

It does not close runtime VoiceOver/focus traversal. Row 23p remains the
active proof path for physical-device VoiceOver validation.

## Change

- `CoachContext` now carries `dataReliabilityDetails` alongside the existing
  `dataReliability` source map.
- `CoachContextProfileMapper.dataReliabilityDetails(...)` converts existing
  `CoachProfile.dataSources` and `CoachProfile.dataTimestamps` into structured
  metadata using Data Spine vocabulary:
  - `source`
  - `confidence`
  - `freshness`
  - `updatedAt`
- `CoachLlmService` and `CoachChatScreen` now pass these details into
  `CoachContext`.
- The independent/no-LPP local Coach answer renders these details inside the
  visible `Provenance et fraîcheur` section:
  - `fraîcheur: fraîche`
  - `confiance: déclarative` for user-entered facts
  - `mise à jour: YYYY-MM-DD`
- If metadata is absent, the answer still says the date by field is not shown
  instead of pretending certainty.

## Proof Commands

Run from `apps/mobile` unless noted.

```bash
flutter test test/services/coach/local_fallback_service_test.dart test/services/coach_context_packet_payload_test.dart test/screens/coach/coach_chat_test.dart
flutter analyze
flutter test test/services/e2e_runtime_flags_test.dart test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart
```

Run from repo root.

```bash
python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
./tools/mint-routes check
git diff --check
```

## Result

- Targeted Coach suite: `All tests passed` (`92` pass, `5` existing skipped in
  `coach_chat_test.dart` output group).
- `flutter analyze`: no issues found.
- Runtime flag, Budget, Rapport/Banks smoke suite: `69/69` passed.
- `mint_quality_os_check`: OK.
- `cjt_context_guard`: OK.
- `maestro_locator_audit`: `47` flows scanned, `529` locators, all resolve.
- `mint-routes check`: `145` routes parity OK after known exemptions.
- `git diff --check`: no whitespace errors.

## Explicit Limits

- This is a local/profile-context and widget-level proof. It does not prove
  live backend/LLM scoring.
- It does not prove iOS platform AX traversal or VoiceOver focus order.
- It does not add user-facing content beyond the audited local
  independent/no-LPP Coach answer.
- CJT-063 / Row 23 remains `PARTIAL`.
