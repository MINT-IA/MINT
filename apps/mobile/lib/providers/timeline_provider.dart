/// TimelineProvider — extends TensionCardProvider with full timeline nodes.
///
/// Phase 18: Full Living Timeline. Aggregates nodes from commitments,
/// conversations, partner estimates, landmarks, and documents into a
/// month-grouped timeline for the Aujourd'hui tab.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/tension_card_provider.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';

/// Raw data fetched from services, cached to avoid double-fetching.
class _RawTimelineData {
  final List<Map<String, dynamic>> commitments;
  final List<FreshStartLandmark> landmarks;
  final List<Map<String, dynamic>> conversationEntries;
  final PartnerEstimate? partner;
  final List<ConfirmedDocumentReference> documents;

  const _RawTimelineData({
    required this.commitments,
    required this.landmarks,
    required this.conversationEntries,
    required this.partner,
    required this.documents,
  });
}

class TimelineProvider extends TensionCardProvider {
  TimelineProvider({
    DocumentReferenceStore? documentReferenceStore,
    super.sessionEpoch,
  }) : _documentReferenceStore =
            documentReferenceStore ?? DocumentReferenceStore();

  final DocumentReferenceStore _documentReferenceStore;
  CoachProfileProvider? _ledger;
  DocumentProvider? _documents;
  bool _documentUpdateScheduled = false;
  bool _disposed = false;
  List<TimelineMonth> _months = [];
  int _visibleCap = 50;
  int _totalNodeCount = 0;

  /// Month-grouped timeline nodes, sorted newest-first.
  List<TimelineMonth> get months => _months;

  /// Whether more nodes are available beyond the visible cap.
  bool get hasMore => _totalNodeCount > _visibleCap;

  /// Whether at least one node exists.
  bool get hasNodes => _totalNodeCount > 0;

  @override
  void clearSessionMemoryAfterPurge() {
    _months = [];
    _visibleCap = 50;
    _totalNodeCount = 0;
    _lastNodes = [];
    super.clearSessionMemoryAfterPurge();
  }

  void bindLedger(CoachProfileProvider ledger) {
    _ledger = ledger;
  }

  void bindDocuments(DocumentProvider documents) {
    if (identical(_documents, documents)) return;
    _documents?.removeListener(_onDocumentsChanged);
    _documents = documents;
    documents.addListener(_onDocumentsChanged);
  }

  /// Opens document projection only after the composition-root session gate.
  void activateAfterSessionReady() => _scheduleDocumentProjection();

  void _onDocumentsChanged() => _scheduleDocumentProjection();

  void _scheduleDocumentProjection() {
    if (_documentUpdateScheduled) return;
    late final SessionEpochGuard guard;
    try {
      guard = sessionEpoch.capture();
    } on SessionEpochInvalidated {
      return;
    }
    _documentUpdateScheduled = true;
    scheduleMicrotask(() {
      _documentUpdateScheduled = false;
      if (_disposed) return;
      try {
        guard.assertCurrent();
      } on SessionEpochInvalidated {
        return;
      }
      _rebuildDocumentProjection();
    });
  }

  void _rebuildDocumentProjection() {
    if (sessionEpoch.isTerminationBlocked) return;
    final documents = _documents?.currentReferences ?? const [];
    final nodes = <TimelineNode>[
      ..._lastNodes.where((node) => node.type != NodeType.document),
      ...documents.map(_documentNode),
    ]..sort((a, b) => b.date.compareTo(a.date));
    _lastNodes = nodes;
    _totalNodeCount = nodes.length;
    _rebuildMonths(nodes);
    notifyListeners();
  }

  /// Increase visible cap by 20 and regroup.
  void loadMore() {
    if (sessionEpoch.isTerminationBlocked) return;
    _visibleCap += 20;
    _rebuildMonths(_lastNodes);
    notifyListeners();
  }

  // ── Cached raw nodes (pre-cap) ────────────────────────────
  List<TimelineNode> _lastNodes = [];

