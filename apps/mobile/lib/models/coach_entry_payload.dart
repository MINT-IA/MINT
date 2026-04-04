/// Typed payload for contextual coach entry.
///
/// When a user taps a chiffre, a lever, a chip, or types in the input bar,
/// this payload tells the coach WHERE the user came from, WHAT topic is
/// relevant, and WHAT DATA to use for the first response.
///
/// Used by:
///   - MintHomeScreen (chiffre tap, lever tap, chip tap, text input)
///   - Coach bottom sheet (from simulators)
///   - Signal cards (proactive triggers)
///   - Radar anticipatoire (upcoming events)
///   - Notification deep links
library;

/// Sources from which a user can enter the coach.
enum CoachEntrySource {
  /// User tapped the chiffre vivant on MintHome.
  homeChiffre,

  /// User tapped the itinéraire alternatif (lever) on MintHome.
  homeLever,

  /// User tapped a suggestion chip on MintHome.
  homeChip,

  /// User typed a message in the MintHome input bar.
  homeInput,

  /// User opened coach from a simulator's bottom sheet.
  simulator,

  /// User opened coach from a simulator's interrupt banner.
  interrupt,

  /// User tapped a signal card on MintHome.
  signal,

  /// User tapped a radar event on MintHome.
  radar,

  /// User arrived via a push notification deep link.
  notification,

  /// User tapped "En parler" in the scan impact screen.
  scanInsight,

  /// Generic/unknown entry (backward compat).
  direct,
}

/// Payload carrying context when entering the coach.
///
/// Immutable. Created at the entry point, consumed by CoachChatScreen
/// to build the initial system prompt injection.
class CoachEntryPayload {
  /// Where the user came from.
  final CoachEntrySource source;

  /// The financial topic relevant to this entry.
  ///
  /// Maps to domain concepts: 'retirementGap', 'rachatLpp', 'pillar3a',
  /// 'mortgage', 'budget', 'divorce', etc.
  /// Null for free-form text input.
  final String? topic;

  /// Structured data relevant to the topic.
  ///
  /// Examples:
  ///   homeChiffre: {'value': 4200.0, 'confidence': 0.62, 'delta': -47.0}
  ///   simulator:   {'annual': 3000, 'maxAnnual': 7258, 'taxSaving': 1247.0}
  ///   signal:      {'type': 'threeADeadline', 'daysLeft': 274}
  final Map<String, dynamic>? data;

  /// Free-form message typed by the user.
  ///
  /// When present, this is sent as the first user message in the chat.
  /// When absent and topic is set, a contextual prompt is auto-generated.
  final String? userMessage;

  const CoachEntryPayload({
    required this.source,
    this.topic,
    this.data,
    this.userMessage,
  });

  /// Build a system prompt injection describing this entry context.
  ///
  /// Used by ContextInjectorService to tell the LLM why the user arrived.
  String toContextInjection() {
    final buf = StringBuffer();
    buf.writeln("--- CONTEXTE D'ENTRÉE ---");
    buf.writeln('Source: ${source.name}');
    if (topic != null) {
      buf.writeln('Sujet: $topic');
    }
    if (data != null && data!.isNotEmpty) {
      buf.writeln(
        'Données: ${data!.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
      );
    }
    if (userMessage != null) {
      buf.writeln('Message utilisateur: "$userMessage"');
    }
    buf.writeln('INSTRUCTION: Réponds en tenant compte de ce contexte.');
    buf.writeln('--- FIN CONTEXTE ---');
    return buf.toString();
  }

  @override
  String toString() =>
      'CoachEntryPayload(source: ${source.name}, topic: $topic, '
      'data: ${data?.length ?? 0} fields, message: ${userMessage != null ? "yes" : "no"})';
}
