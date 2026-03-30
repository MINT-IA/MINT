import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/models/goal_template.dart';

class Session {
  final String id;
  final String profileId;
  final DateTime createdAt;
  final Map<String, dynamic> answers;
  final List<String> selectedFocusKinds;
  final String recommendedGoalTemplateId;
  final String? selectedGoalTemplateId;

  Session({
    required this.id,
    required this.profileId,
    required this.createdAt,
    required this.answers,
    required this.selectedFocusKinds,
    required this.recommendedGoalTemplateId,
    this.selectedGoalTemplateId,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      profileId: json['profileId'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      answers: Map<String, dynamic>.from(json['answers']),
      selectedFocusKinds: List<String>.from(json['selectedFocusKinds']),
      recommendedGoalTemplateId: json['recommendedGoalTemplateId'],
      selectedGoalTemplateId: json['selectedGoalTemplateId'],
    );
  }
}

class ScoreboardItem {
  final String label;
  final String value;
  final String note;

  ScoreboardItem({required this.label, required this.value, required this.note});

  factory ScoreboardItem.fromJson(Map<String, dynamic> json) {
    return ScoreboardItem(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

class ConflictOfInterest {
  final String partner;
  final String type;
  final String disclosure;

  ConflictOfInterest({required this.partner, required this.type, required this.disclosure});

  factory ConflictOfInterest.fromJson(Map<String, dynamic> json) {
    return ConflictOfInterest(
      partner: json['partner'],
      type: json['type'],
      disclosure: json['disclosure'],
    );
  }
}

class MintRoadmap {
  final String mentorshipLevel;
  final String natureOfService;
  final List<String> limitations;
  final List<String> assumptions;
  final List<ConflictOfInterest> conflicts;

  MintRoadmap({
    required this.mentorshipLevel,
    required this.natureOfService,
    required this.limitations,
    required this.assumptions,
    required this.conflicts,
  });

  factory MintRoadmap.fromJson(Map<String, dynamic> json) {
    return MintRoadmap(
      mentorshipLevel: json['mentorshipLevel'] ?? 'Guidance Générale',
      natureOfService: json['natureOfService'] ?? 'Mentor',
      limitations: List<String>.from(json['limitations'] ?? []),
      assumptions: List<String>.from(json['assumptions'] ?? []),
      conflicts: (json['conflictsOfInterest'] as List? ?? [])
          .map((c) => ConflictOfInterest.fromJson(c))
          .toList(),
    );
  }
}

class SessionReport {
  final String id;
  final String sessionId;
  final double precisionScore;
  final String title;
  final SessionReportOverview overview;
  final MintRoadmap mintRoadmap;
  final List<ScoreboardItem> scoreboard;
  final GoalTemplate recommendedGoal;
  final List<GoalTemplate> alternativeGoals;
  final List<TopAction> topActions;
  final List<Recommendation> recommendations;
  final List<String> disclaimers;
  final DateTime generatedAt;

  SessionReport({
    required this.id,
    required this.sessionId,
    required this.precisionScore,
    required this.title,
    required this.overview,
    required this.mintRoadmap,
    required this.scoreboard,
    required this.recommendedGoal,
    required this.alternativeGoals,
    required this.topActions,
    required this.recommendations,
    required this.disclaimers,
    required this.generatedAt,
  });

  factory SessionReport.fromJson(Map<String, dynamic> json) {
    return SessionReport(
      id: json['id'],
      sessionId: json['sessionId'],
      precisionScore: json['precisionScore']?.toDouble() ?? 0.0,
      title: json['title'],
      overview: SessionReportOverview.fromJson(json['overview']),
      mintRoadmap: MintRoadmap.fromJson(json['mintRoadmap']),
      scoreboard: (json['scoreboard'] as List).map((i) => ScoreboardItem.fromJson(i)).toList(),
      recommendedGoal: GoalTemplate(
        id: json['recommendedGoalTemplate']['id'],
        label: json['recommendedGoalTemplate']['label'],
      ),
      alternativeGoals: (json['alternativeGoalTemplates'] as List)
          .map((g) => GoalTemplate(id: g['id'], label: g['label']))
          .toList(),
      topActions: (json['topActions'] as List).map((a) => TopAction.fromJson(a)).toList(),
      recommendations: (json['recommendations'] as List).map((r) => Recommendation.fromJson(r)).toList(),
      disclaimers: List<String>.from(json['disclaimers']),
      generatedAt: DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class SessionReportOverview {
  final String canton;
  final String householdType;
  final String goalRecommendedLabel;

  SessionReportOverview({
    required this.canton,
    required this.householdType,
    required this.goalRecommendedLabel,
  });

  factory SessionReportOverview.fromJson(Map<String, dynamic> json) {
    return SessionReportOverview(
      canton: json['canton'],
      householdType: json['householdType'],
      goalRecommendedLabel: json['goalRecommendedLabel'],
    );
  }
}

class TopAction {
  final String effortTag;
  final String label;
  final String why;
  final String ifThen;
  final NextAction nextAction;

  TopAction({
    required this.effortTag,
    required this.label,
    required this.why,
    required this.ifThen,
    required this.nextAction,
  });

  factory TopAction.fromJson(Map<String, dynamic> json) {
    return TopAction(
      effortTag: json['effortTag'],
      label: json['label'],
      why: json['why'],
      ifThen: json['ifThen'],
      nextAction: NextAction.fromJson(json['nextAction']),
    );
  }
}
