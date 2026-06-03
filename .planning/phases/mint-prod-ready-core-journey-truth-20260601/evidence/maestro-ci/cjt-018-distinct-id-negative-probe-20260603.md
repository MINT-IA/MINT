description: CJT-018 probe showing a distinct Semantics identifier still maps to the bad upper T6 AX frame.

# CJT-018 Distinct-ID Negative Probe — 2026-06-03

## Hypothesis

The bad T6 `Voir` tap might come from reusing the same value as both Flutter
`ValueKey('onboarding-insight-view')` and iOS `Semantics.identifier`.

## Probe

Temporary production-code edit, reverted after runtime:

```dart
Semantics(
  container: true,
  identifier: 'onboarding-insight-cta',
  label: 'Voir',
  button: true,
  onTap: provider.advance,
  child: _PrimaryButton(
    key: const ValueKey('onboarding-insight-view'),
    label: 'Voir',
    onPressed: () => provider.advance(),
  ),
)
```

Temporary S005 flow replaced only the T6 coordinate fallback:

```yaml
- tapOn:
    id: "onboarding-insight-cta"
```

Evidence folder:

```text
evidence/maestro-ci/cjt-018-distinct-id-probe-20260603T090752/
```

## Result

Maestro found the distinct id, but S005 still failed before `Aujourd'hui`.
Post-failure `snapshot_ui` stayed on T6 and exposed:

```text
e16|tap|button|Voir||onboarding-insight-cta
e17|tap|button|Voir||
```

Manual MCP tap of `e16` still hit the bad upper frame:

```text
x=67,y=205
```

## Conclusion

The bad frame is not caused by reusing the same string for the Flutter key and
the Semantics identifier. CJT-018 remains specific to the MINT onboarding T6
tree/layout/semantics composition.
