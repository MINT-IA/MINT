import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapHome(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
      ChangeNotifierProvider(create: (_) => FinancialPlanProvider()),
      ChangeNotifierProvider(create: (_) => MintStateProvider()),
      ChangeNotifierProvider(create: (_) => TimelineProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LandingScreen exposes the stable home route id', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_wrapHome(const LandingScreen()));
      await tester.pump();

      expect(find.bySemanticsIdentifier('home_route'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('AujourdhuiScreen exposes the stable home route id',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_wrapHome(const AujourdhuiScreen()));
      await tester.pump();

      expect(find.bySemanticsIdentifier('home_route'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
