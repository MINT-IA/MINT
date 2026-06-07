// ACCESS-08 (P8b-03): liveRegion announces incoming coach messages.
//
// Asserts that the incoming coach bubble wraps its text content in a
// Semantics node with `liveRegion: true`, so screen readers (TalkBack /
// VoiceOver) announce new Claude output without shifting focus.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: const Locale('fr'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('incoming coach bubble has liveRegion: true on its text content',
      (tester) async {
    final msg = ChatMessage(
      role: 'assistant',
      content: 'Voici une explication calme et factuelle.',
      timestamp: DateTime(2026, 1, 1),
      tier: ChatTier.none,
    );

    await tester.pumpWidget(_wrap(
      CoachMessageBubble(
        message: msg,
        messageIndex: 1,
        announceContentLiveRegion: true,
      ),
    ));
    await tester.pumpAndSettle();

    // Walk the semantics tree and find at least one node with the
    // isLiveRegion flag set on a Text descendant of the bubble.
    final handle = tester.ensureSemantics();
    final textFinder = find.text('Voici une explication calme et factuelle.');
    expect(textFinder, findsOneWidget);

    // The Markdown internals are excluded from semantics so the same content
    // is not read twice. The content Semantics node carries the clean label.
    final SemanticsNode node = tester.getSemantics(
      find.byKey(const Key('coach_message_content_semantics_1')),
    );
    expect(node.identifier, 'coach_message_content_1');
    expect(node.label, contains('Voici une explication calme et factuelle.'));
    bool foundLive = false;
    SemanticsNode? cur = node;
    while (cur != null) {
      if (cur.flagsCollection.isLiveRegion) {
        foundLive = true;
        break;
      }
      cur = cur.parent;
    }
    expect(foundLive, isTrue,
        reason: 'Incoming coach bubble must announce as a live region.');
    handle.dispose();
  });

  testWidgets('restored coach bubble is readable without liveRegion noise',
      (tester) async {
    final msg = ChatMessage(
      role: 'assistant',
      content: 'Voici une réponse déjà restaurée.',
      timestamp: DateTime(2026, 1, 1),
      tier: ChatTier.none,
    );

    await tester.pumpWidget(_wrap(
      CoachMessageBubble(message: msg, messageIndex: 4),
    ));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    final node = tester.getSemantics(
      find.byKey(const Key('coach_message_content_semantics_4')),
    );
    expect(node.identifier, 'coach_message_content_4');
    expect(node.label, contains('Voici une réponse déjà restaurée.'));
    bool foundLive = false;
    SemanticsNode? cur = node;
    while (cur != null) {
      if (cur.flagsCollection.isLiveRegion) {
        foundLive = true;
        break;
      }
      cur = cur.parent;
    }
    expect(
      foundLive,
      isFalse,
      reason:
          'Restored assistant history must be traversable without re-announcing every old answer.',
    );
    handle.dispose();
  });

  testWidgets('tool-only coach bubble does not expose empty liveRegion content',
      (tester) async {
    final msg = ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime(2026, 1, 1),
      tier: ChatTier.none,
      richToolCalls: [
        const RagToolCall(
          name: 'route_to_screen',
          input: {
            'intent': 'open_budget',
            'label': 'Voir le budget',
          },
        ),
      ],
    );

    await tester.pumpWidget(_wrap(
      CoachMessageBubble(message: msg, messageIndex: 2),
    ));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    expect(
      find.byKey(const Key('coach_message_content_semantics_2')),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('suggested action chips are semantic buttons', (tester) async {
    final msg = ChatMessage(
      role: 'assistant',
      content: 'Choisis une suite possible.',
      timestamp: DateTime(2026, 1, 1),
      tier: ChatTier.none,
      suggestedActions: const ['Analyser mon budget'],
    );

    await tester.pumpWidget(_wrap(
      CoachMessageBubble(
        message: msg,
        messageIndex: 3,
        onActionTap: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Analyser mon budget'),
    );
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('outgoing user bubble does NOT have liveRegion', (tester) async {
    final msg = ChatMessage(
      role: 'user',
      content: 'Ma question',
      timestamp: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(_wrap(UserMessageBubble(message: msg)));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    final SemanticsNode node = tester.getSemantics(find.text('Ma question'));
    bool foundLive = false;
    SemanticsNode? cur = node;
    while (cur != null) {
      if (cur.flagsCollection.isLiveRegion) {
        foundLive = true;
        break;
      }
      cur = cur.parent;
    }
    expect(foundLive, isFalse,
        reason:
            'User-echo bubble must not announce — only Claude output does.');
    handle.dispose();
  });
}
