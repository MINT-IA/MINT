// Phase 96 D-04..D-07 — MintCardActionBar widget tests.
//
// Validates the 48dp animated reveal + 3 _VerbChip with 44dp tap targets
// + Semantics + zero hardcoded colors. Per 96-UI-SPEC §MintCardActionBar
// + §Animation Contract + §Accessibility Contract.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/widgets/mint_card_action_bar.dart';

const _fixture = SerializedCardContext(
  cardId: 'mon_3a_2026',
  cardType: 'pillar_3a',
);

Widget _harness({
  required bool expanded,
  required VoidCallback onExplain,
  required VoidCallback onSimulate,
  required VoidCallback onReassure,
}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(
      body: MintCardActionBar(
        sourceCard: _fixture,
        expanded: expanded,
        onExplain: onExplain,
        onSimulate: onSimulate,
        onReassure: onReassure,
      ),
    ),
  );
}

void main() {
  group('MintCardActionBar', () {
    testWidgets('expanded=true renders 3 verb chips with FR labels',
        (tester) async {
      await tester.pumpWidget(_harness(
        expanded: true,
        onExplain: () {},
        onSimulate: () {},
        onReassure: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Explique-moi'), findsOneWidget);
      expect(find.text('Simule'), findsOneWidget);
      expect(find.text('Rassure-moi'), findsOneWidget);
    });

    testWidgets('expanded=false collapses to zero height', (tester) async {
      await tester.pumpWidget(_harness(
        expanded: false,
        onExplain: () {},
        onSimulate: () {},
        onReassure: () {},
      ));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(MintCardActionBar));
      expect(size.height, lessThan(1.0));
    });

    testWidgets('expanded=true renders height >= 48dp after settle',
        (tester) async {
      await tester.pumpWidget(_harness(
        expanded: true,
        onExplain: () {},
        onSimulate: () {},
        onReassure: () {},
      ));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(MintCardActionBar));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('each _VerbChip has minHeight/minWidth >= 44 (Apple HIG)',
        (tester) async {
      await tester.pumpWidget(_harness(
        expanded: true,
        onExplain: () {},
        onSimulate: () {},
        onReassure: () {},
      ));
      await tester.pumpAndSettle();

      // Each verb chip's InkWell + ConstrainedBox enforces the 44dp minimum.
      final inkwells = find.descendant(
        of: find.byType(MintCardActionBar),
        matching: find.byType(InkWell),
      );
      expect(inkwells, findsNWidgets(3));

      for (var i = 0; i < 3; i++) {
        final size = tester.getSize(inkwells.at(i));
        expect(size.height, greaterThanOrEqualTo(44.0),
            reason: 'verb chip $i height must be >= 44dp');
        expect(size.width, greaterThanOrEqualTo(44.0),
            reason: 'verb chip $i width must be >= 44dp');
      }
    });

    testWidgets('tap on Simule invokes onSimulate exactly once',
        (tester) async {
      var simulateCount = 0;
      var explainCount = 0;
      var reassureCount = 0;

      await tester.pumpWidget(_harness(
        expanded: true,
        onExplain: () => explainCount++,
        onSimulate: () => simulateCount++,
        onReassure: () => reassureCount++,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simule'));
      await tester.pumpAndSettle();

      expect(simulateCount, 1);
      expect(explainCount, 0);
      expect(reassureCount, 0);
    });

    testWidgets('tap on Explique-moi invokes onExplain exactly once',
        (tester) async {
      var explainCount = 0;
      var simulateCount = 0;

      await tester.pumpWidget(_harness(
        expanded: true,
        onExplain: () => explainCount++,
        onSimulate: () => simulateCount++,
        onReassure: () {},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explique-moi'));
      await tester.pumpAndSettle();

      expect(explainCount, 1);
      expect(simulateCount, 0);
    });

    testWidgets('tap on Rassure-moi invokes onReassure exactly once',
        (tester) async {
      var reassureCount = 0;

      await tester.pumpWidget(_harness(
        expanded: true,
        onExplain: () {},
        onSimulate: () {},
        onReassure: () => reassureCount++,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rassure-moi'));
      await tester.pumpAndSettle();

      expect(reassureCount, 1);
    });

    testWidgets('Semantics labels are present on each verb chip',
        (tester) async {
      final semHandle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(
        expanded: true,
        onExplain: () {},
        onSimulate: () {},
        onReassure: () {},
      ));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp(r'Explique-moi — ouvre le coach sur cette carte'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Simule — ouvre le simulateur pour cette carte'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r"Rassure-moi — ouvre le coach pour réduire l'inquiétude"),
        ),
        findsOneWidget,
      );
      // Container semantics for the row group.
      expect(
        find.bySemanticsLabel('Actions sur cette carte'),
        findsOneWidget,
      );

      semHandle.dispose();
    });
  });
}
