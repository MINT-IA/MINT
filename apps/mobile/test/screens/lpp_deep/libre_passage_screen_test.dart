import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';

// ────────────────────────────────────────────────────────────
//  LIBRE PASSAGE SCREEN — Widget Tests (LPP Deep)
// ────────────────────────────────────────────────────────────

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

  group('LibrePassageScreen — rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildLibrePassageScreen());
      await tester.pump();
      expect(find.byType(LibrePassageScreen), findsOneWidget);
    });

    testWidgets('shows Scaffold', (tester) async {
      await tester.pumpWidget(buildLibrePassageScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows AppBar with title', (tester) async {
      await tester.pumpWidget(buildLibrePassageScreen());
      await tester.pump();
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      await tester.pumpWidget(buildLibrePassageScreen());
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('uses CustomScrollView for layout', (tester) async {
      await tester.pumpWidget(buildLibrePassageScreen());
      await tester.pump();
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });

  group('LibrePassageScreen — content', () {
    testWidgets('shows slider inputs for avoir and age', (tester) async {
      await tester.pumpWidget(buildLibrePassageScreen());
      await tester.pump();
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows CHF amounts in results', (tester) async {
      await tester.pumpWidget(buildLibrePassageScreen());
      await tester.pump();
      expect(find.textContaining('CHF'), findsWidgets);
    });
  });
}
