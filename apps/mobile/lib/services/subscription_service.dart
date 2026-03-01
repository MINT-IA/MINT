import 'package:mint_mobile/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/ios_iap_service.dart';

// ════════════════════════════════════════════════════════════════════════
//  SubscriptionTier — multi-tier billing (P6)
//  Replaces legacy {free, coach} with {free, starter, premium, couplePlus}.
// ════════════════════════════════════════════════════════════════════════

enum SubscriptionTier {
  free,
  starter,
  premium,
  couplePlus;

  /// Parse from string with backward compatibility.
  /// 'coach' maps to premium for legacy data.
  static SubscriptionTier fromString(String value) {
    switch (value) {
      case 'free':
        return SubscriptionTier.free;
      case 'starter':
        return SubscriptionTier.starter;
      case 'premium':
        return SubscriptionTier.premium;
      case 'couple_plus':
      case 'couplePlus':
        return SubscriptionTier.couplePlus;
      case 'coach':
        return SubscriptionTier.premium; // Legacy backward compat
      default:
        return SubscriptionTier.free;
    }
  }

  String get apiValue {
    switch (this) {
      case SubscriptionTier.free:
        return 'free';
      case SubscriptionTier.starter:
        return 'starter';
      case SubscriptionTier.premium:
        return 'premium';
      case SubscriptionTier.couplePlus:
        return 'couple_plus';
    }
  }

  /// Tier rank for comparison (higher = more features)
  int get rank {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.starter:
        return 1;
      case SubscriptionTier.premium:
        return 2;
      case SubscriptionTier.couplePlus:
        return 3;
    }
  }

  bool get isPaid => this != SubscriptionTier.free;
}

// ════════════════════════════════════════════════════════════════════════
//  AccessLevel + TierFeatureMatrix
// ════════════════════════════════════════════════════════════════════════

enum AccessLevel { none, basic, full }

enum SubscriptionSource { mock, backend, revenueCat }

/// Feature keys for subscription gating.
/// Kept as an enum for type safety + backward compat with CoachGate widget.
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
  monteCarlo,
  arbitrageModules,
}

/// Mirror of backend TIER_FEATURE_MATRIX
class TierFeatureMatrix {
  static const Map<String, Map<SubscriptionTier, AccessLevel>> _matrix = {
    'dashboard': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.full, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'forecast': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.full, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'checkin': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.full, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'scoreEvolution': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'alertesProactives': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.full, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'historique': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'profilCouple': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.basic, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'coachLlm': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'scenariosEtSi': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'exportPdf': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'vault': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'monteCarlo': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
    'arbitrageModules': {SubscriptionTier.free: AccessLevel.none, SubscriptionTier.starter: AccessLevel.none, SubscriptionTier.premium: AccessLevel.full, SubscriptionTier.couplePlus: AccessLevel.full},
  };

  /// Check if a tier has access to a feature (any level above none)
  static bool hasAccess(SubscriptionTier tier, String feature) {
    final featureMap = _matrix[feature];
    if (featureMap == null) return false;
    return (featureMap[tier] ?? AccessLevel.none) != AccessLevel.none;
  }

  /// Get the specific access level for a feature
  static AccessLevel accessLevel(SubscriptionTier tier, String feature) {
    final featureMap = _matrix[feature];
    if (featureMap == null) return AccessLevel.none;
    return featureMap[tier] ?? AccessLevel.none;
  }

  /// Get all features accessible at a given tier
  static List<String> featuresForTier(SubscriptionTier tier) {
    return _matrix.entries
        .where((e) => (e.value[tier] ?? AccessLevel.none) != AccessLevel.none)
        .map((e) => e.key)
        .toList();
  }

