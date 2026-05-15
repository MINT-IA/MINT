// Wave 1b Plan 05 — chip section renderer tests.
// Validates CoachCitationChipsSection (RESEARCH §5.2 sibling widget,
// RESEARCH §9.5 Maestro testID stability via Key('coachCitationChip-<toolName>')).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/coach_citation_chips_section.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
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

    testWidgets('each chip carries Key("coachCitationChip-<toolName>")',
        (tester) async {
      final chips = [
        _fakeChip('budget_snapshot'),
        _fakeChip('cap_status'),
      ];
      await tester.pumpWidget(_wrap(
        CoachCitationChipsSection(chips: chips, onChipTap: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('coachCitationChip-budget_snapshot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('coachCitationChip-cap_status')),
        findsOneWidget,
      );
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
      await tester.tap(
        find.byKey(const Key('coachCitationChip-budget_snapshot')),
      );
      await tester.pumpAndSettle();
      expect(tapped?.toolName, 'budget_snapshot');
    });
  });
}
