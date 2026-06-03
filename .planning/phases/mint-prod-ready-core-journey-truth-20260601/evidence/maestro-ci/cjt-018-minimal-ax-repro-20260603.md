description: Minimal Flutter repro proving Maestro can tap lower `Semantics(identifier:)` buttons on iOS outside MINT onboarding.

# CJT-018 Minimal AX Repro — 2026-06-03

## Purpose

After several MINT onboarding T6 slot probes still exposed
`onboarding-insight-view` at the wrong upper frame, this temporary repro tested
whether Flutter/iOS/Maestro can tap lower-screen `Semantics(identifier:)`
buttons in a small app.

## Setup

Temporary app only, outside the MINT repo:

```text
/tmp/cjt018_ax_repro2
bundle id: ch.mint.debug.cjt018AxRepro2
```

The app renders:

- a prompt and card similar to the T6 screen;
- an inline lower CTA with `identifier: repro-inline-button`;
- a shell-slot lower CTA with `identifier: repro-shell-slot-button`;
- a counter text `TON DOSSIER · taps=N`.

Stored evidence:

```text
evidence/maestro-ci/cjt-018-minimal-ax-repro-20260603T0902/
```

## Runtime Result

Maestro flow:

```yaml
- tapOn:
    id: "repro-inline-button"
- assertVisible: "TON DOSSIER · taps=1"
- tapOn:
    id: "repro-shell-slot-button"
- assertVisible: "TON DOSSIER · taps=2"
```

Result:

```text
[Passed] cjt018_repro_flow (6s)
1/1 Flow Passed in 6s
```

## Conclusion

`Semantics(identifier:)` on lower-screen Flutter buttons works in a minimal iOS
simulator app. CJT-018 is therefore not explained by a broad Flutter/iOS/Maestro
inability to tap lower buttons.

The remaining defect is specific to the MINT onboarding structure around T6.
The next investigation should compare MINT-only factors against the passing
repro: `AnimatedSwitcher`, `KeyedSubtree`, `_StepScaffold`, `DossierStrip`,
duplicate `Voir` semantics, and any retained semantics nodes from prior steps.
