import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/money_truth_receipt_api_service.dart';
import 'package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V2-4 — CTA `rvc-ask-coach` de /retraite/rente-vs-capital : scelle la rente
/// mensuelle nette AFFICHÉE en MoneyTruthReceipt et la porte au coach
/// (receiptId + inputsHash + receiptInputs). Le montant du backend mocké est
/// annualCashflow 30000 → renteNetMensuelle 2500.

CoachProfile _profileWithLpp() => CoachProfile(
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

List<Map<String, Object?>> _trajectory(double cashflow) =>
    List<Map<String, Object?>>.generate(
      31,
      (i) => <String, Object?>{
        'year': 65 + i,
        'net_patrimony': 400000 - i * 5000,
        'annual_cashflow': cashflow,
        'cumulative_tax_delta': 1200 + i * 600,
      },
    );

Map<String, Object?> _backendCompleteReceipt() => <String, Object?>{
      'options': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'full_rente',
          'label': 'Rente',
          'trajectory': _trajectory(30000),
          'terminal_value': 300000,
          'cumulative_tax_impact': 19000,
        },
        <String, Object?>{
          'id': 'full_capital',
          'label': 'Capital',
          'trajectory': _trajectory(22000),
          'terminal_value': 350000,
          'cumulative_tax_impact': 14000,
        },
      ],
      'breakeven_year': 12,
      'premierEclairage': 'Ancre chiffrée.',
      'display_summary': 'Résumé.',
      'hypotheses': <String>['Hypothèses.'],
      'disclaimer': 'Outil éducatif — ne constitue pas un conseil financier.',
      'sources': const <String>[
        'LPP art. 14 (taux de conversion)',
        'LIFD art. 22 (imposition des rentes)',
        'LIFD art. 38 (impot sur retrait en capital)',
      ],
      'confidence_score': 72,
      'sensitivity': <String, Object?>{},
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
          'current_age': 46,
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

Finder _bySemanticsId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

GoRouter _router({
  required MoneyTruthReceiptApiService receiptApi,
  required void Function(GoRouterState) onCoach,
  required CoachProfileProvider provider,
}) =>
    GoRouter(
      initialLocation: '/rvc',
      routes: [
        GoRoute(
          path: '/rvc',
          builder: (context, state) =>
              ChangeNotifierProvider<CoachProfileProvider>.value(
            value: provider,
            child: RenteVsCapitalScreen(receiptApi: receiptApi),
          ),
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

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp.router(
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
      // saveToken populates the in-memory cache before touching the keychain.
    }
  });

  tearDown(() {
    ApiService.setHttpClientForTesting(null);
    AuthService.resetMemoryCacheForTest();
  });

  testWidgets(
      'le CTA scelle la rente affichée (2500), POSTe le receipt puis navigue '
      'vers /coach/chat avec le handoff', (tester) async {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode(_backendCompleteReceipt()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );

    Map<String, dynamic>? storedBody;
    final receiptApi =
        MoneyTruthReceiptApiService(baseUrl: 'https://example.test');
    receiptApi.testClient = MockClient((http.Request request) async {
      storedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'status': 'stored'}), 200);
    });

    final provider = CoachProfileProvider()..updateProfile(_profileWithLpp());
    GoRouterState? coachState;
    await _pump(
      tester,
      _router(
        receiptApi: receiptApi,
        onCoach: (s) => coachState = s,
        provider: provider,
      ),
    );

    expect(_bySemanticsId('rvc-ask-coach'), findsOneWidget);

    await tester.ensureVisible(_bySemanticsId('rvc-ask-coach'));
    await tester.pump();
    await tester.tap(_bySemanticsId('rvc-ask-coach'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(storedBody, isNotNull);
    final receipt = storedBody!['receipt'] as Map<String, dynamic>;
    expect(receipt['claimId'], 'rente_vs_capital.rente_mensuelle.v1');
    expect(receipt['base'], 'net');
    // renteNetMensuelle = annualCashflow(30000) / 12 = 2500.
    expect((receipt['value'] as num).toDouble(), closeTo(2500, 1e-6));

    expect(find.text('coach-chat-landed'), findsOneWidget);
    final query = coachState!.uri.queryParameters;
    expect(query['topic'], 'renteVsCapital');
    expect(query['receiptId'], receipt['receiptId']);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(query['inputsHash']!), isTrue);
    final receiptInputs =
        jsonDecode(query['receiptInputs']!) as Map<String, dynamic>;
    expect(receiptInputs.containsKey('capitalLppTotal'), isTrue);
    expect(receiptInputs['inputMode'], anyOf('estimate', 'certificate'));
  });
}
