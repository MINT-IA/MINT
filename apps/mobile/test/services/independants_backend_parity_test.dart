import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/independants_service.dart';

/// PARITÉ ÉCRAN ↔ COACH (fixture anti-dérive) — cluster 12D V2-1 Indépendants.
///
/// L'écran mobile calcule EN LOCAL (offline, L1) le split dividende/salaire et
/// les cotisations AVS indépendant. Le coach utilise l'étalon BACKEND :
///   - services/backend/app/services/independants/dividende_vs_salaire_service.py
///     (simuler_dividende_vs_salaire / _calculer_charge_split)
///   - services/backend/app/services/independants/avs_cotisations_service.py
///     (calculer_cotisation_avs)
///
/// Les deux DOIVENT rendre le même chiffre pour le même input, sinon un même
/// utilisateur voit une valeur à l'écran et une autre au coach (violation
/// « un seul étalon »). Aucun test ne l'enforçait — ces goldens figent la
/// parité. Toute divergence future (mobile OU backend) casse ce test.
///
/// Valeurs attendues dérivées À LA MAIN des formules backend (lues au SHA de la
/// PR), pas re-générées par le mobile — c'est le point d'un fixture de parité.
void main() {
  group('Parité mobile ↔ backend — dividende vs salaire', () {
    // Backend _calculer_charge_split(benefice, part, taux) :
    //   charges_sociales = salaire * CHARGES_SOCIALES_TOTALES (0.125)
    //   impot_salaire    = salaire * taux
    //   dividende_imposable = dividende * TAUX_IMPOSITION_DIVIDENDE_FEDERAL (0.50)
    //   impot_dividende  = dividende_imposable * taux
    // Mobile _computeSalaryCharge / _computeDividendCharge : formule identique.

    test('charge 100% salaire == backend charge_tout_salaire (200k, 30%)', () {
      // Backend : 200000 * (0.30 + 0.125) = 85'000.
      final r = IndependantsService.calculateDividendeVsSalaire(200000, 100, 0.30);
      expect(r.chargeToutSalaire, closeTo(85000, 0.01));
      expect(r.chargeSalaire, closeTo(85000, 0.01));
    });

    test('charge 100% dividende == backend (200k, 30%)', () {
      // Backend charge_tout_dividende : 200000 * 0.50 * 0.30 = 30'000.
      final r = IndependantsService.calculateDividendeVsSalaire(200000, 0, 0.30);
      expect(r.chargeDividende, closeTo(30000, 0.01));
    });

    test('economie == backend economies (200k, part 60%, 30%)', () {
      // Backend : charge_tout_salaire (85'000) - best_charge (all-dividend,
      // 30'000) = 55'000. Charge linéaire en part -> optimum à un bord (0%),
      // donc le pas 10% (mobile) et le pas 1% (backend) trouvent le même min.
      final r = IndependantsService.calculateDividendeVsSalaire(200000, 60, 0.30);
      expect(r.economie, closeTo(55000, 0.01));
    });

    test('alerte requalification bicritère == backend (part<60% OU salaire<60k)',
        () {
      // Backend alerte_requalification = part < 0.60 OU salaire_propose < 60'000.
      // 80'000 * 0.65 = 52'000 < 60'000 -> True (part >= 60% ne sauve pas).
      final r = IndependantsService.calculateDividendeVsSalaire(80000, 65, 0.30);
      expect(r.requalificationRisk, isTrue);
    });
  });

  group('Parité mobile ↔ backend — AVS cotisations indépendant', () {
    // Backend calculer_cotisation_avs(revenu) : barème AVS_BAREME_INDEPENDANT
    // (identique au mobile _avsBareme), plancher fixe 530 sous 10'100.

    test('15\'000 -> 805.65 (bracket 5.371%, Mémento 2.02)', () {
      // Backend : 15000 * 0.05371 = 805.65 (> 530 minimum).
      final r = IndependantsService.calculateAvsCotisations(15000);
      expect(r.cotisationAnnuelle, closeTo(805.65, 0.01));
    });

    test('70\'000 -> 7\'000 (taux plein indépendant 10.0%, PAS 10.6%)', () {
      final r = IndependantsService.calculateAvsCotisations(70000);
      expect(r.cotisationAnnuelle, closeTo(7000, 0.01));
    });

    test('5\'000 -> 530 (plancher fixe LAVS art. 8 al. 2)', () {
      final r = IndependantsService.calculateAvsCotisations(5000);
      expect(r.cotisationAnnuelle, closeTo(530, 0.01));
    });

    test('60\'500 -> taux plein (borne du barème)', () {
      // Backend : 60'500 entre dans (60_500, inf, 0.10) -> 6'050.
      final r = IndependantsService.calculateAvsCotisations(60500);
      expect(r.cotisationAnnuelle, closeTo(6050, 0.01));
    });
  });
}
