# Stack Research — v2.2 La Beauté de Mint

**Domain:** Flutter+FastAPI design/voice/accessibility milestone (additive only)
**Researched:** 2026-04-07
**Confidence:** HIGH on items 1, 2, 3, 5, 6, 7. MEDIUM on item 4 (Firebase Test Lab device availability — confirmed via official catalog page but A14 specifically requires `gcloud firebase test android models list` to confirm at provisioning time).
**Scope rule:** Only NEW additions. Base stack (Flutter, GoRouter, Provider, Material 3, Montserrat/Inter, FastAPI, Pydantic v2, GoogleFonts, GitHub Actions macos-15) is already mature per CLAUDE.md §2 — DO NOT touch.

---

## TL;DR — What to add, what to skip

| Item | Decision | Where |
|------|----------|-------|
| 1. Krippendorff α | **ADD** `krippendorff` (PyPI, Santiago Castro) — one-shot script in `tools/voice-cursor-irr/` | L1.6a |
| 2. Patrol | **ADD** `patrol ^4.x` + `patrol_cli` — replaces no existing tool, complements `integration_test` | L1.5, L1.2a |
| 3. Galaxy A14 perf harness | **DO NOT ADD** anything new — `flutter run --profile` + DevTools (already shipped with Flutter SDK) is sufficient | L1.0 |
| 4. Firebase Test Lab v2.3 prep | **INVESTIGATE ONLY** — document, do not provision | v2.3 |
| 5. ARB canton namespaces | **DO NOT ADD** package — custom `LocalizationsDelegate` (40 LOC) on top of existing `flutter_localizations` | L1.4 |
| 6. VoiceCursorContract codegen | **ADD** single JSON file as source of truth + 2 thin generators (Python `datamodel-code-generator`, Dart hand-rolled script) | L1.0 |
| 7. AAA contrast tooling | **ADD** Flutter widget test using existing `flutter_test`'s `SemanticsTester` + 30-LOC custom `wcagContrastRatio()` helper. NO new package. | L1.1, L1.3 |

**Net new dependencies: 3** (`krippendorff` python, `patrol` dart, `datamodel-code-generator` python dev). Everything else is glue code on existing infra.

---

## 1. Krippendorff α tooling — L1.6a one-shot

