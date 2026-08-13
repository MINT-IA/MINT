import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/data/commune_registry.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_domicile/mint_next_domicile_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Extrait du registre fédéral suffisant pour les oracles : une commune
/// simple, deux homonymes portant leur suffixe officiel, une commune à alias
/// romand et une à double forme. Le format est celui de l'asset réel.
const String _registryFixture = '''
# Instantané : 13-08-2026
4001|Aarau|AG|01.01.2010|
225|Rickenbach (ZH)|ZH|12.09.1848|
1097|Rickenbach (LU)|LU|01.01.2013|
6621|Genève|GE|12.09.1848|
2275|Murten|FR|01.01.2022|Morat
371|Biel/Bienne|BE|01.01.2010|Biel,Bienne
''';

Finder byIdentifier(String identifier) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.identifier == identifier,
      description: 'Semantics(identifier: $identifier)',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CommuneRegistry.debugReset();
    CommuneRegistry.parse(_registryFixture);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecureWizardStore.resetSealFallbackForTest();
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
  });

  tearDown(() {
    SecureWizardStore.resetSealFallbackForTest();
    CommuneRegistry.debugReset();
    CommuneRegistry.debugLoader = null;
  });

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

  /// Le canton n'est plus saisi : on tape le début du nom, on choisit une
  /// entrée du registre par son NUMÉRO OFS, et le canton en découle.
  Future<void> fillAndContinue(WidgetTester tester) async {
    await tester.enterText(byIdentifier('input:domicile.commune'), 'Aarau');
    await tester.pumpAndSettle();
    await tester.tap(byIdentifier('action:domicile.suggestion:4001'));
    await tester.pumpAndSettle();
    await tester.tap(byIdentifier('action:domicile.continue'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'collect asks for the commune alone and nothing persists before '
      'confirm', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.text('Quelle est ta commune fiscale ?'), findsOneWidget);
    await fillAndContinue(tester);

    expect(find.text('MINT va retenir'), findsOneWidget);
    expect(find.text('Aarau'), findsOneWidget);
    expect(find.text('Commune trouvée, dans le canton d\'Argovie.'),
        findsOneWidget);
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
    await tester.tap(byIdentifier('action:domicile.confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Domicile enregistré'), findsOneWidget);
    expect(find.text('Aarau'), findsOneWidget);
    expect(find.text('Commune trouvée, dans le canton d\'Argovie.'),
        findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(provider.domicileFact?.communeName, 'Aarau');
    expect(provider.domicileFact?.canton, 'AG',
        reason: 'le canton est dérivé de la commune, jamais saisi');
    expect(provider.domicileFact?.communeBfs, 4001,
        reason: "l'identité fédérale est enregistrée avec le fait");
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
    expect(find.text('Carouge'), findsOneWidget);
    expect(find.text('Commune trouvée, dans le canton de Genève.'),
        findsOneWidget);
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
    expect(find.text('Quelle est ta commune fiscale ?'), findsOneWidget);
  });

  testWidgets('continuing without a registry selection blocks with a visible '
      'error', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.tap(byIdentifier('action:domicile.continue'));
    await tester.pump();

    expect(
      find.text('Choisis ta commune dans la liste pour continuer.'),
      findsOneWidget,
    );
    expect(provider.domicileFact, isNull);
  });

  testWidgets(
      'no canton is ever asked — one field carries the whole decision and the '
      'canton is shown as its consequence', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing,
        reason: 'la commune détermine le canton : deux champs seraient une '
            'saisie redondante');
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(byIdentifier('input:domicile.commune'), 'Aarau');
    await tester.pumpAndSettle();
    await tester.tap(byIdentifier('action:domicile.suggestion:4001'));
    await tester.pumpAndSettle();

    expect(byIdentifier('status:domicile.canton_derived'), findsOneWidget);
    expect(find.text('Commune trouvée, dans le canton d\'Argovie.'),
        findsOneWidget);
  });

  testWidgets(
      'homonymous communes are offered as distinct entries carrying the '
      'official suffix and the canton spelled out', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.enterText(byIdentifier('input:domicile.commune'), 'Rickenbach');
    await tester.pumpAndSettle();

    // Sélection MÉCANIQUE par identité fédérale, jamais par libellé.
    expect(byIdentifier('action:domicile.suggestion:225'), findsOneWidget);
    expect(byIdentifier('action:domicile.suggestion:1097'), findsOneWidget);
    expect(find.text('Rickenbach (ZH)'), findsOneWidget);
    expect(find.text('Rickenbach (LU)'), findsOneWidget);
    // Deux initiales ne parlent pas à tout le monde : le canton est écrit.
    expect(find.text('Zurich'), findsOneWidget);
    expect(find.text('Lucerne'), findsOneWidget);
  });

  testWidgets(
      'typed text that matches nothing cannot be saved and says so',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.enterText(byIdentifier('input:domicile.commune'), 'Zzzzville');
    await tester.pumpAndSettle();

    expect(byIdentifier('status:domicile.no_match'), findsOneWidget);
    expect(byIdentifier('node:domicile.suggestions'), findsNothing);

    await tester.tap(byIdentifier('action:domicile.continue'));
    await tester.pump();
    expect(find.text('Choisis ta commune dans la liste pour continuer.'),
        findsOneWidget);
    expect(provider.domicileFact, isNull,
        reason: 'un texte libre n\'est pas une identité communale');
  });

  testWidgets(
      'editing the query after a selection drops that selection rather than '
      'saving a commune no longer shown', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await tester.enterText(byIdentifier('input:domicile.commune'), 'Aarau');
    await tester.pumpAndSettle();
    await tester.tap(byIdentifier('action:domicile.suggestion:4001'));
    await tester.pumpAndSettle();
    expect(byIdentifier('status:domicile.canton_derived'), findsOneWidget);

    await tester.enterText(byIdentifier('input:domicile.commune'), 'Aara');
    await tester.pumpAndSettle();

    expect(byIdentifier('status:domicile.canton_derived'), findsNothing);
    await tester.tap(byIdentifier('action:domicile.continue'));
    await tester.pump();
    expect(provider.domicileFact, isNull);
  });

  testWidgets(
      'the saved summary offers a way onward, not only data management',
      (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    await fillAndContinue(tester);
    await tester.tap(byIdentifier('action:domicile.confirm'));
    await tester.pumpAndSettle();

    expect(byIdentifier('action:domicile.back_to_today'), findsOneWidget,
        reason: 'modifier et supprimer sont de la gestion, pas une suite');
    await tester.tap(byIdentifier('action:domicile.back_to_today'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_after_exit')), findsOneWidget);
  });

  testWidgets(
      'the review step states that the commune was checked against the '
      'federal register — the collect step does not', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(byIdentifier('node:domicile.registry_source'), findsNothing,
        reason: "une mention de provenance avant la première frappe n'aide "
            'personne à choisir sa commune');

    await fillAndContinue(tester);
    expect(byIdentifier('node:domicile.registry_source'), findsOneWidget);
    expect(find.textContaining('registre fédéral'), findsOneWidget);
  });

  testWidgets(
      'a legacy fact saved without a federal number is not given an invented '
      'one', (tester) async {
    final provider = await loadedProvider();
    await provider.saveDomicileFact(MintNextDomicileFact(
      canton: 'AG',
      communeName: 'Aarau',
      assertedAt: DateTime.utc(2026, 8, 10),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    expect(provider.domicileFact!.communeBfs, isNull);
    await tester.tap(byIdentifier('action:domicile.edit'));
    await tester.pumpAndSettle();

    // Le nom est repris pour ne rien perdre, mais la sélection doit être
    // refaite : rien ne prouve que « Aarau » désignait la commune 4001.
    expect(byIdentifier('status:domicile.canton_derived'), findsNothing);
    await tester.tap(byIdentifier('action:domicile.continue'));
    await tester.pump();
    expect(find.text('Choisis ta commune dans la liste pour continuer.'),
        findsOneWidget);
  });

  group('le chargement réel du registre', () {
    // La revue Codex l'a relevé : les autres oracles pré-chargent le registre
    // et ne franchissent donc jamais la branche asynchrone, qui est la plus
    // risquée. Ceux-ci la franchissent.
    setUp(CommuneRegistry.debugReset);

    // Le vrai registre : `load()` exige la couverture nationale, un extrait
    // serait refusé — et c'est exactement ce qu'on veut protéger.
    final realRegistry =
        File('assets/data/commune_registry.txt').readAsStringSync();

    testWidgets('while the register is being read, nothing can be typed and '
        'the wait is stated', (tester) async {
      final gate = Completer<String>();
      CommuneRegistry.debugLoader = () => gate.future;
      final provider = await loadedProvider();
      await tester.pumpWidget(wrap(provider));
      await tester.pump();

      expect(byIdentifier('status:domicile.registry_loading'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      gate.complete(realRegistry);
      await tester.pumpAndSettle();
      expect(byIdentifier('status:domicile.registry_loading'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('a missing register says so and offers to try again rather '
        'than leaving a dead field', (tester) async {
      CommuneRegistry.debugLoader = () => Future.error(Exception('asset absent'));
      final provider = await loadedProvider();
      await tester.pumpWidget(wrap(provider));
      await tester.pumpAndSettle();

      expect(byIdentifier('status:domicile.registry_failed'), findsOneWidget);
      expect(byIdentifier('action:domicile.registry_retry'), findsOneWidget);
      // Proposer « Continuer » quand rien n'est sélectionnable est un piège.
      final continueButton = tester.widget<FilledButton>(find.descendant(
          of: byIdentifier('action:domicile.continue'),
          matching: find.byType(FilledButton)));
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('a corrupted register is refused, not half-loaded',
        (tester) async {
      CommuneRegistry.debugLoader = () async => '4001|Aarau|AG\n';
      final provider = await loadedProvider();
      await tester.pumpWidget(wrap(provider));
      await tester.pumpAndSettle();

      expect(byIdentifier('status:domicile.registry_failed'), findsOneWidget);
      expect(CommuneRegistry.isLoaded, isFalse,
          reason: 'un registre corrompu ne se fait pas passer pour chargé');
    });

    testWidgets('trying again after a failure loads the register',
        (tester) async {
      var attempt = 0;
      CommuneRegistry.debugLoader = () async {
        attempt++;
        if (attempt == 1) throw Exception('lecture impossible');
        return realRegistry;
      };
      final provider = await loadedProvider();
      await tester.pumpWidget(wrap(provider));
      await tester.pumpAndSettle();
      expect(byIdentifier('status:domicile.registry_failed'), findsOneWidget);

      await tester.tap(byIdentifier('action:domicile.registry_retry'));
      await tester.pumpAndSettle();

      expect(byIdentifier('status:domicile.registry_failed'), findsNothing);
      await tester.enterText(byIdentifier('input:domicile.commune'), 'Aarau');
      await tester.pumpAndSettle();
      expect(byIdentifier('action:domicile.suggestion:4001'), findsOneWidget);
    });

    testWidgets('leaving the screen while the register is still loading does '
        'not blow up', (tester) async {
      final gate = Completer<String>();
      CommuneRegistry.debugLoader = () => gate.future;
      final provider = await loadedProvider();
      await tester.pumpWidget(wrap(provider));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      gate.complete(realRegistry);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'the review step refuses a bare pop and sends it back to the commune '
      'field, like the button says', (tester) async {
    final provider = await loadedProvider();
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle();

    // Le paramètre de type de PopScope varie selon l'inférence : on le
    // retrouve par son nom, dans le sous-arbre de l'écran uniquement.
    dynamic scope() => tester.widgetList(find.descendant(
          of: find.byType(MintNextDomicileScreen),
          matching: find.byWidgetPredicate((w) =>
              w.runtimeType.toString().startsWith('PopScope')),
        )).first;

    expect(scope().canPop, isTrue, reason: 'la collecte se quitte librement');

    await fillAndContinue(tester);
    expect(find.text('MINT va retenir'), findsOneWidget);
    expect(scope().canPop, isFalse,
        reason: 'quitter depuis la relecture perdrait la sélection');

    // On invoque la réponse au retour refusé. Ce que cet oracle prouve : la
    // décision de l'écran. Ce qu'il ne prouve PAS : que le geste système
    // atteint bien cette décision à travers le routeur — cela relève d'un
    // passage sur simulateur.
    scope().onPopInvokedWithResult!(false, null);
    await tester.pumpAndSettle();

    expect(byIdentifier('node:domicile.collect'), findsOneWidget);
    expect(provider.domicileFact, isNull);
  });
}
