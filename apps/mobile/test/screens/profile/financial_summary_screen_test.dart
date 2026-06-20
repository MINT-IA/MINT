import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);

  final CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider(this._state);

  final MintAccountDataState _state;

  @override
  MintAccountDataState get accountDataState => _state;
}

Widget _pumpable(
  CoachProfile? profile, {
  AuthProvider? authProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: _FakeCoachProfileProvider(profile),
      ),
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? AuthProvider(),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: FinancialSummaryScreen(),
    ),
  );
}

CoachProfile _defensibleJulienProfile() {
  final profile = CoachProfile.fromWizardAnswers(
    CoachProfileSeeds.registry['julien_swiss']!.toWizardAnswers(
      now: DateTime(2026, 6, 4),
    ),
  );
  return profile.copyWith(
    dataSources: {
      ...profile.dataSources,
      'revenuBrutAnnuel': ProfileDataSource.userInput,
      'salaireBrutMensuel': ProfileDataSource.userInput,
      'depenses.loyer': ProfileDataSource.userInput,
      'depenses.assuranceMaladie': ProfileDataSource.userInput,
      'patrimoine.epargneLiquide': ProfileDataSource.userInput,
      'patrimoine.investissements': ProfileDataSource.userInput,
      'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
      'prevoyance.totalEpargne3a': ProfileDataSource.userInput,
      'dettes.totalDettes': ProfileDataSource.userInput,
      'dettes.hypotheque': ProfileDataSource.userInput,
      'dettes.creditConsommation': ProfileDataSource.userInput,
      'dettes.leasing': ProfileDataSource.userInput,
      'dettes.autresDettes': ProfileDataSource.userInput,
    },
    userProvidedFields: {...profile.userProvidedFields, 'salary'},
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  testWidgets('empty material profile shows diagnostic state, not covered gap',
      (tester) async {
    await tester.pumpWidget(_pumpable(CoachProfile.fromWizardAnswers({})));
    await tester.pumpAndSettle();

    expect(find.text('Aucun profil renseigné'), findsOneWidget);
    expect(find.text('Commencer le diagnostic'), findsOneWidget);
    expect(find.text('Tu es bien couvert·e'), findsNothing);
  });

  testWidgets(
      'Mint 2 live axis handoff appears in dossier before profile facts',
      (tester) async {
    FeatureFlags.enableMint2FirstExperienceEntry = true;
    await ReportPersistenceService.saveMint2AxisHandoff({
      'onb_axis_v2': 'lpp_rente_capital',
      'onb_axis_schema_version': 2,
      'legacy_onb_intent': 'retraite',
    });

    await tester.pumpWidget(_pumpable(null));
    await tester.pumpAndSettle();

    expect(find.text('2e pilier : rente ou capital'), findsOneWidget);
    expect(find.text('Champs requis manquants'), findsOneWidget);
    expect(find.text('Preuve absente'), findsOneWidget);
    expect(find.text('Aucun profil renseigné'), findsNothing);
  });

  testWidgets('Mint 2 axis handoff stays hidden while entry flag is off',
      (tester) async {
    await ReportPersistenceService.saveMint2AxisHandoff({
      'onb_axis_v2': 'lpp_rente_capital',
      'onb_axis_schema_version': 2,
    });

    await tester.pumpWidget(_pumpable(null));
    await tester.pumpAndSettle();

    expect(find.text('2e pilier : rente ou capital'), findsNothing);
    expect(find.text('Aucun profil renseigné'), findsOneWidget);
  });

  testWidgets('reset removes Mint 2 axis handoff from dossier surface',
      (tester) async {
    FeatureFlags.enableMint2FirstExperienceEntry = true;
    await ReportPersistenceService.saveMint2AxisHandoff({
      'onb_axis_v2': 'lpp_rente_capital',
      'onb_axis_schema_version': 2,
    });
    await ReportPersistenceService.clearDiagnostic();

    await tester.pumpWidget(_pumpable(null));
    await tester.pumpAndSettle();

    expect(find.text('2e pilier : rente ou capital'), findsNothing);
    expect(find.text('Aucun profil renseigné'), findsOneWidget);
  });

  testWidgets(
      'estimated LPP profile stays in incomplete dossier state, not projection',
      (tester) async {
    FeatureFlags.enableMint2FirstExperienceEntry = true;
    await ReportPersistenceService.saveMint2AxisHandoff({
      'onb_axis_v2': 'lpp_rente_capital',
      'onb_axis_schema_version': 2,
      'legacy_onb_intent': 'retraite',
    });
    final profile = CoachProfile.defaults().copyWith(
      birthYear: 1988,
      canton: 'VS',
      salaireBrutMensuel: 7000,
      prevoyance: const PrevoyanceProfile(avoirLppTotal: 37600),
      dataSources: const {
        'prevoyance.avoirLppTotal': ProfileDataSource.estimated,
      },
    );

    await tester.pumpWidget(_pumpable(profile));
    await tester.pumpAndSettle();

    expect(find.text('2e pilier : rente ou capital'), findsOneWidget);
    expect(find.text('Champs requis manquants'), findsOneWidget);
    expect(find.text('Preuve absente'), findsOneWidget);
    expect(find.textContaining("37'600"), findsNothing);
    expect(find.text('À la retraite, il te manquera'), findsNothing);
  });

  testWidgets('material profile leads with dossier facts before projection',
      (tester) async {
    tester.view.physicalSize = const Size(368, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final profile = _defensibleJulienProfile();

    await tester.pumpWidget(_pumpable(profile));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile_dossier_facts_summary')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey('profile_dossier_provenance_summary'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey('profile_dossier_correction_action'))
          .hitTestable(),
      findsOneWidget,
    );

    final factsHeader = find.text('Ce que tu as');
    final projectionHeader = find.text('À la retraite, il te manquera');

    expect(factsHeader, findsOneWidget);
    expect(projectionHeader, findsOneWidget);
    expect(
      tester.getTopLeft(factsHeader).dy,
      lessThan(tester.getTopLeft(projectionHeader).dy),
    );
    expect(projectionHeader.hitTestable(), findsNothing);
  });

  testWidgets('dossier correction sheet covers income housing LAMal and debts',
      (tester) async {
    final profile = _defensibleJulienProfile();

    await tester.pumpWidget(_pumpable(profile));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('profile_dossier_correction_action')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Corriger les faits du dossier'), findsOneWidget);
    expect(find.text('Revenus bruts mensuels (CHF)'), findsOneWidget);
    expect(find.text('Loyer mensuel (CHF)'), findsOneWidget);
    expect(find.text('Prime LAMal mensuelle (CHF)'), findsOneWidget);

    await tester.drag(
      find.text('Prime LAMal mensuelle (CHF)'),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hypothèque (CHF)'), findsOneWidget);
    expect(find.text('Crédit consommation (CHF)'), findsOneWidget);
  });

  testWidgets('sync row uses account data state instead of raw cloud bool',
      (tester) async {
    final profile = _defensibleJulienProfile();

    await tester.pumpWidget(
      _pumpable(
        profile,
        authProvider: _FakeAuthProvider(MintAccountDataState.cloudSyncOn),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Synchronisation cloud (multi-appareils)'), findsOneWidget);
    expect(find.text('Activée'), findsOneWidget);
  });
}
