# CJT-018 — Current Runtime ID Negative Probe

Date: 2026-06-03  
Simulator: iPhone 17 Pro `B03E429D-0422-4357-B754-536637D979F9`  
Installed app: `ch.mint.app`, version `2.12.4`, build `66`  
Flow: temporary copy of `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`

## Probe

The S005 regression flow was rerun against the currently installed MINT app with
only the T6 `Voir` tap changed from the temporary coordinate fallback to:

```yaml
- tapOn:
    id: "onboarding-insight-view"
```

No production code or checked-in Maestro flow was changed.

## Result

Artifact folder:

`evidence/maestro-ci/cjt-018-current-id-flow-20260603T100445/`

Maestro result:

```text
[Failed] cjt018_s005_current_id (42s)
Assertion is false: ".*Aujourd'hui.*" is visible
1/1 Flow Failed
```

The app stayed on T6, before the `Aujourd'hui` assertions.

MCP runtime snapshot after failure exposed the target:

```text
e15|tap|button|Voir||onboarding-insight-view
```

MCP tap on that target:

```text
elementRef: e15
x: 67
y: 205
screenHash unchanged: 0a4wfbt
```

The post-tap snapshot still showed:

```text
Avant de te montrer…
MOYENNE SUISSE
Trois scènes, trois chiffres — la réalité de ta tranche.
TON DOSSIER
```

Screenshot:

`evidence/maestro-ci/cjt-018-current-id-flow-20260603T100445/t6-after-id-tap-still-stuck.jpg`

## Conclusion

The current runtime still maps `onboarding-insight-view` to an upper non-activating
frame around the text-sized area (`x=67,y=205`) instead of the visible lower CTA.
This validates keeping the coordinate fallback in S005 while CJT-018 remains open.

This probe also reinforces the design constraint: do not fix the issue by moving
or duplicating the CTA. The next useful slice is to identify why production
attaches the identifier to the text-sized semantics node while the MINT-shaped
temporary repro maps the same strict CTA semantics to the lower button frame.
