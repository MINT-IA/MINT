import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// Calculateur intelligent des plafonds 3a selon le profil utilisateur
///
/// Implémente les règles fiscales suisses 2023-2026 avec :
/// - Cache intelligent pour performance
/// - Validation des données
/// - Explications pédagogiques
/// - Support multi-années
class Pillar3aCalculator {
  static const String disclaimer =
      'Outil éducatif — ne constitue pas un conseil financier '
      'personnalisé au sens de la LSFin.';

  static const List<String> sources = [
    'OPP3 art. 7 (plafonds 3a)',
    'LIFD art. 33 al. 1 let. e (déduction fiscale 3a)',
    'LPP art. 7 (seuil d\'accès au 2e pilier)',
  ];

  static Map<String, dynamic>? _limits;
  static final Map<String, Pillar3aResult> _cache = {};

  /// Charge les limites depuis le fichier JSON
  ///
  /// Doit être appelé au démarrage de l'app (main.dart)
  static Future<void> loadLimits() async {
    if (_limits != null) return; // Déjà chargé

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/config/pillar_3a_limits.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);
      _limits = data['pillar_3a_limits'];
    } catch (e) {
      throw Pillar3aException(
        'Impossible de charger les plafonds 3a: $e',
        type: Pillar3aExceptionType.configurationError,
      );
    }
  }

  /// Calcule le plafond 3a selon le profil
  ///
  /// Retourne un [Pillar3aResult] avec :
  /// - Le montant du plafond
  /// - L'explication pédagogique
  /// - Les détails du calcul
  static Pillar3aResult calculateLimit({
    required int year,
    required String employmentStatus,
    required bool? has2ndPillar,
    double? netIncomeAVS,
    bool useCache = true,
  }) {
    // Validation des paramètres
    _validateInputs(year, employmentStatus, has2ndPillar);

    // Vérifier le cache
    final cacheKey = _getCacheKey(
      year,
      employmentStatus,
      has2ndPillar,
      netIncomeAVS,
    );

    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Calculer le plafond
    final result = _performCalculation(
      year,
      employmentStatus,
      has2ndPillar,
      netIncomeAVS,
    );

    // Mettre en cache
    if (useCache) {
      _cache[cacheKey] = result;
    }

    return result;
  }

  /// Obtient le subtitle dynamique pour la question 3a
  ///
  /// Retourne une explication adaptée au profil de l'utilisateur
  static String getDynamic3aSubtitle({
    required String employmentStatus,
    required bool? has2ndPillar,
    required int year,
    double? netIncomeAVS,
  }) {
    final result = calculateLimit(
      year: year,
      employmentStatus: employmentStatus,
      has2ndPillar: has2ndPillar,
      netIncomeAVS: netIncomeAVS,
    );

    return result.explanation;
  }

  /// Obtient une explication détaillée du calcul
  ///
  /// Utile pour l'écran de détails ou les inserts pédagogiques
  static String getDetailedExplanation({
    required String employmentStatus,
    required bool? has2ndPillar,
    required int year,
    double? netIncomeAVS,
  }) {
    final result = calculateLimit(
      year: year,
      employmentStatus: employmentStatus,
      has2ndPillar: has2ndPillar,
      netIncomeAVS: netIncomeAVS,
    );

    return result.detailedExplanation;
  }

  /// Vide le cache (utile pour les tests ou changement de profil)
  static void clearCache() {
    _cache.clear();
  }

  // ===== Méthodes privées =====

  static void _validateInputs(
    int year,
    String employmentStatus,
    bool? has2ndPillar,
  ) {
    if (_limits == null) {
      throw Pillar3aException(
        'Les plafonds 3a ne sont pas chargés. Appelez loadLimits() d\'abord.',
        type: Pillar3aExceptionType.notInitialized,
      );
    }

    if (!_limits!.containsKey(year.toString())) {
      throw Pillar3aException(
        'Aucun plafond trouvé pour l\'année $year',
        type: Pillar3aExceptionType.invalidYear,
      );
    }

    final validStatuses = [
      'employee',
      'self_employed',
      'mixed',
      'student',
      'retired',
      'other',
    ];

    if (!validStatuses.contains(employmentStatus)) {
      throw Pillar3aException(
        'Statut d\'emploi invalide: $employmentStatus',
        type: Pillar3aExceptionType.invalidStatus,
      );
    }
  }

  static Pillar3aResult _performCalculation(
    int year,
    String employmentStatus,
    bool? has2ndPillar,
    double? netIncomeAVS,
  ) {
    final yearLimits = _limits![year.toString()];

    // Déterminer la clé de configuration
    final configKey = _getConfigKey(employmentStatus, has2ndPillar);
    final config = yearLimits[configKey];

    if (config == null) {
      throw Pillar3aException(
        'Configuration introuvable pour: $configKey',
        type: Pillar3aExceptionType.configurationError,
      );
    }

    // Calculer le montant
    double limit;
    String calculationDetails;

    if (config['calculation'] == 'fixed') {
      limit = config['limit'].toDouble();
      calculationDetails = 'Plafond fixe: CHF ${_formatAmount(limit)}';
    } else if (config['calculation'] == 'percentage') {
      if (netIncomeAVS == null || netIncomeAVS == 0) {
        // Revenu inconnu → retourner le plafond max
        limit = config['limit'].toDouble();
        calculationDetails = 'Plafond maximum: CHF ${_formatAmount(limit)} '
            '(20% du revenu net AVS, revenu non renseigné)';
      } else {
        final calculated = netIncomeAVS * config['percentage'];
        final maxLimit = config['limit'].toDouble();
        limit = min(calculated, maxLimit);

        if (calculated <= maxLimit) {
          calculationDetails = '20% de CHF ${_formatAmount(netIncomeAVS)} = '
              'CHF ${_formatAmount(calculated)}';
        } else {
          calculationDetails = '20% de CHF ${_formatAmount(netIncomeAVS)} = '
              'CHF ${_formatAmount(calculated)}, '
              'plafonné à CHF ${_formatAmount(maxLimit)}';
        }
      }
    } else {
      limit = 0;
      calculationDetails = 'Pas de plafond 3a pour ce statut';
    }

    // Générer les explications
    final explanation = _generateExplanation(
      employmentStatus,
      has2ndPillar,
      year,
      limit,
      config,
    );

    final detailedExplanation = _generateDetailedExplanation(
      employmentStatus,
      has2ndPillar,
      year,
      limit,
      config,
      calculationDetails,
    );

    return Pillar3aResult(
      limit: limit,
      year: year,
      employmentStatus: employmentStatus,
      has2ndPillar: has2ndPillar,
      netIncomeAVS: netIncomeAVS,
      calculationType: config['calculation'],
      explanation: explanation,
      detailedExplanation: detailedExplanation,
      calculationDetails: calculationDetails,
    );
  }

  static String _getConfigKey(String employmentStatus, bool? has2ndPillar) {
    // Cas spéciaux (pas de LPP possible)
    if (employmentStatus == 'student') return 'student';
    if (employmentStatus == 'retired') return 'retired';
    if (employmentStatus == 'other') return 'other';

    // Cas normaux
    final lppSuffix = (has2ndPillar == true) ? 'with_lpp' : 'without_lpp';
    return '${employmentStatus}_$lppSuffix';
  }

  static String _getCacheKey(
    int year,
    String employmentStatus,
    bool? has2ndPillar,
    double? netIncomeAVS,
  ) {
    return '$year|$employmentStatus|$has2ndPillar|${netIncomeAVS ?? 0}';
  }

  static String _generateExplanation(
    String employmentStatus,
    bool? has2ndPillar,
    int year,
    double limit,
    Map<String, dynamic> config,
  ) {
    if (limit == 0) {
      if (employmentStatus == 'student') {
        return 'En tant qu\'étudiant, tu ne peux pas cotiser au 3a.';
      } else if (employmentStatus == 'retired') {
        return 'En tant que retraité, ton 3a est fermé aux cotisations.';
      } else {
        return 'Pas de plafond 3a pour ton statut actuel.';
      }
    }

    if (config['calculation'] == 'fixed') {
      return 'Le 3a te permet de déduire jusqu\'à '
          'CHF ${_formatAmount(limit)}/an ($year) de tes impôts.';
    } else {
      return 'Le 3a te permet de déduire jusqu\'à 20% de ton revenu net '
          '(max CHF ${_formatAmount(limit)}/an, $year).';
    }
  }

  static String _generateDetailedExplanation(
    String employmentStatus,
    bool? has2ndPillar,
    int year,
    double limit,
    Map<String, dynamic> config,
    String calculationDetails,
  ) {
    final buffer = StringBuffer();

    // Titre
    buffer.writeln('📊 Calcul de ton plafond 3a ($year)');
    buffer.writeln();

    // Profil
    buffer.writeln('**Ton profil** :');
    buffer.writeln('- Statut : ${_getStatusLabel(employmentStatus)}');
    buffer.writeln('- 2e pilier (LPP) : ${_getLppLabel(has2ndPillar)}');
    buffer.writeln();

    // Calcul
    buffer.writeln('**Calcul** :');
    buffer.writeln(calculationDetails);
    buffer.writeln();

    // Résultat
    buffer.writeln('**Résultat** :');
    if (limit > 0) {
      buffer.writeln('Tu peux déduire jusqu\'à **CHF ${_formatAmount(limit)}** '
          'de tes impôts en cotisant au 3a.');
    } else {
      buffer.writeln('Pas de plafond 3a pour ton statut actuel.');
    }
    buffer.writeln();

    // Conseil
    if (limit > 0) {
      buffer.writeln('💡 **Conseil** :');
      if (config['calculation'] == 'fixed') {
        buffer.writeln('Maximise ta déduction fiscale en versant '
            'CHF ${_formatAmount(limit)} avant fin décembre.');
      } else {
        buffer.writeln('Ton plafond dépend de ton revenu net AVS. '
            'Plus tu gagnes, plus tu peux déduire (jusqu\'au plafond).');
      }
    }

    return buffer.toString();
  }

  static String _getStatusLabel(String status) {
    switch (status) {
      case 'employee':
        return 'Salarié(e)';
      case 'self_employed':
        return 'Indépendant(e)';
      case 'mixed':
        return 'Mixte (salarié + indépendant)';
      case 'student':
        return 'Étudiant(e)';
      case 'retired':
        return 'Retraité(e)';
      default:
        return 'Autre';
    }
  }

  static String _getLppLabel(bool? has2ndPillar) {
    if (has2ndPillar == null) return 'Non renseigné';
    return has2ndPillar ? 'Oui' : 'Non';
  }

  static String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}\'',
        );
  }
}

