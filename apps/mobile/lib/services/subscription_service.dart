import 'package:mint_mobile/services/api_service.dart';
import 'package:flutter/foundation.dart';

enum SubscriptionTier { free, coach }

enum SubscriptionSource { mock, backend, revenueCat }

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
  vault,
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
      'trialDays: $trialDaysRemaining, source: $source, expiresAt: $expiresAt)';
}

class SubscriptionService {
  static const int trialDurationDays = 14;
  static const double monthlyPriceCHF = 4.90;

  static SubscriptionState _state = const SubscriptionState(
    tier: kReleaseMode ? SubscriptionTier.free : SubscriptionTier.coach,
    source: SubscriptionSource.mock,
  );

  static final Set<String> _activeFeatures = <String>{};

  static SubscriptionState currentState() => _state;

  static bool hasAccess(CoachFeature feature) {
    if (_state.source == SubscriptionSource.backend) {
      return _activeFeatures.contains(feature.name);
    }
    if (_state.tier == SubscriptionTier.free) return false;
    if (_state.expiresAt != null && DateTime.now().isAfter(_state.expiresAt!)) {
      return false;
    }
    return true;
  }

  static Future<SubscriptionState> refreshFromBackend() async {
    try {
      final data = await ApiService.get('/billing/entitlements');
      final tier = (data['tier'] as String?) == 'coach'
          ? SubscriptionTier.coach
          : SubscriptionTier.free;
      final isTrial = data['is_trial'] == true;
      final periodEndRaw = data['current_period_end'];
      final periodEnd = periodEndRaw is String
          ? DateTime.tryParse(periodEndRaw)?.toLocal()
          : null;

      _activeFeatures
        ..clear()
        ..addAll((data['features'] as List?)?.cast<String>() ?? const []);

      _state = SubscriptionState(
        tier: tier,
        source: SubscriptionSource.backend,
        isTrialActive: isTrial,
        trialDaysRemaining: _deriveTrialDays(periodEnd, isTrial),
        expiresAt: periodEnd,
      );
      return _state;
    } catch (_) {
      return _state;
    }
  }

  static int _deriveTrialDays(DateTime? periodEnd, bool isTrial) {
    if (!isTrial || periodEnd == null) return 0;
    final days = periodEnd.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  static Future<bool> upgradeTo(SubscriptionTier tier) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (tier == SubscriptionTier.free) {
      _state = const SubscriptionState(
        tier: SubscriptionTier.free,
        source: SubscriptionSource.mock,
      );
      _activeFeatures.clear();
      return true;
    }

    _state = SubscriptionState(
      tier: tier,
      isTrialActive: false,
      trialDaysRemaining: 0,
      source: SubscriptionSource.mock,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    _activeFeatures
      ..clear()
      ..addAll(CoachFeature.values.map((f) => f.name));
    return true;
  }

  static Future<SubscriptionState> restorePurchases() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final refreshed = await refreshFromBackend();
    if (refreshed.source == SubscriptionSource.backend) return refreshed;
    _state = const SubscriptionState(
      tier: SubscriptionTier.free,
      source: SubscriptionSource.mock,
    );
    return _state;
  }

  static Future<bool> startTrial() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_state.tier == SubscriptionTier.coach && !_state.isTrialActive) {
      return false;
    }
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
    _activeFeatures
      ..clear()
      ..addAll(CoachFeature.values.map((f) => f.name));
    return true;
  }

  static void setMockTier(SubscriptionTier tier) {
    _state = SubscriptionState(
      tier: tier,
      source: SubscriptionSource.mock,
    );
    if (tier == SubscriptionTier.coach) {
      _activeFeatures
        ..clear()
        ..addAll(CoachFeature.values.map((f) => f.name));
    } else {
      _activeFeatures.clear();
    }
  }

  static void setMockState(SubscriptionState state) {
    _state = state;
  }

  static void resetToDefault() {
    _state = const SubscriptionState(
      tier: SubscriptionTier.coach,
      source: SubscriptionSource.mock,
    );
    _activeFeatures
      ..clear()
      ..addAll(CoachFeature.values.map((f) => f.name));
  }
}
