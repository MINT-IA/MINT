// Lego C1 — beats c1/c2/c7 : la surface d'éclairage.
//
// Chaque état non-attesté est DISTINCT (une lecture en échec n'est jamais
// présentée comme un jumeau vide) et n'appelle JAMAIS le réseau. La
// réponse rendue est celle du serveur, sourcée et datée, sans relance.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_vertical_3a/mint_next_coach_eclairage_screen.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/coach/twin_read_api_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _attestation = {
  'amountCents': 375800,
  'currency': 'CHF',
  'taxYear': 2026,
  'state': 'positive',
  'computedAt': '2026-08-13T00:00:00Z',
  'engineVersion': 'marge-3a-v1',
  'inputsHash':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'registryHash':
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
};

class _LoadedProvider extends CoachProfileProvider {
  @override
  bool get isLoaded => true;
  @override
  bool get loadFailed => false;
}

class _FailedProvider extends CoachProfileProvider {
  @override
  bool get isLoaded => true;
  @override
  bool get loadFailed => true;
}

class _LoadingProvider extends CoachProfileProvider {
  @override
  bool get isLoaded => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> sentPaths;

  void mockApi({
    int status = 200,
    Map<String, dynamic> body = const {'answer': 'Ta marge 3a 2026 vaut 3758 CHF.'},
  }) {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          sentPaths.add(request.url.path);
          final isTwinRead = request.url.path.contains('twin-read');
          return http.Response(
            jsonEncode(isTwinRead ? body : const {'consents': []}),
            isTwinRead ? status : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ConsentService.resetCacheForTest();
    sentPaths = [];
    mockApi();
  });

  tearDown(() => ApiService.setHttpClientForTesting(null));

