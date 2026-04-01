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
    // Plural forms (GAP #1: inflection bypass via plurals)
    'garantis',
    'garanties',
    'assurés',
    'assurées',
    'certains',
    'certaines',
    'optimaux',
    'optimales',
    'meilleurs',
    'meilleures',
    'parfaits',
    'parfaites',
    // Prescriptive phrases
    'tu devrais',
    'tu dois',
    'il faut que tu',
    'la meilleure option',
    'nous recommandons',
    'nous te conseillons',
    'il est optimal',
    'la solution idéale',
    // Product recommendation terms (GAP #3: named products/ISINs)
    'idéal',
    'idéale',
    // Superlative form of "meilleur" (GAP #4: "le mieux" bypass)
    'le mieux',
    // FIX-081: German banned terms (Deutschschweiz users)
    'garantiert', 'sicher', 'ohne risiko', 'optimal', 'beste',
    'perfekt', 'berater', 'du solltest', 'du musst', 'wir empfehlen',
    // FIX-081: Italian banned terms (Svizzera italiana users)
    'garantito', 'garantita', 'sicuro', 'senza rischio', 'ottimale',
    'migliore', 'perfetto', 'perfetta', 'consigliamo', 'devi',
    // FIX-081: English banned terms (expat users)
    'guaranteed', 'risk-free', 'optimal', 'best', 'perfect',
    'you should', 'you must', 'we recommend', 'ideal',
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
    // Plural forms
    'garantis': 'possibles dans ce scénario',
    'garanties': 'possibles dans ce scénario',
    'assurés': 'envisageables',
    'assurées': 'envisageables',
    'certains': 'probables',
    'certaines': 'probables',
    'optimaux': 'adaptés',
    'optimales': 'adaptées',
    'meilleurs': 'pertinents',
    'meilleures': 'pertinentes',
    'parfaits': 'adaptés',
    'parfaites': 'adaptées',
    // Prescriptive phrases
    'tu devrais': 'tu pourrais envisager de',
    'tu dois': 'il serait utile de',
    'il faut que tu': 'tu pourrais',
    'la meilleure option': 'une option à considérer',
    'nous recommandons': 'une piste possible serait',
    'nous te conseillons': 'une approche envisageable serait',
    'il est optimal': 'il pourrait être pertinent',
    'la solution idéale': 'une approche adaptée',
    // Product recommendation terms
    'idéal': 'adapté',
    'idéale': 'adaptée',
    // Superlative form
    'le mieux': 'une option pertinente',
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
    RegExp(r'investis?\s+(?:dans|\d)', caseSensitive: false),
    RegExp(r'place\s+ton\s+argent', caseSensitive: false),
    RegExp(r'(?:je|on)\s+(?:te|vous)\s+recommande', caseSensitive: false),
    RegExp(r'priorit[ée]\s+absolue', caseSensitive: false),
    RegExp("c['\u2018\u2019]est\\s+plus\\s+important\\s+que", caseSensitive: false),
    RegExp(r'souscris\b', caseSensitive: false),
    RegExp(r'rach[eè]te\b', caseSensitive: false),
    RegExp(r'transf[eè]re\b', caseSensitive: false),
    // Social comparison patterns (GAP #2: ranking users against others)
    RegExp(r'top\s+\d+\s*%', caseSensitive: false),
    RegExp(r'meilleur\s+que\s+\d+\s*%', caseSensitive: false),
    RegExp(r'mieux\s+que\s+\d+\s*%', caseSensitive: false),
    RegExp(r'devant\s+\d+\s*%\s+des', caseSensitive: false),
    RegExp(r'parmi\s+les\s+meilleurs', caseSensitive: false),
    RegExp(r'au-dessus\s+de\s+la\s+moyenne', caseSensitive: false),
    // Product recommendation patterns (GAP #3: ISIN codes, tickers)
    RegExp(r'ISIN\s+[A-Z]{2}\d', caseSensitive: false),
    RegExp(r'\b[A-Z]{2}\d{10,12}\b'), // ISIN code pattern
    RegExp(r'(?:le|ce)\s+(?:fonds|produit|ETF)\s+\w+\s+(?:est|a)\b', caseSensitive: false),
  ];

  // Fuzzy banned pattern for "sans ... risque" variants
  // FIX-W12: Bounded repetition to prevent ReDoS catastrophic backtracking
  static final _sansRisquePattern = RegExp(r'sans\s+(?:\w+\s+){0,10}risque', caseSensitive: false);

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

    // Defense-in-depth: if sanitization emptied the text, force fallback.
    if (!useFallback && text.trim().isEmpty) {
      useFallback = true;
      violations.add('Texte vide après sanitisation');
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
  /// to avoid false positives on "incertain", "parfaitement".
  /// Text is lowercased before matching to handle accented uppercase
  /// (Dart caseSensitive:false only folds ASCII a-z/A-Z, not À-ÿ).
  static List<String> _checkBannedTerms(String text) {
    final lower = text.toLowerCase();
    final found = <String>[];
    for (final entry in _bannedTermPatterns.entries) {
      if (entry.value.hasMatch(lower)) {
        found.add(entry.key);
      }
    }
    // Fuzzy: "sans aucun risque" etc.
    if (!found.contains('sans risque') && _sansRisquePattern.hasMatch(lower)) {
      found.add('sans risque');
    }
    return found;
  }

  /// Public accessor for banned-term sanitization.
  ///
  /// Used as a minimal safety net when the full [validate] pipeline crashes
  /// (e.g. on SLM output where ComplianceGuard encounters an edge case).
  static String sanitizeBannedTerms(String text) => _sanitizeBannedTerms(text);

  /// Sanitize text by replacing banned terms with softer alternatives.
  /// Processes multi-word phrases first (longer match priority), then
  /// single-word terms, to avoid partial replacements mangling phrases.
  static String _sanitizeBannedTerms(String text) {
    // FIX-W12: Normalize common homoglyphs before banned term matching
    var result = text
        .replaceAll('ο', 'o')  // Greek omicron → Latin o
        .replaceAll('а', 'a')  // Cyrillic a → Latin a
        .replaceAll('е', 'e')  // Cyrillic e → Latin e
        .replaceAll('і', 'i')  // Cyrillic i → Latin i
        .replaceAll('р', 'p')  // Cyrillic r → Latin p
        .replaceAll('с', 'c')  // Cyrillic s → Latin c
        .replaceAll('ⅼ', 'l')  // Roman numeral l → Latin l
        .replaceAll('ⅿ', 'm'); // Roman numeral m → Latin m
    final phrases = termReplacements.entries.where((e) => e.key.contains(' '));
    final words = termReplacements.entries.where((e) => !e.key.contains(' '));
    for (final entry in [...phrases, ...words]) {
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
      return '$trimmed\n\n_${standardDisclaimer}_';
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
