import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Family
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/succession_simulator_screen.dart';

// Patrimoine
import 'package:mint_mobile/screens/housing_sale_screen.dart';
import 'package:mint_mobile/screens/donation_screen.dart';

// Professional
import 'package:mint_mobile/screens/unemployment_screen.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/screens/retirement_screen.dart';

// Mobility
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/screens/fiscal_comparator_screen.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';

void main() {
  // =========================================================================
  // FAMILY SUITE (Famille)
  // =========================================================================

  group('Family screens', () {
    testWidgets('MariageScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MariageScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('NaissanceScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NaissanceScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ConcubinageScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConcubinageScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('DivorceSimulatorScreen renders without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DivorceSimulatorScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('SuccessionSimulatorScreen renders without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SuccessionSimulatorScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // =========================================================================
  // PATRIMOINE SUITE
  // =========================================================================

  group('Patrimoine screens', () {
    testWidgets('HousingSaleScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HousingSaleScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('DonationScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DonationScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // =========================================================================
  // PROFESSIONAL SUITE
  // =========================================================================

  group('Professional screens', () {
    testWidgets('UnemploymentScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnemploymentScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('FirstJobScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FirstJobScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('RetirementScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RetirementScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // =========================================================================
  // MOBILITY SUITE
  // =========================================================================

  group('Mobility screens', () {
    testWidgets('ExpatScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ExpatScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('FiscalComparatorScreen renders without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FiscalComparatorScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('FrontalierScreen renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FrontalierScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
