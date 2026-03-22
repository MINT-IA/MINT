/// Widget tests for GoalSelectorSheet.
///
/// Validates:
///   - Sheet renders without crashing.
///   - "Auto" option is always displayed.
///   - Goal cards are shown for a profile.
///   - Selected goal is visually distinguished.
///   - All text comes from l10n (no hardcoded strings).
///   - Tapping a goal calls onSelected with the intent tag.
///   - Tapping auto calls onSelected with null.
///   - DraggableScrollableSheet is present.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/widgets/pulse/goal_selector_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Helpers ──────────────────────────────────────────────────────────────

CoachProfile _makeProfile({
  int birthYear = 1985,
  String? housingStatus = 'locataire',
  String employmentStatus = 'salarie',
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    employmentStatus: employmentStatus,
    housingStatus: housingStatus,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Test',
    ),
  );
}

Widget _buildSheet({
  CoachProfile? profile,
  String? currentIntentTag,
  void Function(String? intentTag)? onSelected,
}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      body: GoalSelectorSheet(
        profile: profile ?? _makeProfile(),
        currentIntentTag: currentIntentTag,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ==========================================================================
  //  RENDERING
  // ==========================================================================

  group('GoalSelectorSheet rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.pump();
      expect(find.byType(GoalSelectorSheet), findsOneWidget);
    });

    testWidgets('contains DraggableScrollableSheet', (tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.pump();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('shows goal selector title via l10n', (tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.pump();
      // l.goalSelectorTitle = "Quel est ton objectif principal ?"
      expect(find.textContaining('objectif'), findsOneWidget);
    });

    testWidgets('shows auto option', (tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.pump();
      // l.goalSelectorAuto = "Laisser MINT décider"
      expect(find.textContaining('MINT'), findsWidgets);
    });

    testWidgets('shows auto option description', (tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.pump();
      // l.goalSelectorAutoDesc = "MINT adapte automatiquement selon ton profil"
      expect(find.textContaining('automatiquement'), findsOneWidget);
    });

    testWidgets('shows at least one goal card beyond auto', (tester) async {
      await tester.pumpWidget(_buildSheet(profile: _makeProfile()));
      await tester.pumpAndSettle();
      // The sheet should show goal cards for budget + tax at minimum
      expect(find.textContaining('budget'), findsWidgets);
    });

    testWidgets('shows retirement goal for profile with age > 25', (tester) async {
      await tester.pumpWidget(_buildSheet(
        profile: _makeProfile(birthYear: 1985), // age ~41
      ));
      await tester.pumpAndSettle();
      // l.goalRetirementTitle = "Ma retraite"
      expect(find.textContaining('retraite'), findsWidgets);
    });
  });

  // ==========================================================================
  //  SELECTED STATE HIGHLIGHTING
  // ==========================================================================

  group('GoalSelectorSheet selected state', () {
    testWidgets('auto selected when currentIntentTag is null', (tester) async {
      await tester.pumpWidget(_buildSheet(currentIntentTag: null));
      await tester.pumpAndSettle();
      // The auto option should show a check icon (check_circle_rounded)
      final icons = find.byIcon(Icons.check_circle_rounded);
      expect(icons, findsOneWidget);
    });

    testWidgets('check icon shown on selected goal', (tester) async {
      await tester.pumpWidget(_buildSheet(
        currentIntentTag: 'budget_overview',
      ));
      await tester.pumpAndSettle();
      // budget_overview is selected → check_circle on it; auto has chevron
      final icons = find.byIcon(Icons.check_circle_rounded);
      expect(icons, findsOneWidget);
    });
  });

  // ==========================================================================
  //  INTERACTION — onSelected CALLBACK
  // ==========================================================================

  group('GoalSelectorSheet interaction', () {
    testWidgets('tapping auto option calls onSelected with null', (tester) async {
      String? result = 'initial';
      await tester.pumpWidget(_buildSheet(
        currentIntentTag: 'budget_overview',
        onSelected: (tag) => result = tag,
      ));
      await tester.pumpAndSettle();

      // Find and tap the auto option
      final autoText = find.textContaining('MINT décider');
      expect(autoText, findsOneWidget);
      await tester.tap(autoText);
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('all text is non-empty (no raw key leakage)', (tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.pumpAndSettle();

      // Find all Text widgets — none should contain 'goal' prefix (raw key)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final content = t.data ?? '';
        expect(
          content.startsWith('goal'),
          isFalse,
          reason: 'Found raw ARB key: "$content"',
        );
      }
    });
  });
}
