/// TimelineProvider — extends TensionCardProvider with full timeline nodes.
///
/// Phase 18: Full Living Timeline. Aggregates nodes from commitments,
/// conversations, partner estimates, landmarks, and documents into a
/// month-grouped timeline for the Aujourd'hui tab.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/tension_card_provider.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';

/// Raw data fetched from services, cached to avoid double-fetching.
class _RawTimelineData {
  final List<Map<String, dynamic>> commitments;
  final List<FreshStartLandmark> landmarks;
  final List<Map<String, dynamic>> conversationEntries;
  final PartnerEstimate? partner;
  final List<Map<String, dynamic>> documents;

  const _RawTimelineData({
    required this.commitments,
    required this.landmarks,
    required this.conversationEntries,
    required this.partner,
    required this.documents,
  });
}

class TimelineProvider extends TensionCardProvider {
  List<TimelineMonth> _months = [];
  int _visibleCap = 50;
  int _totalNodeCount = 0;

  /// Month-grouped timeline nodes, sorted newest-first.
  List<TimelineMonth> get months => _months;

  /// Whether more nodes are available beyond the visible cap.
  bool get hasMore => _totalNodeCount > _visibleCap;

  /// Whether at least one node exists.
  bool get hasNodes => _totalNodeCount > 0;

  /// Increase visible cap by 20 and regroup.
  void loadMore() {
    _visibleCap += 20;
    _rebuildMonths(_lastNodes);
    notifyListeners();
  }

  // ── Cached raw nodes (pre-cap) ────────────────────────────
  List<TimelineNode> _lastNodes = [];

  @override
  Future<void> refresh() async {
    // Parent populates tension cards + loop position.
    await super.refresh();

    // Fetch raw data for timeline nodes.
    final data = await _fetchRawData();

    // Build all nodes from raw data.
    final allNodes = _aggregateNodes(data);

    // Sort newest-first.
    allNodes.sort((a, b) => b.date.compareTo(a.date));

    _lastNodes = allNodes;
    _totalNodeCount = allNodes.length;
    _rebuildMonths(allNodes);
    notifyListeners();
  }

  // ── Data fetching ─────────────────────────────────────────

  Future<_RawTimelineData> _fetchRawData() async {
    List<Map<String, dynamic>> commitments = [];
    try {
      commitments = await CommitmentService().getCommitments();
    } catch (_) {
      // Auth or network error — graceful empty
    }

    List<FreshStartLandmark> landmarks = [];
    try {
      landmarks = await FreshStartService().fetchLandmarks();
    } catch (_) {
      // Non-critical — graceful empty
    }

    List<Map<String, dynamic>> conversationEntries = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexRaw = prefs.getString('_chat_conversation_index');
      if (indexRaw != null) {
        final list = jsonDecode(indexRaw) as List<dynamic>;
        conversationEntries = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // SharedPreferences read error
    }

    PartnerEstimate? partner;
    try {
      partner = await PartnerEstimateService.load();
    } catch (_) {
      // SecureStorage error — graceful null
    }

    List<Map<String, dynamic>> documents = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final docsRaw = prefs.getString('_uploaded_documents');
      if (docsRaw != null) {
        final list = jsonDecode(docsRaw) as List<dynamic>;
        documents = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // SharedPreferences read error
    }

    return _RawTimelineData(
      commitments: commitments,
      landmarks: landmarks,
      conversationEntries: conversationEntries,
      partner: partner,
      documents: documents,
    );
  }

  // ── Node aggregation ──────────────────────────────────────

  List<TimelineNode> _aggregateNodes(_RawTimelineData data) {
    final nodes = <TimelineNode>[];

    // Commitment nodes
    for (final c in data.commitments) {
      final status = c['status'] as String? ?? '';
      final id = c['id'] as String? ?? '';
      final isCompleted = status == 'completed';
      final dateStr =
          (isCompleted ? c['updatedAt'] : c['createdAt']) as String? ?? '';
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      nodes.add(TimelineNode(
        type: NodeType.commitment,
        id: 'commitment_$id',
        title: isCompleted
            ? 'timelineCommitmentEarned'
            : 'timelineCommitmentActive',
        subtitle: (c['whenText'] as String? ?? c['ifThenText'] as String? ?? '')
            .toString(),
        deepLink: '/coach/chat?prompt=commitments',
        date: date,
        visualState: isCompleted ? TensionType.earned : TensionType.pulsing,
      ));
    }

    // Conversation nodes
    for (final entry in data.conversationEntries) {
      final id = entry['id'] as String? ?? '';
      final title = entry['title'] as String? ?? '';
      final dateStr = entry['createdAt'] as String? ??
          entry['lastMessageAt'] as String? ??
          '';
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      nodes.add(TimelineNode(
        type: NodeType.conversation,
        id: 'conversation_$id',
        title: 'timelineConversation',
        subtitle: title,
        deepLink: '/coach/chat',
        date: date,
        visualState: TensionType.earned,
      ));
    }

    // Couple node
    if (data.partner != null && data.partner!.isDeclared) {
      nodes.add(TimelineNode(
        type: NodeType.couple,
        id: 'couple_estimate',
        title: 'timelineCoupleEstimate',
        subtitle: '',
        deepLink: '/coach/chat?prompt=partnerQuestions',
        date: DateTime.now(),
        visualState: TensionType.earned,
      ));
    }

    // Projection nodes from landmarks
    for (final landmark in data.landmarks) {
      final date = DateTime.tryParse(landmark.date) ?? DateTime.now();

      nodes.add(TimelineNode(
        type: NodeType.projection,
        id: 'projection_${landmark.type}_${landmark.date}',
        title: 'timelineProjection',
        subtitle: landmark.message,
        deepLink: '/coach/chat?prompt=nextLandmark',
        date: date,
        visualState: TensionType.ghosted,
      ));
    }

    // Document nodes
    for (final doc in data.documents) {
      final id = doc['id'] as String? ?? '';
      final name = doc['name'] as String? ?? '';
      final dateStr = doc['uploadedAt'] as String? ?? '';
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      nodes.add(TimelineNode(
        type: NodeType.document,
        id: 'document_$id',
        title: 'timelineDocument',
        subtitle: name,
        deepLink: '/explorer',
        date: date,
        visualState: TensionType.earned,
      ));
    }

    return nodes;
  }

  // ── Month grouping ────────────────────────────────────────

  void _rebuildMonths(List<TimelineNode> allNodes) {
    // Apply cap
    final visible =
        allNodes.length > _visibleCap ? allNodes.sublist(0, _visibleCap) : allNodes;

    // Group by year-month
    final groups = <String, List<TimelineNode>>{};
    for (final node in visible) {
      final key = '${node.date.year}-${node.date.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(node);
    }

    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Sort group keys newest-first
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    _months = sortedKeys.map((key) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final label = _monthLabel(year, month);
      final nodes = groups[key]!;

      return TimelineMonth(
        label: label,
        year: year,
        month: month,
        nodes: nodes,
        isCurrentMonth: key == currentKey,
      );
    }).toList();
  }

  /// Format month label: "Avril 2026"
  String _monthLabel(int year, int month) {
    const months = [
      '', 'Janvier', 'F\u00e9vrier', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Ao\u00fbt', 'Septembre', 'Octobre', 'Novembre', 'D\u00e9cembre',
    ];
    if (month < 1 || month > 12) return '$year';
    return '${months[month]} $year';
  }
}
