// Annual Refresh Service — Sprint S37.
//
// Detects stale profiles (> 11 months since last major update)
// and generates 7 pre-filled refresh questions.
//
// Pure deterministic service — no network, no side effects.
// All text in French (informal "tu").
// No banned terms ("garanti", "certain", "optimal", etc.).

// ────────────────────────────────────────────────────────────
//  DATA CLASSES
// ────────────────────────────────────────────────────────────

/// Type of input widget for a refresh question.
enum RefreshQuestionType { slider, yesNo, select, text }

/// A single refresh question with pre-filled value.
class RefreshQuestion {
  /// Unique key for this question (e.g. 'salary', 'job_change').
  final String key;

  /// French label displayed to the user.
  final String label;

  /// Help text shown below the label (optional).
  final String? helpText;

  /// Input widget type.
  final RefreshQuestionType type;

  /// Pre-filled current value (as String for uniformity).
  final String? currentValue;

  /// Options for [RefreshQuestionType.select] type.
  final List<String> options;

  /// Slider min/max for [RefreshQuestionType.slider] type.
  final double? sliderMin;
  final double? sliderMax;
  final int? sliderDivisions;

  const RefreshQuestion({
    required this.key,
    required this.label,
    required this.type,
    this.helpText,
    this.currentValue,
    this.options = const [],
    this.sliderMin,
    this.sliderMax,
    this.sliderDivisions,
  });
}

/// Result of the annual refresh check.
class AnnualRefreshResult {
  /// Whether the profile needs a refresh (> 11 months stale).
  final bool refreshNeeded;

  /// Months since last major update.
  final int monthsSinceUpdate;

  /// 7 pre-filled refresh questions.
  final List<RefreshQuestion> questions;

  /// Compliance disclaimer.
  final String disclaimer;

  /// Legal source references.
  final List<String> sources;

  const AnnualRefreshResult({
    required this.refreshNeeded,
    required this.monthsSinceUpdate,
    required this.questions,
    required this.disclaimer,
    required this.sources,
  });
}

// ────────────────────────────────────────────────────────────
//  SERVICE
// ────────────────────────────────────────────────────────────

/// Annual refresh detector and question generator.
///
/// Pure static methods — no instantiation needed.
class AnnualRefreshService {
  AnnualRefreshService._();

  /// Check if profile needs a refresh (> 11 months since [lastMajorUpdate]).
  static bool checkRefreshNeeded(DateTime lastMajorUpdate) {
    final daysSince = DateTime.now().difference(lastMajorUpdate).inDays;
    // ~11 months = 335 days (conservative approximation)
    return daysSince > 335;
  }

  /// Compute months elapsed since [lastMajorUpdate].
  static int monthsSince(DateTime lastMajorUpdate) {
    final now = DateTime.now();
    return (now.year - lastMajorUpdate.year) * 12 +
        (now.month - lastMajorUpdate.month);
  }

  /// Generate the 7 refresh questions with pre-filled values.
  ///
  /// [lastMajorUpdate] — date of last profile refresh.
  /// [currentSalary] — current monthly gross salary (CHF).
  /// [currentLpp] — current LPP balance (CHF).
  /// [current3a] — current 3a balance (CHF).
  /// [riskProfile] — current risk tolerance.
  static AnnualRefreshResult generateRefreshQuestions({
    DateTime? lastMajorUpdate,
    double currentSalary = 0,
    double currentLpp = 0,
    double current3a = 0,
    String riskProfile = 'modere',
  }) {
    final effectiveDate =
        lastMajorUpdate ?? DateTime.now().subtract(const Duration(days: 400));
    final needed = checkRefreshNeeded(effectiveDate);
    final months = monthsSince(effectiveDate);

    final questions = <RefreshQuestion>[
      // Q1 — Salaire
      RefreshQuestion(
        key: 'salary',
        label: 'Ton salaire brut mensuel a-t-il change ?',
        type: RefreshQuestionType.slider,
        currentValue: currentSalary.toStringAsFixed(0),
        sliderMin: 0,
        sliderMax: 30000,
        sliderDivisions: 300,
      ),

      // Q2 — Changement d'emploi
      const RefreshQuestion(
        key: 'job_change',
        label: 'As-tu change d\'emploi ?',
        type: RefreshQuestionType.yesNo,
        currentValue: 'non',
      ),

      // Q3 — Avoir LPP
      RefreshQuestion(
        key: 'lpp_balance',
        label: 'Ton avoir LPP actuel',
        type: RefreshQuestionType.text,
        helpText: 'Regarde ton certificat de prevoyance '
            '(tu le recois chaque janvier)',
        currentValue: currentLpp.toStringAsFixed(0),
      ),

      // Q4 — Solde 3a
      RefreshQuestion(
        key: 'three_a_balance',
        label: 'Solde 3a approximatif',
        type: RefreshQuestionType.text,
        helpText: 'Connecte-toi sur ton app 3a pour voir le solde exact',
        currentValue: current3a.toStringAsFixed(0),
      ),

      // Q5 — Projet immobilier
      const RefreshQuestion(
        key: 'real_estate',
        label: 'Nouveau projet immobilier ?',
        type: RefreshQuestionType.yesNo,
        currentValue: 'non',
      ),

      // Q6 — Changement familial
      const RefreshQuestion(
        key: 'family_change',
        label: 'Changement familial cette annee ?',
        type: RefreshQuestionType.select,
        currentValue: 'aucun',
        options: ['aucun', 'mariage', 'naissance', 'divorce'],
      ),

      // Q7 — Appetit au risque
      RefreshQuestion(
        key: 'risk_tolerance',
        label: 'Ton appetit au risque a-t-il change ?',
        type: RefreshQuestionType.select,
        currentValue: riskProfile,
        options: ['conservateur', 'modere', 'dynamique'],
      ),
    ];

    return AnnualRefreshResult(
      refreshNeeded: needed,
      monthsSinceUpdate: months,
      questions: questions,
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier au sens '
          'de la LSFin. Consulte un\u00b7e specialiste pour des conseils '
          'personnalises.',
      sources: [
        'LPP art. 8-10 (salaire coordonne)',
        'LAVS art. 29 (duree de cotisation)',
        'OPP3 art. 7 (plafond 3a)',
      ],
    );
  }
}
