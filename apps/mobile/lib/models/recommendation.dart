enum Period { monthly, yearly, oneoff }

enum NextActionType { learn, simulate, checklist, partnerHandoff, externalResource }

class Impact {
  final double amountCHF;
  final Period period;

  const Impact({required this.amountCHF, required this.period});

  factory Impact.fromJson(Map<String, dynamic> json) {
    return Impact(
      amountCHF: json['amountCHF']?.toDouble() ?? 0,
      period: Period.values.firstWhere(
        (e) => e.name == json['period'],
        orElse: () => Period.oneoff,
      ),
    );
  }
}

class NextAction {
  final NextActionType type;
  final String label;
  final String? deepLink;
  final String? partnerId;

  const NextAction({
    required this.type,
    required this.label,
    this.deepLink,
    this.partnerId,
  });

  factory NextAction.fromJson(Map<String, dynamic> json) {
    return NextAction(
      type: _parseNextActionType(json['type']),
      label: json['label'] ?? '',
      deepLink: json['deepLink'],
      partnerId: json['partnerId'],
    );
  }
}

/// Parse snake_case or camelCase action type from backend JSON.
NextActionType _parseNextActionType(dynamic raw) {
  final s = raw?.toString() ?? '';
  // Handle snake_case → camelCase mapping
  if (s == 'external_resource') return NextActionType.externalResource;
  if (s == 'partner_handoff') return NextActionType.partnerHandoff;
  // Direct match by enum name (camelCase)
  return NextActionType.values.firstWhere(
    (e) => e.name == s || e.name == s.replaceAll('_', ''),
    orElse: () => NextActionType.learn,
  );
}

class EvidenceLink {
  final String label;
  final String url;

  const EvidenceLink({required this.label, required this.url});

  factory EvidenceLink.fromJson(Map<String, dynamic> json) {
    return EvidenceLink(
      label: json['label'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class Recommendation {
  final String id;
  final String kind;
  final String title;
  final String summary;
  final List<String> why;
  final List<String> assumptions;
  final Impact impact;
  final List<String> risks;
  final List<String> alternatives;
  final List<EvidenceLink> evidenceLinks;
  final List<NextAction> nextActions;

  Recommendation({
    required this.id,
    required this.kind,
    required this.title,
    required this.summary,
    required this.why,
    required this.assumptions,
    required this.impact,
    required this.risks,
    required this.alternatives,
    required this.evidenceLinks,
    required this.nextActions,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] ?? '',
      kind: json['kind'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      why: List<String>.from(json['why'] ?? []),
      assumptions: List<String>.from(json['assumptions'] ?? []),
      impact: Impact.fromJson(json['impact'] ?? {}),
      risks: List<String>.from(json['risks'] ?? []),
      alternatives: List<String>.from(json['alternatives'] ?? []),
      evidenceLinks: (json['evidenceLinks'] as List<dynamic>?)
              ?.map((e) => EvidenceLink.fromJson(e))
              .toList() ??
          [],
      nextActions: (json['nextActions'] as List<dynamic>?)
              ?.map((e) => NextAction.fromJson(e))
              .toList() ??
          [],
    );
  }
}
