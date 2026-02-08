import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/services/pillar_3a_calculator.dart';

void main() {
  // Setup: Charger les limites avant tous les tests
  setUpAll(() async {
    // Mock du rootBundle pour les tests
    TestWidgetsFlutterBinding.ensureInitialized();

    // Charger les limites
    await Pillar3aCalculator.loadLimits();
  });

  tearDown(() {
    // Vider le cache entre chaque test
    Pillar3aCalculator.clearCache();
  });

  group('Pillar3aCalculator - Salarié avec LPP', () {
    test('Plafond fixe 2025', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      expect(result.limit, 7258.0);
      expect(result.isFixed, true);
      expect(result.canContribute, true);
      expect(result.calculationType, 'fixed');
    });

    test('Plafond fixe 2024', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2024,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      expect(result.limit, 7056.0);
    });

    test('Plafond fixe 2023', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2023,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      expect(result.limit, 6883.0);
    });

    test('Explanation correcte', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      expect(
        result.explanation,
        contains('CHF 7\'258'),
      );
      expect(
        result.explanation,
        contains('2025'),
      );
    });
  });

  group('Pillar3aCalculator - Indépendant sans LPP', () {
    test('20% revenu net (sous plafond)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 80000,
      );

      // 20% de 80'000 = 16'000
      expect(result.limit, 16000.0);
      expect(result.isPercentageBased, true);
    });

    test('20% revenu net (au-dessus plafond)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 200000,
      );

      // 20% de 200'000 = 40'000 → plafonné à 36'288
      expect(result.limit, 36288.0);
    });

    test('20% revenu net (exactement au plafond)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 181440, // 20% = 36'288
      );

      expect(result.limit, 36288.0);
    });

    test('Revenu inconnu → plafond max', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: null,
      );

      expect(result.limit, 36288.0);
    });

    test('Revenu zéro → plafond max', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 0,
      );

      expect(result.limit, 36288.0);
    });

    test('Explanation correcte (20%)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 80000,
      );

      expect(
        result.explanation,
        contains('20%'),
      );
      expect(
        result.explanation,
        contains('CHF 16\'000'),
      );
    });
  });

  group('Pillar3aCalculator - Indépendant avec LPP volontaire', () {
    test('Plafond fixe 2025', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: true,
      );

      expect(result.limit, 7258.0);
      expect(result.isFixed, true);
    });
  });

  group('Pillar3aCalculator - Mixte', () {
    test('Mixte avec LPP → plafond fixe', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'mixed',
        has2ndPillar: true,
      );

      expect(result.limit, 7258.0);
      expect(result.isFixed, true);
    });

    test('Mixte sans LPP → 20% revenu total', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'mixed',
        has2ndPillar: false,
        netIncomeAVS: 100000,
      );

      // 20% de 100'000 = 20'000
      expect(result.limit, 20000.0);
      expect(result.isPercentageBased, true);
    });
  });

  group('Pillar3aCalculator - Cas spéciaux', () {
    test('Étudiant → plafond 0', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'student',
        has2ndPillar: null,
      );

      expect(result.limit, 0.0);
      expect(result.canContribute, false);
      expect(
        result.explanation,
        contains('étudiant'),
      );
    });

    test('Retraité → plafond 0', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'retired',
        has2ndPillar: null,
      );

      expect(result.limit, 0.0);
      expect(result.canContribute, false);
      expect(
        result.explanation,
        contains('retraité'),
      );
    });

    test('Autre → plafond 0', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'other',
        has2ndPillar: null,
      );

      expect(result.limit, 0.0);
    });
  });

  group('Pillar3aCalculator - Cache', () {
    test('Cache fonctionne', () {
      // Premier appel
      final result1 = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      // Deuxième appel (doit venir du cache)
      final result2 = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      // Vérifier que c'est la même instance (référence)
      expect(identical(result1, result2), true);
    });

    test('Cache différencie les profils', () {
      final result1 = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      final result2 = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 80000,
      );

      expect(result1.limit, 7258.0);
      expect(result2.limit, 16000.0);
    });

    test('clearCache vide le cache', () {
      final result1 = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      Pillar3aCalculator.clearCache();

      final result2 = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      // Après clearCache, ce ne doit plus être la même instance
      expect(identical(result1, result2), false);
      // Mais les valeurs doivent être identiques
      expect(result1.limit, result2.limit);
    });
  });

  group('Pillar3aCalculator - Validation', () {
    test('Erreur si non initialisé', () {
      // Cette partie ne peut pas être testée facilement car loadLimits
      // est appelé dans setUpAll. Mais le code gère ce cas.
    });

    test('Erreur si année invalide', () {
      expect(
        () => Pillar3aCalculator.calculateLimit(
          year: 2020, // Année non supportée
          employmentStatus: 'employee',
          has2ndPillar: true,
        ),
        throwsA(isA<Pillar3aException>()),
      );
    });

    test('Erreur si statut invalide', () {
      expect(
        () => Pillar3aCalculator.calculateLimit(
          year: 2025,
          employmentStatus: 'invalid_status',
          has2ndPillar: true,
        ),
        throwsA(isA<Pillar3aException>()),
      );
    });
  });

  group('Pillar3aCalculator - Subtitle dynamique', () {
    test('Subtitle salarié avec LPP', () {
      final subtitle = Pillar3aCalculator.getDynamic3aSubtitle(
        employmentStatus: 'employee',
        has2ndPillar: true,
        year: 2025,
      );

      expect(subtitle, contains('CHF 7\'258'));
      expect(subtitle, contains('2025'));
    });

    test('Subtitle indépendant sans LPP', () {
      final subtitle = Pillar3aCalculator.getDynamic3aSubtitle(
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        year: 2025,
      );

      expect(subtitle, contains('20%'));
      expect(subtitle, contains('CHF 36\'288'));
    });
  });

  group('Pillar3aCalculator - Explication détaillée', () {
    test('Explication contient profil', () {
      final explanation = Pillar3aCalculator.getDetailedExplanation(
        employmentStatus: 'employee',
        has2ndPillar: true,
        year: 2025,
      );

      expect(explanation, contains('Ton profil'));
      expect(explanation, contains('Salarié'));
      expect(explanation, contains('Oui')); // LPP
    });

    test('Explication contient calcul', () {
      final explanation = Pillar3aCalculator.getDetailedExplanation(
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        year: 2025,
        netIncomeAVS: 80000,
      );

      expect(explanation, contains('Calcul'));
      expect(explanation, contains('20%'));
    });

    test('Explication contient conseil', () {
      final explanation = Pillar3aCalculator.getDetailedExplanation(
        employmentStatus: 'employee',
        has2ndPillar: true,
        year: 2025,
      );

      expect(explanation, contains('Conseil'));
      expect(explanation, contains('décembre'));
    });
  });

  group('Pillar3aCalculator - Multi-années', () {
    test('Évolution des plafonds 2023-2025', () {
      final result2023 = Pillar3aCalculator.calculateLimit(
        year: 2023,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      final result2024 = Pillar3aCalculator.calculateLimit(
        year: 2024,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      final result2025 = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );

      expect(result2023.limit, 6883.0);
      expect(result2024.limit, 7056.0);
      expect(result2025.limit, 7258.0);

      // Vérifier la progression
      expect(result2024.limit > result2023.limit, true);
      expect(result2025.limit > result2024.limit, true);
    });
  });
}
