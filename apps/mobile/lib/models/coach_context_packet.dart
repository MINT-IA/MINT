class CoachContextFact {
  final String id;
  final String domain;
  final String fieldPath;
  final Object value;
  final String? source;
  final String confidence;
  final String freshness;
  final String? state;
  final DateTime? updatedAt;
  final String storageLocation;
  final String syncState;
  final String aiSharingState;
  final String deleteConsequence;

  const CoachContextFact({
    required this.id,
    required this.domain,
    required this.fieldPath,
    required this.value,
    required this.source,
    required this.confidence,
    required this.freshness,
    this.state,
    required this.updatedAt,
    this.storageLocation = 'unknown',
    this.syncState = 'unknown',
    this.aiSharingState = 'unknown',
    this.deleteConsequence = 'unknown',
  });

  Map<String, dynamic> toSafeMap() {
    return {
      'id': id,
      'domain': domain,
      'field_path': fieldPath,
      'value': value,
      if (source != null) 'source': source,
      'confidence': confidence,
      'freshness': freshness,
      if (state != null) 'state': state,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'storage_location': storageLocation,
      'sync_state': syncState,
      'ai_sharing_state': aiSharingState,
      'delete_consequence': deleteConsequence,
    };
  }
}

class CoachMissingField {
  final String fieldPath;
  final String domain;
  final String reason;

  const CoachMissingField({
    required this.fieldPath,
    required this.domain,
    required this.reason,
  });

  Map<String, dynamic> toSafeMap() {
    return {
      'field_path': fieldPath,
      'domain': domain,
      'reason': reason,
    };
  }
}

class CoachTrajectoryContext {
  final String status;
  final double currentMonthlyFree;
  final double currentMonthlyCapacity;
  final double? targetAmount;
  final int? monthsToTarget;
  final double? monthlyRequired;
  final double? monthlyGap;
  final String nextLeverId;

  const CoachTrajectoryContext({
    required this.status,
    required this.currentMonthlyFree,
    required this.currentMonthlyCapacity,
    required this.targetAmount,
    required this.monthsToTarget,
    required this.monthlyRequired,
    required this.monthlyGap,
    required this.nextLeverId,
  });

  Map<String, dynamic> toSafeMap() {
    return {
      'status': status,
      'current_monthly_free': currentMonthlyFree,
      'current_monthly_capacity': currentMonthlyCapacity,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (monthsToTarget != null) 'months_to_target': monthsToTarget,
      if (monthlyRequired != null) 'monthly_required': monthlyRequired,
      if (monthlyGap != null) 'monthly_gap': monthlyGap,
      'next_lever_id': nextLeverId,
    };
  }
}

class CoachNextQuestion {
  final String id;
  final String domain;
  final String fieldPath;

  const CoachNextQuestion({
    required this.id,
    required this.domain,
    required this.fieldPath,
  });

  Map<String, dynamic> toSafeMap() {
    return {
      'id': id,
      'domain': domain,
      'field_path': fieldPath,
    };
  }
}

class CoachReadinessSection {
  final String id;
  final String status;
  final int knownCount;
  final int missingCount;

  const CoachReadinessSection({
    required this.id,
    required this.status,
    required this.knownCount,
    required this.missingCount,
  });

  Map<String, dynamic> toSafeMap() {
    return {
      'id': id,
      'status': status,
      'known_count': knownCount,
      'missing_count': missingCount,
    };
  }
}

class CoachReadinessContext {
  final String overallStatus;
  final List<CoachReadinessSection> sections;
  final List<String> missingDomains;
  final String nextActionId;

  const CoachReadinessContext({
    required this.overallStatus,
    required this.sections,
    required this.missingDomains,
    required this.nextActionId,
  });

  Map<String, dynamic> toSafeMap() {
    return {
      'overall_status': overallStatus,
      'sections': sections.map((s) => s.toSafeMap()).toList(growable: false),
      'missing_domains': missingDomains,
      'next_action_id': nextActionId,
    };
  }
}

class CoachContextPacket {
  final DateTime computedAt;
  final List<CoachContextFact> facts;
  final List<CoachMissingField> missingFields;
  final CoachTrajectoryContext trajectory;
  final List<CoachNextQuestion> nextQuestions;
  final CoachReadinessContext readiness;

  const CoachContextPacket({
    required this.computedAt,
    required this.facts,
    required this.missingFields,
    required this.trajectory,
    required this.nextQuestions,
    required this.readiness,
  });

  Map<String, dynamic> toSafeMap() {
    return {
      'computed_at': computedAt.toIso8601String(),
      'facts': facts.map((f) => f.toSafeMap()).toList(growable: false),
      'missing_fields':
          missingFields.map((f) => f.toSafeMap()).toList(growable: false),
      'trajectory': trajectory.toSafeMap(),
      'next_questions':
          nextQuestions.map((q) => q.toSafeMap()).toList(growable: false),
      'readiness': readiness.toSafeMap(),
    };
  }
}
