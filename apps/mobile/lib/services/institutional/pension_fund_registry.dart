// ────────────────────────────────────────────────────────────
//  PENSION FUND REGISTRY — Sprint S69-S70
// ────────────────────────────────────────────────────────────
//
// Static registry of supported institutional pension funds.
// Pilot: Publica (federal), BVK (Bern), CPEV (Vaud).
//
// Read-only — no money movement (CLAUDE.md compliance).
// ────────────────────────────────────────────────────────────

/// Supported pension fund identifiers for institutional API connections.
enum PensionFund { publica, bvk, cpev }

/// Metadata for a supported pension fund.
class PensionFundInfo {
  /// Unique fund identifier.
  final PensionFund id;

  /// Full official name of the fund.
  final String name;

  /// Short display name.
  final String shortName;

  /// Fund website URL (nullable if not public).
  final String? website;

  /// Cantons where the fund is commonly used.
  final List<String> supportedCantons;

  /// Whether the API connection is currently active.
  final bool isActive;

  /// API version string for compatibility tracking.
  final String apiVersion;

  const PensionFundInfo({
    required this.id,
    required this.name,
    required this.shortName,
    this.website,
    required this.supportedCantons,
    required this.isActive,
    required this.apiVersion,
  });
}

/// Static registry of all supported pension funds.
///
/// Pilot phase: 3 funds (Publica, BVK, CPEV).
/// Additional funds can be added by extending the [_registry] map.
class PensionFundRegistry {
  PensionFundRegistry._();

  static const _registry = <PensionFund, PensionFundInfo>{
    PensionFund.publica: PensionFundInfo(
      id: PensionFund.publica,
      name: 'Caisse fédérale de pensions Publica',
      shortName: 'Publica',
      website: 'https://www.publica.ch',
      supportedCantons: ['BE', 'ZH', 'GE', 'VD', 'BS', 'LU'],
      isActive: true,
      apiVersion: '1.0.0',
    ),
    PensionFund.bvk: PensionFundInfo(
      id: PensionFund.bvk,
      name: 'Bernische Pensionskasse BVK',
      shortName: 'BVK',
      website: 'https://www.bvk.ch',
      supportedCantons: ['BE'],
      isActive: true,
      apiVersion: '1.0.0',
    ),
    PensionFund.cpev: PensionFundInfo(
      id: PensionFund.cpev,
      name: 'Caisse de pensions de l\u2019État de Vaud',
      shortName: 'CPEV',
      website: 'https://www.cpev.ch',
      supportedCantons: ['VD'],
      isActive: true,
      apiVersion: '1.0.0',
    ),
  };

  /// Get info for a specific fund.
  static PensionFundInfo getInfo(PensionFund fund) => _registry[fund]!;

  /// Get all registered funds.
  static List<PensionFundInfo> getAll() => _registry.values.toList();

  /// Get only active (API-enabled) funds.
  static List<PensionFundInfo> getActive() =>
      _registry.values.where((f) => f.isActive).toList();

  /// Lookup fund by short name (case-insensitive). Returns null if not found.
  static PensionFundInfo? findByShortName(String shortName) {
    final lower = shortName.toLowerCase();
    for (final info in _registry.values) {
      if (info.shortName.toLowerCase() == lower) return info;
    }
    return null;
  }

  /// Get funds available for a given canton code.
  static List<PensionFundInfo> getForCanton(String cantonCode) {
    final upper = cantonCode.toUpperCase();
    return _registry.values
        .where((f) => f.supportedCantons.contains(upper))
        .toList();
  }
}
