// Basic smoke test: verifies that core widgets compile and render.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('LandingScreen renders without crash',
      (WidgetTester tester) async {
    // Wider viewport to avoid trust bar overflow
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: LandingScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LandingScreen), findsOneWidget);
    // landingV2CtaSober = "Parle à Mint"
    expect(find.text('Parle \u00e0 Mint'), findsOneWidget);
    // MINT wordmark remains in header.
    expect(find.text('MINT'), findsOneWidget);
  });
}
