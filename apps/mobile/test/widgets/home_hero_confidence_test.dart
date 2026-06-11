/// W3 — Hero a 3 etats + Confidence Gate + tag « estime » generalise.
///
/// Verrouille SOT §5 (Confidence Gate) sur le hero fact card du coach / home :
///   - combined < 50  → le hero ne rend PAS de chiffre nu : etat « inconnu »
///     (demande de donnees / CTA), l'inverse exact de D2 (« 43'691 Avoir LPP »
///     nu affiche avec Fiabilite 44%).
///   - 50 <= combined < 70 → chiffre + note d'incertitude (bande obligatoire).
///   - combined >= 70 ET source connue → chiffre nu autorise.
///   - valeur issue d'un estimateur → badge « estime » sur le hero, jamais nu
///     (le pattern Mon Argent>Prevoyance generalise — D2).
///
/// 0-trust receipt : ce test sort 0 de maniere deterministe (3 etats testes),
/// gate de l'acceptance criterion (a) du plan 11 Task 2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/coach/rich_chat_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    await tester.pumpAndSettle();
  }

  group('Hero fact card — Confidence Gate (SOT §5)', () {
    testWidgets(
        'combined < 50 → chiffre GATE (pas de valeur nue, CTA de demande)',
        (tester) async {
      await pump(
        tester,
        const ChatFactCard(
          eyebrow: 'Avoir LPP',
          value: "43'691 CHF",
          description: 'Estimation de ton 2e pilier',
          confidenceState: FactConfidenceState.gated,
        ),
      );

      // La valeur nue NE doit PAS apparaitre (gate D2 inverse).
      expect(find.text("43'691 CHF"), findsNothing,
          reason:
              'combined<50 doit gater le chiffre vedette (SOT §5), pas '
              'l\'afficher nu comme dans D2.');
      // Un CTA de demande de donnees est present.
      expect(find.byKey(const Key('hero_fact_gated_cta')), findsOneWidget,
          reason: 'L\'etat gate doit pousser vers la saisie de donnees.');
    });

    testWidgets(
        'source estimateur → badge « estime » + valeur (jamais nue)',
        (tester) async {
      await pump(
        tester,
        const ChatFactCard(
          eyebrow: 'Avoir LPP',
          value: "43'691 CHF",
          description: 'Estimation de ton 2e pilier',
          confidenceState: FactConfidenceState.estimated,
        ),
      );

      // La valeur est affichee (confiance suffisante) MAIS taguee « estime ».
      expect(find.text("43'691 CHF"), findsOneWidget);
      expect(find.byKey(const Key('hero_fact_estimated_badge')),
          findsOneWidget,
          reason:
              'Une valeur d\'estimateur porte le badge « estime » sur le hero '
              '(pattern Mon Argent generalise — D2).');
      final badgeText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('hero_fact_estimated_badge')),
          matching: find.byType(Text),
        ),
      );
      expect(badgeText.data, 'estimé');
    });

    testWidgets('source connue (>=70) → valeur nue autorisee, pas de badge',
        (tester) async {
      await pump(
        tester,
        const ChatFactCard(
          eyebrow: 'Avoir LPP',
          value: "43'691 CHF",
          description: 'Certificat LPP',
          confidenceState: FactConfidenceState.known,
        ),
      );

      expect(find.text("43'691 CHF"), findsOneWidget);
      expect(find.byKey(const Key('hero_fact_estimated_badge')), findsNothing,
          reason: 'Une valeur certifiee/connue ne porte pas le badge estime.');
      expect(find.byKey(const Key('hero_fact_gated_cta')), findsNothing);
    });

    testWidgets('defaut (sans confidenceState) = known → retro-compatible',
        (tester) async {
      // Les appelants existants qui ne passent pas confidenceState gardent le
      // comportement nu (pas de regression sur les fact cards non-financieres).
      await pump(
        tester,
        const ChatFactCard(
          eyebrow: 'Levier',
          value: 'Verse en 3a',
          description: 'Action du mois',
        ),
      );
      expect(find.text('Verse en 3a'), findsOneWidget);
      expect(find.byKey(const Key('hero_fact_gated_cta')), findsNothing);
      expect(find.byKey(const Key('hero_fact_estimated_badge')), findsNothing);
    });
  });
}
