import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';

CoachProfile _profileWithLpp() {
  return CoachProfile(
    firstName: 'Marc',
    birthYear: 1980,
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
}

Widget _wrapWithProvider(CoachProfileProvider provider) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: RenteVsCapitalScreen(),
    ),
  );
}

Widget _wrapWithRouterProvider(
  CoachProfileProvider provider,
  GoRouter router,
) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
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
  );
}

List<Map<String, Object?>> _trajectory({
  required double cashflow,
  required double netPatrimony,
  required double tax,
}) {
  return List<Map<String, Object?>>.generate(31, (index) {
    return <String, Object?>{
      'year': 65 + index,
      'net_patrimony': netPatrimony - index * 5000,
      'annual_cashflow': cashflow,
      'cumulative_tax_delta': tax + index * 600,
    };
  });
}

Map<String, Object?> _backendResultWithoutReceipt() {
  return <String, Object?>{
    'options': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'full_rente',
        'label': 'Rente',
        'trajectory': _trajectory(
          cashflow: 30000,
          netPatrimony: 400000,
          tax: 1200,
        ),
        'terminal_value': 300000,
        'cumulative_tax_impact': 19000,
      },
      <String, Object?>{
        'id': 'full_capital',
        'label': 'Capital',
        'trajectory': _trajectory(
          cashflow: 22000,
          netPatrimony: 500000,
          tax: 14000,
        ),
        'terminal_value': 350000,
        'cumulative_tax_impact': 14000,
      },
      <String, Object?>{
        'id': 'mixed',
        'label': 'Mixte',
        'trajectory': _trajectory(
          cashflow: 25000,
          netPatrimony: 450000,
          tax: 9000,
        ),
        'terminal_value': 330000,
        'cumulative_tax_impact': 15000,
      },
    ],
    'breakeven_year': 12,
    'premierEclairage': 'Backend result without receipt must be gated.',
    'display_summary': 'Backend summary',
    'hypotheses': <String>['Backend assumptions without receipt'],
    'disclaimer': 'Outil éducatif — ne constitue pas un conseil financier.',
    'sources': <String>[
      'LPP art. 14 (taux de conversion)',
      'LIFD art. 22 (imposition des rentes)',
      'LIFD art. 38 (impot sur retrait en capital)',
    ],
    'confidence_score': 72,
    'sensitivity': <String, Object?>{},
  };
}

Map<String, Object?> _backendResultWithCompleteReceipt() {
  return <String, Object?>{
    ..._backendResultWithoutReceipt(),
    'calculation_receipt': <String, Object?>{
      'calculation_origin': 'backend_rvc',
      'calculation_version': 'backend-rvc-v1',
      'constants_version_hash': regulatoryConstantsVersionHash,
      'unit': 'CHF/mois; CHF; percent; years',
      'assumptions': const <String, Object?>{
        'safe_withdrawal_rate': 0.04,
        'expected_return': 0.03,
        'inflation': 0.02,
        'horizon_years': 30,
        'canton': 'VD',
        'conversion_rate_obligatory': 0.068,
        'conversion_rate_surobligatory': 0.05,
      },
      'sources': const <String>[
        'LPP art. 14 (taux de conversion)',
        'LIFD art. 22 (imposition des rentes)',
        'LIFD art. 38 (impot sur retrait en capital)',
      ],
      'readiness': 'ready',
      'confidence_score': 72,
      'missing_required_inputs': const <String>[],
    },
  };
}

Map<String, Object?> _backendResultWithInvalidReceipt() {
  final result = Map<String, Object?>.from(_backendResultWithCompleteReceipt());
  final receipt =
      Map<String, Object?>.from(result['calculation_receipt'] as Map);
  receipt['constants_version_hash'] = 'stale-hash';
  result['calculation_receipt'] = receipt;
  return result;
}

