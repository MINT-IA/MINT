/// Compliance Guard — Sprint S34 (BLOCKER).
///
/// Validates ALL LLM output before display. No LLM text reaches the user
/// without passing through this 5-layer validation pipeline.
///
/// Layers:
///   1. Banned terms detection + sanitization
///   2. Prescriptive language detection
///   3. Hallucination detection (numbers verified against financial_core)
///   4. Disclaimer auto-injection
///   5. Length constraints per component type
///
/// References:
///   - LSFin art. 3/8 (quality of financial information)
///   - FINMA circular 2008/21 (operational risk)
library;

import 'coach_models.dart';
import 'hallucination_detector.dart';

class ComplianceGuard {
  ComplianceGuard._();

  // ═══════════════════════════════════════════════════════════════
  // Layer 1: Banned terms
  // ═══════════════════════════════════════════════════════════════

  static const List<String> bannedTerms = [
    // Masculine forms
    'garanti',
    'certain',
    'assuré',
    'sans risque',
    'optimal',
    'meilleur',
    'parfait',
    'conseiller',
    // Feminine forms (HIGH audit: bypass via inflection)
    'garantie',
    'assurée',
    'optimale',
    'meilleure',
    'parfaite',
    'conseillère',
    // Prescriptive phrases
    'tu devrais',
    'tu dois',
    'il faut que tu',
    'la meilleure option',
    'nous recommandons',
    'nous te conseillons',
    'il est optimal',
    'la solution idéale',
  ];

  static const Map<String, String> termReplacements = {
    'garanti': 'possible dans ce scénario',
    'certain': 'probable',
    'assuré': 'envisageable',
    'sans risque': 'à risque modéré',
    'optimal': 'adapté',
    'meilleur': 'pertinent',
    'parfait': 'adapté',
    'conseiller': 'spécialiste',
    // Feminine forms
    'garantie': 'possible dans ce scénario',
    'assurée': 'envisageable',
    'optimale': 'adaptée',
    'meilleure': 'pertinente',
    'parfaite': 'adaptée',
    'conseillère': 'spécialiste',
    // Prescriptive phrases
    'tu devrais': 'tu pourrais envisager de',
    'tu dois': 'il serait utile de',
    'il faut que tu': 'tu pourrais',
    'la meilleure option': 'une option à considérer',
    'nous recommandons': 'une piste possible serait',
    'nous te conseillons': 'une approche envisageable serait',
    'il est optimal': 'il pourrait être pertinent',
    'la solution idéale': 'une approche adaptée',
  };

  // ═══════════════════════════════════════════════════════════════
  // Layer 2: Prescriptive patterns
  // ═══════════════════════════════════════════════════════════════

  static final List<RegExp> prescriptivePatterns = [
    RegExp(r'fais\s+un\s+rachat', caseSensitive: false),
    RegExp(r'verse\s+sur\s+ton', caseSensitive: false),
    RegExp(r'ach[eè]te', caseSensitive: false),
    RegExp(r'vends\b', caseSensitive: false),
    RegExp(r'choisis\s+la\s+rente', caseSensitive: false),
    RegExp(r'prends?\s+le\s+capital', caseSensitive: false),
    RegExp(r'investis?\s+dans', caseSensitive: false),
    RegExp(r'priorit[ée]\s+absolue', caseSensitive: false),
    RegExp(r"c['']est\s+plus\s+important\s+que", caseSensitive: false),
  ];

  // Fuzzy banned pattern for "sans ... risque" variants
  static final _sansRisquePattern = RegExp(r'sans\s+(?:\w+\s+)*risque', caseSensitive: false);

  static const List<String> projectionKeywords = [
    'projection', 'simulation', 'scénario', 'scenario',
    'estimé', 'estimée', 'estimation', 'prévision',
    'retraite', 'rente', 'capital', 'rendement',
  ];

