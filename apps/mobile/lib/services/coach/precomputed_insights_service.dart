// ────────────────────────────────────────────────────────────
//  PRECOMPUTED INSIGHTS SERVICE — S52 / Cleo 3.0 pattern
// ────────────────────────────────────────────────────────────
//
// Cleo 3.0 pre-computes insights in batch (scheduled job → S3 → instant
// at app open). MINT mirrors this pattern: insights are computed and
// cached at profile-change time (MintStateProvider._doRecompute), then
// read instantly at greeting time.
//
// Design:
//  - Compute once at profile change — never at greeting time.
//  - Store type + numeric params in SharedPreferences (JSON).
//  - Resolve i18n at read time using the real AppLocalizations context.
//  - Stale threshold: 1 hour (insights may change if profile is updated
//    from another session or via background sync).
//  - Falls back gracefully: cache miss → synchronous DataDrivenOpener.
//
// Privacy:
//  - Params store only CHF amounts and percentages — no names, IBANs,
//    employer, or other PII.
//  - SharedPreferences key uses a non-identifiable prefix.
//
// Compliance:
//  - No user-facing strings stored — only ARB key enum + numeric params.
//  - i18n resolution happens at display time (real locale, real context).
//  - Non-breaking space (\u00a0) applied by ARB templates, not here.
// ────────────────────────────────────────────────────────────
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/coach/data_driven_opener_service.dart';

// ════════════════════════════════════════════════════════════════
//  CONSTANTS
// ════════════════════════════════════════════════════════════════

/// SharedPreferences key for the cached insight JSON blob.
const String _kInsightCacheKey = 'mint_precomputed_insight_v1';

/// Maximum age of a cached insight before it is considered stale.
const Duration _kStaleDuration = Duration(hours: 1);

// ════════════════════════════════════════════════════════════════
//  MODEL
// ════════════════════════════════════════════════════════════════

/// A pre-computed insight stored as type + raw numeric params.
///
/// i18n resolution is deferred to read time via [resolve] using the
/// real [AppLocalizations] instance from the widget tree.
///
/// Params keys match the positional argument names used in ARB templates:
///
///   budgetAlert          → {'deficit': '350'}
///   deadlineUrgency      → {'daysLeft': '17', 'plafond': '7258'}
///   gapWarning           → {'rate': '55', 'gap': '1200'}
///   savingsOpportunity   → {'plafond': '7258'}
///   progressCelebration  → {'delta': '6'}
///   planProgress         → {'completed': '2', 'total': '5', 'next': 'step_label_key'}
class PrecomputedInsight {
  /// The type of opener — determines which ARB template to use.
  final DataOpenerType type;

  /// Raw numeric/string parameters for the ARB template.
  ///
  /// Values are pre-formatted strings (rounded integers, etc.) to avoid
  /// floating-point formatting issues at read time.
  final Map<String, String> params;

  /// Optional GoRouter intent tag for the first suggestion chip.
  final String? intentTag;

  /// When this insight was computed.
  final DateTime computedAt;

  const PrecomputedInsight({
    required this.type,
    required this.params,
    this.intentTag,
    required this.computedAt,
  });

