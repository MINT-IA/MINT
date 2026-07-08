enum QuestionType {
  choice,
  multiChoice,
  input,
  text, // Alias for input/text
  number, // Added for compatibility
  slider,
  date,
  canton,
  info,
  consent,
}

enum QuestionCategory {
  consent,
  profile,
  objective,
  cashflow,
  housing,
  debt,
  pension,
  assets,
  tax,
  preferences,
}

class WizardQuestion {
  final String id;
  final QuestionType type;
  final QuestionCategory category;
  final String title; // Renamed from 'question' to match data
  final String? subtitle;
  final String? hint;
  final String? explanation;
  final List<QuestionOption>? options;
  final List<String> tags;
  final bool required;
  final bool allowSkip;
  final String skipLabel;
  final bool Function(Map<String, dynamic> answers)? condition;
  final String? validationError;
  final int? minValue;
  final int? maxValue;

  const WizardQuestion({
    required this.id,
    required this.type,
    this.category = QuestionCategory.profile, // Default value to avoid breakage
    required this.title, // Renamed from question
    this.subtitle,
    this.hint,
    this.explanation,
    this.options,
    this.tags = const [],
    this.required = true,
    this.allowSkip = true,
    this.skipLabel = 'Je ne sais pas / plus tard',
    this.condition,
    this.validationError,
    this.minValue,
    this.maxValue,
  });

  bool shouldShow(Map<String, dynamic> answers) {
    if (condition == null) return true;
    return condition!(_withCanonicalAliases(answers));
  }

  static const _canonicalAliases = {
    'q_housing_cost_period_chf': '_coach_depenses_loyer',
    'q_lamal_premium_monthly_chf': '_coach_depenses_assurance',
  };

  static Map<String, dynamic> _withCanonicalAliases(
    Map<String, dynamic> answers,
  ) {
    final normalized = Map<String, dynamic>.from(answers);
    for (final entry in _canonicalAliases.entries) {
      final canonicalValue = answers[entry.value];
      if (canonicalValue != null) {
        normalized[entry.key] = canonicalValue;
      }
    }
    return normalized;
  }
}

class QuestionOption {
  final String label;
  final dynamic value;
  final String? icon;
  final String? description;

  const QuestionOption({
    required this.label,
    required this.value,
    this.icon,
    this.description,
  });
}
