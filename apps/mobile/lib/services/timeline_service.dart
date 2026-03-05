import 'package:mint_mobile/models/age_band_policy.dart';

enum ReminderPriority {
  low,
  medium,
  high,
  critical,
}

class TimelineItem {
  final String id;
  final DateTime date;
  final String category;
  final String label;
  final String description;
  final String? actionUrl;
  final ReminderPriority priority;
  final bool completed;
  final String sourceSessionId;

  const TimelineItem({
    required this.id,
    required this.date,
    required this.category,
    required this.label,
    required this.description,
    this.actionUrl,
    required this.priority,
    this.completed = false,
    required this.sourceSessionId,
  });

  TimelineItem copyWith({
    String? id,
    DateTime? date,
    String? category,
    String? label,
    String? description,
    String? actionUrl,
    ReminderPriority? priority,
    bool? completed,
    String? sourceSessionId,
  }) {
    return TimelineItem(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      label: label ?? this.label,
      description: description ?? this.description,
      actionUrl: actionUrl ?? this.actionUrl,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'category': category,
      'label': label,
      'description': description,
      'actionUrl': actionUrl,
      'priority': priority.name,
      'completed': completed,
      'sourceSessionId': sourceSessionId,
    };
  }

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      id: json['id'],
      date: DateTime.parse(json['date']),
      category: json['category'],
      label: json['label'],
      description: json['description'],
      actionUrl: json['actionUrl'],
      priority:
          ReminderPriority.values.firstWhere((e) => e.name == json['priority']),
      completed: json['completed'] ?? false,
      sourceSessionId: json['sourceSessionId'],
    );
  }
}

class TimelineService {
  /// Génère les timeline items depuis les réponses du wizard
  static List<TimelineItem> generateTimeline(
    String sessionId,
    Map<String, dynamic> answers,
  ) {
    final items = <TimelineItem>[];
    final now = DateTime.now();

    // 1. Hypothèque fixe : rappel 120 jours avant échéance
    if (answers['q_mortgage_fixed_end_date'] != null) {
      final endDate = DateTime.parse(answers['q_mortgage_fixed_end_date']);
      final reminderDate = endDate.subtract(const Duration(days: 120));

      items.add(TimelineItem(
        id: 'mortgage_renewal_$sessionId',
        date: reminderDate,
        category: 'housing',
        label: 'Renégociation hypothèque',
        description:
            'Comparer les offres du marché 90-180 jours avant échéance',
        actionUrl: '/mortgage/affordability',
        priority: ReminderPriority.high,
        sourceSessionId: sessionId,
      ));
    }

    // 2. Leasing : rappel 60 jours avant fin
    if (answers['q_leasing_end_date'] != null) {
      final endDate = DateTime.parse(answers['q_leasing_end_date']);
      final reminderDate = endDate.subtract(const Duration(days: 60));

      items.add(TimelineItem(
        id: 'leasing_end_$sessionId',
        date: reminderDate,
        category: 'debt',
        label: 'Fin de leasing',
        description:
            'Planifier la suite : renouvellement, achat, ou autre véhicule',
        actionUrl: '/check/debt',
        priority: ReminderPriority.medium,
        sourceSessionId: sessionId,
      ));
    }

    // 3. Crédit conso : rappel 30 jours avant fin
    if (answers['q_consumer_credit_end_date'] != null) {
      final endDate = DateTime.parse(answers['q_consumer_credit_end_date']);
      final reminderDate = endDate.subtract(const Duration(days: 30));

      items.add(TimelineItem(
        id: 'credit_end_$sessionId',
        date: reminderDate,
        category: 'debt',
        label: 'Fin de crédit',
        description:
            'Libération de CHF ${answers['q_consumer_credit_monthly']}/mois dans ton budget',
        actionUrl: '/check/debt',
        priority: ReminderPriority.medium,
        sourceSessionId: sessionId,
      ));
    }

    // 4. Achat logement : rappel 12 mois avant date cible
    if (answers['q_mid_housing_purchase_date'] != null) {
      final targetDate = DateTime.parse(answers['q_mid_housing_purchase_date']);
      final reminderDate = targetDate.subtract(const Duration(days: 365));

      items.add(TimelineItem(
        id: 'housing_purchase_$sessionId',
        date: reminderDate,
        category: 'housing',
        label: 'Planifier apport logement',
        description:
            'Vérifier fonds disponibles (3a, épargne, apport familial)',
        actionUrl: '/mortgage/affordability',
        priority: ReminderPriority.high,
        sourceSessionId: sessionId,
      ));
    }

    // 5. Retraite : rappel 10 ans avant âge cible
    if (answers['q_preretire_target_age'] != null) {
      final birthYear = answers['q_birth_year'] as int;
      final targetAge = answers['q_preretire_target_age'] as int;
      final retirementYear = birthYear + targetAge;
      final reminderYear = retirementYear - 10;
      final reminderDate = DateTime(reminderYear, 1, 1);

      if (reminderDate.isAfter(now)) {
        items.add(TimelineItem(
          id: 'retirement_plan_$sessionId',
          date: reminderDate,
          category: 'pension',
          label: 'Plan retraite complet',
          description:
              'Simuler scénarios retraite (60/62/65 ans, rente/capital)',
          actionUrl: '/coach/cockpit',
          priority: ReminderPriority.high,
          sourceSessionId: sessionId,
        ));
      }
    }

    // 6. Versement 3a : rappel annuel (décembre)
    if (answers['q_has_3a'] == true) {
      final december = DateTime(now.year, 12, 1);
      final reminderDate =
          december.isAfter(now) ? december : DateTime(now.year + 1, 12, 1);

      items.add(TimelineItem(
        id: '3a_annual_${sessionId}_${now.year}',
        date: reminderDate,
        category: 'pension',
        label: 'Optimiser versement 3a',
        description: 'Vérifier si tu as maximisé ton versement annuel',
        actionUrl: '/simulator/3a',
        priority: ReminderPriority.medium,
        sourceSessionId: sessionId,
      ));
    }

    // 7. Bénéficiaires : rappel annuel (si 50+)
    final birthYear = answers['q_birth_year'] as int?;
    if (birthYear != null) {
      final age = DateTime.now().year - birthYear;
      if (age >= 50) {
        final january = DateTime(now.year + 1, 1, 1);

        items.add(TimelineItem(
          id: 'beneficiaries_${sessionId}_${now.year}',
          date: january,
          category: 'pension',
          label: 'Vérifier bénéficiaires',
          description: 'Mettre à jour bénéficiaires LPP/3a/assurances',
          actionUrl: '/onboarding/smart',
          priority: ReminderPriority.medium,
          sourceSessionId: sessionId,
        ));
      }
    }

    return items;
  }

