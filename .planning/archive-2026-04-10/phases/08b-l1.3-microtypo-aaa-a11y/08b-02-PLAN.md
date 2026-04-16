---
phase: 08b-l1.3-microtypo-aaa-a11y
plan: 02
type: execute
wave: 2
depends_on: [08b-01]
files_modified:
  - apps/mobile/lib/screens/landing_screen.dart
  - apps/mobile/lib/screens/onboarding/intent_screen.dart
  - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
  - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
  - apps/mobile/lib/widgets/coach/response_card_widget.dart
  - apps/mobile/lib/widgets/report/debt_alert_banner.dart
  - test/design_system/s0_s5_microtypography_test.dart
autonomous: true
requirements: [AESTH-01, AESTH-02, AESTH-03, AESTH-07]
must_haves:
  truths:
    - "Every Text widget on S0-S5 sits on a 4pt baseline grid at A14 width"
    - "Body copy lines fall within 45-75 characters, never above 80"
    - "No S0-S5 screen renders more than 3 distinct heading sizes"
    - "S4 headline numbers render at body weight, not display weight (Aesop rule)"
    - "S4 response card body has exactly 4 slots in MUJI order (D-06)"
  artifacts:
    - path: "test/design_system/s0_s5_microtypography_test.dart"
      provides: "4pt grid + line length + heading count + S4 MUJI 4-slot assertions"
      contains: "expect(baselineY % 4"
  key_links:
    - from: "response_card_widget.dart body Column"
      to: "4 named slots: label, now, without-change, next"
      via: "explicit section comments + children count"
      pattern: "_S4BodySlot|// MUJI slot"
---

<objective>
Apply Spiekermann microtypographie pass on the 6 S0-S5 surfaces (already
AAA-token-clean from Plan 01): 4pt baseline grid snap (AESTH-01), 45-75 char
line length + max 3 heading levels (AESTH-02), Aesop demotion of headline
numbers to body weight on S4 (AESTH-03), and MUJI 4-line grammar on the S4
response card body (AESTH-07).

Purpose: Close AESTH-01/02/03/07. Make every S0-S5 surface read like it was
set in a proper typeshop, not assembled.

Output: 6 modified surfaces + 1 microtypography golden/widget test.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-CONTEXT.md
@.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-01-SUMMARY.md
@docs/DESIGN_SYSTEM.md
@docs/AUDIT_RETRAIT_S0_S5.md
@apps/mobile/lib/theme/colors.dart
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write microtypography test scaffold (RED)</name>
  <files>test/design_system/s0_s5_microtypography_test.dart</files>
  <behavior>
    Four test groups, each rendering each of the 6 surfaces at 360x800 (A14):
    1. **4pt baseline (AESTH-01):** walk RenderBox tree, for every RenderParagraph
       assert `localToGlobal(Offset.zero).dy % 4 == 0`.
    2. **Line length 45-75 (AESTH-02):** extract visible body Text widgets,
       use TextPainter to count glyphs per line, assert `min >= 45 && max <= 75`
       (headings exempted via a tag).
    3. **Max 3 heading levels (AESTH-02):** collect distinct fontSize values
       where `fontSize >= 20 || fontWeight >= w600`, assert `distinct.length <= 3`.
    4. **S4 MUJI 4-slot (AESTH-07) + Aesop number demotion (AESTH-03):** for
       response_card_widget.dart, assert the body Column has exactly 4 direct
       children (or 4 named `_S4BodySlot` widgets), AND any Text containing a
       numeric glyph renders with `fontWeight <= w500` (body, not display).
  </behavior>
  <action>
    Create the test file. RED run expected — current widgets will fail at
    least the MUJI 4-slot and likely the 4pt baseline checks. Failure output
    IS the work list for Task 2.

    Tag body vs heading Text via a `Key('heading')` / `Key('body')` convention
    OR via `TextStyle.fontSize` threshold (>= 20 = heading). Document the
    choice in-file.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/design_system/s0_s5_microtypography_test.dart</automated>
  </verify>
  <done>Test file compiles, runs, and FAILS on current code. Failure report enumerates the offending lines, baselines, heading counts, and S4 slot shape.</done>
</task>

