// Phase 96 D-04 + D-06 — MintChatOverlay scaffold tests.
// Phase 97 W7 F001 — extended with ChatInputBar + turn counter assertions.
//
// Validates :
//   - DraggableScrollableSheet entry
//   - drag handle 40×4dp
//   - intent label slot
//   - Phase 97 F001 testIDs : mint_chat_overlay (root), chat_input_field,
//     chat_send_button, chat_turn_counter (« 0 / 3 » initially)
//   - send button disabled-when-empty, enabled-when-typed
//   - turn counter increments on send (0/3 → 1/3 → 2/3 → 3/3)
//   - send button disabled after counter reaches 3 (cap)
//   - D-26 grep gate

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
      // Phase 97.5 W2-T3 (D2 fix) — header now uses the localised FR
      // label, not the raw enum. « Explique-moi » comes from the
      // chatIntentExplainLabel ARB key.
      expect(text.data, 'Explique-moi');
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

  // ─── Phase 97 W7 F001 ── ChatInputBar + turn counter ─────────────────
  group('MintChatOverlay — F001 ChatInputBar + turn counter', () {
    testWidgets('exposes the 4 F001 testIDs (mint_chat_overlay, '
        'chat_input_field, chat_send_button, chat_turn_counter)',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mint_chat_overlay')), findsOneWidget,
          reason: 'F001 — overlay root must carry a stable Key for Maestro');
      expect(find.byKey(const Key('chat_input_field')), findsOneWidget,
          reason: 'F001 — ChatInputBar TextField must be keyed');
      expect(find.byKey(const Key('chat_send_button')), findsOneWidget,
          reason: 'F001 — ChatInputBar send button must be keyed');
      expect(find.byKey(const Key('chat_turn_counter')), findsOneWidget,
          reason: 'F001 — turn counter Text widget must be keyed');
    });

    testWidgets('turn counter renders « 0 / 3 » initially', (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      final counter = tester.widget<Text>(
        find.byKey(const Key('chat_turn_counter')),
      );
      expect(counter.data, '0 / 3');
    });

    testWidgets('send button is disabled when input is empty', (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      final sendButton = tester.widget<IconButton>(
        find.byKey(const Key('chat_send_button')),
      );
      expect(sendButton.onPressed, isNull,
          reason: 'Send button must be disabled (onPressed=null) when empty');
    });

    testWidgets('send button becomes enabled after typing', (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'Qu\'est-ce que ça change pour moi ?',
      );
      await tester.pumpAndSettle();

      final sendButton = tester.widget<IconButton>(
        find.byKey(const Key('chat_send_button')),
      );
      expect(sendButton.onPressed, isNotNull,
          reason:
              'Send button must be enabled (onPressed≠null) when text non-empty');
    });

    testWidgets('tapping send increments the turn counter and clears input',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      // Type a message.
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'Et si j\'attends deux ans ?',
      );
      await tester.pumpAndSettle();

      // Tap send.
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // Counter is now 1/3.
      final counter = tester.widget<Text>(
        find.byKey(const Key('chat_turn_counter')),
      );
      expect(counter.data, '1 / 3');

      // Input is cleared.
      final field = tester.widget<TextField>(
        find.byKey(const Key('chat_input_field')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('send button disables after 3 turns (UI cap matches D-08)',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      // Send 3 turns.
      for (var i = 0; i < 3; i++) {
        await tester.enterText(
          find.byKey(const Key('chat_input_field')),
          'turn $i',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chat_send_button')));
        await tester.pumpAndSettle();
      }

      // Counter is 3/3.
      final counter = tester.widget<Text>(
        find.byKey(const Key('chat_turn_counter')),
      );
      expect(counter.data, '3 / 3');

      // Send button is disabled. Try typing again — sendEnabled should
      // remain false because _turnCount >= kChatMaxTurns regardless of
      // input content.
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'fourth attempt should not send',
      );
      await tester.pumpAndSettle();

      final sendButton = tester.widget<IconButton>(
        find.byKey(const Key('chat_send_button')),
      );
      expect(sendButton.onPressed, isNull,
          reason: 'Send button must remain disabled once cap reached');
    });

    testWidgets('counter resets to 0/3 when overlay is reopened (fresh state)',
        (tester) async {
      // First mount — send one turn, then dispose. Use a distinct Key
      // to force State recreation on the second pump (without a key
      // change Flutter would re-use the same State instance because
      // runtimeType + position in tree match).
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          key: ValueKey('overlay-session-1'),
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'first session turn 1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // Counter is 1/3 in session 1.
      final counter1 = tester.widget<Text>(
        find.byKey(const Key('chat_turn_counter')),
      );
      expect(counter1.data, '1 / 3');

      // Remount with a different ValueKey — Flutter disposes the old
      // State and creates a fresh one (simulates overlay close + reopen).
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          key: ValueKey('overlay-session-2'),
          sourceCard: _fixture,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      final counter2 = tester.widget<Text>(
        find.byKey(const Key('chat_turn_counter')),
      );
      expect(counter2.data, '0 / 3',
          reason:
              'Counter must reset to 0/3 on re-mount (local state, no '
              'persistence — backend turn_cap is the canonical gate).');
    });
  });
}
