/// Available on-device SLM model tiers.
///
/// Each tier represents a different model size/quality trade-off.
/// E4B = premium (better quality, more RAM), E2B = accessible (lighter).
enum SlmModelTier {
  /// Gemma 3n E4B — ~4B effective params, ~4.4 GB, needs ~3 GB RAM.
  /// Best quality. iPhone 13 Pro+ / Android 8GB+.
  e4b,

  /// Gemma 3n E2B — ~2B effective params, ~3.0 GB, needs ~2 GB RAM.
  /// Good quality for educational coaching. iPhone 11+ / Android 4GB+.
  e2b,
}

/// Configuration for each SLM model tier.
class SlmTierConfig {
  final SlmModelTier tier;
  final String displayName;
  final String hfUrl;
  final int expectedSizeBytes;
  final int minRamGb;
  final int minCores;
  final String compatibilityHint;

  const SlmTierConfig({
    required this.tier,
    required this.displayName,
    required this.hfUrl,
    required this.expectedSizeBytes,
    required this.minRamGb,
    required this.minCores,
    required this.compatibilityHint,
  });

  String get modelId => Uri.parse(hfUrl).pathSegments.last;

  String get modelSizeFormatted {
    final gb = expectedSizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} Go';
  }

  int get estimatedDownloadMinutes {
    const bitsPerSecond = 50 * 1000 * 1000; // 50 Mbps
    const bytesPerSecond = bitsPerSecond / 8;
    final seconds = expectedSizeBytes / bytesPerSecond;
    return (seconds / 60).ceil();
  }

  static const e4b = SlmTierConfig(
    tier: SlmModelTier.e4b,
    displayName: 'Gemma 3n 4B (Premium)',
    hfUrl:
        'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
    expectedSizeBytes: 4400000000,
    minRamGb: 6,
    minCores: 6,
    compatibilityHint: 'iPhone 13 Pro+ / Pixel 7+ / 8\u00a0Go RAM',
  );

  static const e2b = SlmTierConfig(
    tier: SlmModelTier.e2b,
    displayName: 'Gemma 3n 2B (Accessible)',
    hfUrl:
        'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
    expectedSizeBytes: 3000000000,
    minRamGb: 4,
    minCores: 4,
    compatibilityHint: 'iPhone 11+ / Pixel 6+ / 4\u00a0Go RAM',
  );

  static const allTiers = [e4b, e2b];

  static SlmTierConfig forTier(SlmModelTier tier) {
    switch (tier) {
      case SlmModelTier.e4b:
        return e4b;
      case SlmModelTier.e2b:
        return e2b;
    }
  }
}