/// Résultat du calcul du plafond 3a
class Pillar3aResult {
  /// Montant du plafond en CHF
  final double limit;

  /// Année du calcul
  final int year;

  /// Statut d'emploi
  final String employmentStatus;

  /// Présence du 2e pilier
  final bool? has2ndPillar;

  /// Revenu net AVS (si applicable)
  final double? netIncomeAVS;

  /// Type de calcul ('fixed' ou 'percentage')
  final String calculationType;

  /// Explication courte (pour subtitle)
  final String explanation;

  /// Explication détaillée (pour écran de détails)
  final String detailedExplanation;

  /// Détails du calcul
  final String calculationDetails;

  const Pillar3aResult({
    required this.limit,
    required this.year,
    required this.employmentStatus,
    required this.has2ndPillar,
    required this.netIncomeAVS,
    required this.calculationType,
    required this.explanation,
    required this.detailedExplanation,
    required this.calculationDetails,
  });

  /// Retourne true si le plafond est basé sur un pourcentage du revenu
  bool get isPercentageBased => calculationType == 'percentage';

  /// Retourne true si le plafond est un montant fixe
  bool get isFixed => calculationType == 'fixed';

  /// Retourne true si l'utilisateur peut cotiser au 3a
  bool get canContribute => limit > 0;

  @override
  String toString() {
    return 'Pillar3aResult(limit: $limit, year: $year, '
        'employmentStatus: $employmentStatus, has2ndPillar: $has2ndPillar)';
  }
}

/// Exception levée lors d'erreurs de calcul 3a
class Pillar3aException implements Exception {
  final String message;
  final Pillar3aExceptionType type;

  Pillar3aException(this.message, {required this.type});

  @override
  String toString() => 'Pillar3aException: $message (type: $type)';
}

/// Types d'exceptions 3a
enum Pillar3aExceptionType {
  notInitialized,
  invalidYear,
  invalidStatus,
  configurationError,
}