Future<void> _pumpRvc(
  WidgetTester tester, {
  CoachProfileProvider? provider,
}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final effectiveProvider =
      provider ?? (CoachProfileProvider()..updateProfile(_profileWithLpp()));
  await tester.pumpWidget(_wrapWithProvider(effectiveProvider));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetMemoryCacheForTest();
    try {
      await AuthService.saveToken('test-token', 'user-1', 'user@example.ch');
    } catch (_) {
      // saveToken populates the in-memory cache before trying the keychain.
    }
  });

  tearDown(() {
    ApiService.setHttpClientForTesting(null);
    AuthService.resetMemoryCacheForTest();
  });

  testWidgets('backend result with complete receipt renders backend figures',
      (tester) async {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          expect(
              request.url.path, endsWith('/api/v1/arbitrage/rente-vs-capital'));
          return http.Response(
            jsonEncode(_backendResultWithCompleteReceipt()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await _pumpRvc(tester);

    expect(
      find.byKey(const Key('rente_vs_capital_calculation_receipt')),
      findsOneWidget,
    );
    expect(find.textContaining('backend_rvc'), findsOneWidget);
    expect(
      find.textContaining(regulatoryConstantsVersionHash.substring(0, 12)),
      findsOneWidget,
    );
    expect(find.textContaining('CHF/mois'), findsOneWidget);
    expect(find.textContaining('Ce que ton capital rapporte'), findsOneWidget);
    expect(find.textContaining('LPP art. 14'), findsOneWidget);
    expect(find.textContaining('LIFD art. 22'), findsOneWidget);
    expect(find.textContaining('Confiance'), findsWidgets);
    expect(find.textContaining('Aucun champ requis manquant'), findsOneWidget);

    final context = tester.element(find.byType(RenteVsCapitalScreen));
    expect(find.text(S.of(context)!.renteVsCapitalPerMonth), findsWidgets);
  });

  testWidgets(
      'backend result without receipt shows receipt-required state, not CHF/mois output',
      (tester) async {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          expect(
              request.url.path, endsWith('/api/v1/arbitrage/rente-vs-capital'));
          return http.Response(
            jsonEncode(_backendResultWithoutReceipt()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await _pumpRvc(tester);

    final receiptRequired =
        find.byKey(const Key('rente_vs_capital_receipt_required'));
    for (var i = 0; i < 6 && receiptRequired.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pump();
    }

    final context = tester.element(find.byType(RenteVsCapitalScreen));
    expect(receiptRequired, findsOneWidget);
    expect(find.text(S.of(context)!.renteVsCapitalPerMonth), findsNothing);
    expect(
      find.textContaining(S.of(context)!.renteVsCapitalReceiptMissingNone),
      findsNothing,
    );
    expect(
      find.textContaining(S.of(context)!.renteVsCapitalReceiptMissingFallback),
      findsWidgets,
    );
    expect(
      find.text(
        '${S.of(context)!.renteVsCapitalReceiptMissingLabel}: '
        '${S.of(context)!.renteVsCapitalReceiptMissingFallback}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('incomplete backend receipt reports invalid receipt readiness',
      (tester) async {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          expect(
              request.url.path, endsWith('/api/v1/arbitrage/rente-vs-capital'));
          return http.Response(
            jsonEncode(_backendResultWithInvalidReceipt()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await _pumpRvc(tester);

    final receiptRequired =
        find.byKey(const Key('rente_vs_capital_receipt_required'));
    for (var i = 0; i < 6 && receiptRequired.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pump();
    }

    expect(receiptRequired, findsOneWidget);
    expect(find.textContaining('Preuve incomplète'), findsOneWidget);
    expect(find.textContaining('Prête'), findsNothing);
  });

  testWidgets('backend result without receipt does not write back profile data',
      (tester) async {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          expect(
              request.url.path, endsWith('/api/v1/arbitrage/rente-vs-capital'));
          return http.Response(
            jsonEncode(_backendResultWithoutReceipt()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );
    final provider = CoachProfileProvider()..updateProfile(_profileWithLpp());

    await _pumpRvc(tester, provider: provider);
    expect(provider.profile!.prevoyance.projectedRenteLpp, isNull);
    expect(provider.profile!.prevoyance.projectedCapital65, isNull);

    await tester.enterText(find.byType(TextField).at(2), '370000');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RenteVsCapitalScreen));
    expect(find.text(S.of(context)!.profileUpdatedSnackbar), findsNothing);
    final profileAfterInteraction = provider.profile;
    if (profileAfterInteraction != null) {
      expect(profileAfterInteraction.prevoyance.projectedRenteLpp, isNull);
      expect(profileAfterInteraction.prevoyance.projectedCapital65, isNull);
    }
  });

  testWidgets(
      'sequence pop after incomplete receipt records abandoned, not completed',
      (tester) async {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          expect(
              request.url.path, endsWith('/api/v1/arbitrage/rente-vs-capital'));
          return http.Response(
            jsonEncode(_backendResultWithoutReceipt()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final provider = CoachProfileProvider()..updateProfile(_profileWithLpp());
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/rente-vs-capital',
          builder: (context, state) => const RenteVsCapitalScreen(),
        ),
      ],
    );

    await tester.pumpWidget(_wrapWithRouterProvider(provider, router));
    unawaited(router.push('/rente-vs-capital', extra: const {
      'runId': 'run-rvc',
      'stepId': 'step-rvc',
    }));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(2), '370000');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    router.pop();
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final entry = await ScreenCompletionTracker.lastEntry(
      'rente_vs_capital',
      prefs: prefs,
    );

    expect(entry, isNotNull);
    expect(entry!['outcome'], 'abandoned');
    expect(entry['runId'], 'run-rvc');
    expect(entry['stepId'], 'step-rvc');
    expect(entry, isNot(contains('stepOutputs')));
  });

  testWidgets('backend failure fallback is visibly marked as local mobile L1',
      (tester) async {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          expect(
              request.url.path, endsWith('/api/v1/arbitrage/rente-vs-capital'));
          return http.Response('{"detail":"forced failure"}', 500);
        }),
      ),
    );

    await _pumpRvc(tester);

    expect(
      find.byKey(const Key('rente_vs_capital_calculation_receipt')),
      findsOneWidget,
    );
    expect(find.textContaining('mobile_l1_arbitrage_engine'), findsOneWidget);
  });
}
