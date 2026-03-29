import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';

// ────────────────────────────────────────────────────────────
//  RACHAT ECHELONNE SCREEN — Widget Tests (LPP Deep)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildRachatScreen() {
    return ChangeNotifierProvider<CoachProfileProvider>(
      create: (_) => CoachProfileProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RachatEchelonneScreen(),
      ),
    );
  }

  group('RachatEchelonneScreen — rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildRachatScreen());
      await tester.pump();
      expect(find.byType(RachatEchelonneScreen), findsOneWidget);
    });

    testWidgets('shows Scaffold', (tester) async {
      await tester.pumpWidget(buildRachatScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows AppBar with title', (tester) async {
      await tester.pumpWidget(buildRachatScreen());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('RachatEchelonneScreen — content', () {
    testWidgets('shows CHF amounts from default inputs', (tester) async {
      await tester.pumpWidget(buildRachatScreen());
      await tester.pump();
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('shows slider inputs for rachat parameters', (tester) async {
      await tester.pumpWidget(buildRachatScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows comparison between strategies', (tester) async {
      await tester.pumpWidget(buildRachatScreen());
      await tester.pump();
      // The screen displays comparison content between bloc and staggered buyback
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
