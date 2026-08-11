import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_domicile/mint_next_domicile_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecureWizardStore.resetSealFallbackForTest();
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
  });

  tearDown(SecureWizardStore.resetSealFallbackForTest);

  Widget wrap(CoachProfileProvider provider) {
    final router = GoRouter(
      initialLocation: '/domicile',
      routes: [
        GoRoute(
          path: '/domicile',
          builder: (_, __) => MintNextDomicileScreen(
            now: () => DateTime.utc(2026, 8, 11, 9),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(
            body: SizedBox(key: ValueKey('home_after_exit')),
          ),
        ),
      ],
    );
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  Future<CoachProfileProvider> loadedProvider() async {
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    return provider;
  }

  Future<void> fillAndContinue(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Argovie (AG)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Aarau');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'collect shows canton choices and commune entry as one decision and '
      'nothing persists before confirm', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Où habites-tu ?'), findsOneWidget);
    await fillAndContinue(tester);

    expect(find.text('MINT va retenir'), findsOneWidget);
    expect(find.text('Aarau (AG)'), findsOneWidget);
    expect(provider.domicileFact, isNull,
        reason: 'review is not yet a confirmation');
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets('safe exit before confirmation writes nothing', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_after_exit')), findsOneWidget);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  testWidgets(
      'confirm persists the fact and the saved summary offers edit and delete',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await fillAndContinue(tester);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Domicile enregistré'), findsOneWidget);
    expect(find.text('Aarau (AG)'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(provider.domicileFact?.communeName, 'Aarau');
    expect(provider.domicileFact?.canton, 'AG');
    expect(provider.domicileFact?.needsConfirmation, isFalse);
  });

  testWidgets('an existing fact opens directly on the saved summary',
      (tester) async {
    final provider = await loadedProvider();
    await provider.saveDomicileFact(MintNextDomicileFact(
      canton: 'GE',
      communeName: 'Carouge',
      assertedAt: DateTime.utc(2026, 8, 10),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Domicile enregistré'), findsOneWidget);
    expect(find.text('Carouge (GE)'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation then returns to collect',
      (tester) async {
    final provider = await loadedProvider();
    await provider.saveDomicileFact(MintNextDomicileFact(
      canton: 'GE',
      communeName: 'Carouge',
      assertedAt: DateTime.utc(2026, 8, 10),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ton domicile ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(provider.domicileFact, isNull);
    expect(find.text('Où habites-tu ?'), findsOneWidget);
  });

  testWidgets('missing canton or commune blocks with a visible error',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer'));
    await tester.pump();

    expect(
      find.text('Choisis ton canton et indique ta commune pour continuer.'),
      findsOneWidget,
    );
    expect(provider.domicileFact, isNull);
  });
}