  /// Get the minimum tier required for a feature
  static SubscriptionTier minimumTier(String feature) {
    final featureMap = _matrix[feature];
    if (featureMap == null) return SubscriptionTier.couplePlus;
    for (final tier in SubscriptionTier.values) {
      if ((featureMap[tier] ?? AccessLevel.none) != AccessLevel.none) {
        return tier;
      }
    }
    return SubscriptionTier.couplePlus;
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Apple IAP product identifiers
// ════════════════════════════════════════════════════════════════════════

/// Apple IAP product identifiers
class IapProducts {
  static const Set<String> all = {
    'ch.mint.starter.monthly',
    'ch.mint.premium.monthly',
    'ch.mint.couple_plus.monthly',
    'ch.mint.starter.annual',
    'ch.mint.premium.annual',
    'ch.mint.couple_plus.annual',
  };

  static SubscriptionTier tierFromProductId(String productId) {
    switch (productId) {
      case 'ch.mint.starter.monthly':
      case 'ch.mint.starter.annual':
        return SubscriptionTier.starter;
      case 'ch.mint.premium.monthly':
      case 'ch.mint.premium.annual':
        return SubscriptionTier.premium;
      case 'ch.mint.couple_plus.monthly':
      case 'ch.mint.couple_plus.annual':
        return SubscriptionTier.couplePlus;
      case 'ch.mint.coach.monthly': // Legacy
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }

  static bool isAnnual(String productId) => productId.endsWith('.annual');
}

// ════════════════════════════════════════════════════════════════════════
//  SubscriptionState
// ════════════════════════════════════════════════════════════════════════

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

// ════════════════════════════════════════════════════════════════════════
//  SubscriptionService
// ════════════════════════════════════════════════════════════════════════

class SubscriptionService {
  static const int trialDurationDays = 14;
  static const double monthlyPriceCHF = 4.90;

  static SubscriptionState _state = const SubscriptionState(
    tier: SubscriptionTier.free,
    source: SubscriptionSource.mock,
  );

  static final Set<String> _activeFeatures = <String>{};

  static SubscriptionState currentState() => _state;

  /// Check access using TierFeatureMatrix (replaces old coach-only check).
  /// When source is backend, defers to server-provided feature list.
  static bool hasAccess(CoachFeature feature) {
    if (_state.source == SubscriptionSource.backend) {
      return _activeFeatures.contains(feature.name);
    }
    if (_state.tier == SubscriptionTier.free) return false;
    if (_state.expiresAt != null && DateTime.now().isAfter(_state.expiresAt!)) {
      return false;
    }
    // Use TierFeatureMatrix for mock/local tier resolution
    return TierFeatureMatrix.hasAccess(_state.tier, feature.name);
  }

  static Future<SubscriptionState> refreshFromBackend() async {
    try {
      final data = await ApiService.get('/billing/entitlements');
      final tierStr = data['tier'] as String? ?? 'free';
      final tier = SubscriptionTier.fromString(tierStr);
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
    // IAP flow for paid tiers on iOS
    if (tier.isPaid && IosIapService.isSupportedPlatform) {
      final purchased = await IosIapService.purchaseCoachMonthly();
      if (purchased) {
        await refreshFromBackend();
      }
      return purchased;
    }

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
      ..addAll(TierFeatureMatrix.featuresForTier(tier));
    return true;
  }

  static Future<SubscriptionState> restorePurchases() async {
    if (IosIapService.isSupportedPlatform) {
      final restored = await IosIapService.restoreAndSync();
      if (restored) {
        return await refreshFromBackend();
      }
    }

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
    // Already a paid subscriber (not on trial) — cannot start trial
    if (_state.tier.isPaid && !_state.isTrialActive) {
      return false;
    }
    if (_state.isTrialActive) {
      return false;
    }

    // Trial gives premium-level access
    _state = SubscriptionState(
      tier: SubscriptionTier.premium,
      isTrialActive: true,
      trialDaysRemaining: trialDurationDays,
      source: SubscriptionSource.mock,
      expiresAt: DateTime.now().add(const Duration(days: trialDurationDays)),
    );
    _activeFeatures
      ..clear()
      ..addAll(TierFeatureMatrix.featuresForTier(SubscriptionTier.premium));
    return true;
  }

  static void setMockTier(SubscriptionTier tier) {
    _state = SubscriptionState(
      tier: tier,
      source: SubscriptionSource.mock,
    );
    if (tier.isPaid) {
      _activeFeatures
        ..clear()
        ..addAll(TierFeatureMatrix.featuresForTier(tier));
    } else {
      _activeFeatures.clear();
    }
  }

  static void setMockState(SubscriptionState state) {
    _state = state;
  }

  static void resetToDefault() {
    _state = const SubscriptionState(
      tier: SubscriptionTier.free,
      source: SubscriptionSource.mock,
    );
    _activeFeatures.clear();
  }
}
