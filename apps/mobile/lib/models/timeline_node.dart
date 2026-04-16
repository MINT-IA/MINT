/// Timeline node model for the Aujourd'hui tab.
///
/// Phase 18: Full Living Timeline. Each node represents a discrete event
/// in the user's financial story — documents, conversations, commitments,
/// couple estimates, and future projections.
library;

import 'package:mint_mobile/models/tension_card.dart';

/// The 5 types of timeline nodes.
enum NodeType {
  /// Uploaded or scanned document.
  document,

  /// Past coach conversation.
  conversation,

  /// Implementation intention (WHEN/WHERE/IF-THEN).
  commitment,

  /// Partner estimate declaration.
  couple,

  /// Future landmark or projection.
  projection,
}

/// Immutable data for a single timeline node.
class TimelineNode {
  final NodeType type;
  final String id;
  final String title;
  final String subtitle;
  final String deepLink;
  final DateTime date;
  final TensionType visualState;

  const TimelineNode({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.deepLink,
    required this.date,
    required this.visualState,
  });
}

/// A month grouping of timeline nodes.
class TimelineMonth {
  final String label;
  final int year;
  final int month;
  final List<TimelineNode> nodes;
  final bool isCurrentMonth;

  const TimelineMonth({
    required this.label,
    required this.year,
    required this.month,
    required this.nodes,
    required this.isCurrentMonth,
  });
}
