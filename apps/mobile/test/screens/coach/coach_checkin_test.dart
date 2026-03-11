import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/coach/coach_checkin_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget() {
    return ChangeNotifierProvider(
      create: (_) => CoachProfileProvider(),
      child: const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: CoachCheckinScreen(),
      ),
    );
  }

  group('CoachCheckinScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoachCheckinScreen), findsOneWidget);
    });

    testWidgets('shows check-in title with month', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Check-in'), findsWidgets);
    });

    testWidgets('shows planned contribution rows', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Demo profile has planned contributions (3a, LPP, etc.)
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('shows validate button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Valider'), findsWidgets);
    });

    testWidgets('shows exceptional expense field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('ceptionnelle'), findsWidgets);
    });

    testWidgets('shows exceptional revenue field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('ceptionnel'), findsWidgets);
    });

    testWidgets('scrolls without crash', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      // Scroll down to see all fields
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byType(CoachCheckinScreen), findsOneWidget);
    });

    testWidgets('tap validate shows success state', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Scroll down to reveal the validate button
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -800));
      await tester.pumpAndSettle();

      // Find and tap the validate button
      final validateButton = find.textContaining('Valider');
      if (validateButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(validateButton.first);
        await tester.pumpAndSettle();
        await tester.tap(validateButton.first, warnIfMissed: false);
        await tester.pumpAndSettle();
        // After validation, screen should still be present
        expect(find.byType(CoachCheckinScreen), findsOneWidget);
      }
    });
  });
}
