import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';

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

Widget _wrap(CoachProfileProvider provider) {
  final router = GoRouter(
    initialLocation: '/rente-vs-capital',
    routes: [
      GoRoute(
        path: '/rente-vs-capital',
        builder: (context, state) => const RenteVsCapitalScreen(),
      ),
    ],
  );

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    E2eRuntimeFlags.proofAnchorsOverride = true;
  });

  tearDown(E2eRuntimeFlags.resetForTest);

  testWidgets('proof anchor exposes the current GoRouter RvC location',
      (tester) async {
    final provider = CoachProfileProvider()..updateProfile(_profileWithLpp());

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rvc_route_state')), findsOneWidget);
    expect(find.text('route=/rente-vs-capital'), findsOneWidget);
  });
}
