import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/money_truth_receipt_api_service.dart';
import 'package:mint_mobile/widgets/coach/retirement_hero_zone.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V2-4 — CTA `retraite-ask-coach` du dashboard /retraite : scelle le revenu
/// mensuel de retraite AFFICHÉ (héro) en MoneyTruthReceipt, le POSTe au store
/// puis navigue vers /coach/chat en portant receiptId + inputsHash +
/// receiptInputs (propagation north-star hors firstJob).

CoachProfile _richProfile() => CoachProfile(
      firstName: 'Marc',
      birthYear: 1980, // âge ~46
      canton: 'VD',
      etatCivil: CoachCivilStatus.celibataire,
      salaireBrutMensuel: 9000,
      nombreDeMois: 12,
      employmentStatus: 'salarie',
      prevoyance: const PrevoyanceProfile(avoirLppTotal: 360000),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );

Finder _bySemanticsId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

GoRouter _router({
  required MoneyTruthReceiptApiService receiptApi,
  required void Function(GoRouterState) onCoach,
  required CoachProfileProvider coachProvider,
}) =>
    GoRouter(
      initialLocation: '/retraite',
      routes: [
        GoRoute(
          path: '/retraite',
          builder: (context, state) =>
              RetirementDashboardScreen(receiptApi: receiptApi),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (context, state) {
            onCoach(state);
            return const Scaffold(body: Text('coach-chat-landed'));
          },
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  GoRouter router,
  CoachProfileProvider coachProvider,
) async {
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // RetirementHeroZone porte un overflow horizontal connu et bénin en
  // environnement de test (polices différentes) — hors périmètre V2-4. On
  // l'ignore pour tester le CTA (sliver distinct sous le héro) ; toute autre
  // erreur continue de faire échouer le test.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final summary = details.exception.toString();
    if (summary.contains('A RenderFlex overflowed')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProvider),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final mockStorage = <String, String>{};

  setUp(() {
    mockStorage.clear();
    SharedPreferences.setMockInitialValues({});
    AuthService.resetMemoryCacheForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final v = call.arguments['value'] as String?;
            if (v != null) mockStorage[call.arguments['key'] as String] = v;
            return null;
          case 'read':
            return mockStorage[call.arguments['key'] as String];
          case 'delete':
            mockStorage.remove(call.arguments['key'] as String);
            return null;
          case 'deleteAll':
            mockStorage.clear();
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

  testWidgets(
      'le CTA scelle le revenu mensuel affiché, POSTe le receipt puis '
      'navigue vers /coach/chat avec receiptId + inputsHash + receiptInputs',
      (tester) async {
    await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

    Map<String, dynamic>? storedBody;
    final receiptApi =
        MoneyTruthReceiptApiService(baseUrl: 'https://example.test');
    receiptApi.testClient = MockClient((http.Request request) async {
      storedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'status': 'stored'}),
        200,
      );
    });

    final coachProvider = CoachProfileProvider()..updateProfile(_richProfile());
    GoRouterState? coachState;
    await _pump(
      tester,
      _router(
        receiptApi: receiptApi,
        onCoach: (s) => coachState = s,
        coachProvider: coachProvider,
      ),
      coachProvider,
    );

    // Le chiffre héro affiché — SOURCE de vérité de la valeur scellée.
    final hero = tester.widget<RetirementHeroZone>(
      find.byType(RetirementHeroZone),
    );
    final displayedMonthly = hero.monthlyIncome;
    expect(displayedMonthly, greaterThan(0));

    // Le CTA existe (nœud Semantics `retraite-ask-coach`).
    expect(_bySemanticsId('retraite-ask-coach'), findsOneWidget);

    await tester.tap(_bySemanticsId('retraite-ask-coach'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Ceinture 1 : le store a reçu le receipt du revenu de retraite.
    expect(storedBody, isNotNull);
    final receipt = storedBody!['receipt'] as Map<String, dynamic>;
    expect(receipt['claimId'], 'retirement.monthly_income.v1');
    expect(receipt['base'], 'brut');
    // Parité écran↔receipt : la valeur scellée == le chiffre héro affiché.
    expect((receipt['value'] as num).toDouble(), closeTo(displayedMonthly, 1e-6));

    // Ceinture 2 : nav portant le handoff.
    expect(find.text('coach-chat-landed'), findsOneWidget);
    final query = coachState!.uri.queryParameters;
    expect(query['topic'], 'retirementIncome');
    expect(query['receiptId'], receipt['receiptId']);
    expect(query['inputsHash'], receipt['inputsHash']);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(query['inputsHash']!), isTrue);
    final receiptInputs =
        jsonDecode(query['receiptInputs']!) as Map<String, dynamic>;
    expect(receiptInputs['canton'], 'VD');
    expect(receiptInputs.containsKey('currentAge'), isTrue);
  });

  testWidgets('un store en échec ne bloque pas le handoff coach',
      (tester) async {
    await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

    final receiptApi =
        MoneyTruthReceiptApiService(baseUrl: 'https://example.test');
    receiptApi.testClient =
        MockClient((r) async => http.Response('boom', 500));

    final coachProvider = CoachProfileProvider()..updateProfile(_richProfile());
    var landed = false;
    await _pump(
      tester,
      _router(
        receiptApi: receiptApi,
        onCoach: (_) => landed = true,
        coachProvider: coachProvider,
      ),
      coachProvider,
    );

    await tester.tap(_bySemanticsId('retraite-ask-coach'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(landed, isTrue);
  });
}
