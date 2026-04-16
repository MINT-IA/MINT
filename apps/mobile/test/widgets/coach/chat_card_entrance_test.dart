// ────────────────────────────────────────────────────────────
//  CHAT CARD ENTRANCE — Widget tests
// ────────────────────────────────────────────────────────────
//
//  Tests:
//  1.  Renders child widget
//  2.  Child is visible after animation settles
//  3.  Multiple children can be wrapped independently
//  4.  Delay variant renders child after settlement
//  5.  Custom duration does not crash
//  6.  SlideTransition is present in widget tree
//  7.  FadeTransition is present in widget tree
//  8.  Zero delay renders child without waiting
//  9.  Child content is accessible after pump
//  10. Dispose does not throw (controller cleanup)
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/chat_card_entrance.dart';

// ── Helper ──────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

// ── Tests ───────────────────────────────────────────────────

void main() {
  group('ChatCardEntrance', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          child: Text('Contenu de la carte'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Contenu de la carte'), findsOneWidget);
    });

    testWidgets('child is visible after animation settles', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          child: Text('Carte animée'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Carte animée'), findsOneWidget);
    });

    testWidgets('SlideTransition is present in widget tree', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          child: SizedBox(width: 100, height: 100),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      // MaterialApp also uses SlideTransitions for routing; check at least one
      // comes from our widget (it will be in the subtree of ChatCardEntrance).
      final entrance = find.byType(ChatCardEntrance);
      expect(
        find.descendant(of: entrance, matching: find.byType(SlideTransition)),
        findsOneWidget,
      );
    });

    testWidgets('FadeTransition is present in widget tree', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          child: SizedBox(width: 100, height: 100),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      // MaterialApp also uses FadeTransitions; scope to ChatCardEntrance subtree.
      final entrance = find.byType(ChatCardEntrance);
      expect(
        find.descendant(of: entrance, matching: find.byType(FadeTransition)),
        findsOneWidget,
      );
    });

    testWidgets('multiple wrapped children render independently',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const Column(
          children: [
            ChatCardEntrance(child: Text('Carte 1')),
            ChatCardEntrance(
              delay: Duration(milliseconds: 80),
              child: Text('Carte 2'),
            ),
            ChatCardEntrance(
              delay: Duration(milliseconds: 160),
              child: Text('Carte 3'),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Carte 1'), findsOneWidget);
      expect(find.text('Carte 2'), findsOneWidget);
      expect(find.text('Carte 3'), findsOneWidget);
    });

    testWidgets('delay variant renders child after full settlement',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          delay: Duration(milliseconds: 100),
          child: Text('Carte différée'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Carte différée'), findsOneWidget);
    });

    testWidgets('custom duration does not crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          duration: Duration(milliseconds: 200),
          child: Text('Durée custom'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Durée custom'), findsOneWidget);
    });

    testWidgets('zero delay renders child immediately', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          duration: Duration(milliseconds: 50),
          child: Text('Immédiat'),
        ),
      ));
      // After a single frame the controller has started
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Immédiat'), findsOneWidget);
    });

    testWidgets('child content is accessible after pump', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text('Card content'),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Card content'), findsOneWidget);
    });

    testWidgets('dispose does not throw — controller cleanup', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChatCardEntrance(
          child: Text('A nettoyer'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      // Replace widget tree — forces dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      // No exception should be thrown
      expect(tester.takeException(), isNull);
    });
  });
}
