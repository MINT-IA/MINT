// Wave 1b Plan 06 — modal tap + truncated hash + collapsible JSON viewer.
//
// Unskipped from Plan 01 stubs. Each test renders a fake
// `ToolCallCitationChip`, taps a button that calls `showCoachCitationModal`,
// then asserts the modal surface.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/coach_citation_modal.dart';

Widget _wrap({void Function()? onOpened}) => MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () {
                final chip = ToolCallCitationChip(
                  toolName: 'budget_snapshot',
                  inputsHash: 'a' * 64,
                  computedAt: DateTime.parse('2026-05-15T10:00:00Z'),
                  rawResponse: const {'monthlyIncome': '7500'},
                );
                showCoachCitationModal(ctx, chip);
                onOpened?.call();
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  group('showCoachCitationModal', () {
    testWidgets('opens bottom sheet on chip tap', (tester) async {
      var opened = false;
      await tester.pumpWidget(_wrap(onOpened: () => opened = true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(opened, true);
      // Modal sheet renders — the JSON ExpansionTile is the structural marker.
      expect(
        find.byKey(const Key('coachCitationModalJsonExpansion')),
        findsOneWidget,
      );
    });

    testWidgets('shows truncated 16-char inputs_hash', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // 'a' * 16 + '…' (single ellipsis char, NOT three dots).
      expect(find.text('${'a' * 16}…'), findsOneWidget);
    });

    testWidgets('JSON viewer is collapsible (ExpansionTile)', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Initially collapsed — JSON not visible.
      expect(find.textContaining('monthlyIncome'), findsNothing);
      // Tap to expand.
      await tester.tap(
        find.byKey(const Key('coachCitationModalJsonExpansion')),
      );
      await tester.pumpAndSettle();
      // Now the pretty-printed JSON renders.
      expect(find.textContaining('monthlyIncome'), findsOneWidget);
    });
  });
}
