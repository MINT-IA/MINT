import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/data_quest/revenue_data_quest_planner.dart';
import 'package:mint_mobile/services/financial_core/first_salary_tax_3a_calculator.dart';

enum FirstSalaryFactStatus { known, missing, stale }

class FirstSalaryTax3aSummary {
  final FirstSalaryFactStatus salaryStatus;
  final FirstSalaryFactStatus cantonStatus;
  final FirstSalaryFactStatus ageStatus;
  final FirstSalaryFactStatus pillar3aContributionStatus;
  final List<DataQuestAsk> dataQuestAsks;
  final FirstSalaryTax3aResult? result;

  const FirstSalaryTax3aSummary({
    required this.salaryStatus,
    required this.cantonStatus,
    required this.ageStatus,
    required this.pillar3aContributionStatus,
    required this.dataQuestAsks,
    required this.result,
  });

  bool get canCompute => result != null;

  bool get needsCoreData =>
      salaryStatus == FirstSalaryFactStatus.missing ||
      cantonStatus == FirstSalaryFactStatus.missing ||
      ageStatus == FirstSalaryFactStatus.missing;
}

class FirstSalaryTax3aScreenValues {
  final double grossAnnualSalary;
  final String canton;
  final int age;

  const FirstSalaryTax3aScreenValues({
    required this.grossAnnualSalary,
    required this.canton,
    required this.age,
  });
}

class FirstSalaryTax3aSummaryService {
  FirstSalaryTax3aSummaryService._();

  static FirstSalaryTax3aSummary build({
    required CoachProfile? profile,
    Map<String, dynamic> answers = const {},
    FirstSalaryTax3aScreenValues? screenValues,
    DateTime? now,
  }) {
    final dataQuestAsks = RevenueDataQuestPlanner.plan(
      profile: profile,
      answers: answers,
      now: now,
    );
    final salaryStatus = _statusFor(
      answerKey: 'q_gross_salary_annual',
      profileHasValue: _hasSalary(profile, answers),
      screenHasValue: screenValues?.grossAnnualSalary.isFinite ?? false,
      asks: dataQuestAsks,
    );
    final cantonStatus = _statusFor(
      answerKey: 'q_canton',
      profileHasValue: _hasCanton(profile, answers),
      screenHasValue: (screenValues?.canton.isNotEmpty ?? false),
      asks: dataQuestAsks,
    );
    final ageStatus = _statusFor(
      answerKey: 'q_birth_year',
      profileHasValue: _hasBirthYear(profile, answers),
      screenHasValue: screenValues?.age != null,
      asks: dataQuestAsks,
    );
    final pillar3aContributionStatus =
        _hasPillar3aContribution(profile, answers)
            ? FirstSalaryFactStatus.known
            : FirstSalaryFactStatus.missing;

    final input = _inputFrom(profile, answers, screenValues);
    FirstSalaryTax3aResult? result;
    if (input != null &&
        salaryStatus != FirstSalaryFactStatus.missing &&
        cantonStatus != FirstSalaryFactStatus.missing &&
        ageStatus != FirstSalaryFactStatus.missing) {
      result = FirstSalaryTax3aCalculator.analyze(input);
    }

    return FirstSalaryTax3aSummary(
      salaryStatus: salaryStatus,
      cantonStatus: cantonStatus,
      ageStatus: ageStatus,
      pillar3aContributionStatus: pillar3aContributionStatus,
      dataQuestAsks: dataQuestAsks,
      result: result,
    );
  }

  static FirstSalaryFactStatus _statusFor({
    required String answerKey,
    required bool profileHasValue,
    required bool screenHasValue,
    required List<DataQuestAsk> asks,
  }) {
    for (final ask in asks) {
      if (ask.answerKey == answerKey) {
        if (screenHasValue) return FirstSalaryFactStatus.stale;
        return ask.mode == AskMode.reconfirm
            ? FirstSalaryFactStatus.stale
            : FirstSalaryFactStatus.missing;
      }
    }
    if (screenHasValue && !profileHasValue) return FirstSalaryFactStatus.stale;
    return profileHasValue
        ? FirstSalaryFactStatus.known
        : FirstSalaryFactStatus.missing;
  }

