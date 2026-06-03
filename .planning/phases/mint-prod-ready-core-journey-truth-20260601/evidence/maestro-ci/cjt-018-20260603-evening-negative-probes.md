# CJT-018 — 2026-06-03 Evening Negative Probes

## Scope

Goal: close the T6 onboarding CTA locator debt by replacing the S005 T6
coordinate fallback with:

```yaml
- tapOn:
    id: "onboarding-insight-view"
```

The production flow was not changed. Each run used a copied proof flow in its
own evidence folder.

## Result

All four probes were rejected. In every case S005 stayed on T6 before the
`Aujourd'hui` assertion. MCP runtime snapshots exposed a tappable
`onboarding-insight-view` node, but tapping it used the upper non-activating
point `x=67,y=205` instead of the visible lower CTA.

## Rejected Candidates

1. `cjt-018-active-step-semantics-20260603T191339/`
   - Candidate: `AnimatedSwitcher.layoutBuilder` excluded previous children
     from semantics, plus T6 `Semantics(identifier:)`.
   - Static proof: targeted `flutter analyze` passed; onboarding storyboard
     passed.
   - Runtime: S005 failed before `Aujourd'hui`; MCP tapped
     `onboarding-insight-view` at `x=67,y=205`.

2. `cjt-018-deferred-revenue-advance-20260603T191717/`
   - Candidate: after T5 revenue, defer `provider.advance()` by one frame after
     dossier mutation.
   - Static proof: targeted `flutter analyze` passed; onboarding storyboard
     passed.
   - Runtime: S005 failed before `Aujourd'hui`; runtime stayed on T6.

3. `cjt-018-constrained-button-semantics-20260603T192013/`
   - Candidate: put the explicit T6 semantics node inside the 52 px button
     `SizedBox` so its frame is layout-constrained.
   - Static proof: targeted `flutter analyze` passed; onboarding storyboard
     passed.
   - Runtime: S005 failed before `Aujourd'hui`; MCP still tapped
     `onboarding-insight-view` at `x=67,y=205`.

4. `cjt-018-t6-explicit-child-semantics-20260603T192342/`
   - Candidate: add a T6-local `Semantics(container: true,
     explicitChildNodes: true)` boundary around the insight content.
   - Static proof: targeted `flutter analyze` passed; onboarding storyboard
     passed.
   - Runtime: S005 failed before `Aujourd'hui`; MCP tapped
     `onboarding-insight-view` at `x=67,y=205`.

## Interpretation

These probes reject:

- outgoing `AnimatedSwitcher` semantics alone as the root cause;
- immediate dossier mutation plus step advance as the root cause;
- unconstrained CTA semantics bounds as the root cause;
- missing T6-local explicit-child semantics boundary as the root cause.

The durable signal remains: explicit `Semantics(identifier:)` can make the id
appear in the full path, but the native activation frame maps to the upper T6
content area. The current production coordinate fallback must remain in S005 and
the affected perfect-set flows until a runtime-green fix moves the activation
point to the visible CTA and reaches `Aujourd'hui`, `card_cap_du_jour`, and
`mint_card_action_bar`.

## Local Code State

The rejected code probes were reverted after evidence capture. No production
code changes from these candidates are retained.
