import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
    ],
    child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: child),
  );
}

Widget _wrapRouter(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => child),
      GoRoute(
        path: '/onb',
        builder: (_, __) => const Scaffold(body: Text('onboarding')),
      ),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const Scaffold(body: Text('coach')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
    ],
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorage = <String, String>{};

  setUp(() {
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) {
              secureStorage[key] = value;
            }
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return secureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            secureStorage.remove(key);
            return null;
          case 'deleteAll':
            secureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  testWidgets('maps pension alias to LPP block metadata', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'pension')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('maps accented prevoyance alias to LPP block metadata',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'Prévoyance-LPP')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('unknown block shows migration-safe fallback', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'legacy_unknown')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Données'), findsWidgets);
    expect(find.textContaining('n’est plus à jour'), findsOneWidget);
    expect(find.text('Ouvrir le diagnostic'), findsOneWidget);
  });

  testWidgets('empty-stack back returns onboarding, not coach', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _wrapRouter(const DataBlockEnrichmentScreen(blockType: 'situation')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('onboarding'), findsOneWidget);
    expect(find.text('coach'), findsNothing);
  });

  testWidgets('situation block persists canonical wizard keys', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _wrapRouter(const DataBlockEnrichmentScreen(blockType: 'situation')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('situationBirthYearField')),
      '1988',
    );
    await tester.enterText(
      find.byKey(const ValueKey('situationCantonField')),
      'VD',
    );
    await tester.enterText(
      find.byKey(const ValueKey('situationNetIncomeField')),
      '7200',
    );
    await tester.enterText(
      find.byKey(const ValueKey('situationCashField')),
      '25000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('situationDebtPaymentField')),
      '350',
    );
    await tester
        .ensureVisible(find.byKey(const ValueKey('situationSaveButton')));
    await tester.tap(find.byKey(const ValueKey('situationSaveButton')));
    await tester.pumpAndSettle();

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_birth_year'], 1988);
    expect(answers['q_canton'], 'VD');
    expect(answers['q_net_income_period_chf'], 7200.0);
    expect(answers['q_pay_frequency'], 'monthly');
    expect(answers['q_cash_total'], 25000.0);
    expect(answers['q_has_consumer_debt'], 'yes');
    expect(answers['q_debt_payments_period_chf'], 350.0);
    expect(find.text('onboarding'), findsOneWidget);
    expect(find.text('coach'), findsNothing);
  });

  testWidgets('situation aliases render the same capture form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _wrapRouter(const DataBlockEnrichmentScreen(blockType: 'age_canton')),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('situationBirthYearField')), findsOneWidget);
    expect(find.byKey(const ValueKey('situationCantonField')), findsOneWidget);
  });
}
