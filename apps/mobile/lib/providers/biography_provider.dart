import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/biography_repository.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

// ────────────────────────────────────────────────────────────
//  BIOGRAPHY PROVIDER — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// ChangeNotifier wrapping BiographyRepository for Provider-based
// state management. Caches facts in memory and exposes filtered
// views (active, stale, by category).
//
// Pattern follows DocumentProvider / CoachProfileProvider.
//
// Privacy: facts are local-only. This provider never sends
// raw facts to any external API.
// ────────────────────────────────────────────────────────────

/// Provider for the user's FinancialBiography.
///
/// Wraps [BiographyRepository] with cached state and
/// freshness-aware filtered views.
class BiographyProvider extends ChangeNotifier {
  BiographyRepository? _repository;

  List<BiographyFact> _facts = [];
  bool _isLoading = false;
  String? _error;

  /// Create with an existing repository (for testing or pre-initialized).
  /// If [repository] is null, lazily initializes via [BiographyRepository.instance()].
  BiographyProvider({BiographyRepository? repository})
      : _repository = repository;

  /// Lazily initialize the repository if not yet set.
  Future<BiographyRepository> _getRepository() async {
    _repository ??= await BiographyRepository.instance();
    return _repository!;
  }

  // ── Getters ──────────────────────────────────────────────────

  /// All active (non-deleted) facts, cached.
  List<BiographyFact> get facts => List.unmodifiable(_facts);

  /// Whether facts are currently being loaded.
  bool get isLoading => _isLoading;

  /// Last error message, if any.
  String? get error => _error;

  /// Facts with freshness weight >= 0.60 (still reliable).
  List<BiographyFact> get activeFreshFacts {
    final now = DateTime.now();
    return _facts
        .where((f) => FreshnessDecayService.weight(f, now) >= 0.60)
        .toList();
  }

  /// Facts with freshness weight < 0.60 (need refresh).
  List<BiographyFact> get staleFacts {
    final now = DateTime.now();
    return _facts
        .where((f) => FreshnessDecayService.weight(f, now) < 0.60)
        .toList();
  }

  /// Facts grouped by display category.
  ///
  /// Categories:
  /// - 'Donnees financieres': salary, LPP, 3a, AVS, tax, mortgage
  /// - 'Evenements de vie': lifeEvent, civilStatus, employmentStatus, canton
  /// - 'Decisions': userDecision, coachPreference
  Map<String, List<BiographyFact>> get factsByCategory {
    final result = <String, List<BiographyFact>>{
      'Donnees financieres': [],
      'Evenements de vie': [],
      'Decisions': [],
    };

    for (final fact in _facts) {
      final category = _categoryForType(fact.factType);
      result[category]?.add(fact);
    }

    return result;
  }

  /// Map a [FactType] to a display category.
  static String _categoryForType(FactType type) {
    switch (type) {
      case FactType.salary:
      case FactType.lppCapital:
      case FactType.lppRachatMax:
      case FactType.threeACapital:
      case FactType.avsContributionYears:
      case FactType.taxRate:
      case FactType.mortgageDebt:
        return 'Donnees financieres';
      case FactType.lifeEvent:
      case FactType.civilStatus:
      case FactType.employmentStatus:
      case FactType.canton:
        return 'Evenements de vie';
      case FactType.userDecision:
      case FactType.coachPreference:
        return 'Decisions';
    }
  }

  // ── Operations ──────────────────────────────────────────────

  /// Load all active facts from the repository.
  ///
  /// Call on app startup or after authentication.
  Future<void> loadFacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final repo = await _getRepository();
      _facts = await repo.getActiveFacts();
    } catch (e) {
      _error = 'Failed to load biography: $e';
      debugPrint('[BiographyProvider] $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new fact to the biography.
  Future<void> addFact(BiographyFact fact) async {
    try {
      final repo = await _getRepository();
      await repo.insertFact(fact);
      await loadFacts();
    } catch (e) {
      _error = 'Failed to add fact: $e';
      debugPrint('[BiographyProvider] $e');
      notifyListeners();
    }
  }

  /// Update a fact's value (sets source to userEdit automatically).
  Future<void> updateFactValue(String id, String newValue) async {
    try {
      final repo = await _getRepository();
      await repo.updateFact(id, newValue);
      await loadFacts();
    } catch (e) {
      _error = 'Failed to update fact: $e';
      debugPrint('[BiographyProvider] $e');
      notifyListeners();
    }
  }

  /// Soft-delete a fact (remains in DB but hidden from active queries).
  Future<void> deleteFact(String id) async {
    try {
      final repo = await _getRepository();
      await repo.softDeleteFact(id);
      await loadFacts();
    } catch (e) {
      _error = 'Failed to delete fact: $e';
      debugPrint('[BiographyProvider] $e');
      notifyListeners();
    }
  }

  /// Permanently delete a fact (GDPR/nLPD privacy screen).
  Future<void> hardDeleteFact(String id) async {
    try {
      final repo = await _getRepository();
      await repo.hardDeleteFact(id);
      await loadFacts();
    } catch (e) {
      _error = 'Failed to hard-delete fact: $e';
      debugPrint('[BiographyProvider] $e');
      notifyListeners();
    }
  }
}
