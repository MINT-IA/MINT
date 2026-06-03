---
description: Temporary MINT-shaped Flutter repro for CJT-018 AX geometry.
status: evidence
date: 2026-06-03
---

# CJT-018 — MINT-Shaped Repro

## Scope

A temporary Flutter app was created outside the repo at
`/tmp/cjt018_mint_shape_repro` to test whether the following factors are enough
to reproduce the bad T6 CTA AX frame:

- `_StepScaffold`-style `Padding` and `Expanded(child: child)`;
- `AnimatedSwitcher` + `KeyedSubtree`;
- T6 `Column` with card, `Spacer`, and bottom CTA;
- strict `Semantics(container: true, identifier:, label:, button:, onTap:)`;
- `DossierStrip`-style bottom strip with constrained `SingleChildScrollView`.

The repro uses bundle id `ch.mint.debug.cjt018MintShapeRepro`.

## Result

First flow:

- Evidence: `cjt-018-mint-shaped-repro-20260603T095715/`.
- Flow tapped `id: "onboarding-insight-view"` then immediately asserted
  `.*Aujourd'hui.*`.
- JUnit failed before the assertion saw the transition.

Runtime inspection after that failure:

```text
targets: e17|tap|button|Voir||onboarding-insight-view
```

Manual MCP tap:

```text
tap e17 -> x=201, y=629
screen advances to Aujourd'hui · card_cap_du_jour · mint_card_action_bar
```

Second flow:

- Evidence: `cjt-018-mint-shaped-repro-wait-20260603T095823/`.
- Same id tap, but followed by `extendedWaitUntil` for `.*Aujourd'hui.*`.
- Result: passed (`EXIT_CODE=0`, `1/1 Flow Passed in 4s`).

## Conclusion

This reduced MINT-shaped widget tree does **not** reproduce the bad MINT frame.
The strict CTA semantics resolve to a lower visible activation point and advance
correctly.

CJT-018 therefore remains specific to some remaining factor in the production
onboarding tree or runtime environment, not merely:

- `_StepScaffold`;
- `AnimatedSwitcher`;
- `KeyedSubtree`;
- `DossierStrip` scrollability;
- `Spacer`;
- strict CTA semantics.

Next useful work: compare the actual production T6 widget tree against this
passing repro at the render/semantics boundary, especially inherited wrappers,
parent semantics, overlay/route shell, and any production-only semantics labels.
