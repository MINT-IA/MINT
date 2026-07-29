import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/services/financial_report_service.dart';

void main() {
  group('AVS Logic Tests', () {
    test('UserProfile avsReductionFactor calculation', () {
      // 44 years = 1.0
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: 44,
        ).avsReductionFactor,
        1.0,
      );

      // 40 years = 40/44
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: 40,
        ).avsReductionFactor,
        40 / 44,
      );

      // 22 years = 0.5
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: 22,
        ).avsReductionFactor,
        0.5,
      );

      // Null years = 1.0 (default)
      expect(
        const UserProfile(
          birthYear: 1980,
          canton: 'VD',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 5000,
          contributionYears: null,
        ).avsReductionFactor,
        1.0,
      );
    });

    test('FinancialReportService._estimateAvsRent with gaps', () {
      final service = FinancialReportService();

      // The report uses AvsCalculator.computeMonthlyRente which takes into
      // account income-based rente (RAMD) and future contribution years.

      final answersSingleGap = {
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'single',
        'q_employment_status': 'employee',
        'q_net_income_period_chf': 5000,
        'q_avs_lacunes_status': 'yes',
        'q_avs_contribution_years': 40,
        'q_current_lpp_capital': 100000,
      };

      final report = service.generateReport(answersSingleGap);
      // grossAnnualSalary = NetIncomeBreakdown.estimateBrutFromNet(60000)
      //   uses Newton-Raphson iteration (not the old / 0.87 linear approx)
      //   → ~67548 CHF with current social charges constants
      // renteFromRAMD(~67382) via table officielle OFAS 318.117.011 :
      //   67382 est entre 66528 (2197) et 68040 (2218)
      //   ratio ≈ (67382-66528)/1512 = 0.565 → ~2208.9 CHF
      // With anneesContribuees=40 + futureYears=19 = 44 total => gapFactor=1.0
      // So rente = ~2208.9

      expect(
          report.retirementProjection?.monthlyAvsRent, closeTo(2208.9, 1.5));
    });

    test('Married, spouse income UNKNOWN -> borne prudente, pas de clone', () {
      // Beads MINT_nosync-pd4 (Codex review PR #976) : le rapport SUBSTITUAIT
      // le salaire de l'utilisateur au conjoint sans revenu renseigné —
      // fabrication de données qui gonflait la rente couple. Honnête :
      // années de cotisation conjoint connues + revenu inconnu -> borne
      // PRUDENTE (rente minimale x gapFactor), jamais le salaire cloné.
      final service = FinancialReportService();

      final answersMarriedGaps = {
        'q_birth_year': 1980,
        'q_canton': 'ZH',
        'q_civil_status': 'married',
        'q_employment_status': 'employee',
        // Revenu modeste : le cap couple (150% de 2520 = 3780) ne masque
        // pas la substitution — l'ancien code clonait le revenu et donnait
        // 2 x userRente.
        'q_net_income_period_chf': 4000,
        'q_avs_lacunes_status': 'yes',
        'q_avs_contribution_years': 40,
        'q_spouse_avs_contribution_years': 42,
        'q_current_lpp_capital': 150000,
      };

      final report = service.generateReport(answersMarriedGaps);
      final total = report.retirementProjection!.monthlyAvsRent;

      // userRente (brut ~52k via Newton-Raphson) est < max ; conjoint =
      // rente minimale 1260 x gapFactor 1.0 (42+19 capped 44).
      // Substitution clonée -> total ≈ 2 x userRente (~4000+, cappé 3780).
      // Borne prudente -> total = userRente + 1260 < 2 x userRente.
      final userAlone = service.generateReport({
        ...answersMarriedGaps,
        'q_civil_status': 'single',
        'q_spouse_avs_contribution_years': null,
      }).retirementProjection!.monthlyAvsRent;

      expect(total, closeTo(userAlone + 1260.0, 5.0),
          reason: 'conjoint sans revenu renseigné = borne minimale légale, '
              'jamais le salaire de l\'utilisateur cloné');
      expect(total, lessThan(userAlone * 2 - 100),
          reason: 'la substitution clonée donnerait ~2 x userRente');

      // La limite est DITE : prompt d'enrichissement vers le revenu conjoint.
      expect(
        report.enrichmentPrompts.any((p) =>
            p.toLowerCase().contains('conjoint')),
        isTrue,
        reason: 'estimation basse silencieuse = aussi malhonnête que la '
            'fabrication — la donnée manquante doit être demandée',
      );
    });

    test('Married sans AUCUNE donnée conjoint -> rien estimé (0) + prompt dédié',
        () {
      // Review Codex PR #980 : sans années de cotisation, computeMonthlyRente
      // suppose une carrière complète — la borne 1'260 surestimait un
      // conjoint arrivé tardivement. Aucune donnée -> rien d'estimé.
      final service = FinancialReportService();
      final answers = {
        'q_birth_year': 1980,
        'q_canton': 'ZH',
        'q_civil_status': 'married',
        'q_employment_status': 'employee',
        'q_net_income_period_chf': 4000,
        'q_avs_contribution_years': 40,
        'q_current_lpp_capital': 150000,
      };
      final report = service.generateReport(answers);
      final userAlone = service
          .generateReport({...answers, 'q_civil_status': 'single'})
          .retirementProjection!
          .monthlyAvsRent;

      expect(report.retirementProjection!.monthlyAvsRent,
          closeTo(userAlone, 1.0),
          reason: 'aucune donnée conjoint = aucune rente conjoint inventée');
      expect(
        report.enrichmentPrompts
            .any((p) => p.contains('années de cotisation')),
        isTrue,
        reason: 'le prompt dédié doit demander revenu ET années',
      );
    });

    test('Married avec revenu conjoint renseigné : inchangé (données réelles)',
        () {
      // Revenus DIFFÉRENTS et modestes (4000 vs 1500) : discriminant contre
      // une réintroduction du clonage (review PR #980 — deux revenus égaux,
      // ou des totaux saturés par le cap couple LAVS 35, ne distinguaient
      // pas substitution et donnée réelle). Sous le cap, le total doit
      // refléter strictement le revenu conjoint RÉEL : au-dessus de la
      // borne minimale, en dessous du plafond couple.
      final base = {
        'q_birth_year': 1980,
        'q_canton': 'ZH',
        'q_civil_status': 'married',
        'q_employment_status': 'employee',
        'q_net_income_period_chf': 4000,
        'q_avs_lacunes_status': 'yes',
        'q_avs_contribution_years': 40,
        'q_spouse_avs_contribution_years': 42,
        'q_current_lpp_capital': 150000,
      };
      final total = FinancialReportService()
          .generateReport({...base, 'q_partner_net_income_chf': 1500})
          .retirementProjection!
          .monthlyAvsRent;
      final withMinBound = FinancialReportService()
          .generateReport(base)
          .retirementProjection!
          .monthlyAvsRent;
      expect(total, greaterThan(withMinBound),
          reason: 'un revenu réel 1500 net vaut plus que la borne minimale');
      expect(total, lessThan(3780.0),
          reason: 'total sous le cap couple : la donnée réelle est visible, '
              'pas saturée');
    });
  });
}