  static const String standardDisclaimer =
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). '
      'Consulte un·e spécialiste pour une analyse personnalisée.';

  // Hoisted to static final — avoids recompilation on every call.
  static final List<RegExp> _englishMarkers = [
    RegExp(r'\byour\b', caseSensitive: false),
    RegExp(r'\byou\b', caseSensitive: false),
    RegExp(r'\bshould\b', caseSensitive: false),
    RegExp(r'\bwould\b', caseSensitive: false),
    RegExp(r'\bcould\b', caseSensitive: false),
    RegExp(r'\bthe\b', caseSensitive: false),
    RegExp(r'\bwith\b', caseSensitive: false),
    RegExp(r'\bthis\b', caseSensitive: false),
  ];

  /// Pre-compiled word-boundary patterns for single-word banned terms.
  ///
  /// Uses French-aware word boundaries via lookbehind/lookahead with a
  /// character class that includes accented letters (À-ÿ). Standard \b
  /// treats accented chars as \W, breaking terms like "assuré" or
  /// "conseillère" where the accent sits at a boundary position.
  ///
  /// Multi-word phrases (containing spaces) still use substring matching
  /// because word boundaries around phrases are implicit.
  static final Map<String, RegExp> _bannedTermPatterns = {
    for (final term in bannedTerms)
      term: term.contains(' ')
          ? RegExp(RegExp.escape(term), caseSensitive: false)
          : RegExp(
              '(?<![a-zA-ZÀ-ÿ])${RegExp.escape(term)}(?![a-zA-ZÀ-ÿ])',
              caseSensitive: false,
            ),
  };

  // ═══════════════════════════════════════════════════════════════
  // Main validation
  // ═══════════════════════════════════════════════════════════════

  /// Validate LLM output through 5 compliance layers.
  static ComplianceResult validate(
    String llmOutput, {
    CoachContext? context,
    ComponentType componentType = ComponentType.general,
  }) {
    final violations = <String>[];
    var text = llmOutput;
    var useFallback = false;

    // Pre-check: empty output
    if (text.trim().isEmpty) {
      return const ComplianceResult(
        isCompliant: false,
        sanitizedText: '',
        violations: ['Sortie vide'],
        useFallback: true,
      );
    }

    // Pre-check: wrong language
    final langViolations = _checkLanguage(text);
    if (langViolations.isNotEmpty) {
      violations.addAll(langViolations);
      useFallback = true;
    }

    // Layer 1: Banned terms
    final bannedFound = _checkBannedTerms(text);
    if (bannedFound.isNotEmpty) {
      violations.addAll(bannedFound.map((t) => "Terme interdit: '$t'"));
      if (bannedFound.length > 2) {
        useFallback = true;
      } else {
        text = _sanitizeBannedTerms(text);
      }
    }

    // Layer 2: Prescriptive language
    final prescriptiveFound = _checkPrescriptive(text);
    if (prescriptiveFound.isNotEmpty) {
      violations.addAll(prescriptiveFound.map((p) => "Langage prescriptif: '$p'"));
      useFallback = true;
    }

    // Layer 3: Hallucination detection
    if (context != null && context.knownValues.isNotEmpty) {
      final hallucinations = HallucinationDetector.detect(text, context.knownValues);
      if (hallucinations.isNotEmpty) {
        for (final h in hallucinations) {
          violations.add(
            "Hallucination: '${h.foundText}' "
            "(attendu ~${h.closestValue}, trouvé ${h.foundValue}, "
            "déviation ${h.deviationPct.toStringAsFixed(1)}%)",
          );
        }
        useFallback = true;
      }
    }

    // Layer 4: Disclaimer injection
    if (!useFallback) {
      text = _injectDisclaimerIfNeeded(text);
    }

    // Layer 5: Length check
    if (!useFallback) {
      final wordLimit = componentWordLimits[componentType] ??
          componentWordLimits[ComponentType.general]!;
      final (truncated, lengthViolation) = _enforceLength(text, wordLimit);
      text = truncated;
      if (lengthViolation != null) {
        violations.add(lengthViolation);
      }
    }

    return ComplianceResult(
      isCompliant: violations.isEmpty,
      sanitizedText: useFallback ? '' : text,
      violations: violations,
      useFallback: useFallback,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Layer implementations
  // ═══════════════════════════════════════════════════════════════

  static List<String> _checkLanguage(String text) {
    var count = 0;
    for (final pattern in _englishMarkers) {
      if (pattern.hasMatch(text)) count++;
    }
    if (count >= 3) {
      return ['Langue incorrecte: texte semble être en anglais ($count marqueurs)'];
    }
    return [];
  }

  /// CRIT #5 fix: use word-boundary regex for single-word banned terms
  /// to avoid false positives on "incertain", "certains", "parfaitement".
  static List<String> _checkBannedTerms(String text) {
    final found = <String>[];
    for (final entry in _bannedTermPatterns.entries) {
      if (entry.value.hasMatch(text)) {
        found.add(entry.key);
      }
    }
    // Fuzzy: "sans aucun risque" etc.
    if (!found.contains('sans risque') && _sansRisquePattern.hasMatch(text)) {
      found.add('sans risque');
    }
    return found;
  }

  /// Sanitize text by replacing banned terms with softer alternatives.
  /// Uses word-boundary patterns for single-word terms.
  static String _sanitizeBannedTerms(String text) {
    var result = text;
    for (final entry in termReplacements.entries) {
      final pattern = _bannedTermPatterns[entry.key];
      if (pattern != null) {
        result = result.replaceAll(pattern, entry.value);
      }
    }
    return result;
  }

  static List<String> _checkPrescriptive(String text) {
    final found = <String>[];
    for (final pattern in prescriptivePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        found.add(match.group(0)!);
      }
    }
    return found;
  }

  static String _injectDisclaimerIfNeeded(String text) {
    final lower = text.toLowerCase();
    final discussesProjection = projectionKeywords.any((kw) => lower.contains(kw));
    final hasDisclaimer = lower.contains('outil éducatif') ||
        lower.contains('outil educatif') ||
        lower.contains('lsfin') ||
        lower.contains('spécialiste');

    if (discussesProjection && !hasDisclaimer) {
      var trimmed = text.trimRight();
      if (!trimmed.endsWith('.')) trimmed += '.';
      return '$trimmed\n\n_$standardDisclaimer\_';
    }
    return text;
  }

  static (String, String?) _enforceLength(String text, int maxWords) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return (text, null);

    final truncatedWords = words.take(maxWords).toList();
    var truncated = truncatedWords.join(' ');

    final lastPeriod = truncated.lastIndexOf('.');
    final lastExclaim = truncated.lastIndexOf('!');
    final lastQuestion = truncated.lastIndexOf('?');
    final lastBoundary = [lastPeriod, lastExclaim, lastQuestion]
        .reduce((a, b) => a > b ? a : b);

    if (lastBoundary > 0) {
      truncated = truncated.substring(0, lastBoundary + 1);
    }

    return (truncated, 'Texte trop long: ${words.length} mots (limite: $maxWords)');
  }
}
