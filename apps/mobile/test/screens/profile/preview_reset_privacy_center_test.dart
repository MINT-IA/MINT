// Bascule 2 — beats r2 (UI préversion, copie bornée, confirmation forte)
// et r5 (OFF strict) du contrat local_reset.storyboard.json.
//
// La copie est PINNÉE mot à mot sur le contrat : distinguer appareil,
// compte et serveur — jamais « toutes tes données », jamais une promesse
// de suppression de compte.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/profile/privacy_center_screen.dart';
import 'package:mint_mobile/services/local_preview_reset_service.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool isLoggedIn = true;

  // B3a : l'autorité du rendu est le lifecycle CANONIQUE — anonyme ici.
  @override
  AuthLifecycleState get authLifecycle =>
      AuthLifecycleState.guestEmpty(installId: 'test-install');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildApp() {
  final router = GoRouter(
    initialLocation: '/profile/privacy',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (_, __) => const PrivacyCenterScreen(),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuthProvider()),
      ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => CoachProfileProvider()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.resetMemoryCacheForTest();
    SecureWizardStore.resetSealFallbackForTest();
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
    PreviewShellPolicy.debugOverride =
        const PreviewShellPolicy.forTest(isPreviewShell: true);
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          if (request.url.path == '/api/v1/consents') {
            return http.Response(
              '{"consents":[]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"detail":"not found"}', 404);
        }),
      ),
    );
  });

  tearDown(() {
    PreviewShellPolicy.debugOverride = null;
    ApiService.setHttpClientForTesting(null);
    SecureWizardStore.resetSealFallbackForTest();
  });

  testWidgets('the reset entry renders only under the preview policy',
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.text('Repartir à zéro sur cet appareil ?'), 200);
    expect(find.text('Préversion'), findsOneWidget);
    expect(find.text('Repartir à zéro sur cet appareil ?'), findsOneWidget);
  });

  testWidgets(
      'the reset entry renders even when the consents fetch fails — a local '
      'action never depends on the network', (tester) async {
    // Bug runtime run 1 : en anonyme le fetch consents échoue et l'état
    // d'erreur du centre masquait toute la section Préversion.
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async =>
            http.Response('{"detail":"boom"}', 500)),
      ),
    );
    // Portrait téléphone : le viewport test par défaut (800x600 paysage)
    // fait déborder la carte d'erreur sous les sections locales.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Repartir à zéro sur cet appareil ?'), findsOneWidget,
        reason: 'le reset LOCAL rend indépendamment du réseau');
  });

  testWidgets('the copy never promises account or server deletion',
      (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Repartir à zéro sur cet appareil ?'), 200);

    // Copie PINNÉE mot à mot sur le contrat (Q1 du cadrage).
    const contractBody =
        'MINT effacera ta situation financière et ton historique enregistrés '
        'sur cet appareil. Ton compte, ta connexion et tes consentements '
        'restent inchangés. Les données déjà enregistrées sur nos serveurs '
        'ne seront pas supprimées.';
    expect(find.text(contractBody), findsOneWidget);
    expect(contractBody.contains('toutes tes données'), isFalse,
        reason: 'promesse totale interdite — le reset est local');
    expect(contractBody.contains('supprimera ton compte'), isFalse,
        reason: 'jamais une promesse de suppression de compte');
  });

  testWidgets('the strong confirmation gates the destructive action',
      (tester) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: '_mint_canonical_revenu_v1', value: 'seeded');

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Repartir à zéro sur cet appareil ?'), 200);

    // 1er passage : CTA sans saisie ⇒ RIEN n'est purgé.
    await tester.tap(find.text('Repartir à zéro sur cet appareil ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Effacer l'état local"));
    await tester.pumpAndSettle();
    expect(await storage.read(key: '_mint_canonical_revenu_v1'), 'seeded',
        reason: 'sans la saisie exacte la purge ne part JAMAIS');

    // 2e passage : saisie erronée ⇒ toujours rien.
    await tester.tap(find.text('Repartir à zéro sur cet appareil ?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('preview_reset_confirm_field')), 'REPARTIR');
    await tester.tap(find.text("Effacer l'état local"));
    await tester.pumpAndSettle();
    expect(await storage.read(key: '_mint_canonical_revenu_v1'), 'seeded');

    // 3e passage : saisie exacte ⇒ purge réelle + retour racine.
    await tester.tap(find.text('Repartir à zéro sur cet appareil ?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('preview_reset_confirm_field')),
        'REPARTIR À ZÉRO');
    await tester.tap(find.text("Effacer l'état local"));
    await tester.pumpAndSettle();
    expect(await storage.read(key: '_mint_canonical_revenu_v1'), isNull,
        reason: 'la saisie exacte déclenche la purge vérifiée');
    expect(find.text('home'), findsOneWidget,
        reason: 'retour à la racine de la coque après reset');
  });

  testWidgets(
      'the confirmation tolerates missing diacritics but still requires the '
      'full phrase', (tester) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: '_mint_canonical_revenu_v1', value: 'seeded');

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    // Saisie sans accents (clavier iOS réel / driver E2E) : acceptée —
    // le geste fort reste la phrase ENTIÈRE, pas la précision des
    // diacritiques.
    await tester.tap(find.text('Repartir à zéro sur cet appareil ?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('preview_reset_confirm_field')),
        'repartir a zero');
    await tester.tap(find.text("Effacer l'état local"));
    await tester.pumpAndSettle();
    expect(await storage.read(key: '_mint_canonical_revenu_v1'), isNull,
        reason: 'phrase entière sans accents = même geste intentionnel');
  });

  testWidgets(
      'a failed purge shows the honest retry message and never claims '
      'success', (tester) async {
    // Panne injectée dans l'orchestrateur — l'UI doit montrer le message de
    // retry, jamais le succès, et rester sur le centre de confidentialité.
    LocalPreviewResetService.debugPurgeFailureForTest =
        () async => throw StateError('injected purge failure');
    addTearDown(
        () => LocalPreviewResetService.debugPurgeFailureForTest = null);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Repartir à zéro sur cet appareil ?'), 200);
    await tester.tap(find.text('Repartir à zéro sur cet appareil ?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('preview_reset_confirm_field')),
        'REPARTIR À ZÉRO');
    await tester.tap(find.text("Effacer l'état local"));
    await tester.pumpAndSettle();

    expect(
        find.text("L'effacement n'a pas abouti. Il sera retenté au prochain "
            'démarrage.'),
        findsOneWidget,
        reason: 'échec partiel = rouge honnête, jamais silencieux');
    expect(find.text('État local effacé.'), findsNothing,
        reason: 'jamais un succès annoncé sur une purge non vérifiée');
    expect(find.text('home'), findsNothing,
        reason: 'pas de retour racine sur un reset non abouti');
  });

  testWidgets(
      'without the preview policy the reset action never renders and '
      'behavior is unchanged', (tester) async {
    PreviewShellPolicy.debugOverride =
        const PreviewShellPolicy.forTest(isPreviewShell: false);
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Préversion'), findsNothing);
    expect(find.text('Repartir à zéro sur cet appareil ?'), findsNothing);
    expect(find.text("Effacer l'état local"), findsNothing);
    // Référence OFF positive : l'état compte anonyme HONNÊTE rend (B3a) —
    // version publique SANS pointeur préversion.
    expect(find.text('Supprimer mon compte'), findsNothing);
    expect(
        find.text("Aucun compte connecté sur cet appareil — il n'y a pas "
            'de compte à supprimer.'),
        findsOneWidget);
  });
}