  /// Retourne les rappels à venir (prochains 90 jours)
  static List<TimelineItem> getUpcomingReminders(List<TimelineItem> timeline) {
    final now = DateTime.now();
    final in90Days = now.add(const Duration(days: 90));

    return timeline
        .where((item) => !item.completed)
        .where((item) => item.date.isAfter(now) && item.date.isBefore(in90Days))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Retourne les rappels en retard
  static List<TimelineItem> getOverdueReminders(List<TimelineItem> timeline) {
    final now = DateTime.now();

    return timeline
        .where((item) => !item.completed)
        .where((item) => item.date.isBefore(now))
        .toList()
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  }

  /// Génère les questions delta pour un événement de vie
  static List<String> getDeltaQuestionIds(LifeEventType event) {
    final deltaQuestions = LifeEvent.all[event]?.deltaQuestions ?? [];
    return deltaQuestions;
  }

  /// Génère les timeline items pour un événement de vie
  static List<TimelineItem> getEventTimelineItems(
    String sessionId,
    LifeEventType event,
    Map<String, dynamic> eventData,
  ) {
    final items = <TimelineItem>[];
    final now = DateTime.now();

    switch (event) {
      case LifeEventType.newJob:
        items.add(TimelineItem(
          id: 'new_job_lpp_transfer_$sessionId',
          date: now.add(const Duration(days: 30)),
          category: 'pension',
          label: 'Transfert LPP',
          description: 'Transférer ton avoir LPP vers ta nouvelle caisse',
          actionUrl: '/lpp-deep/rachat',
          priority: ReminderPriority.high,
          sourceSessionId: sessionId,
        ));
        break;

      case LifeEventType.birth:
        items.add(TimelineItem(
          id: 'birth_insurance_review_$sessionId',
          date: now.add(const Duration(days: 7)),
          category: 'insurance',
          label: 'Revue couverture',
          description: 'Vérifier assurances décès/invalidité',
          actionUrl: '/assurances/lamal',
          priority: ReminderPriority.critical,
          sourceSessionId: sessionId,
        ));
        break;

      default:
        break;
    }

    return items;
  }
}
