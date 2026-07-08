import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/biography_refresh_detector.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

enum AskMode { collect, reconfirm }

class DataQuestAsk {
  final AskMode mode;
  final String answerKey;
  final String fieldPath;
  final Object? priorValue;

  const DataQuestAsk({
    required this.mode,
    required this.answerKey,
    required this.fieldPath,
    this.priorValue,
  });
}

class RevenueDataQuestPlanner {
  RevenueDataQuestPlanner._();

  static List<DataQuestAsk> plan({
    required CoachProfile? profile,
    Map<String, dynamic> answers = const {},
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final asks = <DataQuestAsk>[];

    if (!_hasSalary(profile, answers)) {
      asks.add(const DataQuestAsk(
        mode: AskMode.collect,
        answerKey: 'q_gross_salary_annual',
        fieldPath: 'salaireBrutMensuel',
      ));
    }

    if (!_hasCanton(profile, answers)) {
      asks.add(const DataQuestAsk(
        mode: AskMode.collect,
        answerKey: 'q_canton',
        fieldPath: 'canton',
      ));
    }

    if (!_hasBirthYear(profile, answers)) {
      asks.add(const DataQuestAsk(
        mode: AskMode.collect,
        answerKey: 'q_birth_year',
        fieldPath: 'age',
      ));
    }

    if (profile == null) return asks;

    final stale = BiographyRefreshDetector.detectStaleFields(
      [
        if (_hasSalary(profile, answers))
          _profileFact(
            profile: profile,
            fieldPath: 'salaireBrutMensuel',
            factType: FactType.salary,
            value: _salaryPriorValue(profile, answers),
          ),
        if (_hasCanton(profile, answers))
          _profileFact(
            profile: profile,
            fieldPath: 'canton',
            factType: FactType.canton,
            value: _cantonPriorValue(profile, answers),
          ),
      ],
      now: effectiveNow,
    );

    final stalePaths = stale.map((field) => field.fieldPath).toSet();
    if (stalePaths.contains('salaireBrutMensuel')) {
      asks.add(DataQuestAsk(
        mode: AskMode.reconfirm,
        answerKey: 'q_gross_salary_annual',
        fieldPath: 'salaireBrutMensuel',
        priorValue: _salaryPriorValue(profile, answers),
      ));
    }
    if (stalePaths.contains('canton')) {
      asks.add(DataQuestAsk(
        mode: AskMode.reconfirm,
        answerKey: 'q_canton',
        fieldPath: 'canton',
        priorValue: _cantonPriorValue(profile, answers),
      ));
    }

    return asks;
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

  static Object? _salaryPriorValue(
    CoachProfile profile,
    Map<String, dynamic> answers,
  ) {
    final raw = answers['q_gross_salary_annual'];
    if (raw is num) return raw.round();
    final annual = profile.salaireBrutMensuel * profile.nombreDeMois;
    return annual > 0 ? annual.round() : null;
  }

  static Object? _cantonPriorValue(
    CoachProfile profile,
    Map<String, dynamic> answers,
  ) {
    return answers['q_canton'] ?? profile.canton;
  }

  static BiographyFact _profileFact({
    required CoachProfile profile,
    required String fieldPath,
    required FactType factType,
    required Object? value,
  }) {
    final updatedAt = profile.dataTimestamps[fieldPath] ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return BiographyFact(
      id: 'profile-$fieldPath',
      factType: factType,
      fieldPath: fieldPath,
      value: value?.toString() ?? '',
      source: FactSource.userInput,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      freshnessCategory: FreshnessDecayService.categoryFor(factType),
    );
  }
}
