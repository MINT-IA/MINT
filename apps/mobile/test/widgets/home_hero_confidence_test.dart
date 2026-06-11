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
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/rich_chat_widgets.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';

/// Test-only provider exposing a direct profile setter (no SecureStorage).
class _TestCoachProfileProvider extends CoachProfileProvider {
  CoachProfile? _testProfile;
  void setTestProfile(CoachProfile? p) {
    _testProfile = p;
    notifyListeners();
  }

  @override
  CoachProfile? get profile => _testProfile;
}

/// A minimal valid profile whose canonical confidence is below the SOT §5
/// gate (combined ≈ 30 < 50) — the exact condition that wrongly gated a
/// legal-citation fact card before the Codex W3 fix.
CoachProfile _lowConfidenceProfile() => CoachProfile(
      birthYear: DateTime.now().year - 40,
      canton: 'VD',
      salaireBrutMensuel: 90000 / 12,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(DateTime.now().year + 25, 1, 1),
        label: 'Retraite',
      ),
    );

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

  /// Renders a [RagToolCall] (show_fact_card) through the real WidgetRenderer
  /// with a [profile] in the tree — exercises `_factConfidenceState`, the
  /// predicate that classifies a card as financial (and therefore gated).
  Future<void> pumpFactCardViaRenderer(
    WidgetTester tester,
    Map<String, dynamic> input,
    CoachProfile? profile,
  ) async {
    final provider = _TestCoachProfileProvider()..setTestProfile(profile);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final w = WidgetRenderer.build(
              context,
              RagToolCall(name: 'show_fact_card', input: input),
            );
            return Scaffold(body: SingleChildScrollView(child: w ?? const SizedBox()));
          },
        ),
      ],
    );
    await tester.pumpWidget(ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp.router(
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
    ));
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Codex W3 finding 2 (P2) — the gate must not hide legal/educational
  //    fact cards. show_fact_card REQUIRES `source` (« Legal or official
  //    source », coach_tools.py:152,159), so the old predicate
  //    `is_financial == true || source != null` classified EVERY card as
  //    financial and gated a pure legal citation at low profile confidence.
  group('Confidence Gate — legal vs financial classification (Codex W3)', () {
    testWidgets(
        'legal-source card (no figure) is NOT gated at low confidence',
        (tester) async {
      await pumpFactCardViaRenderer(
        tester,
        const {
          'title': 'Le pilier 3a est déductible',
          'content': 'Les versements 3a réduisent le revenu imposable.',
          'source': 'LIFD art. 33', // legal citation, NOT a financial figure
        },
        _lowConfidenceProfile(), // combined ≈ 30 < 50
      );

      // The card content renders ungated: no « demande de données » CTA.
      expect(find.byKey(const Key('hero_fact_gated_cta')), findsNothing,
          reason: 'a static legal citation must not trigger the SOT §5 gate '
              '— it carries no profile-dependent financial figure.');
      // And no estimated badge (it is not an estimator-sourced figure).
      expect(find.byKey(const Key('hero_fact_estimated_badge')), findsNothing,
          reason: 'a legal citation is not an estimated value.');
    });

    testWidgets(
        'explicit is_financial:true card IS gated at low confidence',
        (tester) async {
      await pumpFactCardViaRenderer(
        tester,
        const {
          'title': 'Ton avoir LPP',
          'highlight_value': "43'691 CHF",
          'content': 'Estimation de ton 2e pilier.',
          'source': 'LPP art. 14',
          'is_financial': true, // explicit financial figure
        },
        _lowConfidenceProfile(), // combined ≈ 30 < 50
      );

      // A genuine financial figure stays gated below 50 (D2 invariant).
      expect(find.byKey(const Key('hero_fact_gated_cta')), findsOneWidget,
          reason: 'an explicit financial figure must still be gated below '
              'the SOT §5 confidence floor.');
    });

    testWidgets(
        'card with a CHF figure in the value IS gated at low confidence',
        (tester) async {
      await pumpFactCardViaRenderer(
        tester,
        const {
          'title': 'Plafond 3a',
          'highlight_value': '7 258 CHF', // contains a financial figure
          'content': 'Le plafond annuel avec LPP.',
          'source': 'OPP3 art. 7',
        },
        _lowConfidenceProfile(), // combined ≈ 30 < 50
      );

      expect(find.byKey(const Key('hero_fact_gated_cta')), findsOneWidget,
          reason: 'a value carrying a CHF figure is financial and must be '
              'gated below the confidence floor.');
    });
  });

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
