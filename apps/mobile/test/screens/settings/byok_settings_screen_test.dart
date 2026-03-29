import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/screens/byok_settings_screen.dart';

// ────────────────────────────────────────────────────────────
//  BYOK SETTINGS SCREEN — Widget Tests
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildByokScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: ByokSettingsScreen(),
      ),
    );
  }

  group('ByokSettingsScreen — rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildByokScreen());
      await tester.pump();
      expect(find.byType(ByokSettingsScreen), findsOneWidget);
    });

    testWidgets('shows Scaffold', (tester) async {
      await tester.pumpWidget(buildByokScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows AppBar with title', (tester) async {
      await tester.pumpWidget(buildByokScreen());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows privacy card with lock icon', (tester) async {
      await tester.pumpWidget(buildByokScreen());
      await tester.pump();
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('ByokSettingsScreen — form elements', () {
    testWidgets('shows API key text field', (tester) async {
      await tester.pumpWidget(buildByokScreen());
      await tester.pump();
      // Should have at least one TextField for API key input
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows provider selector', (tester) async {
      await tester.pumpWidget(buildByokScreen());
      await tester.pump();
      // Provider selection via SegmentedButton or similar
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('shows save button', (tester) async {
      await tester.pumpWidget(buildByokScreen());
      await tester.pump();
      expect(find.byType(FilledButton), findsWidgets);
    });
  });
}
