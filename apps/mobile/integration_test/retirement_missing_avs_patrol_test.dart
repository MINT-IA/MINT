import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/document_scan/avs_guide_screen.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'retirement dashboard keeps capital but hides complete totals without AVS',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      SharedPreferences.setMockInitialValues({});
      final profileProvider = CoachProfileProvider()
        ..updateProfile(CoachProfile(
          firstName: 'Patrol',
          birthYear: 1985,
          canton: 'VD',
          salaireBrutMensuel: 8000,
          prevoyance: const PrevoyanceProfile(
            avoirLppTotal: 120000,
            totalEpargne3a: 20000,
          ),
          patrimoine: const PatrimoineProfile(
            epargneLiquide: 15000,
            investissements: 50000,
          ),
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2050),
            label: 'Retraite',
          ),
        ));

      final router = GoRouter(
        initialLocation: '/retraite',
        routes: [
          GoRoute(
            path: '/retraite',
            builder: (_, __) => const RetirementDashboardScreen(),
          ),
          GoRoute(
            path: '/scan/avs-guide',
            builder: (_, __) => const AvsGuideScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await $.pumpWidgetAndSettle(MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: profileProvider,
          ),
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
      ));

      await $(#retirement_missing_avs_state).waitUntilVisible();
      await $(#retirement_capital_amount).waitUntilVisible();
      await $(#retirement_avs_document_cta).waitUntilVisible();
      expect(find.byKey(const Key('retirement_complete_income')), findsNothing);
      expect(
        find.byKey(const Key('retirement_replacement_rate')),
        findsNothing,
      );

      await $(#retirement_avs_document_cta).scrollTo().tap();
      await $.pumpAndSettle();
      await $(find.textContaining('318.282')).waitUntilVisible();
      await $(#avs_official_form_cta).scrollTo();
      await $(#avs_official_form_cta).waitUntilVisible();
    },
  );

  patrolTest(
    'financial report keeps AVS, LPP, and 3a pending without fake totals',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 4)),
    ($) async {
      final router = GoRouter(
        initialLocation: '/rapport',
        routes: [
          GoRoute(
            path: '/rapport',
            builder: (_, __) => const FinancialReportScreenV2(
              wizardAnswers: <String, dynamic>{
                'q_firstname': 'Patrol',
                'q_birth_year': 1985,
                'q_canton': 'VD',
                'q_civil_status': 'single',
                'q_children': '0',
                'q_employment_status': 'employee',
                'q_net_income_period_chf': 8000.0,
                'q_lpp_current_capital': 120000.0,
                'q_lpp_buyback_available': 200000.0,
                'q_3a_annual_contribution': 7258.0,
              },
            ),
          ),
          GoRoute(
            path: '/scan/avs-guide',
            builder: (_, __) => const AvsGuideScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await $.pumpWidgetAndSettle(MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
      ));

      await $(#financial_report_avs_pending).scrollTo();
      await $(#financial_report_avs_pending).waitUntilVisible();
      await $(#financial_report_lpp_pending).scrollTo();
      await $(#financial_report_lpp_pending).waitUntilVisible();
      await $(#financial_report_3a_pending).scrollTo();
      await $(#financial_report_3a_pending).waitUntilVisible();
      expect(
        find.byKey(const Key('financial_report_lpp_estimate')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('financial_report_3a_estimate')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('financial_report_avs_amount')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('financial_report_retirement_total')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('financial_report_replacement_rate')),
        findsNothing,
      );
    },
  );
}
