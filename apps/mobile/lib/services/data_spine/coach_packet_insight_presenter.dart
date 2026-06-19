class CoachPacketInsight {
  final String title;
  final String knownLabel;
  final String knownText;
  final String nextLabel;
  final String nextText;

  const CoachPacketInsight({
    required this.title,
    required this.knownLabel,
    required this.knownText,
    required this.nextLabel,
    required this.nextText,
  });
}

abstract final class CoachPacketInsightPresenter {
  // SALVAGE-00 SC-4: lead with monthly_free (the converged "Disponible/mois"
  // shown on Budget + Mon Argent) so the coach surface shows the SAME number
  // the user sees everywhere — not monthly_capacity (pre-3a), which diverges
  // and breaks the money-trust-chain. Mirrors coach_context_packet_service's
  // ordering (monthly_free first).
  static const _factPriority = <String>[
    'budget.monthly_free',
    'budget.monthly_capacity',
    'budget.monthly_net',
    'pillar.lpp.total_balance',
    'pillar.3a.total_balance',
    'pillar.avs.estimated_monthly_pension',
    'profile.canton',
    'profile.birth_year',
  ];

  static const _questionLabels = <String, String>{
    'define_target_amount': 'Objectif à atteindre',
    'review_fixed_charges': 'Charges fixes à revoir',
    'increase_monthly_capacity': 'Capacité mensuelle à ajuster',
    'confirm_plan_tracking': 'Suivi du plan',
  };

  static const _fieldLabels = <String, String>{
    'trajectory.targetAmount': 'Objectif à atteindre',
    'trajectory.monthlyGap': 'Écart mensuel',
    'budget.present.monthlyFree': 'Marge mensuelle',
    'pillars.lpp.totalBalance': 'Avoir LPP',
    'pillars.lpp.insuredSalary': 'Salaire assuré LPP',
    'pillars.lpp.buybackMax': 'Rachat LPP possible',
    'pillars.avs.contributionYears': 'Années AVS',
    'pillars.avs.gaps': 'Lacunes AVS',
    'pillars.avs.estimatedMonthlyPension': 'Rente AVS estimée',
    'pillars.pillar3a.totalBalance': 'Solde 3a',
    'pillars.pillar3a.accountsCount': 'Comptes 3a',
  };

  static CoachPacketInsight? fromSafeMap(Map<String, dynamic> packet) {
    final fact = _selectedFact(packet['facts']);
    final nextText = _selectedFollowUp(packet);
    if (fact == null || nextText == null) return null;

    return CoachPacketInsight(
      title: 'Point de départ',
      knownLabel: 'Déjà clair',
      knownText: fact,
      nextLabel: 'Prochaine pièce',
      nextText: nextText,
    );
  }

  static String? _selectedFact(Object? factsValue) {
    final facts = factsValue is List ? factsValue : const [];
    for (final id in _factPriority) {
      for (final item in facts) {
        if (item is! Map) continue;
        if (item['id'] != id) continue;
        if (_isEstimatedFact(item)) continue;
        return _factText(id, item['value']);
      }
    }
    return null;
  }

  static bool _isEstimatedFact(Map item) {
    final source = item['source']?.toString();
    final confidence = item['confidence']?.toString();
    final state = item['state']?.toString();
    return source == 'estimated' ||
        source == 'system_estimate' ||
        source == 'systemEstimate' ||
        confidence == 'estimated' ||
        state == 'estimated';
  }

  static String? _factText(String id, Object? value) {
    if (value == null) return null;
    switch (id) {
      case 'budget.monthly_capacity':
        return 'Capacité mensuelle: ${_formatChf(value)}';
      case 'budget.monthly_free':
        return 'Marge libre: ${_formatChf(value)}';
      case 'budget.monthly_net':
        return 'Revenu net: ${_formatChf(value)}';
      case 'pillar.lpp.total_balance':
        return 'LPP: ${_formatChf(value)}';
      case 'pillar.3a.total_balance':
        return '3a: ${_formatChf(value)}';
      case 'pillar.avs.estimated_monthly_pension':
        return 'AVS estimée: ${_formatChf(value)}';
      case 'profile.canton':
        final canton = value.toString().trim();
        if (canton.isEmpty) return null;
        return 'Canton: $canton';
      case 'profile.birth_year':
        final year = value.toString().trim();
        if (year.isEmpty) return null;
        return 'Année de naissance: $year';
      default:
        return null;
    }
  }

  static String? _selectedFollowUp(Map<String, dynamic> packet) {
    final nextQuestions = packet['next_questions'];
    if (nextQuestions is List) {
      for (final item in nextQuestions) {
        if (item is! Map) continue;
        final id = item['id']?.toString();
        final fieldPath = item['field_path']?.toString();
        final label = id == null ? null : _questionLabels[id];
        if (label != null) return label;
        final fieldLabel = fieldPath == null ? null : _fieldLabels[fieldPath];
        if (fieldLabel != null) return fieldLabel;
      }
    }

    final missingFields = packet['missing_fields'];
    if (missingFields is List) {
      for (final item in missingFields) {
        if (item is! Map) continue;
        final fieldPath = item['field_path']?.toString();
        final label = fieldPath == null ? null : _fieldLabels[fieldPath];
        if (label != null) return label;
      }
    }

    return null;
  }

  static String _formatChf(Object value) {
    final number = value is num ? value : num.tryParse(value.toString());
    if (number == null) return 'CHF ${value.toString()}';
    final rounded = number.round().toString();
    final grouped = rounded.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => "${match[1]}'",
    );
    return 'CHF $grouped';
  }
}
