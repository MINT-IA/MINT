import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';

/// Unit tests pour Pillar 3a Deep Service — Sprint S16 (3a Deep)
///
/// Teste les 3 simulateurs pedagogiques :
///   A. StaggeredWithdrawalSimulator — retrait echelonne multi-comptes
///   B. RealReturnCalculator         — rendement reel avec taux marginal
///   C. ProviderComparator           — comparateur fintech/banque/assurance
///
/// Base legale : OPP3, LIFD art. 38 (imposition retrait capital prevoyance)
void main() {
  // ════════════════════════════════════════════════════════════
  //  A. RETRAIT ECHELONNE
  // ════════════════════════════════════════════════════════════

  group('StaggeredWithdrawalSimulator - impot progressif', () {
    test('impot retrait en bloc suit le modèle v2 (IFD art. 38 + ESTV)', () {
      // 200'000 CHF a ZH — v2 -2i2 : IFD art. 38 (1/5 du barème revenu)
      // + interpolation cantonale sur points ESTV officiels.
      // Sanity backend : estimate_capital_withdrawal_tax(200000, 'ZH')
      // = 11140.69.
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 1,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      expect(result.impotBloc, closeTo(11140.69, 1.0)); // v2 -2i2
    });

    test('retrait echelonne reduit l impot total', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 300000,
        nbComptes: 3,
        canton: 'VD',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.economie, greaterThan(0));
      expect(result.impotEchelonne, lessThan(result.impotBloc));
    });

    test('plan annuel a le bon nombre d entrees', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 250000,
        nbComptes: 5,
        canton: 'GE',
        revenuImposable: 90000,
        ageRetraitDebut: 60,
        ageRetraitFin: 65,
      );
      expect(result.planAnnuel.length, 5);
      // Chaque retrait = 50000
      for (final plan in result.planAnnuel) {
        expect(plan.montantRetire, closeTo(50000, 0.01));
      }
    });

    test('nombre de comptes limites par duree echelonnement', () {
      // ageDebut=64, ageFin=65 => duree = 2 ans
      // 5 comptes demandes mais max 2 possibles
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 5,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      expect(result.planAnnuel.length, 2);
    });

    test('nombre optimal de comptes maximise l economie', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 400000,
        nbComptes: 5,
        canton: 'VD',
        revenuImposable: 100000,
        ageRetraitDebut: 60,
        ageRetraitFin: 65,
      );
      expect(result.nbComptesOptimal, greaterThanOrEqualTo(1));
      expect(result.nbComptesOptimal, lessThanOrEqualTo(5));
    });

    test('canton ZG a un taux plus bas que VD', () {
      final resultZG = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 1,
        canton: 'ZG',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      final resultVD = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 1,
        canton: 'VD',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      expect(resultZG.impotBloc, lessThan(resultVD.impotBloc));
    });

    test('avoir zero retourne impot zero', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 0,
        nbComptes: 3,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.impotBloc, 0);
      expect(result.impotEchelonne, 0);
    });

    test('disclaimer present et mentionne specialiste', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 3,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.disclaimer, contains('specialiste'));
      expect(result.disclaimer, contains('OPP3'));
    });

    test('premier éclairage positif quand economie > 0', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 300000,
        nbComptes: 3,
        canton: 'VD',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.premierEclairage.isPositive, true);
      expect(result.premierEclairage.montant, greaterThan(0));
    });
  });

  group('StaggeredWithdrawalSimulator - brackets progressifs detailles', () {
    test('montant > 500k interpole entre les points ESTV 500k et 750k (v2)',
        () {
      // 600000 CHF a ZH — v2 -2i2 : IFD art. 38 + interpolation cantonale
      // entre les points ESTV 500k et 750k.
      // Sanity backend : estimate_capital_withdrawal_tax(600000, 'ZH')
      // = 48921.29.
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 600000,
        nbComptes: 1,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 65,
        ageRetraitFin: 65,
      );
      expect(result.impotBloc, closeTo(48921.29, 1.0)); // v2 -2i2
    });

    test('montant net = montant retire - impot estime', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 150000,
        nbComptes: 3,
        canton: 'BE',
        revenuImposable: 70000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      for (final plan in result.planAnnuel) {
        expect(
          plan.montantNet,
          closeTo(plan.montantRetire - plan.impotEstime, 0.01),
        );
      }
    });

    test('liste des cantons contient 26 cantons', () {
      expect(StaggeredWithdrawalSimulator.cantons.length, 26);
      expect(StaggeredWithdrawalSimulator.cantons, contains('ZH'));
      expect(StaggeredWithdrawalSimulator.cantons, contains('GE'));
      expect(StaggeredWithdrawalSimulator.cantons, contains('TI'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B. RENDEMENT REEL
  // ════════════════════════════════════════════════════════════

  // ── fvAnnuityDue (primitif mathematique) ──────────────────────

  group('fvAnnuityDue', () {
    test('n=0 retourne 0', () {
      expect(RealReturnCalculator.fvAnnuityDue(7258, 0.03, 0), 0.0);
    });

    test('n=1 retourne pmt × (1+r)', () {
      final fv = RealReturnCalculator.fvAnnuityDue(7258, 0.03, 1);
      expect(fv, closeTo(7258 * 1.03, 0.01));
    });

    test('r=0 retourne pmt × n (limite exacte)', () {
      final fv = RealReturnCalculator.fvAnnuityDue(7258, 0.0, 16);
      expect(fv, closeTo(7258 * 16, 0.01));
    });

    test('r quasi-nul utilise la limite pmt × n × (1+r)', () {
      final fv = RealReturnCalculator.fvAnnuityDue(7258, 1e-12, 16);
      expect(fv, closeTo(7258 * 16, 0.01));
    });

    test('cas general : 7258 CHF, 3%, 16 ans', () {
      // fvOrd = 7258 × ((1.03^16 - 1) / 0.03) = 7258 × 20.15688
      // fvDue = fvOrd × 1.03
      final fv = RealReturnCalculator.fvAnnuityDue(7258, 0.03, 16);
      // 1.03^16 ≈ 1.604706 → factor ≈ 20.15687 → fvOrd ≈ 146298.9 → fvDue ≈ 150687.9
      expect(fv, closeTo(150688, 1));
    });

    test('rendement negatif fonctionne', () {
      final fv = RealReturnCalculator.fvAnnuityDue(1000, -0.02, 10);
      // Capital shrinks each year but payments continue
      expect(fv, greaterThan(0));
      expect(fv, lessThan(1000 * 10)); // less than zero-return case
    });
  });

  // ── solveRateBisection (solveur numerique) ──────────────────

  group('solveRateBisection', () {
    test('marginalTaxRate=0 (pmtNet=pmtGross) → rNet ≈ rGross', () {
      const pmt = 7258.0;
      const r = 0.03;
      const n = 16;
      final fvGross = RealReturnCalculator.fvAnnuityDue(pmt, r, n);
      // pmtNet = pmtGross when marginalTaxRate = 0
      final rNet = RealReturnCalculator.solveRateBisection(pmt, fvGross, n);
      expect(rNet, closeTo(r, 1e-5));
    });

    test('n=1 cas analytique : r = targetFV/pmt - 1', () {
      const pmt = 6532.2;
      const targetFV = 7258 * 1.03; // = 7475.74
      final rNet = RealReturnCalculator.solveRateBisection(pmt, targetFV, 1);
      expect(rNet, closeTo(targetFV / pmt - 1, 1e-10));
    });

    test('n=0 retourne 0', () {
      final rNet = RealReturnCalculator.solveRateBisection(6532.2, 150688, 0);
      expect(rNet, 0.0);
    });

    test('non-regression : 7258 CHF, taux 10%, rGross 3%, n=16', () {
      const pmtGross = 7258.0;
      const marginalTaxRate = 0.10;
      const rGross = 0.03;
      const n = 16;

      final fvGross = RealReturnCalculator.fvAnnuityDue(pmtGross, rGross, n);
      const pmtNet = pmtGross * (1 - marginalTaxRate); // 6532.2
      final rNet = RealReturnCalculator.solveRateBisection(pmtNet, fvGross, n);

      // Verify roundtrip: fvAnnuityDue(pmtNet, rNet, n) ≈ fvGross
      final fvCheck = RealReturnCalculator.fvAnnuityDue(pmtNet, rNet, n);
      expect(fvCheck, closeTo(fvGross, 1e-3));

      // rNet must be > rGross (tax advantage boosts effective return)
      expect(rNet, greaterThan(rGross));
    });

    test('taux marginal eleve (45%) → rNet sensiblement > rGross', () {
      const pmtGross = 7258.0;
      const rGross = 0.04;
      const n = 30;

      final fvGross = RealReturnCalculator.fvAnnuityDue(pmtGross, rGross, n);
      const pmtNet = pmtGross * (1 - 0.45); // 3991.9
      final rNet = RealReturnCalculator.solveRateBisection(pmtNet, fvGross, n);

      // rNet should be much higher when tax advantage is large
      expect(rNet, greaterThan(rGross + 0.02));

      // Verify roundtrip
      final fvCheck = RealReturnCalculator.fvAnnuityDue(pmtNet, rNet, n);
      expect(fvCheck, closeTo(fvGross, 1e-3));
    });
  });

  // ── RealReturnCalculator.calculate() ────────────────────────

  group('RealReturnCalculator', () {
    test('taux marginal 0% => rendement reel ≈ rendement nominal', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.0,
        rendementBrut: 0.03,
        fraisGestion: 0.0,
        dureeAnnees: 16,
      );
      expect(result.rendementReel, closeTo(result.rendementNominal, 1e-4));
    });

    test('duree 0 => capital et versements a 0', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 0,
      );
      expect(result.totalVersements, 0.0);
      expect(result.capitalFinal3a, 0.0);
      expect(result.rendementReel, 0.0);
    });

    test('rendement negatif est supporte (>= -99%)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.20,
        rendementBrut: -0.02,
        fraisGestion: 0.0,
        dureeAnnees: 10,
      );
      expect(result.rendementNominal, lessThan(0));
      expect(result.capitalFinal3a, greaterThan(0));
    });

    test('capital final 3a > total des versements (rendement positif)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.045,
        fraisGestion: 0.0039,
        dureeAnnees: 20,
      );
      expect(result.capitalFinal3a, greaterThan(result.totalVersements));
    });

    test('capital3a = fvAnnuityDue(versement, rGross, n)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 20,
      );
      // rGross = 0.04 - 0.004 = 0.036
      final expected = RealReturnCalculator.fvAnnuityDue(7258, 0.036, 20);
      expect(result.capitalFinal3a, closeTo(expected, 0.01));
    });

    test('rendementNominal = (rendementBrut - fraisGestion) × 100', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.045,
        fraisGestion: 0.005,
        dureeAnnees: 20,
      );
      // rGross = 0.045 - 0.005 = 0.04 → rendementNominal = 4.0%
      expect(result.rendementNominal, closeTo(4.0, 0.01));
    });

    test('rendement reel > rendement nominal (avantage fiscal)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.35,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 25,
      );
      expect(result.rendementReel, greaterThan(result.rendementNominal));
    });

    test('economie fiscale totale = versement * taux marginal * duree', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 10,
      );
      expect(
        result.economieFiscaleTotale,
        closeTo(7258 * 0.30 * 10, 0.01),
      );
    });

    test('capital epargne classique = fvAnnuityDue(versement, 0.005, n)', () {
      // Audit 2026-04-18 P1-5 : rendement épargne hardcoded 1.5% → 0.5%
      // (médiane taux épargne UBS/PostFinance/Raiffeisen 2026, 1.5% était
      // irréaliste post-2023).
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 10000,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 1,
      );
      // n=1 → fvAnnuityDue = pmt × (1+r) = 10000 × 1.005
      expect(
        result.capitalFinalEpargne,
        closeTo(10000 * 1.005, 0.01),
      );
    });

    test('rendementEpargne = 0.5 (taux brut compte épargne CH 2026)', () {
      // Audit P1-5 2026-04-18 : valeur alignée sur médiane Suisse post-2023.
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 10,
      );
      expect(result.rendementEpargne, closeTo(0.5, 0.01));
    });

    test('gain vs epargne positif (3a + fiscal > epargne classique)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 20,
      );
      expect(result.gainVsEpargne, greaterThan(0));
    });

    test('total versements = versement annuel * duree', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 15,
      );
      expect(result.totalVersements, closeTo(7258 * 15, 0.01));
    });

    test('disclaimer mentionne OPP3 et specialiste', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 10,
      );
      expect(result.disclaimer, contains('OPP3'));
      expect(result.disclaimer, contains('spécialiste'));
      expect(result.disclaimer, contains('réduction d’impôt estimée'));
      expect(result.disclaimer, isNot(contains('économie fiscale')));
    });

    test('premier éclairage positif quand gain vs epargne > 0', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 20,
      );
      expect(result.premierEclairage.isPositive, true);
    });

    test('versement plafonne a 36288 (plafond sans LPP)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 50000, // > 36288
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 10,
      );
      expect(result.totalVersements, closeTo(36288 * 10, 0.01));
    });

    test('roundtrip: fvAnnuityDue(pmtNet, rNet, n) ≈ capital3a', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.045,
        fraisGestion: 0.005,
        dureeAnnees: 30,
      );
      // Verify the fundamental identity holds
      const pmtNet = 7258 * (1 - 0.30);
      final rNet = result.rendementReel / 100;
      final fvCheck = RealReturnCalculator.fvAnnuityDue(pmtNet, rNet, 30);
      expect(fvCheck, closeTo(result.capitalFinal3a, 1e-3));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  C. COMPARATEUR PROVIDERS
  // ════════════════════════════════════════════════════════════

  group('ProviderComparator', () {
    test('compare retourne 5 providers', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      expect(result.providers.length, 5);
    });

    test('fintech a un rendement superieur a banque classique', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      final fintech = result.providers.firstWhere(
        (p) => p.provider.nom == 'Fintech B',
      );
      final banque = result.providers.firstWhere(
        (p) => p.provider.type == 'banque',
      );
      expect(fintech.capitalFinal, greaterThan(banque.capitalFinal));
    });

    test('assurance 3a a un warning pour les jeunes (< 35 ans)', () {
      // Calculation path (l == null): the flag is set; the message is null
      // because user-facing copy is resolved via AppLocalizations only.
      final calcOnly = ProviderComparator.compare(
        age: 28,
        versementAnnuel: 7258,
        duree: 30,
        profilRisque: ProfilRisque.equilibre,
      );
      final calcAssurance = calcOnly.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      expect(calcAssurance.hasWarning, true);
      expect(calcAssurance.warningMessage, isNull);

      // Localized path (l provided): the warning message is a non-null
      // localized string — never a hardcoded FR literal.
      final localized = ProviderComparator.compare(
        age: 28,
        versementAnnuel: 7258,
        duree: 30,
        profilRisque: ProfilRisque.equilibre,
        l: SFr(),
      );
      final assurance = localized.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      expect(assurance.hasWarning, true);
      expect(assurance.warningMessage, isNotNull);
      expect(assurance.warningMessage, contains('assurance 3a'));
    });

    test('pas de warning assurance pour les 35+ ans', () {
      final result = ProviderComparator.compare(
        age: 40,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      final assurance = result.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      expect(assurance.hasWarning, false);
    });

    test('difference max > 0 entre meilleur et pire provider', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 25,
        profilRisque: ProfilRisque.dynamique,
      );
      expect(result.differenceMax, greaterThan(0));
    });

    test('profil prudent a un rendement inferieur a dynamique', () {
      final prudent = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.prudent,
      );
      final dynamique = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.dynamique,
      );
      // Finpension capital should be higher in dynamique
      final finpPrudent = prudent.providers.firstWhere(
        (p) => p.provider.nom == 'Fintech B',
      );
      final finpDynamique = dynamique.providers.firstWhere(
        (p) => p.provider.nom == 'Fintech B',
      );
      expect(
        finpDynamique.capitalFinal,
        greaterThan(finpPrudent.capitalFinal),
      );
    });

    test('disclaimer mentionne MINT n est pas intermediaire', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      expect(result.disclaimer, contains('MINT'));
      expect(result.disclaimer, contains('specialiste'));
    });

    test('assurance exposes hasWarning flag instead of hardcoded badge', () {
      // Audit 2026-04-18 P0-6 + doctrine CLAUDE.md §6.4 No-Ranking : on ne
      // désigne pas de "winner" ni d'écrase avec un badge "WARNING" anglais
      // non-i18n. Le warning assurance est exposé via hasWarning +
      // warningMessage — la UI les rend comme un badge contextuel localisé
      // distinct du badge de ranking (qui n'existe plus).
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      final assurance = result.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      expect(assurance.badge, isNull,
          reason: 'No winner designation — No-Ranking doctrine');
      expect(assurance.hasWarning, isTrue,
          reason: 'Assurance provider should still surface a warning flag');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  D. i18n LOCALISATION (device evidence 2026-08-03)
  //  When AppLocalizations is passed, disclaimers must come from the ARB
  //  (accents corrects), not the ASCII calculation-path fallback that the
  //  device surfaced on « Retrait 3a échelonné ».
  // ════════════════════════════════════════════════════════════
  group('i18n localisation', () {
    final S l = SFr();

    test('staggered disclaimer localisé = ARB accentué (pas le fallback ASCII)',
        () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 300000,
        nbComptes: 3,
        canton: 'ZH',
        revenuImposable: 120000,
        ageRetraitDebut: 60,
        ageRetraitFin: 64,
        l: l,
      );
      expect(result.disclaimer, l.pillar3aStaggeredDisclaimer);
      expect(result.disclaimer, contains('à titre indicatif'));
      expect(result.disclaimer, contains('prévoyance'));
      // Regression: the ASCII fallback ("a titre indicatif") must not surface.
      expect(result.disclaimer, isNot(contains('Simulation pedagogique a')));
    });

    test('real return disclaimer localisé = ARB', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.045,
        fraisGestion: 0.005,
        dureeAnnees: 30,
        l: l,
      );
      expect(result.disclaimer, l.pillar3aRealReturnDisclaimer);
      expect(result.disclaimer, contains('pédagogique'));
    });

    test('provider disclaimer + warning localisés = ARB', () {
      final result = ProviderComparator.compare(
        age: 28,
        versementAnnuel: 7258,
        duree: 30,
        profilRisque: ProfilRisque.equilibre,
        l: l,
      );
      expect(result.disclaimer, l.pillar3aProviderDisclaimer);
      final assurance = result.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      // Warning is localized from the ARB (accents corrects), not hardcoded FR.
      expect(assurance.warningMessage, isNotNull);
      expect(assurance.warningMessage, contains('flexibilité réduite'));
      expect(assurance.warningMessage, contains('À 28 ans'));
    });
  });
}
