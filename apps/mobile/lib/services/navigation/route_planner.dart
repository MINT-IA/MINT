/// RoutePlanner — decides how to handle a user intent arriving from the chat.
///
/// ## Principle (NON-NEGOTIABLE)
/// The LLM decides the intention. The code decides the routing.
/// The LLM never returns a raw `context.push('/route')`. It returns an
/// [intentTag] + [confidence], and this class consults the [ScreenRegistry]
/// and [ReadinessGate] to produce the final [RouteDecision].
///
/// ## Usage
/// ```dart
/// final planner = RoutePlanner(
///   registry: registry,
///   profile: coachProfile,
/// );
/// final decision = planner.plan('retirement_choice', confidence: 0.85);
/// switch (decision.action) {
///   case RouteAction.openScreen:
///     context.push(decision.route!);
///   case RouteAction.openWithWarning:
///     context.push(decision.route!, extra: {'missingFields': decision.missingFields});
///   case RouteAction.askFirst:
///     coachAskMissingFields(decision.missingFields!);
///   case RouteAction.conversationOnly:
///     // Coach handles inline
/// }
/// ```
///
/// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §6
library;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/navigation/readiness_gate.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

// ════════════════════════════════════════════════════════════════
//  ROUTE ACTION
// ════════════════════════════════════════════════════════════════

/// The action the app should take in response to a resolved intent.
enum RouteAction {
  /// Open the target screen directly. [RouteDecision.route] is set.
  openScreen,

  /// Open the target screen in estimation/warning mode.
  /// [RouteDecision.missingFields] lists the fields that would improve accuracy.
  openWithWarning,

  /// Do not open a screen yet — ask the user for the missing critical fields
  /// via the chat's `ask_user_input` tool, then re-plan.
  /// [RouteDecision.missingFields] lists exactly what must be gathered.
  askFirst,

  /// No screen is appropriate. The Coach handles the intent inline.
  /// This is the safe fallback for unknown intents, low confidence,
  /// and type-E (conversation-only) surfaces.
  conversationOnly,
}

// ════════════════════════════════════════════════════════════════
//  ROUTE DECISION
// ════════════════════════════════════════════════════════════════

/// The result of [RoutePlanner.plan].
///
/// Immutable value object consumed by the chat orchestration layer.
class RouteDecision {
  /// The action to take.
  final RouteAction action;

  /// The canonical GoRouter route to navigate to.
  ///
  /// Non-null for [RouteAction.openScreen] and [RouteAction.openWithWarning].
  /// Null for [RouteAction.askFirst] and [RouteAction.conversationOnly].
  final String? route;

  /// Fields that are absent from the profile and triggered this decision.
  ///
  /// Non-null (and non-empty) for [RouteAction.askFirst] and
  /// [RouteAction.openWithWarning]. These are surfaced to the Coach so it
  /// can ask focused questions (maximum 1–2 per interaction).
  final List<String>? missingFields;

  /// Prefill values extracted from [CoachProfile] to pass to the screen.
  ///
  /// The receiving screen uses these as initial hypothesis values so the
  /// user sees their own numbers immediately rather than defaults.
  /// Keys match the screen's own parameter contract.
  final Map<String, dynamic>? prefill;

  const RouteDecision({
    required this.action,
    this.route,
    this.missingFields,
    this.prefill,
  });

  /// Open a screen directly, optionally with prefill data.
  const RouteDecision.openScreen(
    String route, {
    Map<String, dynamic>? prefill,
  }) : this(
          action: RouteAction.openScreen,
          route: route,
          prefill: prefill,
        );

  /// Open a screen in estimation/warning mode with a list of missing fields.
  const RouteDecision.openWithWarning(
    String route, {
    required List<String> missingFields,
    Map<String, dynamic>? prefill,
  }) : this(
          action: RouteAction.openWithWarning,
          route: route,
          missingFields: missingFields,
          prefill: prefill,
        );

