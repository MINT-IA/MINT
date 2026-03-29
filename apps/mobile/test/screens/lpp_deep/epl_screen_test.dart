import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';

// ────────────────────────────────────────────────────────────
//  EPL SCREEN — Widget Tests (LPP Deep: Property Withdrawal)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildEplScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: EplScreen(),
    );
  }

  group('EplScreen — rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildEplScreen());
      await tester.pump();
      expect(find.byType(EplScreen), findsOneWidget);
    });

    testWidgets('shows Scaffold', (tester) async {
      await tester.pumpWidget(buildEplScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows AppBar with EPL title', (tester) async {
      await tester.pumpWidget(buildEplScreen());
      await tester.pump();
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      await tester.pumpWidget(buildEplScreen());
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('uses CustomScrollView', (tester) async {
      await tester.pumpWidget(buildEplScreen());
      await tester.pump();
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('shows slider inputs', (tester) async {
      await tester.pumpWidget(buildEplScreen());
      await tester.pump();
      // EPL screen has sliders for inputs
      expect(find.byType(Slider), findsWidgets);
    });
  });

  group('EplScreen — content', () {
    testWidgets('shows CHF amounts in results', (tester) async {
      await tester.pumpWidget(buildEplScreen());
      await tester.pump();
      // Default values should produce visible CHF amounts
      expect(find.textContaining('CHF'), findsWidgets);
    });
  });
}
