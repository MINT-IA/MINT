import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/document_scan/avs_guide_screen.dart';

void main() {
  testWidgets('official pension guide distinguishes future calculation from CI',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
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
      home: AvsGuideScreen(),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Obtenir ton calcul AVS officiel'), findsOneWidget);
    expect(find.textContaining('318.282'), findsWidgets);
    expect(find.textContaining('Un extrait CI ne suffit pas'), findsOneWidget);
    expect(find.text('Ouvrir le formulaire officiel'), findsOneWidget);
    expect(
      find.text('J’ai seulement un extrait CI → Le scanner'),
      findsOneWidget,
    );
  });
}
