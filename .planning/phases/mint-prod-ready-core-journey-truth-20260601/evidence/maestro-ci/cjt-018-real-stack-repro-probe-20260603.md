# CJT-018 — Real Stack Repro Probe

Date: 2026-06-03  
Simulator: iPhone 17 Pro `B03E429D-0422-4357-B754-536637D979F9`

## Probe

A temporary debug-only build routed `/onb` to the already-passing MINT-shaped
repro screen while keeping the real production hosting stack:

- `MintApp`;
- `MultiProvider`;
- `_AuthRouterBridge`;
- `MigrationNoticeListener`;
- `MaterialApp.router`;
- GoRouter `/onb` route.

The temporary screen kept the T6-shaped layout, strict
`Semantics(identifier: "onboarding-insight-view")`, bottom CTA, and dossier
strip shape. It was used only for this runtime probe and then reverted.

## Result

Artifact folder:

`evidence/maestro-ci/cjt-018-real-stack-repro-probe-20260603T101211/`

Maestro result:

```text
[Passed] cjt018_real_stack_repro_probe (12s)
1/1 Flow Passed in 12s
```

A second stop-before-tap run reached the T6-shaped probe screen, then MCP exposed:

```text
e15|tap|button|Voir||onboarding-insight-view
```

MCP tap on that element:

```text
elementRef: e15
x: 201
y: 610
```

The app advanced to:

```text
CJT018 probe advanced
```

Screenshot:

`evidence/maestro-ci/cjt-018-real-stack-repro-probe-20260603T101211/real-stack-probe-advanced.jpg`

## Conclusion

The real app hosting stack is not sufficient to reproduce CJT-018. The same
identifier maps to the lower visible CTA and activates correctly when the
MINT-shaped repro is served through `MintApp` and GoRouter.

CJT-018 is therefore narrower: the next investigation should compare the real
`OnboardingShellScreen` step sequence/history/private widgets against the
passing repro, especially how the production T6 `_PrimaryButton` key becomes a
text-sized upper AX node while the strict repro node keeps the button-sized
lower activation frame.
