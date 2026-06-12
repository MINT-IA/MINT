// ECL-01 gate — hotfix 2026-06-12.
//
// Device bug (Julien, sim iPhone 17 Pro, flow « je veux y voir clair » →
// « j'ai 50 ans »): TWO identical Premier Éclairage cards rendered in the same
// conversation. Root cause: the `_eclairageDelivered` gate in
// AnonymousChatScreen was a `final bool = false` marked `// ignore: unused_field`
// — never wired. Every coach turn carrying `response['eclairage']` (and every
// turn in pinned-seed walker builds) appended another card.
//
// These tests prove the wired gate:
//   1. Two consecutive coach responses BOTH carrying the same eclairage
//      payload → exactly ONE EclairageCard in the tree.
//   2. Cold-restore of a conversation that already crossed the ≥2-coach-turn
//      threshold → a NEW response carrying a payload does NOT add a card.
//
// We drive deterministic coach responses through the screen's test-only
// `sendOverride` seam (MintHttpClient.shared is a final static, so there is no
// clean HTTP mock point; the override exercises the REAL `_sendMessage` →
// `_resolveEclairageForTurn` → card-render path).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/anonymous/anonymous_chat_screen.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart' show ChatMessage;
import 'package:mint_mobile/widgets/anonymous/eclairage_card.dart';

/// A coach response carrying a valid `eclairage` payload (mirrors the backend
/// AnonymousChatResponse contract: kind=fiscal_margin_3a, conditional range,
/// LSFin disclaimer). `messagesRemaining` stays > 0 so the auth-gate / locked
/// flow does not interfere with the card-count assertions.
Map<String, dynamic> _responseWithEclairage(int remaining) => {
      'message': 'Réponse du coach.',
      'disclaimers': <String>[],
      'messagesRemaining': remaining,
      'tokensUsed': 10,
      'eclairage': <String, dynamic>{
        'kind': 'fiscal_margin_3a',
        'headline': 'Ta marge fiscale 3a',
        'body': 'Si tu cotises au 3e pilier, verser jusqu\'au plafond '
            'pourrait réduire ton revenu imposable.',
        'chf_range_low': 1500,
        'chf_range_high': 2500,
        'chf_range_period': 'year',
        'lsfin_disclaimer': 'Information à but éducatif.',
      },
    };

Widget _appWith({
  required Future<Map<String, dynamic>> Function(String) sendOverride,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    locale: const Locale('fr'),
    home: AnonymousChatScreen(sendOverride: sendOverride),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1024, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _sendOne(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('anon-chat-input')), text);
  await tester.tap(find.byIcon(Icons.send_rounded));
  // Drain canSendMessage future + sendOverride future + setState + persist.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'ECL-01 — two consecutive coach turns carrying the same eclairage '
      'payload render exactly ONE EclairageCard', (tester) async {
    _setLargeSurface(tester);

    // Both turns carry an identical eclairage payload. Without the gate the
    // screen appended one card per turn (the device duplicate bug).
    await tester.pumpWidget(_appWith(
      sendOverride: (_) async => _responseWithEclairage(2),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Turn 1 — card appears.
    await _sendOne(tester, "j'ai 50 ans");
    expect(find.byType(EclairageCard), findsOneWidget,
        reason: 'first eclairage-carrying turn renders one card');

    // Turn 2 — payload present again, but the gate must suppress a 2nd card.
    await _sendOne(tester, 'et ensuite ?');
    expect(find.byType(EclairageCard), findsOneWidget,
        reason: 'ECL-01 gate: at most ONE card per conversation');
  });

  testWidgets(
      'ECL-01 restore — a conversation with ≥2 prior coach turns starts gated; '
      'a new payload-carrying turn does NOT add a second card', (tester) async {
    _setLargeSurface(tester);

    // Seed a persisted anonymous conversation with 2 coach turns (the
    // threshold at which the backend has already delivered the éclairage).
    ConversationStore.setCurrentUserId(null);
    await ConversationStore().saveConversation('anonymous_seed', [
      ChatMessage(
          role: 'user', content: 'salut', timestamp: DateTime(2026, 6, 1, 9)),
      ChatMessage(
          role: 'assistant',
          content: 'réponse 1',
          timestamp: DateTime(2026, 6, 1, 9, 1)),
      ChatMessage(
          role: 'user', content: 'et après', timestamp: DateTime(2026, 6, 1, 9, 2)),
      ChatMessage(
          role: 'assistant',
          content: 'réponse 2',
          timestamp: DateTime(2026, 6, 1, 9, 3)),
    ]);

    await tester.pumpWidget(_appWith(
      sendOverride: (_) async => _responseWithEclairage(1),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Restored conversation already crossed the ≥2-coach-turn threshold, so
    // the gate restores as delivered — no card from the restored turns.
    expect(find.byType(EclairageCard), findsNothing,
        reason: 'restored turns carry no card payload (text-only persistence)');

    // A NEW turn carrying a payload must NOT add a card — the gate was
    // restored as delivered.
    await _sendOne(tester, 'nouvelle question');
    expect(find.byType(EclairageCard), findsNothing,
        reason: 'ECL-01 restore gate: no second card after cold-restore of a '
            'conversation that already delivered the éclairage');
  });
}
