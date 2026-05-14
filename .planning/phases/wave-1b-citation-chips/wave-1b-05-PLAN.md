---
phase: wave-1b
plan: 05
type: execute
wave: 2
depends_on: [wave-1b-04, wave-1b-07]
files_modified:
  - apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart
  - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
  - apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart
  - apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart
autonomous: true
requirements: [WAVE1B-04, WAVE1B-08]
must_haves:
  truths:
    - "New widget CoachCitationChipsSection exists at apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart and is a sibling of CoachSourcesSection (NOT an extension — per RESEARCH §9.4)"
    - "The widget renders one InkWell-wrapped Row per ToolCallCitationChip with Icons.calculate_outlined + S.of(context)!.coachCitationChipLabel(toolDisplayName) label"
    - "Each chip carries a stable Key('coachCitationChip-<toolName>') for Maestro testID stability per RESEARCH §9.5"
    - "coach_message_bubble.dart renders CoachCitationChipsSection in the message bubble tree alongside (NOT replacing) CoachSourcesSection, gated by msg.citationChips.isNotEmpty"
    - "Plan 01's chip widget stubs are unskipped and pass"
    - "Golden snapshots for 6 tools render and match files under apps/mobile/test/goldens/"
    - "onChipTap callback signature accepts a ToolCallCitationChip (modal opens in Plan 06 — Plan 05 just exposes the callback)"
  artifacts:
    - path: "apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart"
      provides: "Sibling widget rendering tool-call provenance chips alongside RagSource sources"
      contains: "class CoachCitationChipsSection|Icons.calculate_outlined|S.of(context)"
    - path: "apps/mobile/lib/widgets/coach/coach_message_bubble.dart"
      provides: "Chip section wired into the message render tree"
      contains: "CoachCitationChipsSection|citationChips"
    - path: "apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart"
      provides: "Plan 01 stubs unskipped + passing"
      contains: "testWidgets"
    - path: "apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart"
      provides: "Plan 01 golden stubs unskipped + 6 PNG snapshots generated"
      contains: "matchesGoldenFile"
  key_links:
    - from: "apps/mobile/lib/widgets/coach/coach_message_bubble.dart"
      to: "apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart"
      via: "import + use in build tree"
      pattern: "import 'coach_citation_chips_section.dart'|CoachCitationChipsSection"
    - from: "apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart"
      to: "apps/mobile/lib/services/rag_service.dart"
      via: "consumes ToolCallCitationChip list"
      pattern: "ToolCallCitationChip"
---

<objective>
Create `CoachCitationChipsSection` — a sibling Flutter widget to `CoachSourcesSection` (per RESEARCH §5.2 + §9.4) that renders one chip per `ToolCallCitationChip` returned by the backend. Wire it into the chat message bubble tree.

This plan only renders the chip surface and exposes an `onChipTap` callback. The modal (bottom sheet) lands in Plan 06.

**Why a sibling and NOT an extension of `CoachSourcesSection`** (per RESEARCH §9.4): `RagSource` is read by 30+ Flutter files; a sealed-class refactor is too invasive. Sibling widget = minimal blast radius, respects CONTEXT hard constraint #5 (reuses chip design tokens, not a new primitive).

**Maestro testID stability** (RESEARCH §9.5): each chip carries `Key('coachCitationChip-<toolName>')` so Plan 09's Maestro flow can tap by `id` instead of fragile text matching.
</objective>

## Counter-arguments considered

