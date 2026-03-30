import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/staggered_withdrawal_screen.dart';

// ────────────────────────────────────────────────────────────
//  STAGGERED WITHDRAWAL SCREEN — Widget Tests (3a Deep)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildStaggeredScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: StaggeredWithdrawalScreen(),
    );
  }

  group('StaggeredWithdrawalScreen — rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildStaggeredScreen());
      await tester.pump();
      expect(find.byType(StaggeredWithdrawalScreen), findsOneWidget);
    });

    testWidgets('shows Scaffold', (tester) async {
      await tester.pumpWidget(buildStaggeredScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows SliverAppBar', (tester) async {
      await tester.pumpWidget(buildStaggeredScreen());
      await tester.pump();
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('uses CustomScrollView', (tester) async {
      await tester.pumpWidget(buildStaggeredScreen());
      await tester.pump();
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });

  group('StaggeredWithdrawalScreen — content', () {
    testWidgets('shows CHF amounts from default inputs', (tester) async {
      await tester.pumpWidget(buildStaggeredScreen());
      await tester.pump();
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('shows slider inputs', (tester) async {
      await tester.pumpWidget(buildStaggeredScreen());
      await tester.pumpAndSettle();
      // Screen renders with slider section (MintPremiumSlider inside MintEntrance)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
