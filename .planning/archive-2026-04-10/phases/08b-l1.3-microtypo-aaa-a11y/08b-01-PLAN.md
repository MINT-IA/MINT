---
phase: 08b-l1.3-microtypo-aaa-a11y
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/screens/landing_screen.dart
  - apps/mobile/lib/screens/onboarding/intent_screen.dart
  - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
  - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
  - apps/mobile/lib/widgets/coach/response_card_widget.dart
  - apps/mobile/lib/widgets/report/debt_alert_banner.dart
  - test/accessibility/s0_s5_aaa_contrast_test.dart
autonomous: true
requirements: [AESTH-05, AESTH-06, ACCESS-04]
must_haves:
  truths:
    - "Every information-bearing text/icon on S0-S5 uses an Aaa-suffixed token"
    - "Pastels (saugeClaire, bleuAir, pecheDouce, corailDiscret, porcelaine) no longer carry text on S0-S5"
    - "Only one semantic color (warningAaa) survives on S0-S5 text surfaces per D-04"
    - "WCAG AAA 7:1 contrast verified by a dart test for every S0-S5 text/background pair"
  artifacts:
    - path: "test/accessibility/s0_s5_aaa_contrast_test.dart"
      provides: "Pure-Dart 30-LOC AAA contrast helper + assertions on the 6 surfaces"
      contains: "expect(contrastRatio"
  key_links:
    - from: "6 S0-S5 source files"
      to: "MintColors.*Aaa tokens in lib/theme/colors.dart"
      via: "direct const reference"
      pattern: "MintColors\\.(textSecondary|textMuted|success|warning|error|info)Aaa"
---

<objective>
Migrate S0-S5 information-bearing text and icon surfaces from pastels and
legacy semantic tokens to the 6 AAA tokens implemented in Phase 2. Enforce
one-color-one-meaning (D-04): only `warningAaa` carries semantic weight on
S0-S5 text. Commit a pure-Dart AAA contrast helper test that fails if any
text/background pair drops below 7:1.

Purpose: Close AESTH-05, AESTH-06, ACCESS-04. Make "AAA from day 1" on
S0-S5 actually true, not aspirational.

Output: 6 modified surfaces + 1 new test file proving AAA.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-CONTEXT.md
@apps/mobile/lib/theme/colors.dart
@docs/AUDIT_RETRAIT_S0_S5.md
@docs/DESIGN_SYSTEM.md

<interfaces>
From apps/mobile/lib/theme/colors.dart (Phase 2 AESTH-04 tokens, already merged):

```dart
static const Color textSecondaryAaa = Color(0xFF595960);
static const Color textMutedAaa     = Color(0xFF5C5C61);
static const Color successAaa       = Color(0xFF0F5E28);
static const Color warningAaa       = Color(0xFF8C3F06);
static const Color errorAaa         = Color(0xFFA52121);
static const Color infoAaa          = Color(0xFF004FA3);
```

Swap map (per D-03):
- textSecondary -> textSecondaryAaa
- textMuted     -> textMutedAaa
- success (info-bearing) -> successAaa  OR  neutralize to textPrimary (per D-04)
- warning (info-bearing) -> warningAaa  (kept — the one semantic color)
- error   (info-bearing) -> errorAaa    (only for destructive confirms, max 1/surface)
- info    (info-bearing) -> neutralize to textPrimary (per D-04)

Audit reference rows (docs/AUDIT_RETRAIT_S0_S5.md line 620):
S0 = 7 REPLACE->AAA rows (R1, R2, R4, R5, R6, R7, R8)
S2 = 4 rows (R2, R4, R6, R7)
S3 = 1 row (R1)
S4 = 3 rows (R3, R5, R6)
S5 = 0 rows (handled via debt banner one-off)
Total = 15 swap sites minimum.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write AAA contrast test scaffold (RED)</name>
  <files>test/accessibility/s0_s5_aaa_contrast_test.dart</files>
  <behavior>
    - Pure-Dart helper `double contrastRatio(Color fg, Color bg)` computing WCAG 2.1 relative luminance ratio.
    - Test group "S0-S5 AAA contrast":
      - For each of the 6 surfaces, pump the widget, walk the element tree, extract every Text + Icon with its effective color and nearest ancestor background color.
      - Assert `contrastRatio(fg, bg) >= 7.0` on every pair.
    - Expect to FAIL initially (legacy pastels fail 7:1).
  </behavior>
  <action>
    Create the test file. Reference `apps/mobile/lib/theme/colors.dart` for the
    Aaa tokens. Helper is ~30 LOC per ACCESS-04. Use `WidgetTester.pumpWidget`
    with each of the 6 screens/widgets stubbed with minimal required providers.
    For Semantics/theme lookup use `Theme.of(context).textTheme` fallbacks.
    Run test and confirm RED on legacy tokens (this is the baseline failure
    the Task 2 swap will fix).
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/accessibility/s0_s5_aaa_contrast_test.dart</automated>
  </verify>
  <done>Test file exists, compiles, runs, and FAILS on current code (RED). Failure log enumerates the text/bg pairs below 7:1 — this list IS the swap checklist for Task 2.</done>