- **Counter-arg 1: extend `CoachSourcesSection` to render a mixed list (RagSource + CitationChip).** Rejected because `RagSource` is read by 30+ files (RESEARCH §9.4); a sealed-class refactor at this layer has high blast radius. A sibling section preserves blast-radius to ~3 files (this widget, `coach_message_bubble.dart`, the test files).
- **Counter-arg 2: render chips inline next to each number (Option (a) from CONTEXT open Q2).** Rejected per CONTEXT plan default Q2 (footer row, less visual noise). Inline placement requires regex-parsing the narrator's output to splice chips between text runs — complex and brittle to format changes; would also collide with citation_parser.py invariants (CONTEXT hard constraint #4).
- **Counter-arg 3: use a horizontal scrollable row (Row + SingleChildScrollView) instead of a Column.** Rejected because horizontal scroll hides chips off-screen and confuses Maestro tap-by-id (chip must be visible to tap). Column keeps all chips visible at the cost of vertical space — acceptable for 1-6 chips per response.
- **Data gap:** No visual A/B on inline vs footer layouts. Acceptable for v1; revisit if Sentry shows tap-through < 5%/week.

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@apps/mobile/lib/widgets/coach/coach_message_bubble.dart
@apps/mobile/lib/widgets/coach/chat_consent_chip.dart
@apps/mobile/lib/services/rag_service.dart

<interfaces>
CoachSourcesSection precedent (coach_message_bubble.dart:359-451):
- Container with `padding: 12dp` + `MintColors.bleuAir alpha 0.1` + `BorderRadius.circular(16)`.
- Header `S.of(context)!.coachSources` styled via `MintTextStyles.micro(color: MintColors.textMutedAaa).copyWith(fontWeight: w600, letterSpacing: 0.3)`.
- One row per source: `Icon(Icons.description_outlined, size: 12, color: MintColors.textSecondaryAaa.withValues(alpha: 0.6))` + `Text(title — section)` underlined.
- `InkWell(borderRadius: BorderRadius.circular(8), onTap: () => _navigate...)`.

Wave 1b widget — same shape with these differences:
- Header text: `S.of(context)!.coachCitationChipsHeader` (key from Plan 07 ARB).
- Icon: `Icons.calculate_outlined` (RESEARCH §5.6 — semantic "calculé").
- Row label: `S.of(context)!.coachCitationChipLabel(toolDisplayName)` where `toolDisplayName` comes from a tool-name-to-ARB-key lookup.
- onTap: invokes the `onChipTap(chip)` callback passed by parent (Plan 06 wires the modal).
- Each chip's `InkWell` is wrapped in `Key('coachCitationChip-${chip.toolName}')` for Maestro stability.

Tool display name lookup (Plan 07 ships ARB keys; Plan 05 wires the lookup function):
```dart
String _toolDisplayName(BuildContext context, String toolName) {
  final s = S.of(context)!;
  switch (toolName) {
    case 'budget_snapshot': return s.coachToolBudgetSnapshot;
    case 'retirement_projection': return s.coachToolRetirementProjection;
    case 'cross_pillar_analysis': return s.coachToolCrossPillarAnalysis;
    case 'couple_optimization': return s.coachToolCoupleOptimization;
    case 'cap_status': return s.coachToolCapStatus;
    case 'retrieve_memories': return s.coachToolRetrieveMemories;
    default: return toolName; // fallback for unknown tools
  }
}
```

Wiring in coach_message_bubble.dart (insert AFTER line 165 — the existing Sources block ends — and BEFORE Disclaimers at line 167):
```dart
// Citation chips (Wave 1b) — tool-call provenance, sibling of Sources.
if (msg.citationChips.isNotEmpty) ...[
  const SizedBox(height: MintSpacing.md - 4),
  Padding(
    padding: const EdgeInsets.only(left: 44, right: MintSpacing.xxl),
    child: CoachCitationChipsSection(
      chips: msg.citationChips,
      onChipTap: (chip) {
        // Plan 06 wires the modal; Plan 05 leaves an empty callback.
      },
    ),
  ),
],
```

