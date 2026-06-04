import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/coach/conversation_history_screen.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConversationStore.setCurrentUserId(null);
  });

  Future<void> seedConversation() async {
    await ConversationStore().saveConversation('conv-row20-history', [
      ChatMessage(
        role: 'user',
        content: 'On parlait de mon rachat LPP',
        timestamp: DateTime(2026, 6, 4, 9),
      ),
      ChatMessage(
        role: 'assistant',
        content: 'Oui, je garde ce contexte.',
        timestamp: DateTime(2026, 6, 4, 9, 1),
      ),
    ]);
  }

  testWidgets('opens persisted conversation through query conversationId',
      (tester) async {
    await seedConversation();

    final router = GoRouter(
      initialLocation: '/coach/history',
      routes: [
        GoRoute(
          path: '/coach/history',
          builder: (context, state) => const ConversationHistoryScreen(),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (context, state) => Scaffold(
            body: Text(
              'chat:${state.uri.queryParameters['conversationId']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On parlait de mon rachat LPP'), findsOneWidget);

    await tester.tap(find.text('On parlait de mon rachat LPP'));
    await tester.pumpAndSettle();

    expect(find.text('chat:conv-row20-history'), findsOneWidget);
  });
}