</task>

<task type="auto">
  <name>Task 2: Apply AAA token swap map across S0-S5 (GREEN)</name>
  <files>
    apps/mobile/lib/screens/landing_screen.dart,
    apps/mobile/lib/screens/onboarding/intent_screen.dart,
    apps/mobile/lib/screens/main_tabs/mint_home_screen.dart,
    apps/mobile/lib/widgets/coach/coach_message_bubble.dart,
    apps/mobile/lib/widgets/coach/response_card_widget.dart,
    apps/mobile/lib/widgets/report/debt_alert_banner.dart
  </files>
  <action>
    For each of the 6 files, apply the D-03 swap map (per D-02, manual edits,
    NOT codemod). Cross-reference every swap against `docs/AUDIT_RETRAIT_S0_S5.md`
    REPLACE->AAA rows enumerated in the interfaces block (15 sites total).

    Per-file guidance:
    - **S0 landing_screen.dart (7 sites, R1/R2/R4/R5/R6/R7/R8):** post Phase 7
      rebuild this is mostly already AAA; verify each Text color reference uses
      an Aaa token. Kill any remaining `textSecondary` / `textMuted` on
      information-bearing surfaces.
    - **S1 intent_screen.dart (0 audit rows but verify):** sweep for
      `MintColors.textSecondary` / `textMuted` and promote.
    - **S2 mint_home_screen.dart (4 sites, R2/R4/R6/R7):** swap the 4 sites,
      neutralize any success/info chip color per D-04.
    - **S3 coach_message_bubble.dart (1 site, R1):** body text -> textSecondaryAaa.
      Leave liveRegion work for Plan 03.
    - **S4 response_card_widget.dart (3 sites, R3/R5/R6):** swap body labels.
      Do NOT touch layout ordering — that is Plan 02's MUJI 4-line job.
    - **S5 debt_alert_banner.dart:** title/CTA -> errorAaa (destructive confirm,
      D-04 exception allows 1 errorAaa per surface). Body -> textSecondaryAaa.

    One-color-one-meaning (D-04): if a success/info color is information-bearing,
    demote to `textPrimary` or `textSecondaryAaa`. warningAaa is the ONLY
    semantic chip color allowed on S0-S5 (exception: S5 banner errorAaa).

    **Prohibited:** creating new tokens, modifying `colors.dart`, expanding
    scope beyond the 6 files, touching background pastels (they stay as fills).

    Commit inline code comment above each swap citing the audit row, e.g.
    `// AESTH-05 per AUDIT_RETRAIT S2 R4 (D-03 swap map)`.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/accessibility/s0_s5_aaa_contrast_test.dart && flutter analyze</automated>
  </verify>
  <done>
    AAA contrast test from Task 1 passes GREEN. `flutter analyze` returns 0 errors.
    Every swap site carries an inline comment citing the audit row. No new
    tokens introduced; `colors.dart` untouched.
  </done>
</task>

</tasks>

<verification>
- `cd apps/mobile && flutter test test/accessibility/s0_s5_aaa_contrast_test.dart` → PASS
- `cd apps/mobile && flutter analyze` → 0 errors
- Grep: `MintColors\.(textSecondary|textMuted|success|warning|error|info)(?!Aaa)` inside the 6 files → must only return background-only or destructive-confirm matches, each commented with AESTH-05/06 justification.
</verification>

<success_criteria>
- 15+ swap sites migrated across the 6 files (per AUDIT_RETRAIT line 620)
- Pure-Dart AAA contrast test committed and GREEN
- One-color-one-meaning (D-04): grep shows ≤ 1 errorAaa per surface, warningAaa is the only success/info-level semantic color
- No regressions in `flutter analyze`
- AESTH-05, AESTH-06, ACCESS-04 closed
</success_criteria>

<output>
After completion, create `.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-01-SUMMARY.md`
with: files touched, swap count per surface, grep proof, contrast test results,
and a one-line recommendation for Plan 02 (any surfaces where microtypo work is
blocked by token choices).
</output>
