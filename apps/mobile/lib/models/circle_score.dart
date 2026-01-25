/// Modèle représentant le score de santé financière par cercle
class CircleScore {
  final String circleName;
  final int circleNumber;
  final double percentage; // 0-100
  final ScoreLevel level;
  final List<ScoreItem> items;
  final List<String> recommendations;

  const CircleScore({
    required this.circleName,
    required this.circleNumber,
    required this.percentage,
    required this.level,
    required this.items,
    required this.recommendations,
  });

  bool get isPerfect => percentage >= 95;
  bool get isGood => percentage >= 70;
  bool get isOk => percentage >= 50;
  bool get needsWork => percentage < 50;
}

enum ScoreLevel {
  critical, // < 30%
  needsImprovement, // 30-50%
  adequate, // 50-70%
  good, // 70-90%
  excellent, // > 90%
}

extension ScoreLevelExtension on ScoreLevel {
  String get label {
    switch (this) {
      case ScoreLevel.critical:
        return 'Critique';
      case ScoreLevel.needsImprovement:
        return 'À améliorer';
      case ScoreLevel.adequate:
        return 'Adéquat';
      case ScoreLevel.good:
        return 'Bon';
      case ScoreLevel.excellent:
        return 'Excellent';
    }
  }

  String get emoji {
    switch (this) {
      case ScoreLevel.critical:
        return '🚨';
      case ScoreLevel.needsImprovement:
        return '⚠️';
      case ScoreLevel.adequate:
        return '👌';
      case ScoreLevel.good:
        return '✅';
      case ScoreLevel.excellent:
        return '🏆';
    }
  }
}

/// Item individuel de scoring (ex: "Fonds d'urgence : OK")
class ScoreItem {
  final String label;
  final ItemStatus status;
  final String? detail;
  final double weight; // Importance dans le cercle (0-1)

  const ScoreItem({
    required this.label,
    required this.status,
    this.detail,
    this.weight = 1.0,
  });
}

enum ItemStatus {
  perfect, // ✅
  good, // 👍
  warning, // ⚠️
  critical, // ❌
  unknown, // ❓
}

extension ItemStatusExtension on ItemStatus {
  String get icon {
    switch (this) {
      case ItemStatus.perfect:
        return '✅';
      case ItemStatus.good:
        return '👍';
      case ItemStatus.warning:
        return '⚠️';
      case ItemStatus.critical:
        return '❌';
      case ItemStatus.unknown:
        return '❓';
    }
  }

  double get scoreValue {
    switch (this) {
      case ItemStatus.perfect:
        return 1.0;
      case ItemStatus.good:
        return 0.75;
      case ItemStatus.warning:
        return 0.5;
      case ItemStatus.critical:
        return 0.0;
      case ItemStatus.unknown:
        return 0.5; // Neutre
    }
  }
}

/// Score global de santé financière
class FinancialHealthScore {
  final CircleScore circle1Protection;
  final CircleScore circle2Prevoyance;
  final CircleScore circle3Croissance;
  final CircleScore circle4Optimisation;
  final double overallScore; // 0-100
  final List<String> topPriorities; // 3 actions prioritaires

  const FinancialHealthScore({
    required this.circle1Protection,
    required this.circle2Prevoyance,
    required this.circle3Croissance,
    required this.circle4Optimisation,
    required this.overallScore,
    required this.topPriorities,
  });

  List<CircleScore> get allCircles => [
        circle1Protection,
        circle2Prevoyance,
        circle3Croissance,
        circle4Optimisation,
      ];

  ScoreLevel get overallLevel {
    if (overallScore >= 90) return ScoreLevel.excellent;
    if (overallScore >= 70) return ScoreLevel.good;
    if (overallScore >= 50) return ScoreLevel.adequate;
    if (overallScore >= 30) return ScoreLevel.needsImprovement;
    return ScoreLevel.critical;
  }
}
