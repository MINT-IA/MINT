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
      expect(find.text('Vos Recommandations'), findsOneWidget);
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
      expect(find.text('Le pouvoir du temps'), findsOneWidget);
      expect(find.text('Optimisation Fiscale'), findsOneWidget);
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

      // Scroll down to make simulators section visible
      await tester.scrollUntilVisible(
        find.text('Simulateurs de Voyage'),
        500.0,
      );
      await tester.pumpAndSettle();

      // Check simulators section
      expect(find.text('Simulateurs de Voyage'), findsOneWidget);
      expect(find.text('Retraite 3a'), findsOneWidget);
      expect(find.text('Croissance'), findsOneWidget);
      expect(find.text('Leasing'), findsOneWidget);
    });
  });
}
