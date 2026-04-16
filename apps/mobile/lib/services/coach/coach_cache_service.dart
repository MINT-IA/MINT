/// Coach Cache Service — Sprint S35.
///
/// Smart in-memory cache for coach narrative components with
/// invalidation triggers tied to user actions.
///
/// Each narrative component (greeting, scoreSummary, tipNarrative,
/// premierEclairageReframe) is cached independently with its own TTL.
///
/// Cache keys combine component name + context hash to ensure
/// stale data from a different profile state is never served.
library;

/// Triggers that invalidate specific cached narrative components.
///
/// Each trigger maps to a set of components that become stale
/// when the corresponding user action occurs.
enum InvalidationTrigger {
  /// User performed a check-in.
  /// Invalidates: scoreSummary, tipNarrative.
  checkIn,

  /// User updated their profile (salary, age, canton, etc.).
  /// Invalidates: ALL components.
  profileUpdate,

  /// A new calendar day started.
  /// Invalidates: greeting.
  newDay,

  /// User completed an arbitrage simulation.
  /// Invalidates: premierEclairageReframe.
  arbitrageCompleted,

  /// User explicitly requested a refresh.
  /// Invalidates: ALL components.
  manualRefresh,
}

/// Internal cache entry with TTL tracking.
class _CacheEntry {
  final String content;
  final DateTime expiresAt;

  _CacheEntry({
    required this.content,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Smart in-memory cache for coach narrative components.
///
/// Usage:
/// ```dart
/// // Store a generated greeting
/// CoachCacheService.set('greeting', contextHash, text, Duration(hours: 1));
///
/// // Retrieve if still valid
/// final cached = CoachCacheService.get('greeting', contextHash);
///
/// // Invalidate after user action
/// CoachCacheService.invalidate(InvalidationTrigger.checkIn);
/// ```
class CoachCacheService {
  CoachCacheService._();

  static final Map<String, _CacheEntry> _cache = {};

  // ═══════════════════════════════════════════════════════════════
  // Component → Trigger mapping
  // ═══════════════════════════════════════════════════════════════

  /// Maps each trigger to the component keys it invalidates.
  static const Map<InvalidationTrigger, List<String>> _triggerMap = {
    InvalidationTrigger.checkIn: ['scoreSummary', 'tipNarrative'],
    InvalidationTrigger.profileUpdate: [
      'greeting',
      'scoreSummary',
      'tipNarrative',
      'premierEclairageReframe',
    ],
    InvalidationTrigger.newDay: ['greeting'],
    InvalidationTrigger.arbitrageCompleted: ['premierEclairageReframe'],
    InvalidationTrigger.manualRefresh: [
      'greeting',
      'scoreSummary',
      'tipNarrative',
      'premierEclairageReframe',
    ],
  };

  // ═══════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════

  /// Retrieve a cached narrative component.
  ///
  /// Returns `null` if:
  ///   - No entry exists for the component+context combination
  ///   - The entry has expired (TTL exceeded)
  ///
  /// [component]: One of 'greeting', 'scoreSummary', 'tipNarrative', 'premierEclairageReframe'.
  /// [contextHash]: Hash of the CoachContext to ensure freshness.
  static String? get(String component, String contextHash) {
    final key = _buildKey(component, contextHash);
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.content;
  }

  /// Store a narrative component in the cache.
  ///
  /// [component]: One of 'greeting', 'scoreSummary', 'tipNarrative', 'premierEclairageReframe'.
  /// [contextHash]: Hash of the CoachContext.
  /// [content]: The generated narrative text.
  /// [ttl]: Time-to-live for this entry.
  static void set(
    String component,
    String contextHash,
    String content,
    Duration ttl,
  ) {
    final key = _buildKey(component, contextHash);
    _cache[key] = _CacheEntry(
      content: content,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Invalidate cached components based on a user action trigger.
  ///
  /// Removes all cache entries whose component key matches the
  /// trigger's invalidation list, regardless of context hash.
  static void invalidate(InvalidationTrigger trigger) {
    final components = _triggerMap[trigger];
    if (components == null) return;

    final keysToRemove = <String>[];
    for (final cacheKey in _cache.keys) {
      for (final component in components) {
        if (cacheKey.startsWith('$component:')) {
          keysToRemove.add(cacheKey);
          break;
        }
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Clear the entire cache. Used for testing and hard resets.
  static void clear() {
    _cache.clear();
  }

  /// Returns the number of entries currently in the cache (for testing).
  static int get length => _cache.length;

  // ═══════════════════════════════════════════════════════════════
  // Internal
  // ═══════════════════════════════════════════════════════════════

  static String _buildKey(String component, String contextHash) {
    return '$component:$contextHash';
  }
}