  // ── Serialisation ────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'params': params,
        if (intentTag != null) 'intentTag': intentTag,
        'computedAt': computedAt.toIso8601String(),
      };

  factory PrecomputedInsight.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? '';
    final type = DataOpenerType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => DataOpenerType.savingsOpportunity,
    );
    final rawParams = json['params'];
    final Map<String, String> params;
    if (rawParams is Map) {
      params = Map<String, String>.from(
        rawParams.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    } else {
      params = {};
    }
    return PrecomputedInsight(
      type: type,
      params: params,
      intentTag: json['intentTag'] as String?,
      computedAt: DateTime.tryParse(json['computedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  // ── Staleness ────────────────────────────────────────────────

  /// Whether this insight is older than [_kStaleDuration].
  ///
  /// Pass [now] to override [DateTime.now] for deterministic tests.
  bool isStale([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return reference.difference(computedAt) > _kStaleDuration;
  }

  // ── i18n resolution ──────────────────────────────────────────

  /// Resolve the pre-computed insight to a displayable [DataDrivenOpener]
  /// using the caller's real [AppLocalizations] instance.
  ///
  /// Returns null if params are malformed or the type cannot be resolved.
  DataDrivenOpener? resolve(S l) {
    try {
      final message = _resolveMessage(l);
      if (message == null || message.isEmpty) return null;
      return DataDrivenOpener(
        message: message,
        intentTag: intentTag,
        type: type,
      );
    } catch (_) {
      return null;
    }
  }

  String? _resolveMessage(S l) {
    switch (type) {
      case DataOpenerType.budgetAlert:
        final deficit = params['deficit'];
        if (deficit == null) return null;
        return l.openerBudgetDeficit(deficit);

      case DataOpenerType.deadlineUrgency:
        final daysLeft = params['daysLeft'];
        final plafond = params['plafond'];
        if (daysLeft == null || plafond == null) return null;
        return l.opener3aDeadline(daysLeft, plafond);

      case DataOpenerType.gapWarning:
        final rate = params['rate'];
        final gap = params['gap'];
        if (rate == null || gap == null) return null;
        return l.openerGapWarning(rate, gap);

      case DataOpenerType.savingsOpportunity:
        final plafond = params['plafond'];
        if (plafond == null) return null;
        return l.openerSavingsOpportunity(plafond);

      case DataOpenerType.progressCelebration:
        final delta = params['delta'];
        if (delta == null) return null;
        return l.openerProgressCelebration(delta);

      case DataOpenerType.planProgress:
        final completed = params['completed'];
        final total = params['total'];
        final next = params['next'];
        if (completed == null || total == null || next == null) return null;
        // Resolve the titleKey via the DataDrivenOpenerService helper.
        // Falls back to the raw titleKey string when not found.
        final resolvedNext =
            DataDrivenOpenerService.resolveCapStepTitle(next, l) ?? next;
        return l.openerPlanProgress(completed, total, resolvedNext);
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Pre-computes and caches [DataDrivenOpener] insights at profile-change
/// time, so they are available instantly at greeting time.
///
/// Lifecycle:
///   1. [MintStateProvider._doRecompute] calls [computeAndCache] after
///      the new [MintUserState] is ready.
///   2. The greeting flow calls [getCachedInsight] — returns immediately,
///      no recomputation.
///   3. If stale or missing, the caller falls back to synchronous
///      [DataDrivenOpenerService.generate].
///
/// All methods are static — no instantiation.
class PrecomputedInsightsService {
  PrecomputedInsightsService._();

  // ── Public API ────────────────────────────────────────────────

  /// Compute an insight from [state] and write it to [prefs].
  ///
  /// Uses [SFr] (French fallback) so this can be called without a
  /// [BuildContext] — same pattern as [MintStateEngine] and CapEngine.
  /// The raw params are stored; i18n is resolved at read time with the
  /// real locale.
  ///
  /// Pass [now] to override [DateTime.now] for deterministic tests.
  ///
  /// Silent degradation: never throws. If computation fails, the cache
  /// is left unchanged (stale is preferable to corrupt).
  static Future<void> computeAndCache({
    required MintUserState state,
    required SharedPreferences prefs,
    DateTime? now,
  }) async {
    try {
      // French fallback — same pattern as MintStateEngine.
      final frL10n = SFr();
      final currentDate = now ?? DateTime.now();

      final opener = DataDrivenOpenerService.generate(
        state: state,
        l: frL10n,
        now: currentDate,
      );

      if (opener == null) {
        // No interesting data point — clear any stale entry.
        await prefs.remove(_kInsightCacheKey);
        return;
      }

      final insight = _openerToInsight(opener, state, currentDate);
      if (insight == null) {
        await prefs.remove(_kInsightCacheKey);
        return;
      }

      await prefs.setString(
        _kInsightCacheKey,
        jsonEncode(insight.toJson()),
      );
    } catch (_) {
      // Silent degradation — never crash the recompute pipeline.
    }
  }

  /// Read the most recently cached insight.
  ///
  /// Returns null if:
  ///   - No cache exists (first launch or cleared).
  ///   - Cache is stale (> 1 hour old).
  ///   - Cache JSON is malformed.
  ///
  /// Called at greeting time — instant, no heavy I/O.
  ///
  /// Pass [now] to override [DateTime.now] for deterministic tests.
  static Future<PrecomputedInsight?> getCachedInsight({
    required SharedPreferences prefs,
    DateTime? now,
  }) async {
    try {
      final raw = prefs.getString(_kInsightCacheKey);
      if (raw == null || raw.isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final insight = PrecomputedInsight.fromJson(json);

      if (insight.isStale(now)) return null;

      return insight;
    } catch (_) {
      return null;
    }
  }

  /// Clear all cached insights.
  ///
  /// Call on sign-out, data reset, or when forcing a full recompute.
  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(_kInsightCacheKey);
  }

  // ── Private helpers ────────────────────────────────────────────

  /// Convert a [DataDrivenOpener] to a [PrecomputedInsight] by extracting
  /// locale-independent raw params from [state].
  ///
  /// Re-extracts params directly from the state (not from the formatted
  /// message string) to preserve locale-independent integer values.
  static PrecomputedInsight? _openerToInsight(
    DataDrivenOpener opener,
    MintUserState state,
    DateTime now,
  ) {
    final Map<String, String> params;

    switch (opener.type) {
      case DataOpenerType.budgetAlert:
        final snapshot = state.budgetSnapshot;
        if (snapshot == null || !snapshot.present.isDeficit) return null;
        final deficit = snapshot.present.monthlyFree.abs().round();
        params = {'deficit': deficit.toString()};

      case DataOpenerType.deadlineUrgency:
        final daysLeft =
            DateTime(now.year, 12, 31).difference(now).inDays + 1;
        if (daysLeft <= 0) return null;
        final isIndepNoLpp =
            state.archetype == FinancialArchetype.independentNoLpp;
        final plafond =
            isIndepNoLpp ? _kPlafondSansLpp : _kPlafondAvecLpp;
        params = {
          'daysLeft': daysLeft.toString(),
          'plafond': plafond.round().toString(),
        };

      case DataOpenerType.gapWarning:
        final rate = state.replacementRate;
        final gap = state.budgetSnapshot?.gap?.monthlyGap;
        if (rate == null || gap == null || gap <= 0) return null;
        params = {
          'rate': rate.round().toString(),
          'gap': gap.round().toString(),
        };

      case DataOpenerType.savingsOpportunity:
        final isIndepNoLpp =
            state.archetype == FinancialArchetype.independentNoLpp;
        final plafond =
            isIndepNoLpp ? _kPlafondSansLpp : _kPlafondAvecLpp;
        params = {'plafond': plafond.round().toString()};

      case DataOpenerType.progressCelebration:
        // progressCelebration requires previousConfidenceScore which is not
        // part of MintUserState (it is session-transient). We cannot safely
        // reconstruct the delta here — skip caching this type and let the
        // synchronous fallback handle it at greeting time.
        return null;

      case DataOpenerType.planProgress:
        final sequence = state.capSequencePlan;
        if (sequence == null || !sequence.hasSteps) return null;
        if (sequence.completedCount == 0) return null;
        final next = sequence.currentStep ?? sequence.nextStep;
        if (next == null) return null;
        params = {
          'completed': sequence.completedCount.toString(),
          'total': sequence.totalCount.toString(),
          'next': next.titleKey, // resolved to i18n at display time
        };
    }

    return PrecomputedInsight(
      type: opener.type,
      params: params,
      intentTag: opener.intentTag,
      computedAt: now,
    );
  }

  /// 3a plafond salarié avec LPP (OPP3 2025/2026).
  static const double _kPlafondAvecLpp = 7258.0;

  /// 3a plafond indépendant sans LPP (OPP3 2025/2026).
  static const double _kPlafondSansLpp = 36288.0;
}