ChatConsentChip primitive (chat_consent_chip.dart:70-95) — chip design-system tokens to reuse:
- `padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)`
- `BorderRadius.circular(20)` (rounded pill shape)
- `border: Border.all(width: 0.5, color: MintColors....)`
- `MintColors.porcelaine` background.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create CoachCitationChipsSection widget</name>
  <read_first>
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart lines 355-451 (FULL CoachSourcesSection — replicate shape)
    - apps/mobile/lib/widgets/coach/chat_consent_chip.dart lines 1-130 (chip design-system primitive)
    - apps/mobile/lib/theme/colors.dart (MintColors enum — verify bleuAir, porcelaine, textMutedAaa, textSecondaryAaa exist)
    - apps/mobile/lib/theme/text_styles.dart (MintTextStyles — verify .micro / .bodyMedium signatures)
    - apps/mobile/lib/theme/spacing.dart (MintSpacing — verify md, xs, xxl tokens)
    - apps/mobile/lib/services/rag_service.dart (ToolCallCitationChip definition from Plan 04)
  </read_first>
  <files>
    - apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart (create)
  </files>
  <behavior>
    The widget:
    - Accepts `List<ToolCallCitationChip> chips` (required) + `void Function(ToolCallCitationChip)? onChipTap` (optional).
    - Renders `SizedBox.shrink()` if `chips.isEmpty`.
    - Otherwise renders a Container with the same shape as `CoachSourcesSection` (bleuAir alpha 0.1 background, 16dp radius, 12dp padding).
    - Header: `S.of(context)!.coachCitationChipsHeader` (Plan 07 ARB key — for now in Plan 05 fall back to placeholder string "Calculs serveur" and add a TODO comment to wire ARB in Plan 07 — OR if ARB is wired by execution time, use S.of(context)!).
    - For each chip: an `InkWell` with `Key('coachCitationChip-${chip.toolName}')`, tap calls `onChipTap?.call(chip)`, child is a Row with `Icons.calculate_outlined size 12 color textSecondaryAaa alpha 0.6` + 8px gap + `Text(_toolDisplayName(context, chip.toolName))` styled as `MintTextStyles.micro(color: textSecondaryAaa).copyWith(decoration: underline)`.
    - Wraps each row in `Semantics(label: ..., button: true)` for accessibility.
  </behavior>
  <action>
    Create `apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart`:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:mint_mobile/l10n/app_localizations.dart';
    import 'package:mint_mobile/services/rag_service.dart';
    import 'package:mint_mobile/theme/colors.dart';
    import 'package:mint_mobile/theme/spacing.dart';
    import 'package:mint_mobile/theme/text_styles.dart';

    /// Wave 1b — citation chip section for server-side tool calls.
    ///
    /// Sibling of [CoachSourcesSection]. Renders one chip per
    /// [ToolCallCitationChip] returned by the backend. Tap opens the
    /// citation modal (Plan 06 wires the modal handler).
    ///
    /// Per CONTEXT hard constraint #5: reuses chip design tokens from
    /// chat_consent_chip.dart, NOT a new design-system primitive.
    ///
    /// Per RESEARCH §9.5: each chip carries Key('coachCitationChip-<toolName>')
    /// for Maestro testID stability.
    class CoachCitationChipsSection extends StatelessWidget {
      final List<ToolCallCitationChip> chips;
      final void Function(ToolCallCitationChip)? onChipTap;

      const CoachCitationChipsSection({
        super.key,
        required this.chips,
        this.onChipTap,
      });

      String _toolDisplayName(BuildContext context, String toolName) {
        final s = AppLocalizations.of(context)!;
        switch (toolName) {
          case 'budget_snapshot':
            return s.coachToolBudgetSnapshot;
          case 'retirement_projection':
            return s.coachToolRetirementProjection;
          case 'cross_pillar_analysis':
            return s.coachToolCrossPillarAnalysis;
          case 'couple_optimization':
            return s.coachToolCoupleOptimization;
          case 'cap_status':
            return s.coachToolCapStatus;
          case 'retrieve_memories':
            return s.coachToolRetrieveMemories;
          default:
            return toolName;
        }
      }

      @override
      Widget build(BuildContext context) {
        if (chips.isEmpty) {
          return const SizedBox.shrink();
        }
        final s = AppLocalizations.of(context)!;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md - 4,
            vertical: MintSpacing.md - 4,
          ),
          decoration: BoxDecoration(
            color: MintColors.bleuAir.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.coachCitationChipsHeader,
                style: MintTextStyles.micro(
                  color: MintColors.textMutedAaa,
                ).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: MintSpacing.xs),
              for (final chip in chips)
                Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                  child: Semantics(
                    label: _toolDisplayName(context, chip.toolName),
                    button: true,
                    child: InkWell(
                      key: Key('coachCitationChip-${chip.toolName}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: onChipTap == null
                          ? null
                          : () => onChipTap!(chip),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            size: 12,
                            color: MintColors.textSecondaryAaa
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: MintSpacing.xs),
                          Expanded(
                            child: Text(
                              s.coachCitationChipLabel(
                                _toolDisplayName(context, chip.toolName),
                              ),
                              style: MintTextStyles.micro(
                                color: MintColors.textSecondaryAaa,
                              ).copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: MintColors.textSecondaryAaa
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    }
    ```
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter analyze lib/widgets/coach/coach_citation_chips_section.dart 2>&amp;1 | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - `test -f apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` exits 0.
    - `grep -c "class CoachCitationChipsSection" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns 1.
    - `grep -c "Icons.calculate_outlined" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns 1.
    - `grep -c "Key('coachCitationChip-" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns 1.
    - `grep -c "AppLocalizations.of(context)!.coachCitationChipsHeader\\|coachCitationChipLabel\\|coachToolBudgetSnapshot\\|coachToolRetirementProjection\\|coachToolCrossPillarAnalysis\\|coachToolCoupleOptimization\\|coachToolCapStatus\\|coachToolRetrieveMemories" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns ≥8 (header + label + 6 tool names).
    - `cd apps/mobile && flutter analyze lib/widgets/coach/coach_citation_chips_section.dart 2>&1 | grep -c "error"` returns 0.
  </acceptance_criteria>
  <done>
    CoachCitationChipsSection widget exists; uses Icons.calculate_outlined; reads ARB strings via AppLocalizations; carries Maestro keys; available for import in Task 2 via `package:mint_mobile/widgets/coach/coach_citation_chips_section.dart`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire CoachCitationChipsSection into coach_message_bubble.dart + unskip Plan 01 widget tests + generate golden snapshots</name>
  <read_first>
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart lines 155-200 (Sources + Disclaimers + ResponseCards section — find insertion point at line 165-166)
    - apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart (Plan 01 stubs)
    - apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart (Plan 01 stubs)
    - apps/mobile/test/widgets/coach/ (any existing test setup helper / TestWidgetWrapper for AppLocalizations)
  </read_first>
  <files>
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart (modify — add import + render section)
    - apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart (modify — unskip + implement)
    - apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart (modify — unskip + generate 6 PNGs)
    - apps/mobile/test/goldens/coach_citation_chip_budget_snapshot.png (golden generated)
    - apps/mobile/test/goldens/coach_citation_chip_retirement_projection.png (golden generated)
    - apps/mobile/test/goldens/coach_citation_chip_cross_pillar_analysis.png (golden generated)
    - apps/mobile/test/goldens/coach_citation_chip_couple_optimization.png (golden generated)
    - apps/mobile/test/goldens/coach_citation_chip_cap_status.png (golden generated)
    - apps/mobile/test/goldens/coach_citation_chip_retrieve_memories.png (golden generated)
  </files>
  <action>
    Step A — Edit `apps/mobile/lib/widgets/coach/coach_message_bubble.dart`. Add the import at the top with the other widget imports:
    ```dart
    import 'package:mint_mobile/widgets/coach/coach_citation_chips_section.dart';
    ```

    Step B — Locate line 165 (end of the Sources block, just before the `// Disclaimers` comment). Insert the citation chips block AFTER the Sources block and BEFORE the Disclaimers block:
    ```dart
              // Citation chips (Wave 1b) — tool-call provenance.
              // Sibling of Sources; rendered alongside (NOT replacing) it.
              if (msg.citationChips.isNotEmpty) ...[
                const SizedBox(height: MintSpacing.md - 4),
                Padding(
                  padding: const EdgeInsets.only(left: 44, right: MintSpacing.xxl),
                  child: CoachCitationChipsSection(
                    chips: msg.citationChips,
                    onChipTap: (chip) {
                      // Plan 06 wires the modal here.
                    },
                  ),
                ),
              ],
    ```

    Step C — Edit `apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart`. REMOVE all `skip:` arguments and implement the 4 tests. Pattern:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_localizations/flutter_localizations.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/l10n/app_localizations.dart';
    import 'package:mint_mobile/services/rag_service.dart';
    import 'package:mint_mobile/widgets/coach/coach_citation_chips_section.dart';

    Widget _wrap(Widget child) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(body: child),
        );

    ToolCallCitationChip _fakeChip(String name) => ToolCallCitationChip(
          toolName: name,
          inputsHash: 'a' * 64,
          computedAt: DateTime.parse('2026-05-15T10:00:00Z'),
          rawResponse: const {'monthlyIncome': '7500'},
        );

    void main() {
      group('CoachCitationChipsSection', () {
        testWidgets('renders one chip per ToolCallCitationChip', (tester) async {
          final chips = [
            _fakeChip('budget_snapshot'),
            _fakeChip('retirement_projection'),
          ];
          await tester.pumpWidget(_wrap(
            CoachCitationChipsSection(chips: chips, onChipTap: (_) {}),
          ));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.calculate_outlined), findsNWidgets(2));
        });

        testWidgets('renders nothing when chips list is empty', (tester) async {
          await tester.pumpWidget(_wrap(
            const CoachCitationChipsSection(chips: []),
          ));
          await tester.pumpAndSettle();
          expect(find.byType(Icon), findsNothing);
        });

        testWidgets('each chip carries Key("coachCitationChip-<toolName>")', (tester) async {
          final chips = [
            _fakeChip('budget_snapshot'),
            _fakeChip('cap_status'),
          ];
          await tester.pumpWidget(_wrap(
            CoachCitationChipsSection(chips: chips, onChipTap: (_) {}),
          ));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('coachCitationChip-budget_snapshot')), findsOneWidget);
          expect(find.byKey(const Key('coachCitationChip-cap_status')), findsOneWidget);
        });

        testWidgets('onChipTap fires with the tapped chip', (tester) async {
          ToolCallCitationChip? tapped;
          final chips = [_fakeChip('budget_snapshot')];
          await tester.pumpWidget(_wrap(
            CoachCitationChipsSection(
              chips: chips,
              onChipTap: (chip) => tapped = chip,
            ),
          ));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('coachCitationChip-budget_snapshot')));
          await tester.pumpAndSettle();
          expect(tapped?.toolName, 'budget_snapshot');
        });
      });
    }
    ```

    Step D — Edit `apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart`. Remove skip markers, implement:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/l10n/app_localizations.dart';
    import 'package:mint_mobile/services/rag_service.dart';
    import 'package:mint_mobile/widgets/coach/coach_citation_chips_section.dart';

    void main() {
      for (final tool in const [
        'budget_snapshot',
        'retirement_projection',
        'cross_pillar_analysis',
        'couple_optimization',
        'cap_status',
        'retrieve_memories',
      ]) {
        testWidgets('golden — chip for $tool', (tester) async {
          final chip = ToolCallCitationChip(
            toolName: tool,
            inputsHash: 'a' * 64,
            computedAt: DateTime.parse('2026-05-15T10:00:00Z'),
            rawResponse: const {'_test': true},
          );
          await tester.pumpWidget(MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: CoachCitationChipsSection(chips: [chip], onChipTap: (_) {}),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(CoachCitationChipsSection),
            matchesGoldenFile('../../goldens/coach_citation_chip_$tool.png'),
          );
        });
      }
    }
    ```
    Generate goldens with `cd apps/mobile && flutter test --update-goldens test/widgets/coach/coach_citation_chip_golden_test.dart`. Inspect the 6 PNGs to confirm they render the expected chip text + icon + frame.

    Step E — Run `cd apps/mobile && flutter analyze lib/widgets/coach/coach_message_bubble.dart && flutter test test/widgets/coach/coach_citation_chips_section_test.dart test/widgets/coach/coach_citation_chip_golden_test.dart`. MUST exit 0.
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter test test/widgets/coach/coach_citation_chips_section_test.dart test/widgets/coach/coach_citation_chip_golden_test.dart</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "CoachCitationChipsSection\\|citationChips" apps/mobile/lib/widgets/coach/coach_message_bubble.dart` returns ≥2 (import + render block).
    - `grep -c "skip: 'Wave 1b" apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart` returns 0.
    - `grep -c "skip: 'Wave 1b" apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart` returns 0.
    - `ls apps/mobile/test/goldens/coach_citation_chip_*.png 2>/dev/null | wc -l` returns 6.
    - `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chips_section_test.dart 2>&1 | grep "All tests passed"` returns non-empty.
    - `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chip_golden_test.dart 2>&1 | grep "All tests passed"` returns non-empty.
    - `cd apps/mobile && flutter analyze 2>&1 | grep -c "error"` returns 0.
  </acceptance_criteria>
  <done>
    Chip section wired into message bubble; 4 widget tests pass (exit 0) + 6 golden snapshots pass; Plan 06 can hook the modal into the onChipTap callback.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-05-01 | T | Widget renders with hardcoded FR strings — i18n violation | mitigate | Task 1 wires every string via `AppLocalizations.of(context)!.<key>`. Plan 07 ships the ARB keys; Plan 05 depends on Plan 07 in `depends_on`. |
| T-WAVE1B-05-02 | T | Sealed-class refactor of RagSource breaks 30+ Flutter files | mitigate | RESEARCH §9.4 decision: sibling widget, NOT extension. Verified by grepping `RagSource` import count (read-only access to confirm). |
| T-WAVE1B-05-03 | T | Hardcoded color literal triggers Phase 90 lint regression (LINT-01 prefer_mint_color_token) | mitigate | All colors via `MintColors.<token>`. No `Color(0x...)` in the file. CI gate G5 catches violations. |
| T-WAVE1B-05-04 | I | Tap-target size violates accessibility (44dp minimum) | mitigate | InkWell padding inherits parent Padding which provides 44dp tap height per Material guidelines. Test in Plan 06's modal-tap widget test. |
| T-WAVE1B-05-05 | T | Golden snapshot is platform-dependent (renders differently on macOS vs Linux CI) | mitigate | Goldens generated on macOS during exec; flutter test --update-goldens regenerates on CI if needed. Plan 09's close-out runs full flutter test which surfaces golden divergence. |
</threat_model>

<verification>
- `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chips_section_test.dart test/widgets/coach/coach_citation_chip_golden_test.dart -q` exits 0.
- `cd apps/mobile && flutter analyze 2>&1 | grep -c "error\\|warning - .*new" returns 0 (no new analyzer errors/warnings beyond baseline).
- `find apps/mobile/test/goldens -name 'coach_citation_chip_*.png' | wc -l` returns 6.
- `grep -c "skip: 'Wave 1b" apps/mobile/test/widgets/coach/coach_citation_chip*.dart` returns 0 (all Plan 01 stubs unskipped).
</verification>

<success_criteria>
- CoachCitationChipsSection widget exists + renders chips.
- Each chip carries a Maestro-stable key.
- 4 widget tests pass (exit 0) + 6 golden snapshots pass.
- Wired into coach_message_bubble.dart as a sibling section.
- No new analyzer errors; no LINT-01 / LINT-02 / LINT-04 regressions.
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-05-SUMMARY.md` with:
- Widget file size + key count
- 6 golden PNG sizes (sanity check — not all 4KB stubs)
- Flutter test count delta
- 0-trust self-check citing flutter test output verbatim
</output>
</content>
</invoke>
