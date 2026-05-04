/// MINT breadcrumb helper — PII-safe, D-03 4-level category literals.
///
/// Phase 31 OBS-05 (Wave 1, Plan 31-01).
///
/// Every data-payload key is ENUM / INT / BOOL only. NEVER put user-
/// generated strings (fact values, banned-term contents, error messages,
/// IBANs, AVS numbers, CHF amounts). Pitfall 6 mitigation — enforced at
/// the API surface and by `sentry_breadcrumbs_pii_test.dart` fuzzing.
///
/// D-03 locked 4-level category literals (CONTEXT.md §Implementation
/// Decisions):
///   - mint.compliance.guard.pass         / mint.compliance.guard.fail
///   - mint.coach.save_fact.success       / mint.coach.save_fact.error
///   - mint.feature_flags.refresh.success / mint.feature_flags.refresh.failure
///
/// The outcome lives in the CATEGORY STRING (4th dotted segment) — NOT
/// only in `SentryLevel`. This enables Sentry UI search like
/// `event.category:mint.compliance.guard.pass`. The `SentryLevel` is set
/// in parallel for ops filtering but is orthogonal to the category.
///
/// Intermediate `tool` segment (`mint.coach.tool.save_fact.*`) is
/// REJECTED per D-03 revision; the 4-level form `mint.coach.save_fact.*`
/// is the only accepted literal.
library;

import 'package:sentry_flutter/sentry_flutter.dart';

/// Static-only helper. All methods emit a single `Breadcrumb` via
/// `Sentry.addBreadcrumb`. They are safe to call when Sentry is not
/// initialised (the SDK no-ops in that case).
class MintBreadcrumbs {
  MintBreadcrumbs._();

  /// Compliance guard validate() outcome breadcrumb.
  ///
  /// category = `mint.compliance.guard.pass` when [passed] is true,
  ///            `mint.compliance.guard.fail` otherwise.
  /// level    = info on pass, warning on fail.
  /// data     = { 'passed': bool, 'surface': String,
  ///              'flagged_count': int? }
  ///
  /// [flaggedTerms] is accepted for ergonomics at the call site but ONLY
  /// its `.length` is emitted (as `flagged_count`). The term strings
  /// themselves MUST NOT reach Sentry — they contain the banned
  /// financial vocabulary the guard is meant to suppress (A1 secondary
  /// PITFALLS.md / nLPD).
  static void complianceGuard({
    required bool passed,
    required String surface,
    List<String>? flaggedTerms,
  }) {
    final category = passed
        ? 'mint.compliance.guard.pass'
        : 'mint.compliance.guard.fail';
    final data = <String, dynamic>{
      'passed': passed,
      'surface': surface,
      if (flaggedTerms != null) 'flagged_count': flaggedTerms.length,
    };
    Sentry.addBreadcrumb(Breadcrumb(
      category: category,
      level: passed ? SentryLevel.info : SentryLevel.warning,
      data: data,
    ));
  }

  /// Coach `save_fact` tool-call outcome breadcrumb.
  ///
  /// category = `mint.coach.save_fact.success` when [success] is true,
  ///            `mint.coach.save_fact.error` otherwise. (D-03 4-level —
  /// NO intermediate `tool` segment.)
  /// level    = info on success, error on failure.
  /// data     = { 'success': bool, 'fact_kind': String,
  ///              'error_code': String? }
  ///
  /// [factKind] is an ENUM STRING (e.g. `'income'`, `'housing'`,
  /// `'family'`, `'third_pillar_balance'`) — NEVER the fact value.
  /// Leaking the value would regress Pitfall 6 (CHF amounts, AVS
  /// numbers, IBANs reaching Sentry).
  static void saveFact({
    required bool success,
    required String factKind,
    String? errorCode,
  }) {
    final category = success
        ? 'mint.coach.save_fact.success'
        : 'mint.coach.save_fact.error';
    final data = <String, dynamic>{
      'success': success,
      'fact_kind': factKind,
      if (errorCode != null) 'error_code': errorCode,
    };
    Sentry.addBreadcrumb(Breadcrumb(
      category: category,
      level: success ? SentryLevel.info : SentryLevel.error,
      data: data,
    ));
  }

  /// FeatureFlags refresh outcome breadcrumb.
  ///
  /// category = `mint.feature_flags.refresh.success` on success,
  ///            `mint.feature_flags.refresh.failure` on failure.
  /// (NOTE: failure literal is `failure` — NOT `error` — per CONTEXT.md
  /// D-03 asymmetry; feature-flag refresh can fail on network/parse
  /// without an uncaught exception.)
  /// level    = info on success, warning on failure.
  /// data     = { 'success': bool, 'error_code': String?,
  ///              'flag_count': int? }
  static void featureFlagsRefresh({
    required bool success,
    String? errorCode,
    int? flagCount,
  }) {
    final category = success
        ? 'mint.feature_flags.refresh.success'
        : 'mint.feature_flags.refresh.failure';
    final data = <String, dynamic>{
      'success': success,
      if (errorCode != null) 'error_code': errorCode,
      if (flagCount != null) 'flag_count': flagCount,
    };
    Sentry.addBreadcrumb(Breadcrumb(
      category: category,
      level: success ? SentryLevel.info : SentryLevel.warning,
      data: data,
    ));
  }

  /// Phase 32 MAP-05 — legacy redirect hit breadcrumb.
  ///
  /// category = `mint.routing.legacy_redirect.hit`
  /// level    = info
  /// data     = { 'from': String, 'to': String }
  ///
  /// nLPD D-09: [from] and [to] are path-only (no query string, no
  /// user id). Callers MUST pass `state.uri.path` (which excludes query
  /// by go_router contract) — NOT `state.uri.toString()`.
  static void legacyRedirectHit({
    required String from,
    required String to,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'mint.routing.legacy_redirect.hit',
      level: SentryLevel.info,
      data: <String, dynamic>{
        'from': from,
        'to': to,
      },
    ));
  }

  /// Phase 32 D-09 §4 — admin tool access processing record (nLPD Art. 12).
  ///
  /// category = `mint.admin.routes.viewed`
  /// level    = info
  /// data     = { 'route_count': int, 'feature_flags_enabled_count': int,
  ///              'snapshot_age_minutes': int? }
  ///
  /// **Aggregates only.** MUST NOT contain: user identifiers, route paths,
  /// query params, email, IP, or any other PII. The parameter surface
  /// here is int/int? — reviewers can verify no String field reaches Sentry.
  static void adminRoutesViewed({
    required int routeCount,
    required int featureFlagsEnabledCount,
    int? snapshotAgeMinutes,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'mint.admin.routes.viewed',
      level: SentryLevel.info,
      data: <String, dynamic>{
        'route_count': routeCount,
        'feature_flags_enabled_count': featureFlagsEnabledCount,
        if (snapshotAgeMinutes != null) 'snapshot_age_minutes': snapshotAgeMinutes,
      },
    ));
  }
}
