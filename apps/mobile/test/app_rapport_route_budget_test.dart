import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Future<void> _pumpFrames(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSecureStorage = <String, String>{};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _secureStorageChannel,
      (call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) {
              mockSecureStorage[key] = value;
            }
            return null;
          case 'read':
            return key == null ? null : mockSecureStorage[key];
          case 'delete':
            if (key != null) mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('/rapport loads persisted budget answers without state.extra',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_net_income_period_chf': null,
      'q_pay_frequency': 'yearly',
      'q_housing_cost_period_chf': 2200.0,
      'q_debt_payments_period_chf': 0.0,
      'q_tax_provision_monthly_chf': 458.0,
      'q_lamal_premium_monthly_chf': 420.0,
      'q_other_fixed_costs_monthly_chf': 0.0,
      'q_emergency_fund': 'yes_3months',
      'q_employment_status': 'employee',
    });
    await ReportPersistenceService.setCompleted(true);

    final router = GoRouter(
      initialLocation: '/rapport',
      routes: [
        GoRoute(
          path: '/rapport',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            if (extra.isNotEmpty) {
              return FinancialReportScreenV2(wizardAnswers: extra);
            }
            return FutureBuilder<Map<String, dynamic>>(
              future: ReportPersistenceService.loadAnswers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return FinancialReportScreenV2(
                  wizardAnswers: snapshot.data ?? {},
                );
              },
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
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
    await tester.pump();
    await _pumpFrames(tester, frames: 20);

    expect(find.textContaining('Ton Budget'), findsOneWidget);
    expect(find.textContaining('Charges fixes totales'), findsOneWidget);
    expect(find.textContaining("5'000"), findsWidgets);
    expect(find.textContaining("2'200"), findsWidgets);
    expect(find.textContaining('458'), findsWidgets);
    expect(find.textContaining('420'), findsWidgets);
    expect(find.textContaining("3'078"), findsWidgets);
    expect(find.textContaining("1'922"), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
