class OnboardingConstants {
  static const int totalSteps = 3;
  static const int wizardTotalQuestions = 24;

  static const double defaultSavingsRate = 0.10;
  static const double maxMonthlySavingsCap = 1200.0;
  static const double minMonthlySavingsFloor = 100.0;
  static const double lppAccessThreshold = 22680.0;

  static const Set<String> highLamalCantons = {'GE', 'VD', 'BS', 'NE', 'TI'};
  static const Set<String> lowLamalCantons = {'ZG', 'AI', 'UR', 'OW', 'NW', 'GL', 'AR'};

  static const Duration autoSaveDebounce = Duration(milliseconds: 500);

  static const List<int> incomeQuickPicks = [4000, 6000, 8000, 10000];

  static const Map<int, int> fallbackStepDurations = {
    1: 20,
    2: 25,
    3: 22,
  };
}
