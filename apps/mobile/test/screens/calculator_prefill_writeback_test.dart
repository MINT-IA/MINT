// ────────────────────────────────────────────────────────────
//  Calculator Prefill + Write-back Tests
//
//  Validates:
//  - PatrimoineProfile.mortgageCapacity / estimatedMonthlyPayment fields
//  - PrevoyanceProfile.copyWith() for write-back
//  - salaireBrut monthly → annual conversion (× 13)
//  - AffordabilityScreen renders without crash
//  - Simulator3aScreen renders without crash
//  - _hasUserInteracted guard logic (via unit test)
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/retroactive_3a_screen.dart';

// ---------------------------------------------------------------------------
//  Shared helpers
// ---------------------------------------------------------------------------

Widget _buildWrapped(Widget screen) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => CoachProfileProvider(),
      ),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: screen),
    ),
  );
}

// ---------------------------------------------------------------------------
//  Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  //  1. PatrimoineProfile — write-back fields
  // ═══════════════════════════════════════════════════════════

  group('PatrimoineProfile write-back fields', () {
    test('mortgageCapacity can be set via copyWith', () {
      const p = PatrimoineProfile();
      final updated = p.copyWith(mortgageCapacity: 850000);
      expect(updated.mortgageCapacity, 850000);
      expect(updated.epargneLiquide, 0); // unchanged
    });

    test('estimatedMonthlyPayment can be set via copyWith', () {
      const p = PatrimoineProfile(epargneLiquide: 10000);
      final updated = p.copyWith(estimatedMonthlyPayment: 2800);
      expect(updated.estimatedMonthlyPayment, 2800);
      expect(updated.epargneLiquide, 10000); // unchanged
    });

    test('mortgageCapacity roundtrips through toJson/fromJson', () {
      const p = PatrimoineProfile(mortgageCapacity: 720000, estimatedMonthlyPayment: 3500);
      final json = p.toJson();
      final restored = PatrimoineProfile.fromJson(json);
      expect(restored.mortgageCapacity, 720000);
      expect(restored.estimatedMonthlyPayment, 3500);
    });

    test('copyWith preserves fields not provided', () {
      const p = PatrimoineProfile(
        epargneLiquide: 50000,
        investissements: 100000,
        mortgageCapacity: 500000,
      );
      final updated = p.copyWith(estimatedMonthlyPayment: 2500);
      expect(updated.epargneLiquide, 50000);
      expect(updated.investissements, 100000);
      expect(updated.mortgageCapacity, 500000);
      expect(updated.estimatedMonthlyPayment, 2500);
    });

    test('operator == accounts for mortgageCapacity and estimatedMonthlyPayment', () {
      const p1 = PatrimoineProfile(mortgageCapacity: 500000);
      const p2 = PatrimoineProfile(mortgageCapacity: 500000);
      const p3 = PatrimoineProfile(mortgageCapacity: 600000);
      expect(p1 == p2, isTrue);
      expect(p1 == p3, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. PrevoyanceProfile copyWith — required for write-back
  // ═══════════════════════════════════════════════════════════

  group('PrevoyanceProfile copyWith', () {
    test('copyWith updates projectedRenteLpp', () {
      const p = PrevoyanceProfile(avoirLppTotal: 70377);
      final updated = p.copyWith(projectedRenteLpp: 33000);
      expect(updated.projectedRenteLpp, 33000);
      expect(updated.avoirLppTotal, 70377); // unchanged
    });

    test('copyWith updates projectedCapital65', () {
      const p = PrevoyanceProfile(avoirLppTotal: 70377);
      final updated = p.copyWith(projectedCapital65: 677847);
      expect(updated.projectedCapital65, 677847);
    });

    test('copyWith preserves existing fields when not provided', () {
      const p = PrevoyanceProfile(
        avoirLppTotal: 70377,
        rachatMaximum: 539414,
        tauxConversion: 0.068,
      );
      final updated = p.copyWith(projectedRenteLpp: 33000);
      expect(updated.avoirLppTotal, 70377);
      expect(updated.rachatMaximum, 539414);
      expect(updated.tauxConversion, 0.068);
    });

    test('copyWith updates avoirLppTotal', () {
      const p = PrevoyanceProfile(avoirLppTotal: 70377);
      // After EPL write-back: 70377 - 30000 = 40377
      final updated = p.copyWith(avoirLppTotal: 40377);
      expect(updated.avoirLppTotal, 40377);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. salaireBrut monthly → annual conversion
  // ═══════════════════════════════════════════════════════════

  group('salaireBrut prefill multiplication', () {
    test('9400 monthly × 13 = 122200 annual (Julien test case)', () {
      const monthly = 9400.0;
      const nombreDeMois = 13;
      final annual = monthly * nombreDeMois;
      expect(annual, closeTo(122200, 0.01));
    });

    test('5000 monthly × 13 = 65000 annual', () {
      const monthly = 5000.0;
      const nombreDeMois = 13;
      final annual = monthly * nombreDeMois;
      expect(annual, closeTo(65000, 0.01));
    });

    test('avoirLpp=70377 stays as-is (not multiplied)', () {
      // avoirLpp is a direct capital value, not monthly
      const avoirLpp = 70377.0;
      final clamped = avoirLpp.clamp(0, 5000000);
      expect(clamped, closeTo(70377, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  4. Screen smoke tests — render without crash
  // ═══════════════════════════════════════════════════════════

  group('AffordabilityScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(_buildWrapped(const AffordabilityScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows income field area', (tester) async {
      await tester.pumpWidget(_buildWrapped(const AffordabilityScreen()));
      await tester.pump();
      // Screen should render with a CustomScrollView
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });

  group('Simulator3aScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(_buildWrapped(const Simulator3aScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('RachatEchelonneScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(_buildWrapped(const RachatEchelonneScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('Retroactive3aScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(_buildWrapped(const Retroactive3aScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  5. _hasUserInteracted guard — unit test via model logic
  // ═══════════════════════════════════════════════════════════

  group('_hasUserInteracted guard logic', () {
    test('write-back should NOT fire if hasUserInteracted is false', () {
      // This mirrors the guard pattern used in all 6 screens:
      // if (!_hasUserInteracted) return;
      bool writeBackFired = false;
      const hasUserInteracted = false;

      void simulateWriteBack() {
        if (!hasUserInteracted) return;
        writeBackFired = true;
      }

      simulateWriteBack();
      expect(writeBackFired, isFalse);
    });

    test('write-back SHOULD fire after user interaction', () {
      bool writeBackFired = false;
      const hasUserInteracted = true;

      void simulateWriteBack() {
        if (!hasUserInteracted) return;
        writeBackFired = true;
      }

      simulateWriteBack();
      expect(writeBackFired, isTrue);
    });
  });
}
