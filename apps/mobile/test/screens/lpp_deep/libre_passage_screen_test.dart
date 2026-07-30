import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildLibrePassageScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: LibrePassageScreen(),
    );
  }

  testWidgets('LibrePassageScreen renders without crashing', (tester) async {
    await tester.pumpWidget(buildLibrePassageScreen());
    await tester.pump();
    expect(find.byType(LibrePassageScreen), findsOneWidget);
  });

  testWidgets(
      'libre passage transfer options are localized via ARB keys (no hardcoded strings)',
      (tester) async {
    // Tall viewport so the whole CustomScrollView lays its slivers out and the
    // LppRescueWidget (deep in the list) is mounted for `find.text`.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLibrePassageScreen());
    await tester.pumpAndSettle();

    final l = S.of(tester.element(find.byType(LibrePassageScreen)))!;

    // Labels render inside the widget's « Option N : <label> » heading, so
    // match by substring. Descriptions render verbatim.
    expect(find.textContaining(l.librePassageOptionCompteLabel), findsOneWidget);
    expect(find.textContaining(l.librePassageOptionPoliceLabel), findsOneWidget);
    expect(find.textContaining(l.librePassageOptionFondsLabel), findsOneWidget);
    expect(find.text(l.librePassageOptionCompteDescription), findsOneWidget);
  });

  testWidgets(
      'compte libre passage legalRef is LFLP art. 4 al. 2 — not the erroneous art. 3',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLibrePassageScreen());
    await tester.pumpAndSettle();

    final l = S.of(tester.element(find.byType(LibrePassageScreen)))!;

    // The ARB key carries the corrected article (LFLP art. 4 al. 2, not art. 3).
    expect(
        l.librePassageOptionCompteLegalRef, 'LFLP art. 4 al. 2 — délai 6 mois');
    // And it renders on screen.
    expect(find.text(l.librePassageOptionCompteLegalRef), findsOneWidget);
    // The exact erroneous legalRef « art. 3 — délai 6 mois » must be gone.
    // (The widget disclaimer still legitimately cites the range LFLP art. 3-4,
    // so we forbid the precise old string, not every « art. 3 ».)
    expect(find.textContaining('art. 3 — délai'), findsNothing);
  });
}
