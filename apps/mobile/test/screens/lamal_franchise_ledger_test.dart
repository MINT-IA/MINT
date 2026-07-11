import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/lamal_franchise_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapWithRouter() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const LamalFranchiseScreen(),
      ),
      GoRoute(
        path: '/budget/setup',
        builder: (_, state) => Text(
          'budget-setup:${state.uri.queryParameters['focus'] ?? 'none'}',
          key: const Key('budget_setup_route_probe'),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    routerConfig: router,
  );
}

void _setReliableViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('waits for ledger facts instead of using local defaults',
      (tester) async {
    _setReliableViewport(tester);
    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lamal_ledger_facts')), findsOneWidget);
    expect(find.byKey(const Key('lamal_premium_fact')), findsOneWidget);
    expect(find.byKey(const Key('lamal_medical_fact')), findsOneWidget);
    expect(find.byKey(const Key('lamal_missing_facts_card')), findsOneWidget);
    expect(find.byKey(const Key('lamal_result_section')), findsNothing);
    expect(find.byType(MintAmountField), findsNothing);
    expect(find.text("CHF 350"), findsNothing);
    expect(find.text("CHF 2'000"), findsNothing);
  });

  testWidgets('exposes runtime semantics identifiers for ledger state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      _setReliableViewport(tester);
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('lamal_ledger_facts'), findsOneWidget);
      expect(find.bySemanticsIdentifier('lamal_premium_fact'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('lamal_current_franchise_fact'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('lamal_medical_fact'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('lamal_missing_facts_card'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('lamal_enrich_cta'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('routes missing facts to the budget collector', (tester) async {
    _setReliableViewport(tester);
    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lamal_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('budget-setup:lamal'), findsOneWidget);
  });

  testWidgets('waits for current franchise before comparing LAMal options',
      (tester) async {
    _setReliableViewport(tester);
    await ReportPersistenceService.saveAnswers(const {
      'q_lamal_premium_monthly_chf': 390,
      '_coach_depenses_frais_medicaux': 120,
    });

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lamal_ledger_facts')), findsOneWidget);
    expect(find.byKey(const Key('lamal_premium_fact')), findsOneWidget);
    expect(find.byKey(const Key('lamal_medical_fact')), findsOneWidget);
    expect(find.textContaining('390'), findsOneWidget);
    expect(find.textContaining("1'440"), findsOneWidget);
    expect(find.byKey(const Key('lamal_missing_facts_card')), findsOneWidget);
    expect(find.byKey(const Key('lamal_result_section')), findsNothing);
  });

  testWidgets('computes from canonical LAMal, franchise and medical facts',
      (tester) async {
    _setReliableViewport(tester);
    await ReportPersistenceService.saveAnswers(const {
      'q_lamal_premium_monthly_chf': 390,
      'q_lamal_franchise': '2500',
      '_coach_depenses_frais_medicaux': 120,
    });

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lamal_ledger_facts')), findsOneWidget);
    expect(find.byKey(const Key('lamal_premium_fact')), findsOneWidget);
    expect(
        find.byKey(const Key('lamal_current_franchise_fact')), findsOneWidget);
    expect(find.byKey(const Key('lamal_medical_fact')), findsOneWidget);
    expect(find.textContaining('390'), findsOneWidget);
    expect(find.textContaining("2'500"), findsOneWidget);
    expect(find.textContaining("1'440"), findsOneWidget);
    expect(find.byKey(const Key('lamal_missing_facts_card')), findsNothing);
    expect(find.byKey(const Key('lamal_result_section')), findsOneWidget);
    expect(find.byType(MintAmountField), findsNothing);
  });

  testWidgets(
      'does not unlock comparison from broad insurance expense fallback',
      (tester) async {
    _setReliableViewport(tester);
    await ReportPersistenceService.saveAnswers(const {
      '_coach_depenses_assurance': 410,
      'q_lamal_franchise': '2500',
      '_coach_depenses_frais_medicaux': 120,
    });

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    expect(find.textContaining('410'), findsNothing);
    expect(find.byKey(const Key('lamal_missing_facts_card')), findsOneWidget);
    expect(find.byKey(const Key('lamal_result_section')), findsNothing);
  });
}