  Widget buildApp({
    required CoachProfileProvider provider,
    Map<String, dynamic>? attestation,
  }) {
    final router = GoRouter(
      initialLocation: '/eclairage',
      routes: [
        GoRoute(
          path: '/mon-argent',
          builder: (_, __) => const Scaffold(body: Text('ma-situation')),
        ),
        GoRoute(
          path: '/eclairage',
          builder: (_, __) => MintNextCoachEclairageScreen(
            attestationOverride: attestation,
          ),
        ),
      ],
    );
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp.router(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('fr'),
        routerConfig: router,
      ),
    );
  }

  testWidgets(
      'each non-attested state (absent, invalid, read-failure, stale) '
      'renders its own honest state', (tester) async {
    await tester.pumpWidget(buildApp(provider: _LoadedProvider()));
    await tester.pumpAndSettle();
    expect(
        find.textContaining("Ta marge 3a n'est pas encore attestée"),
        findsOneWidget,
        reason: 'jumeau sans attestation = état unattested');

    await tester.pumpWidget(buildApp(provider: _FailedProvider()));
    await tester.pumpAndSettle();
    expect(
        find.textContaining("Tes données n'ont pas pu être lues"),
        findsOneWidget,
        reason: 'lecture en échec = état DISTINCT');
    expect(find.textContaining("pas encore attestée"), findsNothing);
  });

  testWidgets('a read failure is never presented as an empty twin',
      (tester) async {
    await tester.pumpWidget(buildApp(provider: _FailedProvider()));
    await tester.pumpAndSettle();
    expect(find.textContaining("Tes données n'ont pas pu être lues"),
        findsOneWidget);
    expect(find.textContaining('pas encore attestée'), findsNothing);
  });

  testWidgets('the loading state is neither empty twin nor read failure',
      (tester) async {
    await tester.pumpWidget(buildApp(provider: _LoadingProvider()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining("pas encore attestée"), findsNothing);
    expect(find.textContaining("n'ont pas pu être lues"), findsNothing);
  });

  testWidgets(
      'the C1 entry is reachable from the vertical in every state but the '
      'LLM call is only possible on an attested margin', (tester) async {
    // Sans attestation : l'écran s'ouvre (l'entrée n'est jamais un
    // cul-de-sac) mais aucun champ de question n'existe.
    await tester.pumpWidget(buildApp(provider: _LoadedProvider()));
    await tester.pumpAndSettle();
    expect(find.text('Éclairer ma marge'), findsOneWidget,
        reason: "la surface s'ouvre même sans attestation");
    expect(find.byKey(const Key('coach_eclairage_question')), findsNothing,
        reason: 'aucun appel LLM possible sans marge attestée');

    // Avec attestation : la question devient possible.
    await tester.pumpWidget(buildApp(
        provider: _LoadedProvider(), attestation: _attestation));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach_eclairage_question')), findsOneWidget);
  });

  testWidgets(
      'no non-attested state ever triggers a network call or consumes quota',
      (tester) async {
    for (final provider in [
      _LoadedProvider(),
      _FailedProvider(),
      _LoadingProvider(),
    ]) {
      await tester.pumpWidget(buildApp(provider: provider));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(sentPaths.where((p) => p.contains('twin-read')), isEmpty);
    // Aucun quota consommé : aucune réservation n'a même été posée.
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs
            .getKeys()
            .where((k) => k.startsWith(TwinReadApiService.pendingKeyPrefix)),
        isEmpty);
  });

  testWidgets(
      'the rendered answer shows the source year and freshness, states its '
      'limits, and its only CTA leads to correction or completion',
      (tester) async {
    await ConsentService().grantLocal(ConsentPurpose.twinRead3aMargin);
    await tester.pumpWidget(buildApp(
        provider: _LoadedProvider(), attestation: _attestation));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('coach_eclairage_question')), 'Ça veut dire ?');
    await tester.tap(find.text('Demander un éclairage'));
    await tester.pumpAndSettle();

    expect(find.text('Ta marge 3a 2026 vaut 3758 CHF.'), findsOneWidget,
        reason: "l'écran rend le texte VALIDÉ par le serveur");
    expect(find.byKey(const Key('coach_eclairage_source')), findsOneWidget);
    expect(
        find.textContaining('marge 3a attestée 2026, calculée le 2026-08-13'),
        findsOneWidget,
        reason: 'source + année + date de calcul visibles');
    expect(find.byKey(const Key('coach_eclairage_limit')), findsOneWidget);
    expect(find.text('Demander un éclairage'), findsNothing,
        reason: 'aucune relance libre après la réponse');
    expect(find.text('Voir ma situation'), findsOneWidget,
        reason: 'le seul CTA mène à la correction/complétion');
  });

  testWidgets(
      'the answer never contradicts the attested state and offers no free '
      'follow-up nor generated navigation', (tester) async {
    await ConsentService().grantLocal(ConsentPurpose.twinRead3aMargin);
    await tester.pumpWidget(buildApp(
        provider: _LoadedProvider(), attestation: _attestation));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('coach_eclairage_question')), 'Question');
    await tester.tap(find.text('Demander un éclairage'));
    await tester.pumpAndSettle();

    // La réponse rendue est CELLE du serveur : l'écran n'y ajoute ni
    // chiffre, ni contradiction d'état, ni relance, ni navigation générée.
    expect(find.byKey(const Key('coach_eclairage_question')), findsNothing,
        reason: 'aucun champ de relance après la réponse');
    expect(find.text('Demander un éclairage'), findsNothing);
    final ctas = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(ctas, hasLength(1),
        reason: 'un seul CTA — pas de navigation générée');
    expect(find.textContaining('nulle'), findsNothing,
        reason: "state=positive : aucune contradiction affichée");
  });

  testWidgets('refusing the consent stops locally and sends nothing',
      (tester) async {
    await tester.pumpWidget(buildApp(
        provider: _LoadedProvider(), attestation: _attestation));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('coach_eclairage_question')), 'Ça veut dire ?');
    await tester.tap(find.text('Demander un éclairage'));
    await tester.pumpAndSettle();

    // La feuille de consentement dédiée s'ouvre — refus.
    expect(find.text('Éclairage de ta marge 3a'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(sentPaths.where((p) => p.contains('twin-read')), isEmpty,
        reason: 'refus = arrêt LOCAL, aucun octet');
    expect(
        find.textContaining("Sans ton accord, rien n'est envoyé"),
        findsOneWidget);
  });

  testWidgets(
      'a deterministic refusal shows the safe no-number copy and an '
      'ambiguous failure says it can be retried', (tester) async {
    await ConsentService().grantLocal(ConsentPurpose.twinRead3aMargin);
    mockApi(status: 422, body: const {'detail': 'claim_check_rejected'});
    await tester.pumpWidget(buildApp(
        provider: _LoadedProvider(), attestation: _attestation));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('coach_eclairage_question')), 'Question');
    await tester.tap(find.text('Demander un éclairage'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Je ne peux pas produire un éclairage fiable'),
        findsOneWidget);

    mockApi(status: 503, body: const {'detail': 'boom'});
    await tester.tap(find.text('Demander un éclairage'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining("L'éclairage n'a pas abouti"), findsOneWidget,
        reason: 'issue ambiguë = rejouable, jamais un faux succès');
  });
}
