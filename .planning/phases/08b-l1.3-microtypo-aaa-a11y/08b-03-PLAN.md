---
phase: 08b-l1.3-microtypo-aaa-a11y
plan: 03
type: execute
wave: 3
depends_on: [08b-02]
files_modified:
  - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
  - apps/mobile/lib/widgets/coach/coach_typing_indicator.dart
  - apps/mobile/lib/widgets/mtc/mtc_bloom.dart
  - apps/mobile/lib/screens/onboarding/intent_screen.dart
  - test/accessibility/coach_live_region_test.dart
  - test/accessibility/reduced_motion_test.dart
autonomous: true
requirements: [ACCESS-07, ACCESS-08]
must_haves:
  truths:
    - "Screen readers announce new incoming coach messages without focus shift"
    - "MTC bloom animation collapses to 50ms opacity (or skip) under MediaQuery.disableAnimations"
    - "Coach typing indicator respects reduced-motion"
    - "Onboarding transitions respect reduced-motion"
  artifacts:
    - path: "test/accessibility/coach_live_region_test.dart"
      provides: "Semantics tree assertion proving liveRegion: true on incoming bubble"
    - path: "test/accessibility/reduced_motion_test.dart"
      provides: "MediaQuery.disableAnimations override + duration assertions on 3 motion sites"
  key_links:
    - from: "coach_message_bubble.dart incoming branch"
      to: "Semantics(liveRegion: true)"
      via: "direct wrapper"
      pattern: "liveRegion:\\s*true"
    - from: "MTC bloom + typing + onboarding animations"
      to: "MediaQuery.disableAnimationsOf(context)"
      via: "conditional duration / skip"
      pattern: "disableAnimationsOf|disableAnimations"
---

<objective>
Close ACCESS-07 (reduced-motion fallback across MTC bloom + coach typing +
onboarding transitions) and ACCESS-08 (liveRegion: true on incoming coach
bubble). Audit existing usage first, fix gaps, commit a dart test for each
rule.

Purpose: Screen reader users hear new coach output without losing their
place; users with vestibular disorders do not get ambushed by bloom or
typing animations.

Output: liveRegion on coach bubble incoming + reduced-motion fallback on 3
motion sites + 2 dart tests.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-CONTEXT.md
@.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-02-SUMMARY.md
@apps/mobile/lib/widgets/coach/coach_message_bubble.dart
@apps/mobile/lib/screens/onboarding/intent_screen.dart

<interfaces>
Flutter APIs used:
```dart
Semantics(liveRegion: true, child: Text(message))
MediaQuery.disableAnimationsOf(context) // bool
```
Fallback pattern per D-08:
```dart
final reduced = MediaQuery.disableAnimationsOf(context);
final duration = reduced ? const Duration(milliseconds: 50) : const Duration(milliseconds: 320);
// or: if (reduced) return child; // skip animation entirely
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Audit + fix liveRegion and reduced-motion sites, add tests</name>
  <files>
    apps/mobile/lib/widgets/coach/coach_message_bubble.dart,
    apps/mobile/lib/widgets/coach/coach_typing_indicator.dart,
    apps/mobile/lib/widgets/mtc/mtc_bloom.dart,
    apps/mobile/lib/screens/onboarding/intent_screen.dart,
    test/accessibility/coach_live_region_test.dart,
    test/accessibility/reduced_motion_test.dart
  </files>
  <action>
    **Step A — locate the 3 motion sites.** The executor must first grep to
    confirm exact filenames for MTC bloom and typing indicator post-Phase 8a
    (names may be `mtc_bloom.dart`, `mtc_widget.dart`, `coach_typing_dots.dart`,
    etc.). Update `files_modified` frontmatter in the summary if names differ.

    **Step B — liveRegion (ACCESS-08).** In `coach_message_bubble.dart` locate
    the incoming branch (the path that renders Claude's output, not the user
    echo). Wrap the text content in `Semantics(liveRegion: true, container: true)`.
    Do NOT wrap the whole bubble — only the Text, so that focus stays put
    and only the content is announced.

    **Step C — reduced-motion (ACCESS-07).** For each of the 3 motion sites:
      1. Read `MediaQuery.disableAnimationsOf(context)` at the start of build.
      2. If true: either (a) set `duration: Duration(milliseconds: 50)` and
         replace any implicit curve with `Curves.linear`, or (b) return the
         final state child directly and skip the animation.
      3. For MTC bloom specifically: skip bloom entirely (return the final
         dot state). Bloom is decorative; it has no information.
      4. For coach typing indicator: reduce to a static "…" glyph.
      5. For onboarding transitions in `intent_screen.dart`: check for any
         `AnimatedSwitcher` / `PageTransitionsBuilder` / `Hero` animations;
         shorten to 50ms or skip.

    Inline comment at each site:
    `// ACCESS-07 (D-08): reduced-motion fallback per MediaQuery.disableAnimations`

    **Step D — tests.**
    - `test/accessibility/coach_live_region_test.dart`:
      pumpWidget a CoachMessageBubble with role=incoming, walk the Semantics
      tree via `tester.getSemantics(find.byType(Text))`, assert
      `semantics.hasFlag(SemanticsFlag.isLiveRegion) == true`.
      Second test: role=outgoing (user) → assert liveRegion is FALSE
      (only Claude output should announce).

    - `test/accessibility/reduced_motion_test.dart`:
      Use `tester.binding.window.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: true);`
      (or the `MediaQuery(data: MediaQueryData(disableAnimations: true))`
      wrapper pattern, whichever is easier).
      For each of the 3 sites, pump once, run `tester.pump(Duration(milliseconds: 50))`,
      assert the animation has settled (`tester.hasRunningAnimations == false`
      OR the widget is at its final state).

    **Prohibited:** touching Plan 01 tokens, touching Plan 02 spacing (both
    must remain GREEN), introducing a new accessibility abstraction beyond
    simple Semantics wrappers, changing any i18n string.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/accessibility/ test/design_system/s0_s5_microtypography_test.dart && flutter analyze</automated>
  </verify>
  <done>
    liveRegion test passes for incoming, fails-open for outgoing. Reduced-motion
    test passes for all 3 sites. Plan 01 + Plan 02 tests still GREEN. `flutter analyze`
    0 errors. ACCESS-07 + ACCESS-08 closed.
  </done>
</task>

</tasks>

<verification>
- All 3 new accessibility tests GREEN
- Plan 01 + Plan 02 tests still GREEN (no regressions)
- Grep: `liveRegion:\s*true` appears in coach_message_bubble.dart at least once, and nowhere in the outgoing branch
- Grep: `disableAnimationsOf|disableAnimations` appears in each of the 3 motion site files
</verification>

<success_criteria>
- ACCESS-07 and ACCESS-08 closed
- Zero regressions in 01/02 tests
- Incoming coach bubble announces without focus shift; 3 motion sites respect OS reduced-motion
</success_criteria>

<output>
Create `.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-03-SUMMARY.md` with:
exact filenames for the 3 motion sites (resolved post-audit), test results,
grep proof, and any flags for Plan 04 about what the live session should
exercise first.
</output>
