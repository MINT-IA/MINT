# CJT-008 — LPP scan to profile proof

Date: 2026-06-03

## Finding

The previous scan-review Maestro flow could show extracted LPP data and tap a weak `.*Confirmer.*` matcher without proving that the user reached the post-confirm impact screen or that the extracted LPP values survived a profile reload into the Data Spine and coach packet.

During runtime triage, the weak matcher was confirmed as risky: it can match the intro copy `avant de confirmer` before the real bottom CTA. The flow now uses bounded swipes through the long 14-field LPP review and taps the exact button label `Confirmer et enrichir mon profil`.

## Code Changes

- Added `apps/mobile/test/providers/coach_profile_provider_lpp_extraction_test.dart`.
- Hardened `tools/simulator/flows/maestro-perfect-set/flow_lpp_scan_review.yaml` so it proves:
  - `/scan` renders.
  - Debug LPP fixture reaches `/scan/review`.
  - LPP total balance appears on the review screen.
  - The real confirm CTA is tapped.
  - The user reaches `DocumentImpactScreen`.
  - The review screen is unmounted.

No app feature code was changed for this closure.

## Runtime Evidence

Green Maestro run:

- Command: `MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=90 bash tools/simulator/maestro_with_watchdog.sh test --format junit --output <evidence>/result.xml tools/simulator/flows/maestro-perfect-set/flow_lpp_scan_review.yaml`
- Evidence: `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/scan-profile/cjt-008-lpp-scan-review-20260603T081312/`
- Result: `1/1 Flow Passed in 28s`
- JUnit: `tests=1`, `failures=0`
- Exit code: `0`
- Screenshots:
  - `01-scan-screen.png`
  - `02-lpp-type-selected.png`
  - `03-example-tapped.png`
  - `04-extraction-review.png`
  - `05-impact-screen.png`

The final screenshot shows `Ton profil est plus précis`, the confidence delta, and LPP values visible in `Ce que Mint voit` including total balance, mandatory/supplementary parts, insured salary, and contribution rate.

## Contract Evidence

Flutter tests:

- Command: `cd apps/mobile && flutter test test/providers/coach_profile_provider_lpp_extraction_test.dart test/providers/coach_profile_provider_tax_extraction_test.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart --reporter=expanded`
- Result: `35 passed`

The new LPP test confirms:

- `updateFromLppExtraction()` persists canonical `_coach_*` scan keys.
- A fresh `CoachProfileProvider.loadFromWizard()` reloads the LPP values.
- `DataSpineService.fromProfile()` exposes LPP total balance as a known certificate-sourced fact.
- `CoachContextPacketService.fromSpine()` emits `pillar.lpp.total_balance` without leaking `wizard_answers`.

Static checks:

- `cd apps/mobile && flutter analyze test/providers/coach_profile_provider_lpp_extraction_test.dart` -> no issues.
- `python3 tools/checks/maestro_locator_audit.py` -> scanned 35 flows, 347 locators, OK.
- `git diff --check` -> clean.

## Scope Limits

- This is a debug-fixture LPP flow because `Utiliser un exemple de test` is gated by `kDebugMode`.
- This does not prove camera OCR or release-build scan input.
- Production-safe OCR paste/camera coverage remains a future gate if CJT scope expands beyond debug fixture validation.
