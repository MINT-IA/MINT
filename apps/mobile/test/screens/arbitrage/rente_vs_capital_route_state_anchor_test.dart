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

CoachProfile _profileWithLpp({bool includeDateOfBirth = true}) {
  return CoachProfile(
    firstName: 'Marc',
    birthYear: 1980,
    dateOfBirth: includeDateOfBirth ? DateTime(1980, 7, 15) : null,
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

int _preciseAge(DateTime dateOfBirth) {
  final now = DateTime.now();
  var age = now.year - dateOfBirth.year;
  if (now.month < dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
    age--;
  }
  return age;
}

Widget _wrap(CoachProfileProvider provider) {
  final router = GoRouter(
    initialLocation: '/retraite/rente-vs-capital',
    routes: [
      GoRoute(
        path: '/retraite/rente-vs-capital',
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
    final expectedAge = _preciseAge(DateTime(1980, 7, 15));

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rvc_route_state')), findsOneWidget);
    expect(find.byKey(const Key('rvc_age_state')), findsOneWidget);
    expect(
      find.text('route=/retraite/rente-vs-capital'),
      findsOneWidget,
    );
    expect(find.text('rvc_age=$expectedAge'), findsOneWidget);
    expect(find.text('rvc_age=2026'), findsNothing);
  });

  testWidgets('proof anchor handles birthYear-only profiles without sentinel',
      (tester) async {
    final provider = CoachProfileProvider()
      ..updateProfile(_profileWithLpp(includeDateOfBirth: false));
    final expectedAge = DateTime.now().year - 1980;

    await tester.pumpWidget(_wrap(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rvc_route_state')), findsOneWidget);
    expect(find.byKey(const Key('rvc_age_state')), findsOneWidget);
    expect(find.text('route=/retraite/rente-vs-capital'), findsOneWidget);
    expect(find.text('rvc_age=$expectedAge'), findsOneWidget);
    expect(find.text('rvc_age=2026'), findsNothing);
  });
}
