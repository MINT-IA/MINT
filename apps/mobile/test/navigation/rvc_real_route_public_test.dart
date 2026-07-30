import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpRootRouter(
  WidgetTester tester, {
  AuthProvider? authProvider,
  CoachProfileProvider? coachProfileProvider,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => authProvider ?? AuthProvider(),
        ),
        ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => coachProfileProvider ?? CoachProfileProvider(),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: testOnlyRootRouter,
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
  await _pumpFrames(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets('real root router lets pre-account users reach RvC',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // AX pilote (ADR 2026-07-30) : l'id RACINE 'rente_vs_capital_screen' est
    // retire (conteneur Semantics racine = effondrement de l'arbre AX sur la
    // route poussee iOS 26.2). On prouve l'arrivee sur RvC via l'ancre INTERNE
    // 'rvc_route_state' (proof anchor, en tete d'arbre). De meme, l'absence du
    // coach se prouve via son id interne 'coach_input_field'.
    E2eRuntimeFlags.proofAnchorsOverride = true;
    addTearDown(E2eRuntimeFlags.resetForTest);

    await _pumpRootRouter(tester);
    testOnlyRootRouter.go('/retraite/rente-vs-capital');
    await _pumpFrames(tester);

    expect(find.byKey(const Key('rvc_route_state')), findsOneWidget);
    expect(find.byKey(const Key('coach_input_field')), findsNothing);
    expect(find.text('Page introuvable'), findsNothing);
    expect(find.text('Encore en chantier pour ton profil'), findsNothing);
  });
}