  static FirstSalaryTax3aInput? _inputFrom(
    CoachProfile? profile,
    Map<String, dynamic> answers,
    FirstSalaryTax3aScreenValues? screenValues,
  ) {
    if (profile != null) {
      return FirstSalaryTax3aInput(
        grossAnnualSalary: profile.revenuBrutAnnuel,
        canton: profile.canton,
        age: profile.age,
        hasLpp: _hasLpp(profile, answers),
        canContribute3a: profile.canContribute3a,
        isCrossBorder: profile.isCrossBorder,
        isMarried: profile.isCouple,
        children: profile.nombreEnfants,
        current3aContribution: _current3aContribution(profile, answers),
      );
    }
    if (screenValues == null) return null;
    return FirstSalaryTax3aInput(
      grossAnnualSalary: screenValues.grossAnnualSalary,
      canton: screenValues.canton,
      age: screenValues.age,
      hasLpp: FirstSalaryTax3aCalculator.inferHasLppFor3a(
        grossAnnualSalary: screenValues.grossAnnualSalary,
        age: screenValues.age,
        employmentStatus: 'employed',
        explicitHasPensionFund: null,
        hasCertificateSignals: false,
        lppBalance: null,
      ),
      canContribute3a: true,
      current3aContribution: _parseDouble(
            answers['q_3a_annual_contribution'],
          ) ??
          0,
    );
  }

  static bool _hasSalary(CoachProfile? profile, Map<String, dynamic> answers) {
    return answers.containsKey('q_gross_salary_annual') ||
        answers.containsKey('q_net_income_period_chf') ||
        (profile?.userProvidedFields.contains('salary') ?? false);
  }

  static bool _hasCanton(CoachProfile? profile, Map<String, dynamic> answers) {
    return answers.containsKey('q_canton') ||
        (profile?.userProvidedFields.contains('canton') ?? false);
  }

  static bool _hasBirthYear(
    CoachProfile? profile,
    Map<String, dynamic> answers,
  ) {
    return answers.containsKey('q_birth_year') ||
        answers.containsKey('q_date_of_birth') ||
        (profile?.userProvidedFields.contains('age') ?? false);
  }

  static bool _hasPillar3aContribution(
    CoachProfile? profile,
    Map<String, dynamic> answers,
  ) {
    return answers.containsKey('q_3a_annual_contribution') ||
        (profile?.userProvidedFields.contains('pillar3aAnnual') ?? false);
  }

  static bool _hasLpp(CoachProfile profile, Map<String, dynamic> answers) {
    return FirstSalaryTax3aCalculator.inferHasLppFor3a(
      grossAnnualSalary: profile.revenuBrutAnnuel,
      age: profile.age,
      employmentStatus: profile.employmentStatus,
      explicitHasPensionFund: _parseBool(answers['q_has_pension_fund']),
      hasCertificateSignals: profile.prevoyance.isLppFromCertificate,
      lppBalance: profile.prevoyance.avoirLppTotal,
    );
  }

  static double _current3aContribution(
    CoachProfile profile,
    Map<String, dynamic> answers,
  ) {
    final answerValue = _parseDouble(answers['q_3a_annual_contribution']);
    if (answerValue != null) return answerValue;
    return FirstSalaryTax3aCalculator.annualizeMonthly3aContribution(
      profile.total3aMensuel,
    );
  }

  static bool? _parseBool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case 'yes':
        case 'oui':
        case '1':
          return true;
        case 'false':
        case 'no':
        case 'non':
        case '0':
          return false;
      }
    }
    return null;
  }

  static double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
