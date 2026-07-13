import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
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

      await $.pumpWidgetAndSettle(MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: profileProvider,
          ),
          ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
          ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
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
          home: RetirementDashboardScreen(),
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
    },
  );
}
