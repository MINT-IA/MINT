// Lego 7 beat entry_points — l'entrée du vertical 3a attesté est VISIBLE
// depuis Aujourd'hui et Ma situation quand le flag est ON, et n'existe
// jamais quand il est OFF. Leçon préversion 2026-08-12 : un jumeau sans
// point d'entrée visible n'existe pas pour l'utilisateur.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/screens/mon_argent/mon_argent_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

class _SeededProfileProvider extends CoachProfileProvider {
  _SeededProfileProvider(this._seed);
  final CoachProfile _seed;
  @override
  CoachProfile? get profile => _seed;
}

class _FakeTimeline extends TimelineProvider {
  @override
  bool get isLoading => false;
  @override
  bool get isEmpty => true;
  @override
  bool get hasNodes => false;
  @override
  bool get hasMore => false;
  @override
  List<TimelineMonth> get months => const [];
  @override
  CleoLoopPosition get loopPosition => CleoLoopPosition.insight;
  @override
  List<TensionCard> get cards => const [];
  @override
  Future<void> refresh() async {}
}

CoachProfile _profile() {
  final now = DateTime.now();
  return CoachProfile(
    birthYear: now.year - 30,
    canton: 'VD',
    salaireBrutMensuel: 7000,
    employmentStatus: 'salarie',
    userProvidedFields: const {'age'},
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(now.year + 35),
      label: 'test',
    ),
  );
}

Finder _entry() => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == 'action:vertical_3a.entry',
    );

Widget _aujourdhui() => MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => _SeededProfileProvider(_profile())),
        ChangeNotifierProvider<TimelineProvider>(create: (_) => _FakeTimeline()),
        ChangeNotifierProvider<FinancialPlanProvider>(
            create: (_) => FinancialPlanProvider()),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('fr')],
        home: AujourdhuiScreen(),
      ),
    );

Widget _monArgent(CoachProfileProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('fr')],
        home: MonArgentScreen(initialSection: 'today'),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecureWizardStore.resetSealFallbackForTest();
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
  });

  tearDown(() {
    FeatureFlags.enableMintNextVertical3a = false;
  });

  testWidgets(
      'the vertical entry point is visible from aujourd\'hui and ma '
      'situation when the flag is on', (tester) async {
    FeatureFlags.enableMintNextVertical3a = true;

    await tester.pumpWidget(_aujourdhui());
    await tester.pump(const Duration(milliseconds: 300));
    expect(_entry(), findsOneWidget,
        reason: "l'entrée vit hors de la section plan — visible même sans "
            'plan (leçon façade : une section gatée sur currentPlan la '
            'cachait)');

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await tester.pumpWidget(_monArgent(provider));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_entry(), findsOneWidget);
    expect(find.text('Ton 3a'), findsOneWidget);
  });

  testWidgets(
      'the entry stays visible on populated paths and its tap opens the '
      'vertical route', (tester) async {
    FeatureFlags.enableMintNextVertical3a = true;

    // Ma situation avec un fait présent (chemin peuplé, pas le early-return).
    final withFact = CoachProfileProvider();
    await withFact.loadFromWizard();
    await withFact.saveLppAffiliationFact(MintNextLppAffiliationFact(
      affiliated: true,
      assertedAt: DateTime.utc(2026, 8, 12),
      source: 'user_declaration',
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    final router = GoRouter(
      initialLocation: '/ma-situation',
      routes: [
        GoRoute(
          path: '/ma-situation',
          builder: (_, __) => const MonArgentScreen(initialSection: 'today'),
        ),
        GoRoute(
          path: '/mint-next/vertical-3a',
          builder: (_, __) => const Scaffold(
              body: SizedBox(key: ValueKey('vertical_stub'))),
        ),
      ],
    );
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
        ChangeNotifierProvider<CoachProfileProvider>.value(value: withFact),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
      ],
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr')],
        routerConfig: router,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_entry(), findsOneWidget,
        reason: 'le chemin peuplé garde son entrée');

    await tester.ensureVisible(find.text('Ton 3a'));
    await tester.tap(find.text('Ton 3a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vertical_stub')), findsOneWidget,
        reason: 'le tap ouvre la route du vertical');
  });

  testWidgets('the entry point never renders when the flag is off',
      (tester) async {
    FeatureFlags.enableMintNextVertical3a = false;

    await tester.pumpWidget(_aujourdhui());
    await tester.pump(const Duration(milliseconds: 300));
    expect(_entry(), findsNothing);

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await tester.pumpWidget(_monArgent(provider));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_entry(), findsNothing);
  });
}
