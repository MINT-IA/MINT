# test/goldens — MINT golden test infrastructure (Plan 04-03)

Dual-device golden image diffs for MINT visual components, starting with
the MintTrameConfiance (MTC) family on S4.

## Layout

```
test/goldens/
├── helpers/
│   ├── screen_pump.dart         # pumpScreen() + GoldenDevice enum
│   └── screen_pump_test.dart    # 7 unit tests on the helper surface
├── mtc_golden_test.dart         # MTC isolation goldens (local-only)
├── s4_response_card_golden_test.dart  # S4 goldens (SKIPPED until 04-02 lands)
└── masters/                     # committed PNG masters (generated locally)
```

## Target devices (locked, 01-CONTEXT §D-04)

| Device         | Logical size | DPR    | CI? | Rationale                     |
| -------------- | ------------ | ------ | --- | ----------------------------- |
| iPhone 14 Pro  | 390 × 844    | 3.0x   | no  | Primary iOS target            |
| Galaxy A14     | 411 × 914    | 2.625x | no  | PERF-04 local-only manual gate |

## CI scope decision (important)

**Only `test/goldens/helpers/` runs on CI.** The image-diff goldens
(`mtc_golden_test.dart`, `s4_response_card_golden_test.dart`) are tagged
`local-only` and **excluded from CI**, for the same reason
`test/golden_screenshots/` is excluded (see `.github/workflows/ci.yml`
comment near the flutter shard definition):

> Flutter pixel goldens are cross-platform fragile. Masters generated
> on macOS (Julien's dev machine) drift by 1-2 pixels against Linux CI
> runners due to font hinting and glyph rasterization differences.
> Forcing CI to run them produces flake, not signal.

Instead:

1. CI runs the **helper unit tests** (`screen_pump_test.dart`). These
   pin the helper's public surface (device dimensions, view wiring,
   locale wiring, MediaQuery flags) without touching pixel output.
2. Image-diff goldens run **locally** via the command below, before
   each release and whenever an MTC-owning surface is modified.
3. Galaxy A14 goldens are a **manual device gate** per PERF-04:
   Julien runs them on a real A14 (or on an A14 emulator) before any
   phase-exit sign-off. They are NOT part of any automated pipeline.

This mirrors the policy that already governs
`test/golden_screenshots/` — it is not a new compromise; it is the
existing pixel-golden doctrine, applied to MTC.

## Regenerating masters locally

```bash
cd apps/mobile
flutter test --update-goldens test/goldens/mtc_golden_test.dart
```

To run the goldens (without regenerating) and diff against committed
masters:

```bash
cd apps/mobile
flutter test test/goldens/mtc_golden_test.dart
```

To run ONLY the helper unit tests (what CI runs):

```bash
cd apps/mobile
flutter test test/goldens/helpers/
```

## Plan 04-02 interaction

At the time Plan 04-03 ships, Plan 04-02 is editing
`apps/mobile/lib/widgets/coach/response_card_widget.dart` in parallel
to introduce the MTC slot on S4. To avoid a race on shared file
ownership, `s4_response_card_golden_test.dart` is committed as a
**skipped placeholder**. Once 04-02 lands on dev:

1. Remove the `skip:` parameters.
2. Update the constructor calls if the 04-02 API differs from the
   draft.
3. Run `flutter test --update-goldens test/goldens/s4_response_card_golden_test.dart`
   locally to generate masters.
4. Commit the masters and the un-skipped test file in a follow-up
   commit (scope: `test(p4): enable S4 response card goldens`).

This staged approach keeps Plan 04-03 executable TODAY without
blocking on 04-02 and without modifying files outside 04-03's
ownership boundary.

## Downstream reuse

The `screen_pump` helper is designed to be consumed without
modification by:

- Phase 8a (MTC 11-surface migration)
- Phase 8c (Polish Pass #1)
- Phase 9 (MintAlertObject)
- Phase 12 (Ship gate + final A14 manual pass)

Any API change to `pumpScreen` after Phase 4 is a breaking change for
every surface above — treat it as an ADR-worthy decision.
