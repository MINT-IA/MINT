// Bascule 3a — beats a1/a2/a3/a5 du contrat account_delete.storyboard.json.
//
// L'autorité du rendu est le lifecycle CANONIQUE : un booléen isLoggedIn
// périmé n'expose JAMAIS la suppression ; l'état anonyme est honnête et,
// en préversion, renvoie au reset local (B2).

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
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LifecycleFakeAuthProvider extends ChangeNotifier
    implements AuthProvider {
  _LifecycleFakeAuthProvider(this._lifecycle, {this.staleLoggedInFlag});

  final AuthLifecycleState _lifecycle;
  final bool? staleLoggedInFlag;
  bool deleteAccountCalled = false;

  @override
  AuthLifecycleState get authLifecycle => _lifecycle;

  @override
  bool get isLoggedIn =>
      staleLoggedInFlag ?? _lifecycle.accessMode == AuthAccessMode.account;

  @override
  Future<bool> deleteAccount() async {
    deleteAccountCalled = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildApp(_LifecycleFakeAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/profile/privacy',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('root')),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (_, __) => const PrivacyCenterScreen(),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
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

  _LifecycleFakeAuthProvider anonymous({bool? staleFlag}) =>
      _LifecycleFakeAuthProvider(
          AuthLifecycleState.guestEmpty(installId: 'test-install'),
          staleLoggedInFlag: staleFlag);

  _LifecycleFakeAuthProvider account() => _LifecycleFakeAuthProvider(
      AuthLifecycleState.cloudSyncOnAccount(userId: 'user-42'));

  testWidgets(
      'without a canonically signed-in identity the delete account action '
      'never renders', (tester) async {
    await tester.pumpWidget(_buildApp(anonymous()));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsNothing);
    expect(find.text('Compte'), findsOneWidget,
        reason: "l'état compte anonyme rend à la place");
  });

  testWidgets(
      'the anonymous state shows an explicit no-account message instead of '
      'a server deletion promise', (tester) async {
    await tester.pumpWidget(_buildApp(anonymous()));
    await tester.pumpAndSettle();

    expect(
        find.textContaining(
            "Aucun compte connecté sur cet appareil — il n'y a pas de "
            'compte à supprimer.'),
        findsOneWidget);
    expect(find.textContaining('seront supprimées'), findsNothing,
        reason: 'aucune promesse de suppression serveur en anonyme — la '
            'copie B2 dit le contraire (« ne seront pas supprimées »)');
  });

  testWidgets(
      'a stale logged-in flag without canonical identity never exposes '
      'account deletion', (tester) async {
    // isLoggedIn=true PÉRIMÉ, lifecycle canonique anonyme : l'autorité
    // est le lifecycle — la suppression n'apparaît jamais.
    await tester.pumpWidget(_buildApp(anonymous(staleFlag: true)));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsNothing);
  });

  testWidgets(
      'in preview the anonymous state points to the local reset and outside '
      'preview it never does', (tester) async {
    await tester.pumpWidget(_buildApp(anonymous()));
    await tester.pumpAndSettle();
    expect(find.textContaining("Effacer l'état local"), findsWidgets,
        reason: 'préversion : le pointeur vers le reset B2 est présent');

    PreviewShellPolicy.debugOverride =
        const PreviewShellPolicy.forTest(isPreviewShell: false);
    await tester.pumpWidget(_buildApp(anonymous()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Préversion'), findsNothing);
    expect(find.textContaining("Effacer l'état local"), findsNothing,
        reason: 'hors préversion : aucun pointeur, aucun reset');
  });

  testWidgets(
      'following the anonymous pointer runs the full B2 reset and lands on '
      'a clean anonymous shell', (tester) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: '_mint_canonical_revenu_v1', value: 'seeded');

    await tester.pumpWidget(_buildApp(anonymous()));
    await tester.pumpAndSettle();
    // Le pointeur désigne l'action de la section Préversion de la même
    // page : parcours complet renvoi → confirmation LOCALE → exécution.
    await tester.tap(find.text('Repartir à zéro sur cet appareil ?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('preview_reset_confirm_field')),
        'REPARTIR A ZERO');
    await tester.tap(find.text("Effacer l'état local"));
    await tester.pumpAndSettle();

    expect(await storage.read(key: '_mint_canonical_revenu_v1'), isNull,
        reason: 'le B2 complet a tourné — purge vérifiée');
    expect(find.text('home'), findsOneWidget,
        reason: 'retour coque anonyme propre');
  });

  testWidgets('a canonically signed-in user still gets the existing delete '
      'account flow', (tester) async {
    final auth = account();
    await tester.pumpWidget(_buildApp(auth));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Supprimer mon compte'), 200);
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le compte ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(auth.deleteAccountCalled, isTrue,
        reason: 'le chemin connecté est INTACT — B3a ne change rien');
  });
}
