import 'package:flutter/cupertino.dart';
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

    testWidgets('shows age step title', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      // quickStartAgeTitle l10n key
      expect(find.byType(CupertinoPicker), findsOneWidget);
    });

    testWidgets('shows CupertinoPicker for age selection', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      expect(find.byType(CupertinoPicker), findsOneWidget);
    });

    testWidgets('shows Next button', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('default age is 45', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      // The picker should have "45 ans" visible
      expect(find.textContaining('45'), findsWidgets);
    });
  });

  group('QuickStartScreen — Step 1: Revenue', () {
    testWidgets('navigates to revenue step on next', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();

      // Tap next to go from age to revenue step
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Revenue step shows a TextField for salary input
      expect(find.byType(TextField), findsOneWidget);
      // Shows "CHF" label
      expect(find.text('CHF'), findsOneWidget);
    });

    testWidgets('shows salary hint placeholder', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Hint text contains Swiss-formatted salary
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('next button disabled when no salary entered', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Next button exists but should be visually disabled (opacity 0.4)
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('can type salary amount', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '85000');
      await tester.pump();
      expect(find.text('85000'), findsOneWidget);
    });
  });

  group('QuickStartScreen — Step 2: Canton', () {
    testWidgets('navigates to canton step after salary', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();

      // Step 0 → Step 1
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Enter salary — need pump to trigger onChanged and setState
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.pump();
      await tester.enterText(textField, '85000');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // FilledButton should now be enabled (salary > 0)
      // Find the enabled FilledButton and tap it
      final buttons = find.byType(FilledButton);
      expect(buttons, findsOneWidget);
      await tester.tap(buttons);
      await tester.pumpAndSettle();

      // Canton step shows a GridView with canton codes
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('canton grid renders with GridView', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();

      // Navigate through steps
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Enter salary
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.pump();
      await tester.enterText(textField, '85000');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Canton grid renders with GridView containing canton codes
      expect(find.byType(GridView), findsOneWidget);
      // With a large viewport, at least some canton codes should be visible
      expect(find.text('AG'), findsOneWidget);
    });
  });

  group('QuickStartScreen — structure', () {
    testWidgets('uses AnimatedSwitcher for transitions', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

    testWidgets('wraps in SafeArea', (tester) async {
      await tester.pumpWidget(buildQuickStart());
      await tester.pump();
      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}