  /// Instruct the Coach to ask for missing critical fields before routing.
  const RouteDecision.askFirst(List<String> missingFields)
      : this(
          action: RouteAction.askFirst,
          missingFields: missingFields,
        );

  /// Coach handles the intent inline — no screen should be opened.
  const RouteDecision.conversationOnly()
      : this(action: RouteAction.conversationOnly);

  /// Whether a route will be opened (either directly or with a warning).
  bool get willNavigate =>
      action == RouteAction.openScreen ||
      action == RouteAction.openWithWarning;

  @override
  String toString() => 'RouteDecision('
      'action: $action, '
      'route: $route, '
      'missingFields: $missingFields, '
      'prefill: $prefill'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteDecision &&
        other.action == action &&
        other.route == route;
  }

  @override
  int get hashCode => Object.hash(action, route);
}

// ════════════════════════════════════════════════════════════════
//  ROUTE PLANNER
// ════════════════════════════════════════════════════════════════

/// Decides how to handle a user intent from the chat.
///
/// Stateless — all decisions are based on the [ScreenRegistry],
/// [CoachProfile], and the optional [BudgetSnapshotData] passed at
/// construction. Construct a new instance whenever the profile changes.
///
/// ## Decision algorithm
///
/// 1. If [confidence] < [confidenceThreshold] → [RouteAction.conversationOnly]
/// 2. Look up [intentTag] in [registry] → not found → [RouteAction.conversationOnly]
/// 3. If [entry.behavior] is [ScreenBehavior.directAnswer] or
///    [ScreenBehavior.conversationOnly] → [RouteAction.conversationOnly]
/// 4. If [entry.preferFromChat] == false → [RouteAction.conversationOnly]
/// 5. Evaluate [ReadinessGate] → [ReadinessLevel.ready] / partial / blocked
/// 6. Return matching [RouteDecision]
class RoutePlanner {
  /// Minimum LLM confidence to attempt routing to a screen.
  ///
  /// Below this threshold the intent is considered ambiguous and the Coach
  /// handles the message inline (asks for clarification).
  static const double confidenceThreshold = 0.5;

  /// The surface registry to look up intent tags.
  final ScreenRegistry registry;

  /// The current user profile — used for readiness checks and prefill.
  final CoachProfile profile;

  /// Optional budget snapshot — reserved for future prefill enrichment.
  /// Not currently used in routing decisions.
  final BudgetSnapshotData? snapshot;

  /// The gate that evaluates field readiness.
  final ReadinessGate _gate;

  RoutePlanner({
    required this.registry,
    required this.profile,
    this.snapshot,
    ReadinessGate? gate,
  }) : _gate = gate ?? const ReadinessGate();

  /// Determine the best action for the given [intentTag] and [confidence].
  ///
  /// [intentTag] — the semantic tag returned by the LLM's IntentResolver.
  /// [confidence] — the LLM's confidence in the resolved intent (0.0–1.0).
  RouteDecision plan(String intentTag, {double confidence = 1.0}) {
    // Step 1: low confidence → stay in conversation
    if (confidence < confidenceThreshold) {
      return const RouteDecision.conversationOnly();
    }

    // Step 2: look up the intent in the registry
    final entry = registry.findByIntent(intentTag);
    if (entry == null) {
      return const RouteDecision.conversationOnly();
    }

    // Step 3: surfaces that are inherently inline or conversation-only
    if (entry.behavior == ScreenBehavior.directAnswer ||
        entry.behavior == ScreenBehavior.conversationPure) {
      return const RouteDecision.conversationOnly();
    }

    // Step 4: some surfaces are not routable from chat (admin, auth, etc.)
    if (!entry.preferFromChat) {
      return const RouteDecision.conversationOnly();
    }

    // Step 5: readiness gate
    final readiness = _gate.evaluate(entry, profile);

    switch (readiness.level) {
      case ReadinessLevel.ready:
        final prefill =
            entry.prefillFromProfile ? _buildPrefill(entry) : null;
        return RouteDecision.openScreen(entry.route, prefill: prefill);

      case ReadinessLevel.partial:
        final prefill =
            entry.prefillFromProfile ? _buildPrefill(entry) : null;
        return RouteDecision.openWithWarning(
          entry.route,
          missingFields: readiness.missingFields,
          prefill: prefill,
        );

      case ReadinessLevel.blocked:
        return RouteDecision.askFirst(readiness.missingFields);
    }
  }

