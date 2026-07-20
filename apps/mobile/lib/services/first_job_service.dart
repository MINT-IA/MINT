import 'package:mint_mobile/services/financial_core/first_job_salary_financial_facts.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;

enum SalaryDeductionKind { avsAiApg, unemploymentInsurance }

class SalaryDeductionItem {
  const SalaryDeductionItem({
    required this.kind,
    required this.montant,
    required this.pourcentage,
    required this.color,
  });

  final SalaryDeductionKind kind;
  final double montant;
  final double pourcentage;
  final String color;
}

/// One presentation model for the First Job screen.
///
/// A gross salary, age and canton do not establish the employee's actual LPP
/// deduction. Consequently this model never fabricates an exact LPP or exact
/// net. The age-credit figure is retained only as a clearly named statutory
/// illustration and is never subtracted from salary.
class FirstJobResult {
  const FirstJobResult({
    required this.brut,
    required this.avsAiApg,
    required this.ac,
    required this.lppEmploye,
    required this.lppAgeCreditIllustration,
    required this.totalKnownDeductionsIllustration,
    required this.netEstime,
    required this.deductionItems,
  });

  final double brut;
  final double avsAiApg;
  final double ac;
  final double? lppEmploye;
  final double? lppAgeCreditIllustration;
  final double totalKnownDeductionsIllustration;
  final double? netEstime;
  final List<SalaryDeductionItem> deductionItems;
}

class FirstJobService {
  FirstJobService._();

  static FirstJobResult analyzeSalary({
    required double salaireBrutMensuel,
    required int age,
    required String canton,
    double tauxActivite = 100,
  }) {
    final facts = FirstJobSalaryFinancialFactsCalculator.calculate(
      grossMonthlySalary: salaireBrutMensuel,
      age: age,
      activityRate: tauxActivite,
    );

    return FirstJobResult(
      brut: salaireBrutMensuel,
      avsAiApg: facts.avsAiApg,
      ac: facts.ac,
      lppEmploye: null,
      lppAgeCreditIllustration: facts.lppAgeCreditIllustration,
      totalKnownDeductionsIllustration: facts.avsAiApg + facts.ac,
      netEstime: null,
      deductionItems: [
        SalaryDeductionItem(
          kind: SalaryDeductionKind.avsAiApg,
          montant: facts.avsAiApg,
          pourcentage: facts.avsAiApgRate * 100,
          color: '#FF453A',
        ),
        SalaryDeductionItem(
          kind: SalaryDeductionKind.unemploymentInsurance,
          montant: facts.ac,
          pourcentage: facts.acDisplayedRate * 100,
          color: '#FF9F0A',
        ),
      ],
    );
  }

  static String formatChf(double value) => chf.formatChfWithPrefix(value);
}
