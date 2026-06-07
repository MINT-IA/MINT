---
description: Row 23/CJT-063 runtime AX retry and strict manual VoiceOver protocol for the independent/no-LPP restart/profile-update journey.
---

# Row 23p - Runtime VoiceOver Protocol

Date: 2026-06-07

## Scope

Persona: `independent_no_lpp_income_reality`.

Automated AX retry target: `iPhone 16e - iOS 26.2` simulator.

Manual VoiceOver proof target: a physical iPhone. Prefer a physical iPhone 16e
on the same iOS build; if another physical iPhone is used, the evidence must
state that the VoiceOver proof is real-device speech/focus proof but not
iPhone-16e-specific proof.

Surfaces:

- Coach chat
- Budget
- Rapport

This lot does not close the Row 23 VoiceOver gap. It records a fresh simulator
platform AX retry and defines the physical-device manual VoiceOver proof that
must be run when `idb ui describe-all` cannot publish a usable iOS accessibility
tree. Simulator screenshots and simulator AX-tree inspection are not VoiceOver
speech/focus proof.

## Automated AX Retry

Pre-existing installed app:

- bundle id: `ch.mint.app`
- simulator: `9C9E9AAE-C3CF-49B8-B06D-625004880A9B`
- device: `iPhone 16e`
- installed app: pre-existing simulator build from the prior Row 23o proof
  session; the retry did not independently prove the build flags because the
  AX transport failed before Row 23 proof-anchor assertions could run.

Script command:

```bash
IDB_UDID=9C9E9AAE-C3CF-49B8-B06D-625004880A9B \
MINT_AX_REQUIRE_ROW23_PROOF=true \
AX_CAPTURE_SETTLE_SECONDS=8 \
tools/simulator/capture_runtime_ax.sh \
  .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638
```

Result:

- failed on Coach with the known empty platform AX sentinel. Because
  `capture_runtime_ax.sh` runs with `set -e`, this command exits at Coach and
  does not continue to Budget or Rapport:

```json
[{"AXFrame":"{{0, 0}, {0, 0}}","AXUniqueId":null,"frame":{"y":0,"x":0,"width":0,"height":0},"role_description":null,"AXLabel":null,"content_required":false,"type":null,"title":null,"help":null,"custom_actions":[],"AXValue":null,"enabled":false,"role":null,"subrole":null}]
```

Manual sequential follow-up checks then opened Budget and Rapport and captured
the same single-node sentinel while simulator screenshots showed visible
rendered screens:

```bash
xcrun simctl openurl 9C9E9AAE-C3CF-49B8-B06D-625004880A9B mintapp:///budget
sleep 5
idb ui describe-all --udid 9C9E9AAE-C3CF-49B8-B06D-625004880A9B --json \
  > .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/budget-describe-all-seq.json
xcrun simctl io 9C9E9AAE-C3CF-49B8-B06D-625004880A9B screenshot \
  .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/budget-visible-seq.png

xcrun simctl openurl 9C9E9AAE-C3CF-49B8-B06D-625004880A9B mintapp:///rapport
sleep 5
idb ui describe-all --udid 9C9E9AAE-C3CF-49B8-B06D-625004880A9B --json \
  > .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/rapport-describe-all-seq.json
xcrun simctl io 9C9E9AAE-C3CF-49B8-B06D-625004880A9B screenshot \
  .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/rapport-visible-seq.png
```

Evidence:

- `evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/coach-chat-describe-all.json`
- `evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/budget-describe-all-seq.json`
- `evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/rapport-describe-all-seq.json`
- `evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/coach-chat-visible.png`
- `evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/budget-visible-seq.png`
- `evidence/maestro-ci/row-23-runtime-ax-retry-20260607T221638/rapport-visible-seq.png`

Interpretation:

- The retry is useful as negative evidence for the simulator AX transport.
- It is not a VoiceOver proof.
- It is not a Row 23 value-continuity proof because the retry did not rerun the
  Row 23n bootstrap flow first.
- The `MINT_AX_REQUIRE_ROW23_PROOF=true` flag is intentionally retained in the
  command, but the sentinel failure happens before proof-anchor matching.
- The Row 23n/23o Maestro evidence remains the source for restart/profile-update
  continuity.

## Manual VoiceOver Protocol

Run this protocol only after the Row 23n bootstrap flow has passed. The
VoiceOver pass itself must run on a physical iPhone because simulator AX
inspection is not speech/focus proof.

### Preflight

1. Build and install the simulator app with proof anchors enabled only for the
   Row 23n Maestro continuity setup:

   ```bash
   cd apps/mobile
   flutter build ios --simulator --debug \
     --dart-define=MINT_DISABLE_BETA_MODAL=true \
     --dart-define=MINT_E2E_PROOF_ANCHORS=true
   ```

2. Run the continuity flow:

   ```bash
   FLOW=tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_restart_profile_update.yaml
   EVIDENCE=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-voiceover-manual-preflight-$(date +%Y%m%dT%H%M%S)
   MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=160 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
     bash tools/simulator/maestro_with_watchdog.sh test \
     --format junit --output "$EVIDENCE/result.xml" "$FLOW"
   ```

