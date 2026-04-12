/// Tension card model for the Aujourd'hui tab.
///
/// Each authenticated user sees exactly 3 tension cards reflecting
/// their financial state: past (earned), present (pulsing), future (ghosted).
library;

/// Visual state of a tension card on the Aujourd'hui tab.
enum TensionType {
  /// Solid, completed — past action acknowledged.
  earned,

  /// Pulsing, active — current tension requiring attention.
  pulsing,

  /// Ghosted, projected — future landmark or projection.
  ghosted,
}

/// Position in the Cleo service loop (Insight -> Plan -> Conversation -> Action -> Memory).
enum CleoLoopPosition {
  insight,
  plan,
  conversation,
  action,
  memory,
}

/// Immutable data for a single tension card.
class TensionCard {
  final TensionType type;
  final String title;
  final String subtitle;
  final String deepLink;
  final DateTime? date;

  const TensionCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.deepLink,
    this.date,
  });
}
