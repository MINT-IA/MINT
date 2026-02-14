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
    return condition!(answers);
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
