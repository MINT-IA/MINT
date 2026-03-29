import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/slm_settings_screen.dart';

// ────────────────────────────────────────────────────────────
//  SLM SETTINGS SCREEN — Widget Tests (On-Device AI)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSlmScreen() {
    return ChangeNotifierProvider<SlmProvider>(
      create: (_) => SlmProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: SlmSettingsScreen(),
      ),
    );
  }

  group('SlmSettingsScreen — rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      expect(find.byType(SlmSettingsScreen), findsOneWidget);
    });

    testWidgets('shows Scaffold', (tester) async {
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows AppBar with title', (tester) async {
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows privacy banner with shield icon', (tester) async {
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('shows ListView body', (tester) async {
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('SlmSettingsScreen — content sections', () {
    testWidgets('shows tier selector section', (tester) async {
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      // Tier selector has radio button icons
      expect(find.byIcon(Icons.radio_button_checked), findsWidgets);
    });

    testWidgets('shows engine status section', (tester) async {
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      // Status section shows a status icon
      expect(find.byIcon(Icons.cloud_off), findsWidgets);
    });

    testWidgets('shows how-it-works info section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildSlmScreen());
      await tester.pump();
      // Info section has multiple info rows with icons
      // At minimum, the phone_android icon appears in info section
      expect(find.byIcon(Icons.phone_android), findsWidgets);
    });
  });
}
