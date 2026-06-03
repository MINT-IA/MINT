# CJT-018 — Direct T6 History Probe

Date: 2026-06-03  
Simulator: iPhone 17 Pro `B03E429D-0422-4357-B754-536637D979F9`

## Probe

A temporary compile-time flag started the real `OnboardingShellScreen` directly
at T6 (`OnboardingStep.insight`) with the same dossier data normally collected
by the previous steps. The visual T6 screen, real `_InsightStep`, real
`_PrimaryButton`, real `DossierStrip`, `AnimatedSwitcher`, `KeyedSubtree`, and
`_StepScaffold` stayed in use.

The temporary code was used only for this runtime probe and then reverted.

## Result

Artifact folder:

`evidence/maestro-ci/cjt-018-direct-t6-probe-20260603T101924/`

The stop-before-tap flow reached T6 successfully:

```text
[Passed] cjt018_direct_t6_stop (11s)
1/1 Flow Passed in 11s
```

MCP runtime snapshot on direct T6 exposed the visible CTA as:

```text
e15|tap|button|Voir||
```

There was no `onboarding-insight-view` identifier in the direct-T6 snapshot.

MCP tap on the visible CTA:

```text
elementRef: e15
x: 201
y: 616
```

The app advanced to T7.

## Conclusion

Directly rendering real T6 does not reproduce the full-path failure. The visible
CTA has the correct lower activation point, but the identifier is absent.

The full S005 path is different: after the real multi-step onboarding history,
`onboarding-insight-view` appears and maps to the bad upper point (`x=67,y=205`).
This narrows CJT-018 to retained or stale semantics from the step sequence,
rather than the static T6 layout alone or the global app hosting stack.
