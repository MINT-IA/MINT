// Subscription service for MINT Coach paywall.
//
// Manages subscription state (free vs coach tier).
// Current implementation is a local mock — designed to be swapped
// for RevenueCat/StoreKit in production.
//
// Coach tier (4.90 CHF/mois) unlocks:
// - Dashboard trajectoire (score + projection)
// - Forecast adaptatif (3 scenarios)
// - Check-in mensuel
// - Score evolutif + tendance
// - Alertes proactives
// - Historique progression
// - Profil couple
// - Coach LLM (BYOK)
// - Scenarios "Et si..."
// - Export PDF

enum SubscriptionTier { free, coach }

enum SubscriptionSource { mock, revenueCat }

enum CoachFeature {
  dashboard,
  forecast,
  checkin,
  scoreEvolution,
  alertesProactives,
  historique,
  profilCouple,
  coachLlm,
  scenariosEtSi,
  exportPdf,
  vault, // Document vault — unlimited uploads
}

class SubscriptionState {
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final bool isTrialActive;
  final int trialDaysRemaining;
  final SubscriptionSource source;

  const SubscriptionState({
    required this.tier,
    this.expiresAt,
    this.isTrialActive = false,
    this.trialDaysRemaining = 0,
    this.source = SubscriptionSource.mock,
  });

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    DateTime? expiresAt,
    bool? isTrialActive,
    int? trialDaysRemaining,
    SubscriptionSource? source,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      expiresAt: expiresAt ?? this.expiresAt,
      isTrialActive: isTrialActive ?? this.isTrialActive,
      trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
      source: source ?? this.source,
    );
  }

  /// Whether the subscription is active (paid or trial, not expired).
  bool get isActive {
    if (tier == SubscriptionTier.free) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionState &&
          runtimeType == other.runtimeType &&
          tier == other.tier &&
          isTrialActive == other.isTrialActive &&
          trialDaysRemaining == other.trialDaysRemaining &&
          source == other.source;

  @override
  int get hashCode =>
      tier.hashCode ^
      isTrialActive.hashCode ^
      trialDaysRemaining.hashCode ^
      source.hashCode;

  @override
  String toString() =>
      'SubscriptionState(tier: $tier, trial: $isTrialActive, '
      'trialDays: $trialDaysRemaining, source: $source, '
      'expiresAt: $expiresAt)';
}

/// Mock subscription service for development.
///
/// Defaults to [SubscriptionTier.coach] in dev so Coach features
/// can be tested without hitting a paywall.
/// Use [setMockTier] or [setMockState] in tests to control state.
class SubscriptionService {
  // Trial duration in days
  static const int trialDurationDays = 14;

  // Monthly price in CHF
  static const double monthlyPriceCHF = 4.90;

  // Internal mock state — defaults to coach for development
  static SubscriptionState _state = const SubscriptionState(
    tier: SubscriptionTier.coach,
    source: SubscriptionSource.mock,
  );

  /// Current subscription state.
  static SubscriptionState currentState() => _state;

  /// Check if a specific Coach feature is available.
  ///
  /// All [CoachFeature] values require [SubscriptionTier.coach].
  /// Returns true if the user has an active coach subscription or trial.
  static bool hasAccess(CoachFeature feature) {
    // All coach features require coach tier
    if (_state.tier == SubscriptionTier.free) return false;

    // Check expiry
    if (_state.expiresAt != null &&
        DateTime.now().isAfter(_state.expiresAt!)) {
      return false;
    }

    return true;
  }

  /// Simulate upgrading to a subscription tier.
  ///
  /// In production, this would call RevenueCat/StoreKit.
  /// Mock implementation immediately sets the tier.
  static Future<bool> upgradeTo(SubscriptionTier tier) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (tier == SubscriptionTier.free) {
      _state = const SubscriptionState(
        tier: SubscriptionTier.free,
        source: SubscriptionSource.mock,
      );
      return true;
    }

    _state = SubscriptionState(
      tier: tier,
      isTrialActive: false,
      trialDaysRemaining: 0,
      source: SubscriptionSource.mock,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    return true;
  }

  /// Simulate restoring purchases.
  ///
  /// In production, this would query the App Store / Play Store.
  /// Mock implementation returns current state (no prior purchases).
  static Future<SubscriptionState> restorePurchases() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Mock: no prior purchases to restore — return free
    _state = const SubscriptionState(
      tier: SubscriptionTier.free,
      source: SubscriptionSource.mock,
    );
    return _state;
  }

  /// Start a 14-day free trial of Coach.
  ///
  /// Returns true if the trial was started successfully.
  /// Returns false if a trial is already active or the user
  /// already has a paid subscription.
  static Future<bool> startTrial() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Cannot start trial if already coach (paid)
    if (_state.tier == SubscriptionTier.coach && !_state.isTrialActive) {
      // Already a paid subscriber
      return false;
    }

    // Cannot start trial if trial is already active
    if (_state.isTrialActive) {
      return false;
    }

    _state = SubscriptionState(
      tier: SubscriptionTier.coach,
      isTrialActive: true,
      trialDaysRemaining: trialDurationDays,
      source: SubscriptionSource.mock,
      expiresAt: DateTime.now().add(const Duration(days: trialDurationDays)),
    );
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Testing helpers
  // ═══════════════════════════════════════════════════════════════════════

  /// Set mock tier for testing. Resets trial state.
  static void setMockTier(SubscriptionTier tier) {
    _state = SubscriptionState(
      tier: tier,
      source: SubscriptionSource.mock,
    );
  }

  /// Set full mock state for testing.
  static void setMockState(SubscriptionState state) {
    _state = state;
  }

  /// Reset to default dev state (coach).
  static void resetToDefault() {
    _state = const SubscriptionState(
      tier: SubscriptionTier.coach,
      source: SubscriptionSource.mock,
    );
  }
}
