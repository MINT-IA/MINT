import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';

/// PR-F — la dégradation offline du coach (TRANCHE-FIRSTJOB-SPEC §2.3/A4) est
/// un état NOMMÉ, non vide et RE-TENTABLE : ancre `coach-offline-degradation`
/// + bouton « Réessayer » qui re-tente le dernier message, jamais l'écran vide
/// « Aucune donnée pour l'instant » (régression 2026-05-07). Un message système
/// ordinaire (sans identifiant, sans retry) reste inchangé.

Finder _byId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
      'offline : ancre coach-offline-degradation + « Réessayer » re-tentable',
      (tester) async {
    var retried = 0;
    final msg = ChatMessage(
      role: 'system',
      content: 'Erreur de connexion. Vérifie ta connexion internet.',
      timestamp: DateTime.now(),
      suggestedActions: const ['ma question'],
      semanticsIdentifier: 'coach-offline-degradation',
    );
    await _pump(
      tester,
      SystemMessageBubble(
        message: msg,
        onRetry: () => retried++,
        retryLabel: 'Réessayer',
      ),
    );

    expect(_byId('coach-offline-degradation'), findsOneWidget,
        reason: 'l\'état offline est nommé et assertable (A4)');
    expect(find.text(msg.content), findsOneWidget,
        reason: 'message non vide, non bloquant');
    expect(find.textContaining('Aucune donnée'), findsNothing,
        reason: 'jamais l\'écran vide régressif');

    expect(find.text('Réessayer'), findsOneWidget,
        reason: 'action de retry visible (pas un cul-de-sac)');
    await tester.tap(find.byType(TextButton));
    expect(retried, 1, reason: 'le retry re-tente le dernier message');
  });

  testWidgets('message système ordinaire : ni ancre offline ni bouton',
      (tester) async {
    await _pump(
      tester,
      SystemMessageBubble(
        message: ChatMessage(
          role: 'system',
          content: 'Un message neutre.',
          timestamp: DateTime.now(),
        ),
      ),
    );
    expect(_byId('coach-offline-degradation'), findsNothing,
        reason: 'pas d\'ancre offline sur un message système ordinaire');
    expect(find.byType(TextButton), findsNothing,
        reason: 'pas de retry sur un message système ordinaire');
    expect(find.text('Un message neutre.'), findsOneWidget);
  });
}
