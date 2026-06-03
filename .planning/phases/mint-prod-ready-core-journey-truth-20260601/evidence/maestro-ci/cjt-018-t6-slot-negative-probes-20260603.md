description: CJT-018 negative runtime probes showing that T6 `Voir` still has bad iOS AX geometry after stable-slot attempts.

# CJT-018 T6 Slot Negative Probes — 2026-06-03

## Scope

CJT-018 tracks Maestro point-tap debt caused by Flutter/iOS accessibility
identifiers resolving to frames that do not match the rendered CTA. This report
records the 2026-06-03 T6 `Voir` probes after the earlier `_PrimaryButton`
Semantics wrappers had already been rejected.

## Attempted Fixes

All production-code attempts were reverted after runtime rejection.

1. Move T6 `Voir` outside `_InsightStep` into a shell-level slot above
   `DossierStrip`.
2. Add `Semantics(identifier: 'onboarding-insight-view')` to that shell-level
   CTA.
3. Replace only the T6 coordinate fallback in S005 with
   `id: "onboarding-insight-view"` in `/tmp/cjt018_s005_t6_id.yaml`.
4. Rebuild and install on the booted iPhone 17 Pro simulator. The normal
   Flutter build hit the local Xcode resource-fork/xattr CodeSign issue, so the
   generated app was copied and signed for simulator install.
5. Force `terminate + uninstall + install` before the final rerun to rule out a
   stale simulator process.

## Evidence

| Probe | Code shape | Result |
|---|---|---|
| `cjt-018-t6-layout-probe-20260603T084426/` | Shell slot without explicit Semantics | Failed: `Element not found: Id matching regex: onboarding-insight-view`. |
| `cjt-018-t6-stable-semantics-probe-20260603T085112/` | Shell `Stack/Positioned` slot with Semantics | Failed before `Aujourd'hui`; post-failure snapshot still on T6. |
| `cjt-018-t6-column-slot-probe-20260603T085432/` | Real `Column` bottom slot with Semantics | Failed before `Aujourd'hui`; post-failure snapshot still on T6. |
| `cjt-018-t6-column-slot-forced-install-20260603T085615/` | Same `Column` slot after forced uninstall/install | Failed before `Aujourd'hui`; post-failure snapshot still on T6. |

Runtime `snapshot_ui` after the rejected probes still exposed:

```text
e16|tap|button|Voir||onboarding-insight-view
e17|tap|button|Voir||
```

But tapping the exposed target via xcodebuildMCP still hit the upper bad frame:

```text
tap e16 -> x=67,y=208
```

The visible `Voir` button was rendered near the bottom of the screen above
`DossierStrip`, so this remains an iOS AX frame mismatch, not a missing widget
key.

## Current Decision

Do not close CJT-018 from widget tests, locator audit, `_PrimaryButton`
Semantics wrappers, or a shell-level T6 slot. These probes all fail runtime.

Keep the coordinate fallback in S005 and affected perfect-set flows so the
regression gate remains runnable while the deeper AX geometry issue is open.

## Next Viable Direction

The next slice should use a minimal native/Flutter AX repro outside MINT or a
small isolated MINT screen to determine why Flutter iOS reports the `Voir`
Semantics frame near the text/card area. Only after that should production
onboarding layout be changed again.