<task type="auto">
  <name>Task 2: Spiekermann microtypo pass (GREEN)</name>
  <files>
    apps/mobile/lib/screens/landing_screen.dart,
    apps/mobile/lib/screens/onboarding/intent_screen.dart,
    apps/mobile/lib/screens/main_tabs/mint_home_screen.dart,
    apps/mobile/lib/widgets/coach/coach_message_bubble.dart,
    apps/mobile/lib/widgets/coach/response_card_widget.dart,
    apps/mobile/lib/widgets/report/debt_alert_banner.dart
  </files>
  <action>
    Walk each surface and apply the microtypo rules until Task 1's test is
    GREEN. Work order:

    1. **4pt baseline snap (AESTH-01):** audit every `SizedBox(height: N)`,
       `Padding(EdgeInsets.*)`, `Container(margin/padding: …)` in the 6 files.
       Round N to the nearest multiple of 4 (prefer rounding UP — never
       compress below current visual rhythm). Acceptable values: 4, 8, 12, 16,
       20, 24, 28, 32, 40, 48, 56, 64.

    2. **Line length (AESTH-02):** wrap body `Text` in `ConstrainedBox(
       constraints: BoxConstraints(maxWidth: <computed>))` where the
       computed maxWidth yields ≤ 75 chars at the current TextStyle. For
       ultra-short copy, add `minWidth` or rewrite copy to hit ≥ 45 chars.
       Favor copy edits over width hacks when possible.

    3. **Max 3 heading levels (AESTH-02):** collapse any screen using > 3
       distinct heading sizes. Promote/demote to the canonical 3: display
       (32), title (24), subtitle (20). Do NOT introduce new `MintHeadingN`
       abstraction — use existing TextStyles from `DESIGN_SYSTEM.md`.

    4. **Aesop number demotion on S4 (AESTH-03):** in
       `response_card_widget.dart`, any Text that renders a numeric value
       (CHF amount, percentage, years) gets `fontWeight: FontWeight.w500`
       max and `fontSize <= 18`. The surrounding sentence carries the
       rhythm, not the number. Inline comment: `// AESTH-03 Aesop rule:
       sentence carries rhythm, not the number`.

    5. **MUJI 4-slot S4 (AESTH-07, D-06):** restructure the response card
       body Column to exactly 4 direct children in this order:
         (a) label/category,
         (b) current state ("what you're doing now"),
         (c) without-change outcome (inline MTC slot placeholder if absent),
         (d) next action.
       Add a banner comment above the Column:
       `// MUJI 4-line grammar (AESTH-07, D-06): 4 slots, no chrome.`
       Extract a private `_S4BodySlot({required Widget child, required String role})`
       if it makes the children count assertion cleaner. No chrome (dividers,
       ornaments, decorative spacers beyond 4pt rhythm) between slots.

    **Prohibited:** editing strings in ARB files (i18n untouched in this plan),
    introducing new design tokens, touching non-S0-S5 files, reverting any
    Plan 01 token swap.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/design_system/s0_s5_microtypography_test.dart test/accessibility/s0_s5_aaa_contrast_test.dart && flutter analyze</automated>
  </verify>
  <done>
    Microtypography test + Plan 01 AAA contrast test BOTH pass. `flutter analyze`
    0 errors. S4 body renders exactly 4 slots. Every SizedBox/Padding in the 6
    files is a multiple of 4. AESTH-01/02/03/07 closed.
  </done>
</task>

</tasks>

<verification>
- Both tests GREEN
- `flutter analyze` 0 errors
- Manual grep: `SizedBox\(height: ([0-9]+)` in the 6 files → every captured N % 4 == 0
- Manual grep: `// MUJI 4-line grammar` present in response_card_widget.dart
</verification>

<success_criteria>
- AESTH-01 (4pt), AESTH-02 (45-75 char + 3 headings), AESTH-03 (Aesop demote),
  AESTH-07 (MUJI 4-slot) all closed
- No Plan 01 regressions
- Golden/widget test is the durable enforcement mechanism (D-05)
</success_criteria>

<output>
Create `.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-02-SUMMARY.md` with:
per-surface count of spacing rounds, heading collapses, line-length fixes, S4
slot diff (before/after), and proof both tests are green.
</output>
