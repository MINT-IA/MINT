import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
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

    await _pumpRootRouter(tester);
    testOnlyRootRouter.go('/retraite/rente-vs-capital');
    await _pumpFrames(tester);

    expect(find.byKey(const Key('rente_vs_capital_screen')), findsOneWidget);
    expect(find.byKey(const Key('coach_chat_screen')), findsNothing);
    expect(find.text('Page introuvable'), findsNothing);
    expect(find.text('Encore en chantier pour ton profil'), findsNothing);
  });
}
