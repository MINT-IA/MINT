import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';

/// PARITÉ MOBILE ↔ BACKEND (fixture anti-dérive) — cluster 12D V2-2 Invalidité.
///
/// Fin du doublon « C5-disability à 3 têtes » : les 3 écrans invalidité
/// (disability_gap / disability_insurance / disability_self_employed) calculaient
/// EN INLINE, avec des constantes nues divergentes. Ils consomment désormais
/// l'étalon UNIQUE `DisabilityService` (+ `computeDisabilityGap`), miroir de :
///   - services/backend/app/services/disability_gap_service.py
///     (compute_disability_gap / get_employer_coverage_weeks)
///   - services/backend/app/constants/social_insurance.py
///     (get_ai_rente_monthly, AI_BAREME, IJM_COVERAGE_RATE)
///
/// Valeurs attendues DÉRIVÉES À LA MAIN des formules backend (lues au SHA de la
/// PR), pas re-générées par le mobile — c'est le point d'un fixture de parité
/// (même patron que independants_backend_parity_test : on ne lance pas le
/// backend, on fige ses formules à la main).
///
/// PORTÉE : la parité couverte ici est celle des BARÈMES et COEFFICIENTS
/// (échelle employeur 324a, IJM 0.80, barème AI, seuils/plafonds LPP). Le
/// simulateur mobile raisonne sur le salaire BRUT, l'étalon backend sur le
/// revenu NET : les MONTANTS absolus ne sont donc pas directement comparables
/// (assiette différente, cf. en-tête de DisabilityService). Toute divergence de
/// barème/coefficient (mobile OU backend) casse ce test.
void main() {
  group('Parité barème AI — get_ai_rente_monthly (LAI art. 28)', () {
    // Backend AI_BAREME : <40 -> 0 ; 40-49 -> 0.25 ; 50-59 -> 0.50 ;
    // 60-69 -> 0.75 ; >=70 -> 1.00. AI_RENTE_ENTIERE = 2520 (2026).
    test('degré < 40 % => 0 CHF', () {
      expect(DisabilityService.aiRenteMonthly(39), 0.0);
    });
    test('degré 40-49 % => quart de rente (630)', () {
      expect(DisabilityService.aiRenteMonthly(40), 2520.0 * 0.25);
      expect(DisabilityService.aiRenteMonthly(40), 630.0);
    });
    test('degré 50-59 % => demi-rente (1260)', () {
      expect(DisabilityService.aiRenteMonthly(50), 1260.0);
    });
    test('degré 60-69 % => trois-quarts (1890)', () {
      expect(DisabilityService.aiRenteMonthly(60), 2520.0 * 0.75);
      expect(DisabilityService.aiRenteMonthly(60), 1890.0);
    });
    test('degré >= 70 % => rente entière = maximum légal (2520)', () {
      expect(DisabilityService.aiRenteMonthly(70), 2520.0);
      expect(DisabilityService.aiRenteMonthly(100), aiRenteEntiere);
      expect(DisabilityService.aiRenteFullMonthly, 2520.0);
    });
    test('le service et computeDisabilityGap partagent le MÊME barème', () {
      for (final d in [0, 39, 40, 55, 65, 70, 100]) {
        final gap = computeDisabilityGap(
          revenuMensuelNet: 8000,
          statutProfessionnel: EmploymentStatusType.employee,
          canton: 'VD',
          anneesAnciennete: 5,
          hasIjmCollective: true,
          degreInvalidite: d,
        );
        expect(DisabilityService.aiRenteMonthly(d), gap.aiRenteMensuelle,
            reason: 'degré $d');
      }
    });
  });

  group('Parité couverture employeur (CO art. 324a) — DisabilityRates', () {
    // Verdict actuaire (Codex 2026-07-31, A = JUSTE) : la période employeur est
    // à 100 % du salaire (le 80 % étant l'IJM, phase suivante). Backend :
    // phase1_monthly_benefit = revenu_mensuel_net (100 %).
    test('acte employeur = 100 % du salaire (PAS 80 %)', () {
      expect(DisabilityRates.employerCoverage, 1.0);
      final proj = DisabilityService.acts(grossMonthly: 8333, hasIjm: true);
      expect(proj.employerIncome, 8333.0);
    });
    test('parité avec computeDisabilityGap phase 1 (employé)', () {
      final gap = computeDisabilityGap(
        revenuMensuelNet: 8333,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BE',
        anneesAnciennete: 10,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      // Backend : employé => phase1 = 100 % du revenu.
      expect(gap.phase1MonthlyBenefit, 8333.0);
      // BE (échelle bernoise), 10 ans -> 17 semaines.
      expect(gap.phase1DurationWeeks, 17.0);
    });
  });

  group('Parité IJM — IJM_COVERAGE_RATE = 0.80', () {
    test('acte IJM = 80 % si souscrite, 0 sinon', () {
      expect(DisabilityRates.ijmCoverage, 0.80);
      final withIjm = DisabilityService.acts(grossMonthly: 8333, hasIjm: true);
      expect(withIjm.ijmIncome, closeTo(6666.4, 0.01));
      final noIjm = DisabilityService.acts(grossMonthly: 8333, hasIjm: false);
      expect(noIjm.ijmIncome, 0.0);
    });
  });

  group('Rente invalidité LPP — proxy éducatif ~40 % salaire coordonné', () {
    // PROXY (verdict Codex C = FAUX comme calcul exact, gardé comme scénario
    // sourcé). coordinated = clamp(annualGross - 26'460, 3'780, 64'260) ;
    // rente = coordinated * 0.40 / 12.
    test('gross 8333/mois => coordonné plafonné (64 260) => 2142/mois', () {
      // annual 99'996 - 26'460 = 73'536 -> plafonné à 64'260.
      // 64'260 * 0.40 / 12 = 2142.
      expect(DisabilityService.lppInvalidityMonthly(99996), closeTo(2142.0, 0.01));
    });
    test('salaire annuel sous le seuil LPP => 0', () {
      expect(DisabilityService.lppInvalidityMonthly(18000), 0.0);
      expect(lppSeuilEntree, 22680.0);
    });
    test('acte 3 long terme = AI (max) + LPP (proxy)', () {
      final proj = DisabilityService.acts(grossMonthly: 8333, hasIjm: true);
      expect(proj.aiRente, 2520.0);
      expect(proj.lppInvalidity, closeTo(2142.0, 0.01));
      expect(proj.longTermIncome, closeTo(4662.0, 0.01));
    });
  });

  group('Bulletin de couverture — dédup des 2 scorers (gap + insurance)', () {
    test('cadre LPP + IJM + réserve 5 mois => B+ / notes attendues', () {
      final cov = DisabilityService.coverage(
        grossMonthly: 8333,
        savings: 30000,
        hasIjm: true,
      );
      // reserveMonths = 30000 / (8333 * 0.70) = 5.14 mois.
      expect(cov.reserveMonths, closeTo(5.14, 0.01));
      expect(cov.ijmGrade, 'B+');
      expect(cov.aiGrade, 'C');
      expect(cov.lppGrade, 'A-'); // annuel 99'996 >= seuil LPP
      expect(cov.savingsGrade, 'C+'); // 3 <= 5.14 < 6
      // score = 3 (ijm) + 2 (lpp) + 2 (reserve>=3) = 7 -> B+
      expect(cov.overallGrade, 'B+');
      // lifeDrop = 1 - (2520 + 2142) / 8333 = 44.06 %
      expect(cov.lifeDropPercent, closeTo(44.06, 0.1));
    });
    test('assurance privée seule => note IJM intermédiaire B', () {
      final cov = DisabilityService.coverage(
        grossMonthly: 8333,
        savings: 0,
        hasIjm: false,
        hasPrivateInsurance: true,
      );
      expect(cov.ijmGrade, 'B'); // ni IJM collective, mais privée
    });
    test('aucune couverture IJM/privée => F', () {
      final cov = DisabilityService.coverage(
        grossMonthly: 8333,
        savings: 0,
        hasIjm: false,
      );
      expect(cov.ijmGrade, 'F');
      expect(cov.savingsGrade, 'F');
    });
  });

  group('Dépenses éducatives — ratio 70 %', () {
    test('monthlyExpenses = 70 % du revenu', () {
      expect(DisabilityRates.educationalExpenseRatio, 0.70);
      expect(DisabilityService.monthlyExpenses(8000), closeTo(5600.0, 0.01));
    });
  });

  group('Indépendant — risque critique (parité backend)', () {
    // Backend : indépendant sans IJM => risk_level = critical, phase2 = 0.
    test('indépendant sans IJM => aucune couverture avant l\'AI', () {
      final gap = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.selfEmployed,
        canton: 'GE',
        anneesAnciennete: 0,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );
      expect(gap.riskLevel, 'critical');
      expect(gap.phase1MonthlyBenefit, 0.0); // pas de CO 324a
      expect(gap.phase2MonthlyBenefit, 0.0); // pas d'IJM
    });
  });
}