  // ── Prefill builder ─────────────────────────────────────────────

  /// Builds a prefill map from the profile for the given [entry].
  ///
  /// Only includes non-null values. The receiving screen is responsible for
  /// interpreting the keys according to its own parameter contract.
  Map<String, dynamic>? _buildPrefill(ScreenEntry entry) {
    final fields = [
      ...entry.requiredFields,
      ...entry.optionalFields,
    ];
    if (fields.isEmpty) return null;

    final prefill = <String, dynamic>{};
    for (final field in fields) {
      final value = _resolveProfileValue(field);
      if (value != null) {
        prefill[field] = value;
      }
    }
    return prefill.isEmpty ? null : prefill;
  }

  /// Resolves a profile field by key into a prefill-safe value.
  ///
  /// Keys use the same naming convention as [ReadinessGate._resolveField]
  /// so the same field list from [ScreenEntry.requiredFields] and
  /// [ScreenEntry.optionalFields] can drive both readiness checks and prefill.
  dynamic _resolveProfileValue(String key) {
    switch (key) {
      case 'age':
        return profile.age > 0 ? profile.age : null;
      case 'canton':
        return profile.canton.isNotEmpty ? profile.canton : null;
      case 'nationality':
        return profile.nationality;
      case 'employmentStatus':
        return profile.employmentStatus.isNotEmpty
            ? profile.employmentStatus
            : null;
      case 'civilStatus':
        return profile.etatCivil.name;
      case 'residencePermit':
        return profile.residencePermit;
      // Income — registry uses 'salaireBrut' as canonical key
      case 'salaireBrut':
      case 'salaireBrutMensuel':
        return profile.salaireBrutMensuel > 0
            ? profile.salaireBrutMensuel
            : null;
      case 'netIncome':
        return profile.salaireBrutMensuel > 0
            ? profile.salaireBrutMensuel
            : null;
      // Prevoyance
      case 'avoirLpp':
        return profile.prevoyance.avoirLppTotal;
      case 'rachatMaximum':
        return profile.prevoyance.rachatMaximum;
      case 'epargne3a':
        return profile.prevoyance.totalEpargne3a > 0
            ? profile.prevoyance.totalEpargne3a
            : null;
      // Patrimoine
      case 'epargne':
        return profile.patrimoine.epargneLiquide > 0
            ? profile.patrimoine.epargneLiquide
            : null;
      // Household
      case 'conjoint':
        return profile.conjoint;
      // Other
      case 'riskTolerance':
        return profile.riskTolerance;
      case 'housingStatus':
        return profile.housingStatus;
      case 'nombreEnfants':
        return profile.nombreEnfants > 0 ? profile.nombreEnfants : null;
      default:
        return null;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  BUDGET SNAPSHOT DATA (minimal stub)
// ════════════════════════════════════════════════════════════════

/// Minimal data container for the optional budget snapshot passed to
/// [RoutePlanner].
///
/// The full BudgetSnapshot is defined elsewhere in the codebase. This stub
/// allows RoutePlanner to accept a snapshot reference for future enrichment
/// (e.g. prefilling the monthly budget screen with current numbers)
/// without creating a circular dependency.
///
/// Replace with the real BudgetSnapshot type once the dependency graph allows.
class BudgetSnapshotData {
  /// Estimated monthly free cash flow.
  final double? monthlyFree;

  /// Estimated monthly income (net).
  final double? monthlyIncome;

  const BudgetSnapshotData({
    this.monthlyFree,
    this.monthlyIncome,
  });
}
