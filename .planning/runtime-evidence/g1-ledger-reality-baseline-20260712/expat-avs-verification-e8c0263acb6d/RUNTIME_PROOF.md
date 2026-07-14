# G1 Expat AVS — exact-SHA runtime proof

Date of independent quality review: 2026-07-13
Commit under test: `e8c0263acb6ddad9b5acafd889193c4caf4909f3`
Branch: `codex/mint-product-usability-plan-20260712`
Device: iPhone 17 Pro simulator, iOS 26.2, `B03E429D-0422-4357-B754-536637D979F9`
Bundle: `ch.mint.app`

## Exact-tree boundary

- `runtime-exact-sha/sha-before.txt` and `sha-after.txt` both contain exactly
  `e8c0263acb6ddad9b5acafd889193c4caf4909f3`.
- `status-before.txt` and `status-after.txt` are both zero-byte files: the
  tracked and untracked worktree was clean at both boundaries.
- The final commit exists and is the branch HEAD. Its parent is
  `810741211de48b02d7add7ef3e666a9598c29ab7`.

## MINT tooling gates

`runtime-exact-sha/mint-doctor.log` is green for all repository and host
checks, including Patrol, Maestro, Mermaid, the Claude audit wrapper, agent
workflow, and the iOS plist split. `patrol-tooling-guard.log` independently
confirms the Patrol configuration, test directory, and CLI discovery.

## Patrol native proof

Preserved target:
`apps/mobile/test/patrol/expat_avs_verification_runtime_test.dart`, which
delegates to the real integration body in
`apps/mobile/integration_test/expat_avs_verification_patrol_test.dart`.

- Patrol exit code: `0`.
- The preserved `.xcresult` was independently re-read with
  `xcresulttool`, not trusted from the console summary alone.
- Result: `Passed`; total `1`; passed `1`; failed `0`; skipped `0`;
  expected failures `0`.
- The test pumps the real `MintApp` and uses its real root router. Maestro,
  independently, covers the OS deep link.
- Before interacting, the test records `ReportPersistenceService.loadAnswers()`
  and proves that `q_avs_years_abroad` is absent.
- It proves the picker value is initially `null` and the start button's
  callback is `null`.
- It performs a real Cupertino wheel drag to select `4`, confirms with `OK`,
  and proves the persisted answer map is byte-for-byte logically unchanged.
- It proves the unknown-gap state is visible, no personal `CHF <number>` is
  rendered, navigation reaches the guide, both official CTA semantics are
  visible, and persisted answers remain unchanged at the end.

## Normal app rebuild

Patrol's generated test runner was not reused for Maestro. The evidence
contains a separate normal `flutter build ios --simulator --debug` log and
`build-exit-code.txt = 0`. The build finishes with:

```text
Building ch.mint.app for simulator (ios)...
Xcode build done.
Built build/ios/iphonesimulator/Runner.app
```

The normal Runner was installed on the same named simulator. Its preserved
app-container path ends in `Runner.app`.

## Maestro real-app proof

Checked-in flow: `apps/mobile/.maestro/expat_avs_verification.yaml`
Watchdog: 300-second hard limit; 90-second stall threshold
Maestro exit code: `0`

The final command artifact contains 26 commands: 25 `COMPLETED` and one
expected `WARNED` optional `Cancel` selector. No required command warned or
failed. The flow proves, in order:

1. the real app launches with cleared state and opens
   `mint:///expatriation`;
2. the AVS tab and nullable years picker are reachable by stable semantics;
3. the start control is disabled before selection;
4. tapping that disabled control leaves the scenario result absent;
5. explicit `OK` confirmation enables the start control;
6. the orientation renders the unknown-gap state;
7. no personal `CHF <number>` is visible;
8. the verification CTA opens the AVS guide;
9. `avs_official_ci_request_cta` is visible;
10. `avs_official_form_cta` is visible; and
11. `expat_avs_verification_guide.png` is captured inside the passing flow.

The screenshot is a valid 1206 × 2622 RGB PNG. Visual inspection confirms
that both requested controls are fully visible and legible:
“Demander l’extrait CI officiel” and “Ouvrir le formulaire 318.282”.

## Preserved RED → GREEN chain

### Patrol finder mismatch — RED `4330a292bca4`

The preserved red `.xcresult` and log report one test, zero passed, one failed.
It times out with `Found 0 widgets with key <expat_avs_tab>`. This is a real
runtime-harness failure: the OS-level deep link detached Patrol from the
instrumented tree and the shorthand finder looked for a widget key rather than
the iOS semantics identifier.

Commit `810741211de48b02d7add7ef3e666a9598c29ab7` fixes exactly that failure:
Patrol remains attached to the real `MintApp`, uses `testOnlyRootRouter.go` for
the real router, and uses explicit semantic finders while retaining widget-key
assertions for internal state and gestures. The final `.xcresult` is green.

### Maestro composite text — RED `810741211de4`

The preserved `text-selector/maestro.log` fails on the exact visible-text
selector `À renseigner` even though the picker ID is present. On iOS, that text
is part of a composite accessibility node rather than an independent element.

The final flow replaces fragile composite-text assertions with the stable
`expat_avs_start_scenario` semantic state: disabled before explicit selection,
enabled after `OK`.

### Maestro semantic wrapper without action — RED `810741211de4`

The preserved `action-selector/maestro.log` reaches the identified start
wrapper, taps it, then fails because `expat_avs_scenario_result` never appears.
The hierarchy shows the ID on the large semantic wrapper rather than an
actionable button node.

Final commit `e8c0263acb6ddad9b5acafd889193c4caf4909f3` changes exactly the runtime
contract: it adds an isolated semantic container with explicit label,
enabled-state, and `onTap`; it adds focused negative/positive widget coverage;
and it updates the Maestro flow to assert state and scroll to the result. The
final Maestro log then records the disabled negative tap, enabled positive tap,
result, both guide CTAs, screenshot, and watchdog exit `0`.

## Scope boundary

This evidence closes the **G1 Expat AVS runtime slice**. It does **not** by
itself close all of G1 Ledger Reality Baseline, and it does not claim to close
global ticket `RUNTIME-01` if that ticket requires runtime evidence for other
flows.