3. Confirm the preflight JUnit has `tests=1` and `failures=0`.
4. Build and install an equivalent physical-device build. Do not use
   `--simulator` for this build:

   ```bash
   cd apps/mobile
   flutter build ios --debug \
     --dart-define=MINT_DISABLE_BETA_MODAL=true \
     --dart-define=MINT_E2E_PROOF_ANCHORS=true
   ```

   Install it through the available signed-device path for the current machine
   setup, then record the device model, iOS version, install source, and whether
   it is a physical iPhone 16e.
5. Enable VoiceOver on the physical iPhone in iOS Settings.
6. Start a device recording before the first VoiceOver gesture. Use a recording
   path that captures VoiceOver audio or visible VoiceOver captions, for example
   iPhone screen recording with microphone enabled or a tethered recording that
   captures device audio.
7. Traverse every stop with a one-finger swipe-right gesture. Do not tap around
   the screen to skip focus stops.
8. Transcribe each spoken stop verbatim in the evidence note.

A video alone is not enough unless the VoiceOver captions or audio are captured
clearly. A simulator video is not accepted as VoiceOver evidence.

### Coach Focus Order

Route:

```bash
mintapp:///coach/chat
```

Expected VoiceOver focus sequence after asking `Combien verser en 3a ?`:

1. Screen/app context announces MINT or Coach.
2. `coach_history_button` is reachable and named.
3. The more/settings action is reachable and named.
4. `coach_user_message_0` is reachable as the user's message, without
   duplicating the raw prompt in unrelated controls.
5. `coach_assistant_message_0` is reachable as the coach response.
6. `coach_message_content_1` is reachable once and includes:
   - `Marge 3a à vérifier`
   - `96 000 CHF/an`
   - `13 200 CHF/an`
   - `Faits MINT`
   - `Provenance et fraîcheur`
   - `Confirmations manquantes`
   - `Carte de décision`
   - `Comparer avant de verser`
   - `Prochaine action prudente`
7. `coach_lightning_menu_button` is reachable and named.
8. `coach_input_field` is reachable and named.
9. `coach_send_button` is reachable and named.

Fail Coach if:

- the response content is skipped;
- the response is read twice because wrapper and markdown content both expose
  the full text;
- stale values `86 400 CHF/an` or `11 280 CHF/an` are spoken;
- misleading card copy such as `Versement 3a 2026` or `Impact fiscal indicatif`
  is spoken in this scenario;
- any proof-anchor machine label is spoken in ordinary traversal.

### Budget Focus Order

Route:

```bash
mintapp:///budget
```

Expected VoiceOver focus sequence:

1. `budget_screen` / `Budget mensuel` screen context is reachable.
2. `budget_data_quality_banner` is reachable if visible, including the action to
   complete data.
3. `budget_hero_summary` reads the available monthly amount and context.
4. `budget_calculation_detail_toggle` is reachable as an action.
5. `budget_flow_map` is reachable.
6. `budget_formula_proof` reads the updated income basis, including `CHF 8'000`.
7. The allocation ring or its text summary is reachable without relying on color
   only.
8. Bottom navigation stays reachable after the content.

Fail Budget if:

- `CHF 7'200` is spoken as the income basis after the Row 23n update;
- `budget_income_basis` or `q_self_employed_net_income_annual_chf` is spoken in
  ordinary traversal;
- the calculation details control is unreachable;
- chart meaning is color-only or skipped.

### Rapport Focus Order

Route:

```bash
mintapp:///rapport
```

Expected VoiceOver focus sequence:

1. Back action is named.
2. `Ton Bilan Flash` title is reachable.
3. Export/share action is named.
4. Synthesis section reads:
   - `Quelques ajustements pour être serein`
   - `Clarifier mon statut indépendant avant d'augmenter le 3a`
   - guidance wording about checking budget capacity, AVS-independent status,
     taxable/AVS income, accident/loss-of-earnings cover, liquidity, LPP
     facultative, 3a, and treasury.
5. `Commencer` CTA is reachable as an action.
6. `Transparence et conformité` section is reachable.
7. Hypotheses include the 3a ceiling depends on LPP affiliation and income
   status.

Fail Rapport if:

- `report_3a_income_basis`, `annual=`, `max3a=`, or `remaining=` is spoken in
  ordinary traversal;
- the back or export actions are unnamed;
- the content frames the result as personalized investment advice instead of
  educational guidance;
- the long synthesis block is skipped or unreachable.

## Required Evidence File

After running the manual pass, create a dated file under
`evidence/rapport-design/` with:

- simulator/device UDID and OS version;
- build command and Row 23n preflight evidence path;
- physical device model, iOS version, install source, and recording path;
- one screenshot per surface;
- spoken focus transcript for Coach, Budget, and Rapport, one swipe-right stop
  per row;
- pass/fail table for every criterion above;
- explicit statement that this is manual VoiceOver evidence, not `idb`
  platform AX evidence;
- explicit statement whether a physical iPhone 16e was used;
- explicit statement that Row 23 remains `PARTIAL` unless all other CJT-063
  gaps are also addressed.

## Decision

Row 23 remains `PARTIAL`.

The reliable automated proof path today is:

- Maestro for restart/profile-update continuity;
- Flutter semantics tests for local traversal contracts;
- `capture_runtime_ax.sh` as a guard against false-positive `idb` AX evidence.

The missing proof is still a real VoiceOver/focus traversal pass for the same
independent/no-LPP journey.
