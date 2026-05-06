// Phase 91 Plan 91-01 (VIVANT-04) — widget tests for CoachToneScreen.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/settings/coach_tone_screen.dart';
import 'package:mint_mobile/services/preferences/coach_tone_preference.dart';

void main() {
  Widget pumpScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: CoachToneScreen(),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders 3 tone rows with the existing ARB labels',
      (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    // Reuses tonSoftLabel / tonDirectLabel / tonUnfilteredLabel from
    // app_fr.arb — no new keys per VIVANT-04.
    expect(find.text('Doux'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('Non filtré'), findsOneWidget);
  });

  testWidgets('default selection is calm', (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    // The selected radio sits next to the "Doux" label (calm row).
    final calmRow = find.byKey(
      const ValueKey('coach_tone_row_calm'),
    );
    expect(calmRow, findsOneWidget);
    expect(
      find.descendant(
        of: calmRow,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping Direct persists direct to SharedPreferences',
      (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Direct'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(coachTonePreferenceKey), 'direct');
  });

  testWidgets('tapping Non filtré persists sansFilter', (tester) async {
    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Non filtré'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(coachTonePreferenceKey), 'sansFilter');
  });

  testWidgets('previously-saved selection is highlighted on mount',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      coachTonePreferenceKey: 'sansFilter',
    });

    await tester.pumpWidget(pumpScreen());
    await tester.pumpAndSettle();

    final sansFilterRow = find.byKey(
      const ValueKey('coach_tone_row_sansFilter'),
    );
    expect(
      find.descendant(
        of: sansFilterRow,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
  });
}
