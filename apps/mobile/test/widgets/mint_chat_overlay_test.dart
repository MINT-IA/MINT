// Phase 96 D-04 + D-06 — MintChatOverlay scaffold tests.
//
// Validates DraggableScrollableSheet entry, drag handle, intent label slot,
// and D-26 grep gate. W1 scope is SCAFFOLD only — turn-history rendering,
// input bar, NarrativeSleeve render land in Plan 96-03.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/widgets/mint_chat_overlay.dart';

const _fixture = SerializedCardContext(
  cardId: 'mon_3a_2026',
  cardType: 'pillar_3a',
);

Widget _harness({required Widget child}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('MintChatOverlay', () {
    testWidgets('renders a DraggableScrollableSheet', (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('renders the intent label keyed for test access',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      final labelFinder = find.byKey(const Key('chat_overlay_intent_label'));
      expect(labelFinder, findsOneWidget);

      final text = tester.widget<Text>(labelFinder);
      expect(text.data, 'explain');
    });

    testWidgets('renders a 40x4dp drag handle', (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'reassure',
        ),
      ));
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('chat_overlay_drag_handle'));
      expect(handle, findsOneWidget);

      final size = tester.getSize(handle);
      expect(size.width, 40.0);
      expect(size.height, 4.0);
    });

    testWidgets('show() opens overlay via showModalBottomSheet',
        (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(_harness(
        child: Builder(builder: (ctx) {
          capturedContext = ctx;
          return const SizedBox.shrink();
        }),
      ));

      // Fire the static helper.
      MintChatOverlay.show(
        capturedContext,
        sourceCard: _fixture,
        intent: 'explain',
      );
      await tester.pumpAndSettle();

      expect(find.byType(MintChatOverlay), findsOneWidget);
    });
  });
}