  @override
  Future<void> refresh({bool includeAuthenticatedNetwork = true}) async {
    final guard = sessionEpoch.capture();
    // Parent populates tension cards + loop position.
    await super.refresh(
      includeAuthenticatedNetwork: includeAuthenticatedNetwork,
    );

    // Fetch raw data for timeline nodes.
    final data = await _fetchRawData(
      includeAuthenticatedNetwork: includeAuthenticatedNetwork,
    );
    guard.assertCurrent();

    // Build all nodes from raw data.
    final allNodes = _aggregateNodes(data);

    // Sort newest-first.
    allNodes.sort((a, b) => b.date.compareTo(a.date));

    _lastNodes = allNodes;
    _totalNodeCount = allNodes.length;
    _rebuildMonths(allNodes);
    guard.assertCurrent();
    notifyListeners();
  }

  // ── Data fetching ─────────────────────────────────────────

  Future<_RawTimelineData> _fetchRawData({
    required bool includeAuthenticatedNetwork,
  }) async {
    List<Map<String, dynamic>> commitments = [];
    if (includeAuthenticatedNetwork) {
      try {
        commitments = await CommitmentService().getCommitments();
      } catch (_) {
        // Auth or network error — graceful empty
      }
    }

    List<FreshStartLandmark> landmarks = [];
    if (includeAuthenticatedNetwork) {
      try {
        landmarks = await FreshStartService().fetchLandmarks();
      } catch (_) {
        // Non-critical — graceful empty
      }
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

    List<ConfirmedDocumentReference> documents = const [];
    try {
      final boundDocuments = _documents;
      if (boundDocuments != null) {
        documents = boundDocuments.currentReferences;
      } else {
        final ledger = _ledger;
        if (ledger == null || !ledger.isLoaded) {
          return _RawTimelineData(
            commitments: commitments,
            landmarks: landmarks,
            conversationEntries: conversationEntries,
            partner: partner,
            documents: documents,
          );
        }
        final stored = await _documentReferenceStore.load();
        documents = stored
            .where(
              (reference) =>
                  ledger.currentLppSnapshotId(reference.ownerKind) ==
                  reference.snapshotId,
            )
            .toList(growable: false);
      }
    } catch (_) {
      // A malformed/unavailable reference root is an empty document source.
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
        deepLink: '/coach/chat?topic=commitments',
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
        deepLink: '/coach/chat?topic=partnerQuestions',
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
        deepLink: '/coach/chat?topic=nextLandmark',
        date: date,
        visualState: TensionType.ghosted,
      ));
    }

    // Document nodes
    for (final doc in data.documents) {
      nodes.add(_documentNode(doc));
    }

    return nodes;
  }

  TimelineNode _documentNode(ConfirmedDocumentReference doc) => TimelineNode(
        type: NodeType.document,
        id: 'document_${doc.referenceId}',
        title: 'timelineDocument',
        subtitle: '',
        deepLink: '/documents/${doc.referenceId}',
        date: doc.confirmedAt,
        visualState: TensionType.earned,
      );

  // ── Month grouping ────────────────────────────────────────

  void _rebuildMonths(List<TimelineNode> allNodes) {
    // Apply cap
    final visible = allNodes.length > _visibleCap
        ? allNodes.sublist(0, _visibleCap)
        : allNodes;

    // Group by year-month
    final groups = <String, List<TimelineNode>>{};
    for (final node in visible) {
      final key =
          '${node.date.year}-${node.date.month.toString().padLeft(2, '0')}';
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
      '',
      'Janvier',
      'F\u00e9vrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Ao\u00fbt',
      'Septembre',
      'Octobre',
      'Novembre',
      'D\u00e9cembre',
    ];
    if (month < 1 || month > 12) return '$year';
    return '${months[month]} $year';
  }

  @override
  void dispose() {
    _disposed = true;
    _documents?.removeListener(_onDocumentsChanged);
    super.dispose();
  }
}