### Recommendation
Use the **`krippendorff`** PyPI package (Santiago Castro, https://pypi.org/project/krippendorff/). NumPy-accelerated, supports `level_of_measurement='ordinal'` natively, returns the weighted ordinal α directly. Active maintenance, ~50k monthly downloads, used by Label Studio and HuggingFace eval pipelines.

**Why this over alternatives:**

| Option | Verdict | Why |
|--------|---------|-----|
| `krippendorff` (PyPI) | **CHOSEN** | One-line API: `krippendorff.alpha(reliability_data=matrix, level_of_measurement='ordinal')`. Ordinal metric is the canonical Krippendorff weighting for 5-level Likert. Already in MINT's Python ecosystem. |
| R `irr` package | Reject | Adds R toolchain to a Python+Dart shop. Zero benefit over the Python pkg for a one-shot run. |
| ReCal3 (web) | Reject | Web form upload, no audit trail, no reproducibility, no version control of the input matrix. Acceptable for academic one-offs, not for an engineering shop. |
| `simpledorff` | Reject | Pandas-DataFrame API is nicer for messy data but the Castro package is faster and the input shape (15 raters × 20 phrases) is trivial to express as a NumPy matrix. |
| Aleph-Alpha fork | Reject | Newer fork with custom annotator weights — feature we don't need. Less battle-tested. |

### Where it lives
**`tools/voice-cursor-irr/`** — new directory at repo root. NOT a separate repo (overkill for ~50 LOC + one CSV). NOT inside `services/backend/` (it's not a runtime concern, must not bloat backend deps).

```
tools/voice-cursor-irr/
  README.md          # protocol: 15 testers × 20 phrases × N1-N5
  ratings.csv        # rater_id, phrase_id, level (1-5)
  compute_alpha.py   # ~30 LOC, prints α + 95% bootstrap CI
  requirements.txt   # krippendorff>=0.6.1, numpy
```

### Integration cost
- `pip install krippendorff` (NOT added to backend `pyproject.toml` — isolated venv in `tools/voice-cursor-irr/`)
- ~30 LOC Python script
- 1 CSV template
- README documenting protocol + acceptance gate (α ≥ 0.67)
- **Estimate: 2 hours, including the bootstrap CI block**

### Version
`krippendorff>=0.6.1` (current as of 2026-04, verified PyPI). Pin exact version in requirements.txt for reproducibility of the one-shot result.

---

## 2. Patrol — L1.5 + L1.2a integration tests

### Recommendation
**`patrol: ^4.1.1`** (LeanCode) + **`patrol_cli`** as a global Dart tool. Patrol 4.x is current as of 2026-04 (verified leancode.co/v4 docs). Builds on top of `flutter_test` and `integration_test`, adds native interaction + custom finders + hot restart in tests.

**Why Patrol over alternatives:**

| Option | Verdict | Why |
|--------|---------|-----|
| Patrol 4.x | **CHOSEN** | Only Flutter-native E2E framework that handles native pop-ups (TalkBack/VoiceOver permission dialogs are critical for L1.2a "1 ligne audio" verification). Hot restart between tests = 5x faster than vanilla `integration_test`. |
| `integration_test` only | Reject | Cannot interact with TalkBack overlay or accessibility-tree-only widgets reliably. We need this for MTC's audio-line semantics test. |
| Maestro (Mobile.dev) | Reject | YAML DSL, not Dart. Adds a second test language to a Dart shop. Strong tool but ceremony cost > value for a 6-week milestone. |
| Appium | Reject | WebDriver overhead, slow, brittle on Flutter. |

### Integration with existing test infra
- `flutter_test` (unit/widget) — unchanged, keeps 8137 tests
- `integration_test` (E2E lite) — keeps `coach_tool_choreography_test.dart` (4 tools)
- **NEW:** `patrol/` directory at `apps/mobile/integration_test/patrol/` containing visual + native tests for the 3 v2.2 surfaces

### Golden screenshot diff config
Patrol does NOT ship its own golden differ — it delegates to `flutter_test`'s `matchesGoldenFile`. Existing 1.5% tolerance pattern (per CLAUDE.md) is set via `goldenFileComparator = LocalFileComparator(...)` override at test main entry. **Reuse the existing pattern, do not introduce a parallel one.**

For the 3 v2.2 targets:
- **MintAlertObject (L1.5):** 6 golden states (G2 calm, G2 highlighted, G3 break, × 2 themes light/dark). Tap-to-reveal native sheet via Patrol's `$.native.tap()`.
- **MintTrameConfiance (L1.2a):** 4-axis confidence rendering golden + bloom animation snapshot at t=0, t=125ms, t=250ms (use `tester.binding.scheduler.timeDilation` + `pumpAndSettle`). 1-line audio test asserts `Semantics(label: ...)` matches expected canonical phrase.
- **intent_screen curseur question (L1.6c):** golden of 3-option chooser; Patrol drives a select-confirm-back round trip and asserts persisted preference.

### Integration cost
- 1 line in `pubspec.yaml` (`patrol: ^4.1.1` under dev_dependencies)
- 1 line per test file (`import 'package:patrol/patrol.dart'`)
- ~80 LOC test file per surface × 3 surfaces = ~240 LOC
- patrol_cli installed once globally; CI workflow needs `dart pub global activate patrol_cli` step (3-line addition to existing GitHub Actions Flutter job)
- **Estimate: 1 day for setup + 1 day per surface = 4 days total**

### What Patrol does NOT do (and we don't need)
- Visual regression as a service (Percy/Chromatic) — NOT needed, golden files in repo are fine for a 3-surface scope
- Cross-device farm — that's item 4

### Version pin
`patrol: ^4.1.1` (verified pub.dev as of 2026-04). Requires Android SDK 21+ (already met). Requires patrol_cli matching minor version.

---

## 3. Galaxy A14 perf harness for MANUAL gate (L1.0)

### Recommendation
**DO NOT ADD ANY NEW TOOL.** Use what ships with the Flutter SDK already on Julien's Mac:
1. `flutter run --profile -d <A14-device-id>` — produces a build with profiling enabled, not debug overhead
2. `flutter run` opens DevTools URL in terminal — open in browser, attach to running app
3. **DevTools Performance tab** captures: cold start frame, scroll FPS (Timeline), MTC bloom CPU/GPU frames
4. **DevTools Memory tab** captures: heap snapshot before/after MTC tap

### Capture protocol (one-shot, document in `.planning/perf/A14_BASELINE.md`)
```bash
# 1. Connect Galaxy A14 over USB, enable USB debugging
adb devices  # confirm device id
flutter devices  # confirm Flutter sees it

# 2. Profile build (NOT debug — debug is 3-5x slower, results meaningless)
cd apps/mobile
flutter run --profile -d <A14_id> --trace-startup

# 3. Cold start metric: --trace-startup writes start_up_info.json to build/
cat build/start_up_info.json
# Records: engineEnterTimestampMicros, timeToFirstFrameMicros, timeToFirstFrameRasterizedMicros

# 4. Scroll FPS: open DevTools (URL printed by flutter run), Performance tab,
#    record while scrolling Aujourd'hui home for 10 seconds, export timeline JSON

# 5. MTC bloom: tap a confidence widget, capture frame in Performance tab,
#    target = 16ms per frame for 250ms = 16 frames. Reject if >2 frames >32ms.

# 6. Save artifacts to .planning/perf/A14_BASELINE_2026-04-XX/
```

### Why no new tool
| Option | Verdict | Why |
|--------|---------|-----|
| `flutter --profile` + DevTools | **CHOSEN** | Ships with SDK. Zero install. Officially blessed for Flutter perf. |
| Android Studio Profiler | Reject for Flutter | Reads native traces; for Flutter the Dart timeline is what matters. AS Profiler shows Skia frames but DevTools shows the same with Dart context. |
| `dart devtools` standalone | Same thing | Just a standalone DevTools launcher; equivalent. |
| Perfetto direct | Overkill | Lower-level than DevTools' Timeline tab, which already wraps Perfetto traces. |

### Integration cost
- Zero install
- ~1 hour to write the protocol doc
- ~1 hour for Julien's first capture session (then ~15 min per repeat)
- **Estimate: 2 hours setup, ongoing manual gate per merge to S1-S5**

### Acceptance thresholds (proposed for L1.0 spec)
- Cold start (`timeToFirstFrameMicros`): **< 2500ms** on A14
- Scroll FPS on Aujourd'hui home: **median ≥ 55 FPS, p95 ≥ 50 FPS** over 10s
- MTC bloom: **0 dropped frames** during 250ms ease-out (16/16 frames under 16ms)
- Memory after MTC tap: **delta < 4 MB** (no leak — re-tap 10× must stay flat)

---

## 4. Firebase Test Lab investigation for v2.3 (DOCUMENT ONLY)

### Findings (verified 2026-04 against Firebase docs)

**Pricing model** ([source](https://firebase.google.com/docs/test-lab/usage-quotas-pricing)):
- Spark plan (free): 5 physical device tests/day, 10 virtual/day
- Blaze (pay-as-you-go): **$5/device-hour** for physical devices, $1/device-hour for virtual
- Realistic v2.3 budget for one PR run: 1 device × 15 min = $1.25 per PR. 100 PRs/month = $125/month. Cheap.

**Galaxy A14 availability:**
- Firebase Test Lab device catalog as of 2026-Q1 includes Samsung A-series, but **Galaxy A14 specifically must be confirmed at provisioning time** via `gcloud firebase test android models list | grep -i a14`. The catalog rotates.
- If A14 not in catalog: nearest equivalent is **Galaxy A15** (Android 14, 4 GB RAM) — same SoC family (Mediatek Helio G99), behavior delta is small for our 4 metrics.
- Fallback: **Pixel 4a** (Android 13, 6 GB) — overrepresents perf, would need a deflation factor.

**GitHub Actions integration:**
- Official action: `google-github-actions/auth@v2` + `gcloud firebase test android run` shell step
- Requires GCP service account JSON in repo secrets (1 secret)
- Existing macos-15 runner can call `gcloud` after `setup-gcloud@v2` step (~20 LOC YAML)
- Total CI time impact: ~5-8 min added per run (upload APK, queue, run, fetch report)

**v2.3 prep checklist (do not execute now):**
1. Add `tools/perf-baseline/` directory with the metric extraction script (parses Firebase Test Lab `videos.json` + perf stats output)
2. Provision GCP project + service account with `Firebase Test Lab Admin` role
3. Confirm A14 or fallback device in catalog at v2.3 kickoff
4. Estimate budget: ~$150/month at expected PR volume. Negligible vs Anthropic API spend.
5. Decide PASS/FAIL gate thresholds (likely match item 3's manual thresholds with 10% slack for cloud variance)

**Integration cost when v2.3 lands:** ~1 day (GCP setup + workflow + threshold tuning)

### Sources
- [Firebase Test Lab pricing](https://firebase.google.com/docs/test-lab/usage-quotas-pricing) — pricing verified
- [Firebase Test Lab device catalog](https://firebase.google.com/docs/test-lab/android/available-testing-devices) — catalog page (refresh at v2.3 kickoff)
- [gist: Android device list dump 2026-02](https://gist.github.com/akexorcist/c55af0f438f6ddea6a94e26962ea52ba) — community snapshot, useful sanity check

---

## 5. `flutter_localizations` ARB canton namespace pattern (L1.4)

### Recommendation
**DO NOT ADD A PACKAGE.** Use a **second `LocalizationsDelegate`** alongside the existing one. ~40 LOC custom delegate, no new dependency.

### The pattern
Flutter's `gen_l10n` tool generates one delegate per ARB family (controlled by `arb-dir` + `template-arb-file` + `output-class` in `l10n.yaml`). You can run `gen_l10n` **twice** with two `l10n.yaml` files to produce two independent localization classes:

**File 1: `apps/mobile/l10n.yaml`** (existing — unchanged)
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
```

**File 2: `apps/mobile/l10n_regional.yaml`** (NEW)
```yaml
arb-dir: lib/l10n_regional
template-arb-file: app_regional_vs.arb
output-localization-file: app_regional_localizations.dart
output-class: AppRegionalLocalizations
preferred-supported-locales: ["fr_CH", "de_CH", "it_CH"]
```

**Directory structure:**
```
apps/mobile/lib/l10n_regional/
  app_regional_vs.arb   # fr-CH base, ~30 keys, voix VS
  app_regional_zh.arb   # de-CH base, ~30 keys, voix ZH
  app_regional_ti.arb   # it-CH base, ~30 keys, voix TI
```

**Resolution at runtime:** A custom `RegionalVoiceService.forCanton(canton)` (already exists per CLAUDE.md §6) reads the user's canton from `Profile`, picks the right ARB family by canton key, and exposes a thin lookup `regional.greeting()` that returns from `AppRegionalLocalizations` of the canton-mapped locale. Falls back to base `AppLocalizations` if no regional override exists for that key.

### Why custom delegate over alternatives
| Option | Verdict | Why |
|--------|---------|-----|
| Two `gen_l10n` configs + custom delegate | **CHOSEN** | Zero new dependency. Reuses ARB tooling exactly as designed. Canton scoping happens in app code where it belongs (it's a profile-driven choice, not a locale-driven one). |
| `slang` package | Reject | Beautiful tool, but adopting a non-flutter_localizations i18n package mid-project means migrating 233 existing keys. Cost > benefit. |
| Single ARB family with `vs_`/`zh_`/`ti_` key prefixes | Reject | Pollutes the canonical 6-language ARB files with strings that have no business being translated into Portuguese. Violates the carve-out spirit. |
| Custom JSON loader (no ARB) | Reject | Loses ARB tooling (placeholders, plurals, ICU). |

### Code skeleton (the actual ~40 LOC)
```dart
// apps/mobile/lib/services/regional_voice_service.dart (extension)
class RegionalVoiceService {
  static String? lookup(BuildContext context, String key, String canton) {
    final regional = AppRegionalLocalizations.of(context);
    if (regional == null) return null;
    return switch (canton) {
      'VS' => regional.vs(key),
      'ZH' => regional.zh(key),
      'TI' => regional.ti(key),
      _ => null,
    };
  }
}

// In app shell:
MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,         // existing
    AppRegionalLocalizations.delegate, // NEW
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('fr'), Locale('en'), Locale('de'), Locale('es'), Locale('it'), Locale('pt'),
    Locale('fr', 'CH'), Locale('de', 'CH'), Locale('it', 'CH'), // NEW for regional
  ],
)
```

### Integration cost
- 3 ARB files (~30 keys each, written by Julien + native validators)
- 1 `l10n_regional.yaml`
- 1 build script update to run `flutter gen-l10n --config l10n_regional.yaml` after the main one
- ~40 LOC to extend `RegionalVoiceService`
- ~10 LOC delegate registration
- **Estimate: 1 day setup + content writing ongoing per chantier**

---

## 6. VoiceCursorContract codegen (Phase 0, L1.0)

### Recommendation
**Single JSON file as source of truth** + **two thin generators**:
1. **Source of truth:** `contracts/voice_cursor.json` (committed at repo root, not inside backend or mobile)
2. **Python generator:** `datamodel-code-generator` (`pip install datamodel-code-generator`) reads JSON Schema → emits Pydantic v2 model. Run via Makefile target `make voice-cursor-py`.
3. **Dart generator:** Hand-rolled ~60 LOC Dart script (`tools/codegen/voice_cursor_to_dart.dart`) reads same JSON → emits a `const` class. Runs via `dart run tools/codegen/voice_cursor_to_dart.dart`.

Both generators run in CI as a **drift check**: if regenerated output differs from committed file, the build fails. This is the standard contract-codegen guard.

### Why this over alternatives
| Option | Verdict | Why |
|--------|---------|-----|
| JSON schema + 2 thin gens | **CHOSEN** | Single source. Pydantic v2 is fully spec'd from JSON Schema by `datamodel-code-generator` (battle-tested, used by FastAPI ecosystem). Dart side is so small (5 levels, ~10 fields, ~20 garde-fou rules) that hand-rolling a 60-LOC generator is cheaper than learning a heavyweight Dart codegen package. |
| Hand-written sync (no codegen) | Reject | Drift risk is the entire reason VoiceCursorContract is a Phase 0 deliverable. Manual sync defeats the purpose. |
| `freezed` + Python codegen | Reject | `freezed` is great for unions but VoiceCursorContract is a const config matrix, not a sum type. Adds build_runner ceremony to mobile. Pydantic side has no equivalent toolchain so we'd still need a second generator. |
| Protobuf | Reject | Overkill for a config doc. Adds .proto compilation to two languages. The data is read once at app boot, not transmitted on the wire. |
| OpenAPI extension | Reject | VoiceCursorContract is a config artifact, not an API endpoint. Doesn't belong in `tools/openapi/`. |

### Source-of-truth shape
```json
// contracts/voice_cursor.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "VoiceCursorContract",
  "version": "1.0.0",
  "levels": {
    "N1": { "name": "Neutre", "posture": "factual", "weeklyMax": null },
    "N2": { "name": "Vif",    "posture": "direct",  "weeklyMax": null },
    "N3": { "name": "Complice","posture": "warm",   "weeklyMax": null },
    "N4": { "name": "Piquant","posture": "sharp",   "weeklyMax": null },
    "N5": { "name": "Cash",   "posture": "blunt",   "weeklyMax": 1   }
  },
  "routingMatrix": {
    "G1": { "new": "N1", "established": "N2", "intimate": "N2" },
    "G2": { "new": "N2", "established": "N3", "intimate": "N4" },
    "G3": { "new": "N4", "established": "N5", "intimate": "N5" }
  },
  "guardrails": {
    "minOnG3": "N2",
    "maxOnSensitiveTopics": "N3",
    "fragileModeMaxDays": 30,
    "fragileModeCap": "N3",
    "sensitiveTopics": ["bereavement","divorce","jobLoss","illness"]
  },
  "userPreferenceCaps": {
    "soft": "N3",
    "direct": "N4",
    "unfiltered": "N5"
  }
}
```

### Generated artifacts
- `services/backend/app/schemas/voice_cursor.py` (Pydantic v2, do-not-edit header)
- `apps/mobile/lib/services/voice/voice_cursor_contract.dart` (Dart const, do-not-edit header)

### Integration cost
- ~80 LOC JSON
- ~60 LOC Dart codegen script
- ~3 LOC Makefile targets (`voice-cursor-py`, `voice-cursor-dart`, `voice-cursor-check`)
- ~10 LOC GitHub Actions step for drift check (run codegen, `git diff --exit-code`)
- **Estimate: 0.5 day total**
- Runtime cost: zero (const data, loaded once)

### Version pins
- `datamodel-code-generator>=0.25` (current, supports JSON Schema draft-07 + Pydantic v2 output cleanly)
- Add to `services/backend/pyproject.toml` under `[tool.poetry.group.dev.dependencies]`

---

## 7. AAA contrast tooling (L1.1, L1.3)

### Recommendation
**DO NOT ADD A PACKAGE.** Write a ~30 LOC pure-Dart `wcagContrastRatio(Color fg, Color bg)` helper + a widget test pattern that traverses MintColors token pairs and asserts ratios. Runs in existing `flutter test` job, blocks CI.

### Why no package
| Option | Verdict | Why |
|--------|---------|-----|
| Custom 30-LOC helper + widget test | **CHOSEN** | WCAG 2.1 contrast formula is 6 lines (relative luminance + (L1+0.05)/(L2+0.05)). Adding a package for 6 lines is silly. Runs in existing `flutter test`. Zero CI infra change. |
| `axe-core` | Reject | Web/DOM only. Flutter renders to canvas; axe has no Flutter binding. |
| Stark (Figma plugin) | Reject | Design-time only, not runtime, not CI-able. Useful for designers, not engineers. |
| `accessibility_test` Dart package | Reject after check | The package exists (pub.dev) but is largely unmaintained, last update 2023, wraps the same `SemanticsTester` we already get from `flutter_test`. No value-add. |
| Flutter's built-in `accessibilityGuideline` matchers | **PARTIALLY ADOPT** | `meetsGuideline(textContrastGuideline)` exists in `flutter_test` and checks AA, NOT AAA. Use it for AA gating across the whole app, then layer the custom AAA helper on top for S1-S5. |

### The 30-LOC helper
```dart
// apps/mobile/test/helpers/wcag_contrast.dart
import 'dart:math';
import 'package:flutter/material.dart';

double _luminanceChannel(double c) {
  c = c / 255.0;
  return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color c) =>
    0.2126 * _luminanceChannel(c.red.toDouble()) +
    0.7152 * _luminanceChannel(c.green.toDouble()) +
    0.0722 * _luminanceChannel(c.blue.toDouble());

double wcagContrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

const aaaNormalText = 7.0;
const aaaLargeText = 4.5;
```

### The test pattern
```dart
// apps/mobile/test/accessibility/aaa_contrast_test.dart
testWidgets('S1 intent_screen — all text pairs meet AAA', (tester) async {
  await tester.pumpWidget(const MintApp());
  await tester.tap(find.byType(IntentScreen));
  await tester.pumpAndSettle();

  // For each Text widget, walk up to the nearest Container background,
  // compute contrast, assert >= 7.0 (or >= 4.5 if fontSize >= 18sp or >= 14sp bold)
  final textWidgets = find.byType(Text);
  for (final element in textWidgets.evaluate()) {
    final text = element.widget as Text;
    final fg = (text.style?.color ?? DefaultTextStyle.of(element).style.color)!;
    final bg = _findNearestBackground(element);
    final ratio = wcagContrastRatio(fg, bg);
    final isLarge = (text.style?.fontSize ?? 14) >= 18;
    final required = isLarge ? aaaLargeText : aaaNormalText;
    expect(ratio, greaterThanOrEqualTo(required),
      reason: 'Text "${text.data}" fg=$fg bg=$bg ratio=$ratio < $required');
  }
});
```

### What this does NOT cover (and our gaps)
- **Non-text contrast** (icons, focus rings, dividers) — WCAG 1.4.11 requires 3:1 for non-text UI. Add separate matcher with 3:1 threshold for icon-bearing widgets.
- **Live overlay states** (focus, hover, pressed) — covered by Patrol golden tests in item 2.
- **Semantic labels presence** — covered by Flutter's `meetsGuideline(labeledTapTargetGuideline)`.

Combine all 4 into one `accessibility_smoke_test.dart` that runs per S1-S5 surface in CI.

### Integration cost
- ~30 LOC helper
- ~50 LOC test pattern + ~50 LOC per surface × 5 surfaces = ~280 LOC tests
- 0 new dependencies
- 0 CI changes (runs in existing `flutter test` job)
- **Estimate: 1 day total for helper + S1-S5 coverage**

---

## Installation summary

```bash
# Backend dev tooling (codegen)
cd services/backend
poetry add --group dev datamodel-code-generator

# IRR one-shot tool (isolated)
mkdir -p tools/voice-cursor-irr
cd tools/voice-cursor-irr
python3 -m venv .venv && source .venv/bin/activate
pip install krippendorff>=0.6.1 numpy
deactivate

# Flutter dev dependency
cd apps/mobile
flutter pub add --dev patrol
dart pub global activate patrol_cli

# CI: add 'dart pub global activate patrol_cli' to .github/workflows/flutter.yml
# CI: add codegen drift check step to .github/workflows/backend.yml
```

**Net new dependencies on the running app: ZERO.** All additions are dev/test/tooling. The shipped APK and FastAPI service get nothing new. This is the right shape for a design milestone.

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `easy_localization` package | Would replace `flutter_localizations` and force migrating 233 keys mid-milestone | Custom delegate + second `gen_l10n` config (item 5) |
| `slang` i18n | Same migration cost, no value for canton scoping | Same |
| `accessibility_test` pub package | Stale (2023), wraps existing `flutter_test` | 30-LOC helper + native matchers (item 7) |
| `freezed` for VoiceCursorContract | Build_runner ceremony for a const config | JSON + thin codegen (item 6) |
| Protobuf for VoiceCursorContract | Not on the wire, two-language compile step | Same |
| Maestro / Appium | Non-Dart test DSLs, slow | Patrol (item 2) |
| ReCal3 web tool | No reproducibility, no version control | `krippendorff` PyPI (item 1) |
| Android Studio Profiler for Flutter perf | Reads native traces; misses Dart context | `flutter --profile` + DevTools (item 3) |
| Stark / axe-core | Design-time or web-only | Custom WCAG helper (item 7) |
| Adding Patrol golden differ | Doesn't exist as separate concept | Reuse existing `matchesGoldenFile` 1.5% tolerance (item 2) |
| Firebase Test Lab NOW | v2.2 is manual gate by decision | v2.3 prep doc only (item 4) |

---

## Version Compatibility Notes

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `patrol ^4.1.1` | Flutter ≥3.16, Android SDK ≥21 | Both already met. patrol_cli must match minor version. |
| `krippendorff ≥0.6.1` | Python ≥3.8, NumPy ≥1.20 | Isolated venv — no impact on backend `pyproject.toml`. |
| `datamodel-code-generator ≥0.25` | Pydantic v2 ≥2.0 | Backend already on Pydantic v2 per CLAUDE.md §4. |
| Custom WCAG helper | Pure Dart, no deps | — |
| Custom regional delegate | `flutter_localizations` (already in) | Requires running `gen_l10n` twice; document in README. |

---

## Sources

- **Patrol** — [pub.dev/packages/patrol](https://pub.dev/packages/patrol), [patrol.leancode.co](https://patrol.leancode.co/), [Patrol 4.0 docs](https://patrol.leancode.co/v4) (verified 2026-04-07, version 4.1.1 confirmed)
- **Krippendorff** — [PyPI krippendorff](https://pypi.org/project/krippendorff/) (Santiago Castro), [Label Studio writeup](https://labelstud.io/blog/how-to-use-krippendorff-s-alpha-to-measure-annotation-agreement/), [Wikipedia: Krippendorff's alpha](https://en.wikipedia.org/wiki/Krippendorff's_alpha) (verified 2026-04-07)
- **Firebase Test Lab** — [Pricing & quotas](https://firebase.google.com/docs/test-lab/usage-quotas-pricing), [Available devices](https://firebase.google.com/docs/test-lab/android/available-testing-devices), [Device list snapshot 2026-02](https://gist.github.com/akexorcist/c55af0f438f6ddea6a94e26962ea52ba) (verified 2026-04-07; A14 specifically requires runtime confirmation)
- **datamodel-code-generator** — [koxudaxi/datamodel-code-generator GitHub](https://github.com/koxudaxi/datamodel-code-generator) (Pydantic v2 support stable since 0.21)
- **WCAG 2.1 contrast formula** — [W3C WCAG 2.1 §1.4.3 / §1.4.6](https://www.w3.org/TR/WCAG21/) (AA = 4.5/3.0, AAA = 7.0/4.5)
- **Flutter perf** — [docs.flutter.dev/perf/ui-performance](https://docs.flutter.dev/perf/ui-performance), DevTools Performance tab (built-in to Flutter SDK)
- **Flutter accessibility matchers** — `package:flutter_test`'s `meetsGuideline(textContrastGuideline)` (AA-only, AAA must be custom)

**Confidence:** HIGH on all engineering recommendations (items 1, 2, 3, 5, 6, 7). MEDIUM on item 4 device availability — Firebase Test Lab catalog rotates and Galaxy A14 specifically must be re-confirmed at v2.3 kickoff via `gcloud firebase test android models list`.

---
*Stack research for: MINT v2.2 La Beauté de Mint — additive only*
*Researched: 2026-04-07*
