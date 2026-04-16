/// Contract deadline alert service.
///
/// Stores key dates extracted from scanned documents (lease end dates,
/// insurance renewals, LPP certificate validity, etc.) and generates
/// proactive alerts when deadlines approach.
///
/// Data stored in SharedPreferences — no backend needed for V1.
/// Privacy-first: stores dates and labels only, no document content.
///
/// See: MINT_FINAL_EXECUTION_SYSTEM.md §13.11
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A tracked contract deadline.
class ContractDeadline {
  /// Human-readable label (e.g., "Fin de bail Rue des Alpes 12")
  final String label;

  /// The deadline date.
  final DateTime deadline;

  /// Document type that produced this deadline.
  final String documentType;

  /// How many days before deadline to alert (default: 90 for lease, 30 for insurance)
  final int alertDaysBefore;

  /// Whether the user has dismissed this alert.
  bool dismissed;

  ContractDeadline({
    required this.label,
    required this.deadline,
    required this.documentType,
    this.alertDaysBefore = 60,
    this.dismissed = false,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'deadline': deadline.toIso8601String(),
    'documentType': documentType,
    'alertDaysBefore': alertDaysBefore,
    'dismissed': dismissed,
  };

  factory ContractDeadline.fromJson(Map<String, dynamic> json) =>
      ContractDeadline(
        label: json['label'] as String? ?? '',
        deadline: DateTime.parse(json['deadline'] as String),
        documentType: json['documentType'] as String? ?? '',
        alertDaysBefore: json['alertDaysBefore'] as int? ?? 60,
        dismissed: json['dismissed'] as bool? ?? false,
      );

  /// Days remaining until deadline.
  int daysRemaining([DateTime? now]) =>
      deadline.difference(now ?? DateTime.now()).inDays;

  /// Whether this deadline should trigger an alert now.
  bool shouldAlert([DateTime? now]) {
    if (dismissed) return false;
    final remaining = daysRemaining(now);
    return remaining >= 0 && remaining <= alertDaysBefore;
  }
}

/// Manages contract deadlines extracted from scanned documents.
class ContractAlertService {
  static const _key = 'mint_contract_deadlines';

  /// Load all stored deadlines.
  static Future<List<ContractDeadline>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ContractDeadline.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save a new deadline (from document extraction).
  static Future<void> addDeadline(ContractDeadline deadline) async {
    final all = await loadAll();
    // Deduplicate by label + date
    all.removeWhere((d) =>
        d.label == deadline.label &&
        d.deadline.year == deadline.deadline.year &&
        d.deadline.month == deadline.deadline.month);
    all.add(deadline);
    await _save(all);
  }

  /// Get deadlines that should alert now.
  static Future<List<ContractDeadline>> getActiveAlerts([DateTime? now]) async {
    final all = await loadAll();
    return all.where((d) => d.shouldAlert(now)).toList()
      ..sort((a, b) => a.daysRemaining(now).compareTo(b.daysRemaining(now)));
  }

  /// Dismiss an alert (user acknowledged it).
  static Future<void> dismiss(String label) async {
    final all = await loadAll();
    for (final d in all) {
      if (d.label == label) d.dismissed = true;
    }
    await _save(all);
  }

  /// Remove expired deadlines (past date + 30 days).
  static Future<void> cleanup([DateTime? now]) async {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 30));
    final all = await loadAll();
    all.removeWhere((d) => d.deadline.isBefore(cutoff));
    await _save(all);
  }

  static Future<void> _save(List<ContractDeadline> deadlines) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(deadlines.map((d) => d.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
