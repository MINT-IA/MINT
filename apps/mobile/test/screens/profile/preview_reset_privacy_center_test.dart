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
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/profile/privacy_center_screen.dart';
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
      'without the preview policy the reset action never renders and '
      'behavior is unchanged', (tester) async {
    PreviewShellPolicy.debugOverride =
        const PreviewShellPolicy.forTest(isPreviewShell: false);
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Préversion'), findsNothing);
    expect(find.text('Repartir à zéro sur cet appareil ?'), findsNothing);
    expect(find.text("Effacer l'état local"), findsNothing);
    // Référence OFF positive : le reste du centre est inchangé.
    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });
}
