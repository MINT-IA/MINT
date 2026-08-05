import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

Future<void> _surface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _loadAppFonts() async {
  final supreme = FontLoader('Supreme')
    ..addFont(rootBundle.load('assets/fonts/Supreme-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/Supreme-Medium.otf'))
    ..addFont(rootBundle.load('assets/fonts/Supreme-Bold.otf'));
  final gambarino = FontLoader('Gambarino')
    ..addFont(rootBundle.load('assets/fonts/Gambarino-Regular.otf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([supreme.load(), gambarino.load(), materialIcons.load()]);
}

void main() {
  setUpAll(_loadAppFonts);

  testWidgets('FR first slice golden sequence', (tester) async {
    await _surface(tester, const Size(390, 844));
    await tester.pumpWidget(const MintNextDesignLabApp(locale: Locale('fr')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/fr_today_390.png'),
    );

    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/fr_orientation_390.png'),
    );

    await tester.tap(find.byKey(const ValueKey('action:orientation.continue')));
    await tester.pumpAndSettle();
    // Phase B: orientation.continue now lands on the LPP affiliation question
    // (fact_tax_year screen removed from the journey). Golden the screen that
    // now follows orientation.
    expect(
      find.byKey(const ValueKey('node:fact_lpp_affiliation')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/fr_lpp_affiliation_390.png'),
    );
  });

  testWidgets('DE 320px text scale 2 golden', (tester) async {
    await _surface(tester, const Size(320, 700));
    await tester.pumpWidget(
      const MintNextDesignLabApp(
        locale: Locale('de'),
        textScaler: TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/de_today_320_text2.png'),
    );

    await tester.drag(
      find.byKey(const ValueKey('scroll:today_3a_intent')),
      const Offset(0, -2400),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('scroll:orientation')),
      const Offset(0, -3600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:orientation.continue')));
    await tester.pumpAndSettle();
    // Phase B: 6-screen journey — orientation.continue lands on the LPP
    // affiliation question directly (fact_tax_year screen removed).
    expect(
      find.byKey(const ValueKey('node:fact_lpp_affiliation')),
      findsOneWidget,
    );
  });
}
