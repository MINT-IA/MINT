import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/screens/home_screen.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('displays header with plan d\'actions', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Wait for loading
      await tester.pumpAndSettle();

      // Check header is displayed
      expect(find.text('🎯 Vos 3 priorités'), findsOneWidget);
    });

    testWidgets('displays recommendation cards', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that recommendation titles are displayed
      expect(find.text('Commencer à investir tôt'), findsOneWidget);
      expect(find.text('Le coût caché du leasing'), findsOneWidget);
      expect(find.text('Optimiser votre 3e pilier'), findsOneWidget);
    });

    testWidgets('displays simulators section', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check simulators section
      expect(find.text('Simulateurs'), findsOneWidget);
      expect(find.text('Intérêts composés'), findsOneWidget);
      expect(find.text('Anti-Leasing'), findsOneWidget);
      expect(find.text('3a Optimizer'), findsOneWidget);
    });
  });
}
