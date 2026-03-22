import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/recap/recap_formatter.dart';
import 'package:mint_mobile/services/recap/weekly_recap_service.dart';

// ────────────────────────────────────────────────────────────
//  RecapFormatter TESTS — S59
// ────────────────────────────────────────────────────────────
//
// 11 tests covering:
//   1.  Empty recap → only actions section (with "none" text)
//   2.  Budget section included when budget present
//   3.  Budget section omitted when budget null
//   4.  Actions section present always
//   5.  Progress section included when RecapProgress present
//   6.  Progress section omitted when RecapProgress null
//   7.  Highlights section omitted when empty
//   8.  Highlights section included when highlights non-empty
//   9.  NextFocus section included when nextWeekFocus non-null
//   10. NextFocus section omitted when nextWeekFocus null
//   11. Section type matches expected RecapSectionType enum
// ────────────────────────────────────────────────────────────

// ══ Helpers ══════════════════════════════════════════════════

final _monday = DateTime(2026, 3, 16);
final _sunday = DateTime(2026, 3, 22);

WeeklyRecap _emptyRecap() => WeeklyRecap(
      weekStart: _monday,
      weekEnd: _sunday,
      budget: null,
      actions: const [],
      progress: null,
      highlights: const [],
      nextWeekFocus: null,
      activeGoals: 0,
      disclaimer: 'Outil éducatif.',
      sources: const ['LAVS art. 21'],
    );

WeeklyRecap _fullRecap() => WeeklyRecap(
      weekStart: _monday,
      weekEnd: _sunday,
      budget: const RecapBudget(
        totalSpent: 3000,
        totalIncome: 8000,
        savedAmount: 5000,
        savingsRate: 0.625,
      ),
      actions: [
        RecapAction(
          actionId: 'engagement_2026-03-16',
          completedAt: DateTime(2026, 3, 16),
          capId: 'engagement',
        ),
        RecapAction(
          actionId: 'engagement_2026-03-17',
          completedAt: DateTime(2026, 3, 17),
          capId: 'engagement',
        ),
      ],
      progress: const RecapProgress(
        confidenceBefore: 0,
        confidenceAfter: 4.5,
        delta: 4.5,
      ),
      highlights: const ['recapBudgetTitle', 'recapActionsTitle', 'recapProgressDelta'],
      nextWeekFocus: '3a',
      activeGoals: 2,
      disclaimer: 'Outil éducatif.',
      sources: const ['LAVS art. 21', 'LPP art. 14'],
    );

/// Build a test [S] localizations instance using the French locale.
///
/// Uses a [MaterialApp] with all three global localization delegates
/// (Material + Widgets + Cupertino) so that the fr locale is fully
/// resolved without warnings that would cause test failures.
Future<S> _buildL10n(WidgetTester tester) async {
  late S result;

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Builder(
        builder: (context) {
          result = S.of(context)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

// ══ Tests ════════════════════════════════════════════════════

void main() {
  group('RecapFormatter', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── 1. Empty recap → only actions section ─────────────────
    testWidgets('1. empty recap produces actions section (none text)', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_emptyRecap(), l);

      expect(sections.length, 1);
      expect(sections.first.type, RecapSectionType.actions);
      expect(sections.first.content, l.recapActionsNone);
    });

    // ── 2. Budget section included when budget present ─────────
    testWidgets('2. full recap: budget section present', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_fullRecap(), l);

      final budgetSections =
          sections.where((s) => s.type == RecapSectionType.budget);
      expect(budgetSections.length, 1);
      expect(budgetSections.first.title, l.recapBudgetTitle);
    });

    // ── 3. Budget section omitted when null ────────────────────
    testWidgets('3. empty recap: no budget section', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_emptyRecap(), l);

      final budgetSections =
          sections.where((s) => s.type == RecapSectionType.budget);
      expect(budgetSections, isEmpty);
    });

    // ── 4. Actions section present always ─────────────────────
    testWidgets('4. actions section always present (full or empty)', (tester) async {
      final l = await _buildL10n(tester);

      for (final recap in [_emptyRecap(), _fullRecap()]) {
        final sections = RecapFormatter.format(recap, l);
        final actionSections =
            sections.where((s) => s.type == RecapSectionType.actions);
        expect(actionSections.length, 1,
            reason: 'Actions section must always be present');
      }
    });

    // ── 5. Progress section included when RecapProgress present ─
    testWidgets('5. progress section present when RecapProgress non-null', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_fullRecap(), l);

      final progressSections =
          sections.where((s) => s.type == RecapSectionType.progress);
      expect(progressSections.length, 1);
      expect(progressSections.first.title, l.recapProgressTitle);
    });

    // ── 6. Progress section omitted when RecapProgress null ────
    testWidgets('6. progress section absent when RecapProgress null', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_emptyRecap(), l);

      final progressSections =
          sections.where((s) => s.type == RecapSectionType.progress);
      expect(progressSections, isEmpty);
    });

    // ── 7. Highlights section omitted when empty ───────────────
    testWidgets('7. highlights section absent when highlights list is empty', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_emptyRecap(), l);

      final highlightSections =
          sections.where((s) => s.type == RecapSectionType.highlights);
      expect(highlightSections, isEmpty);
    });

    // ── 8. Highlights section included when non-empty ──────────
    testWidgets('8. highlights section present when highlights non-empty', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_fullRecap(), l);

      final highlightSections =
          sections.where((s) => s.type == RecapSectionType.highlights);
      expect(highlightSections.length, 1);
      expect(highlightSections.first.title, l.recapHighlightsTitle);
    });

    // ── 9. NextFocus section when nextWeekFocus non-null ───────
    testWidgets('9. nextFocus section present when nextWeekFocus set', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_fullRecap(), l);

      final focusSections =
          sections.where((s) => s.type == RecapSectionType.nextFocus);
      expect(focusSections.length, 1);
      expect(focusSections.first.title, l.recapNextFocusTitle);
      expect(focusSections.first.content, '3a');
    });

    // ── 10. NextFocus section omitted when null ─────────────────
    testWidgets('10. nextFocus section absent when nextWeekFocus null', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_emptyRecap(), l);

      final focusSections =
          sections.where((s) => s.type == RecapSectionType.nextFocus);
      expect(focusSections, isEmpty);
    });

    // ── 11. Section types match enum ─────────────────────────────
    testWidgets('11. full recap: section types in expected order', (tester) async {
      final l = await _buildL10n(tester);
      final sections = RecapFormatter.format(_fullRecap(), l);

      final types = sections.map((s) => s.type).toList();

      // Order: budget, actions, progress, highlights, nextFocus
      expect(types.contains(RecapSectionType.budget), isTrue);
      expect(types.contains(RecapSectionType.actions), isTrue);
      expect(types.contains(RecapSectionType.progress), isTrue);
      expect(types.contains(RecapSectionType.highlights), isTrue);
      expect(types.contains(RecapSectionType.nextFocus), isTrue);

      // Budget before actions
      expect(
        types.indexOf(RecapSectionType.budget),
        lessThan(types.indexOf(RecapSectionType.actions)),
      );

      // Actions before progress
      expect(
        types.indexOf(RecapSectionType.actions),
        lessThan(types.indexOf(RecapSectionType.progress)),
      );
    });
  });
}
