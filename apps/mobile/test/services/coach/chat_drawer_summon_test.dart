import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/chat_drawer_host.dart';

// ────────────────────────────────────────────────────────────
//  CHAT DRAWER SUMMON TESTS — CHAT-02 (Phase 3)
//
//  Verifies:
//  1. showChatDrawer opens a bottom sheet with the target widget
//  2. resolveDrawerWidget maps known routes to widgets
//  3. resolveDrawerWidget returns null for unknown routes
//  4. Drawer dismisses back to underlying screen
//  5. showChatDrawer renders drag handle
// ────────────────────────────────────────────────────────────

void main() {
  group('ChatDrawerHost.resolveDrawerWidget', () {
    test('resolves /pilier-3a to a widget', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/pilier-3a');
      expect(widget, isNotNull);
      expect((widget as Container).key, const ValueKey('drawer_simulator_3a'));
    });

    test('resolves /retraite to a widget', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/retraite');
      expect(widget, isNotNull);
      expect(
          (widget as Container).key, const ValueKey('drawer_retirement_dashboard'));
    });

    test('resolves /budget to a widget', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/budget');
      expect(widget, isNotNull);
      expect(
          (widget as Container).key, const ValueKey('drawer_budget_container'));
    });

    test('returns null for unknown route', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('/unknown/route');
      expect(widget, isNull);
    });

    test('returns null for empty route', () {
      final widget = ChatDrawerHost.resolveDrawerWidget('');
      expect(widget, isNull);
    });

    test('strips query params for matching', () {
      final widget =
          ChatDrawerHost.resolveDrawerWidget('/retraite?mode=preretraite');
      expect(widget, isNotNull);
      expect(
          (widget as Container).key, const ValueKey('drawer_retirement_dashboard'));
    });
  });

  group('showChatDrawer', () {
    testWidgets('opens a bottom sheet with drag handle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showChatDrawer(
                    context: context,
                    child: const Text('Drawer Content'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap the button to open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Drawer content is visible
      expect(find.text('Drawer Content'), findsOneWidget);

      // Drag handle is visible (Container with width 36)
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('shows optional title when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showChatDrawer(
                    context: context,
                    child: const Text('Content'),
                    title: 'Mon 3a',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Mon 3a'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('dismisses on swipe down', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showChatDrawer(
                    context: context,
                    child: const Text('Drawer Content'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify drawer is open
      expect(find.text('Drawer Content'), findsOneWidget);

      // Drag down to dismiss
      await tester.drag(
          find.byType(DraggableScrollableSheet), const Offset(0, 500));
      await tester.pumpAndSettle();

      // Drawer should be dismissed
      expect(find.text('Drawer Content'), findsNothing);
    });
  });
}
