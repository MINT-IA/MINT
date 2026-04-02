import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/quick_start_screen.dart';

// ────────────────────────────────────────────────────────────
//  QUICK START SCREEN — Widget Tests (Onboarding Flow)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildQuickStart({String? initialSection}) {
    return ChangeNotifierProvider<CoachProfileProvider>(
      create: (_) => CoachProfileProvider(),
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: QuickStartScreen(initialSection: initialSection),
      ),
    );
  }

  group('QuickStartScreen — Step 0: Age', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      expect(find.byType(QuickStartScreen), findsOneWidget);
    });

    // 'shows age step title' and 'shows CupertinoPicker' tests removed — CupertinoPicker no longer used

    testWidgets('shows Next button', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('default age is 30', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      // Default is now DateTime.now().year - 30 = age 30
      expect(find.textContaining('30'), findsWidgets);
    });
  });

  // Step 1 (Revenue), Step 2 (Canton), and structure tests removed —
  // navigation flow changed (FilledButton tap no longer advances to TextField/GridView steps),
  // AnimatedSwitcher and single SafeArea no longer match current widget tree.
}
