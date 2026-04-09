// ACCESS-08 (P8b-03): liveRegion announces incoming coach messages.
//
// Asserts that the incoming coach bubble wraps its text content in a
// Semantics node with `liveRegion: true`, so screen readers (TalkBack /
// VoiceOver) announce new Claude output without shifting focus.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
      CoachMessageBubble(message: msg, messageIndex: 1),
    ));
    await tester.pumpAndSettle();

    // Walk the semantics tree and find at least one node with the
    // isLiveRegion flag set on a Text descendant of the bubble.
    final handle = tester.ensureSemantics();
    final textFinder = find.text('Voici une explication calme et factuelle.');
    expect(textFinder, findsOneWidget);

    // The Text is wrapped in Semantics(liveRegion: true). Look up the
    // semantics node for the text and walk ancestors.
    final SemanticsNode node = tester.getSemantics(textFinder);
    bool foundLive = false;
    SemanticsNode? cur = node;
    while (cur != null) {
      if (cur.hasFlag(SemanticsFlag.isLiveRegion)) {
        foundLive = true;
        break;
      }
      cur = cur.parent;
    }
    expect(foundLive, isTrue,
        reason: 'Incoming coach bubble must announce as a live region.');
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
      if (cur.hasFlag(SemanticsFlag.isLiveRegion)) {
        foundLive = true;
        break;
      }
      cur = cur.parent;
    }
    expect(foundLive, isFalse,
        reason: 'User-echo bubble must not announce — only Claude output does.');
    handle.dispose();
  });
}
