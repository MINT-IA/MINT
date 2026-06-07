# Row 23o - proof-anchor and runtime AX hygiene

Date: 2026-06-07

## Scope

This Row 23/CJT-063 lot hardens the independent/no-LPP proof layer without
claiming VoiceOver closure.

The previous restart/profile-update proof used Budget and Rapport machine
anchors:

- `budget_income_basis`
- `report_3a_income_basis`

Those anchors are useful for non-circular runtime value checks, but they should
not appear in ordinary debug/profile accessibility traversal because their
labels contain machine facts such as `q_self_employed_net_income_annual_chf`,
`annual`, `max3a`, and `remaining`.

## Change

- Added `E2eRuntimeFlags`.
- `MINT_E2E_PROOF_ANCHORS=true` now explicitly gates the Budget/Rapport
  machine proof anchors.
- Added `tools/simulator/capture_runtime_ax.sh`, which fails on the known
  single-node `{{0, 0}, {0, 0}}` AX sentinel instead of accepting it as proof.
- Updated the Row 23 restart/profile-update flow precondition to require
  `MINT_E2E_PROOF_ANCHORS=true`.

## Local proof

Command:

```bash
cd apps/mobile
flutter test \
  test/services/e2e_runtime_flags_test.dart \
  test/screens/budget_screen_smoke_test.dart \
  test/screens/advisor_banking_smoke_test.dart
```

Result:

- `69/69` tests passed.

Coverage added:

- E2E flags are off by default.
- Budget default semantics traversal does not include `budget_income_basis`.
- Rapport default semantics traversal does not include `report_3a_income_basis`.
- Budget proof-anchor payload renders only when `proofAnchorsOverride=true`.
- Rapport proof-anchor payload renders only when `proofAnchorsOverride=true`.

## Runtime proof

Build:

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=MINT_E2E_PROOF_ANCHORS=true
```

Maestro:

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_restart_profile_update.yaml
EVIDENCE=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-proof-anchors-opt-in-final-20260607T215153
MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=160 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test \
  --format junit --output "$EVIDENCE/result.xml" "$FLOW"
```

Result:

- `tests=1`
- `failures=0`
- watchdog returned `0`
- device: `iPhone 16e - iOS 26.2`

Evidence:

- `evidence/maestro-ci/row-23-proof-anchors-opt-in-final-20260607T215153/result.xml`
- `evidence/maestro-ci/row-23-proof-anchors-opt-in-final-20260607T215153/maestro.log`
- screenshots in the same directory:
  - `row23-bootstrap-update.png`
  - `row23-restart-updated-coach.png`
  - `row23-restart-updated-budget.png`
  - `row23-restart-updated-rapport.png`

This proves the Row 23n restart/profile-update scenario still works when the
machine anchors are opt-in rather than always exposed in debug builds.

## Runtime AX attempt

Command:

```bash
IDB_UDID=9C9E9AAE-C3CF-49B8-B06D-625004880A9B \
MINT_AX_REQUIRE_ROW23_PROOF=true \
AX_CAPTURE_SETTLE_SECONDS=8 \
tools/simulator/capture_runtime_ax.sh \
  .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-runtime-ax-row23-proof-final-20260607T215250
```

Result:

- Failed on Coach because `idb ui describe-all --json` still returned the
  known empty platform AX sentinel:

```json
[{"AXFrame":"{{0, 0}, {0, 0}}","AXLabel":null,"enabled":false,"role":null}]
```

Evidence:

- `evidence/maestro-ci/row-23-runtime-ax-row23-proof-final-20260607T215250/coach-chat-describe-all.json`

## Decision

Row 23 stays `PARTIAL`.

This lot improves proof hygiene and prevents proof-only machine labels from
leaking into normal debug/profile accessibility traversal. It does not prove
VoiceOver focus order, and it does not prove a non-empty iOS platform AX tree
for Coach/Budget/Rapport. The new AX script is a guard against false-positive
runtime AX evidence.

Next proof should either:

- find a reliable simulator/device method to publish the iOS AX tree for
  Flutter screens, or
- run a manual VoiceOver sweep on real device/simulator and record the focus
  and speech order separately from Maestro.
