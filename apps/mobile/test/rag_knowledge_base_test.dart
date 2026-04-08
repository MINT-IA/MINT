import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Tests for S56 RAG Knowledge Base — 45 structured concept documents
///
/// Validates: structure, compliance, legal references, Swiss law accuracy,
/// content quality, and cross-document consistency.
///
/// These tests read markdown files from education/inserts/concepts/ and
/// validate them against MINT compliance rules (CLAUDE.md § 6).
void main() {
  late List<File> conceptFiles;
  late Map<String, String> fileContents;
  late Map<String, Map<String, String>> parsedFrontmatter;

  setUpAll(() {
    // Navigate from test/ up to project root
    final projectRoot = _findProjectRoot(Directory.current.path);
    final conceptDir =
        Directory('$projectRoot/education/inserts/concepts');

    expect(conceptDir.existsSync(), isTrue,
        reason: 'education/inserts/concepts/ directory must exist');

    conceptFiles = conceptDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    fileContents = {
      for (final f in conceptFiles)
        _basename(f): f.readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n')
    };

    parsedFrontmatter = {
      for (final entry in fileContents.entries)
        entry.key: _parseFrontmatter(entry.value)
    };
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 1. INVENTORY — Document count
  // ═══════════════════════════════════════════════════════════════════════

  group('Inventory', () {
    test('at least 45 concept documents exist (S56 baseline)', () {
      expect(conceptFiles.length, greaterThanOrEqualTo(45));
    });

    test('all S56 documents are present', () {
      const s56Ids = [
        'avs_13e_rente',
        'avs_ajournement',
        'avs_bonifications_educatives',
        'avs_cotisation_minimale',
        'avs_cotisations_independants',
        'avs_extrait_compte',
        'avs_plafonnement_couple',
        'avs_rachat_lacunes',
        'avs_rente_calcul',
        'avs_rente_invalidite',
        'avs_rente_survivant',
        'avs_retraite_anticipee',
        'lpp_taux_conversion_detail',
        'lpp_rachat_strategie',
        'lpp_libre_passage_detail',
        'lpp_capital_vs_rente_decision',
        'lpp_retrait_epl',
        'lpp_retraite_anticipee_impact',
        'lpp_bonifications_age',
        'lpp_salaire_coordonne',
        'lpp_surobligatoire_role',
        'lpp_changement_caisse',
        'lpp_1e_plans',
        'lpp_divorce_partage',
        '3a_plafonds_detail',
        '3a_retroactif_conditions',
        '3a_retrait_echelonne',
        '3a_multi_comptes',
        '3a_investissement_vs_epargne',
        '3a_retrait_immobilier',
        '3a_beneficiaires',
        '3a_depart_suisse',
        'fiscal_impot_capital_retrait',
        'fiscal_deductions_courantes',
        'fiscal_declaration_simplifiee',
        'fiscal_impot_fortune',
        'fiscal_impot_succession',
        'fiscal_double_imposition',
        'fiscal_impot_source',
        'fiscal_optimisation_legale',
        'budget_regle_50_30_20',
        'patrimoine_fonds_urgence',
        'patrimoine_diversification',
        'assurance_lamal_subsides',
        'succession_testament',
      ];

      final existingIds =
          parsedFrontmatter.values.map((fm) => fm['id']).toSet();

      for (final id in s56Ids) {
        expect(existingIds, contains(id),
            reason: 'Missing S56 document: $id');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. FRONTMATTER — Required fields
  // ═══════════════════════════════════════════════════════════════════════

  group('Frontmatter', () {
    test('every document has id field', () {
      for (final entry in parsedFrontmatter.entries) {
        expect(entry.value.containsKey('id'), isTrue,
            reason: '${entry.key} missing frontmatter id');
        expect(entry.value['id']!.isNotEmpty, isTrue,
            reason: '${entry.key} has empty id');
      }
    });

    test('every document has title field', () {
      for (final entry in parsedFrontmatter.entries) {
        expect(entry.value.containsKey('title'), isTrue,
            reason: '${entry.key} missing frontmatter title');
        expect(entry.value['title']!.isNotEmpty, isTrue,
            reason: '${entry.key} has empty title');
      }
    });

    test('every document has trigger field', () {
      for (final entry in parsedFrontmatter.entries) {
        expect(entry.value.containsKey('trigger'), isTrue,
            reason: '${entry.key} missing frontmatter trigger');
        expect(entry.value['trigger']!.isNotEmpty, isTrue,
            reason: '${entry.key} has empty trigger');
      }
    });

    test('every document has tags field', () {
      for (final entry in parsedFrontmatter.entries) {
        expect(entry.value.containsKey('tags'), isTrue,
            reason: '${entry.key} missing frontmatter tags');
        expect(entry.value['tags']!.isNotEmpty, isTrue,
            reason: '${entry.key} has empty tags');
      }
    });

    test('id matches filename (without .md)', () {
      for (final entry in parsedFrontmatter.entries) {
        final expectedId = entry.key.replaceAll('.md', '');
        expect(entry.value['id'], equals(expectedId),
            reason:
                '${entry.key}: id "${entry.value['id']}" != filename "$expectedId"');
      }
    });

    test('trigger has at least 2 keywords', () {
      for (final entry in parsedFrontmatter.entries) {
        final trigger = entry.value['trigger'] ?? '';
        final keywords = trigger.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty);
        expect(keywords.length, greaterThanOrEqualTo(2),
            reason: '${entry.key}: trigger needs at least 2 keywords, has ${keywords.length}');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. STRUCTURE — Required sections
  // ═══════════════════════════════════════════════════════════════════════

  group('Structure — required sections', () {
    const requiredSections = [
      '## Trigger',
      '## Premier Éclairage',
      '## Niveau 0',
      '## Niveau 1',
      '## Sources',
      '## Disclaimer',
    ];

    for (final section in requiredSections) {
      test('every document has "$section"', () {
        for (final entry in fileContents.entries) {
          expect(entry.value.contains(section), isTrue,
              reason: '${entry.key} missing section: $section');
        }
      });
    }

    test('Niveau 0 appears before Niveau 1', () {
      for (final entry in fileContents.entries) {
        final n0 = entry.value.indexOf('## Niveau 0');
        final n1 = entry.value.indexOf('## Niveau 1');
        if (n0 >= 0 && n1 >= 0) {
          expect(n0, lessThan(n1),
              reason: '${entry.key}: Niveau 0 must come before Niveau 1');
        }
      }
    });

    test('Disclaimer is the last section', () {
      for (final entry in fileContents.entries) {
        final disc = entry.value.indexOf('## Disclaimer');
        final sources = entry.value.indexOf('## Sources');
        if (disc >= 0 && sources >= 0) {
          expect(disc, greaterThan(sources),
              reason: '${entry.key}: Disclaimer must come after Sources');
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. COMPLIANCE — Banned terms (CLAUDE.md § 6)
  // ═══════════════════════════════════════════════════════════════════════

  group('Compliance — banned terms', () {
    // These patterns match banned terms used AS ABSOLUTES
    // False positives: "certains cantons" (= some), "assuré·e" (= insured person),
    // "ne garantissent pas" (= disclaimer), comparative "meilleur ou pire"

    test('no "optimal/optimale" as absolute', () {
      for (final entry in fileContents.entries) {
        // Match "optimal" standalone, not in "sous-optimal" or negation
        final matches = RegExp(r'\boptimal(?:e|es|ement)?\b', caseSensitive: false)
            .allMatches(entry.value)
            .where((m) {
          final context = entry.value.substring(
              (m.start - 30).clamp(0, entry.value.length),
              (m.end + 10).clamp(0, entry.value.length));
          return !context.contains('sous-optimal');
        });
        expect(matches.isEmpty, isTrue,
            reason:
                '${entry.key} contains banned "optimal": ${matches.map((m) => m.group(0)).join(", ")}');
      }
    });

    test('no "sans risque" (absolute safety promise)', () {
      for (final entry in fileContents.entries) {
        expect(entry.value.toLowerCase().contains('sans risque'), isFalse,
            reason: '${entry.key} contains banned "sans risque"');
      }
    });

    test('no "parfait/parfaite" (absolute)', () {
      for (final entry in fileContents.entries) {
        final has = RegExp(r'\bparfait(?:e|s|es|ement)?\b', caseSensitive: false)
            .hasMatch(entry.value);
        expect(has, isFalse,
            reason: '${entry.key} contains banned "parfait"');
      }
    });

    test('no "conseiller" (use "spécialiste" instead)', () {
      for (final entry in fileContents.entries) {
        final has = RegExp(r'\bconseiller\b', caseSensitive: false)
            .hasMatch(entry.value);
        expect(has, isFalse,
            reason:
                '${entry.key} uses "conseiller" — must use "spécialiste"');
      }
    });

    test('"garanti" only in disclaimers or negations', () {
      for (final entry in fileContents.entries) {
        final matches = RegExp(r'\bgaranti(?:e|s|es|r|ssent|ssait)?\b',
                caseSensitive: false)
            .allMatches(entry.value);

        for (final m in matches) {
          final start = (m.start - 50).clamp(0, entry.value.length);
          final end = (m.end + 50).clamp(0, entry.value.length);
          final context = entry.value.substring(start, end).toLowerCase();

          // Allowed contexts: disclaimers, negations, factual descriptions
          final isAllowed = context.contains('non garanti') ||
              context.contains('ne garanti') ||
              context.contains('pas de garantie') ||
              context.contains('garantie des dépôts') ||
              context.contains('ne constitue pas') ||
              context.contains('rendements passés') ||
              context.contains('fixé par la loi');

          if (!isAllowed) {
            fail(
                '${entry.key} uses "garanti" outside disclaimer/negation: '
                '"...${context.trim()}..."');
          }
        }
      }
    });

    test('"meilleur" only in comparative or negation, never as absolute', () {
      for (final entry in fileContents.entries) {
        final matches = RegExp(r'\bmeilleur(?:e|s|es)?\b',
                caseSensitive: false)
            .allMatches(entry.value);

        for (final m in matches) {
          final start = (m.start - 60).clamp(0, entry.value.length);
          final end = (m.end + 40).clamp(0, entry.value.length);
          final context = entry.value.substring(start, end).toLowerCase();

          // Allowed: comparative "meilleur ou", negation "pas de meilleur",
          // "Il n'y a pas de meilleur", "légèrement meilleur"
          final isAllowed = context.contains('pas de') ||
              context.contains("n'y a pas") ||
              context.contains('ou pire') ||
              context.contains('légèrement');

          if (!isAllowed) {
            fail(
                '${entry.key} uses "meilleur" as absolute: '
                '"...${context.trim()}..."');
          }
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. DISCLAIMER — Must reference LSFin
  // ═══════════════════════════════════════════════════════════════════════

  group('Disclaimer quality', () {
    test('every disclaimer mentions "éducatif" or "informatif"', () {
      for (final entry in fileContents.entries) {
        final discIdx = entry.value.indexOf('## Disclaimer');
        if (discIdx < 0) continue;
        final disclaimer = entry.value.substring(discIdx);
        final hasEducatif = disclaimer.toLowerCase().contains('éducatif') ||
            disclaimer.toLowerCase().contains('informatif');
        expect(hasEducatif, isTrue,
            reason:
                '${entry.key}: disclaimer must mention "éducatif" or "informatif"');
      }
    });

    test('every disclaimer mentions "ne constitue pas"', () {
      for (final entry in fileContents.entries) {
        final discIdx = entry.value.indexOf('## Disclaimer');
        if (discIdx < 0) continue;
        final disclaimer = entry.value.substring(discIdx);
        expect(disclaimer.contains('ne constitue pas'), isTrue,
            reason:
                '${entry.key}: disclaimer must include "ne constitue pas"');
      }
    });

    test('every disclaimer mentions LSFin or spécialiste', () {
      for (final entry in fileContents.entries) {
        final discIdx = entry.value.indexOf('## Disclaimer');
        if (discIdx < 0) continue;
        final disclaimer = entry.value.substring(discIdx);
        final hasRef = disclaimer.contains('LSFin') ||
            disclaimer.contains('spécialiste');
        expect(hasRef, isTrue,
            reason:
                '${entry.key}: disclaimer must reference LSFin or spécialiste');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. LEGAL REFERENCES — Sources section quality
  // ═══════════════════════════════════════════════════════════════════════

  group('Sources quality', () {
    test('every document has at least one legal reference', () {
      final legalPattern = RegExp(
          r'(LAVS|LPP|LIFD|OPP[23]?|LFLP|LAMal|LACI|LSFin|CC|CO|FINMA|art\.\s*\d+)',
          caseSensitive: false);

      for (final entry in fileContents.entries) {
        final srcIdx = entry.value.indexOf('## Sources');
        if (srcIdx < 0) continue;
        final discIdx = entry.value.indexOf('## Disclaimer');
        final sourcesSection = discIdx > srcIdx
            ? entry.value.substring(srcIdx, discIdx)
            : entry.value.substring(srcIdx);
        expect(legalPattern.hasMatch(sourcesSection), isTrue,
            reason:
                '${entry.key}: Sources section must reference at least one Swiss law');
      }
    });

    test('AVS documents reference LAVS', () {
      for (final entry in fileContents.entries) {
        if (!entry.key.startsWith('avs_')) continue;
        expect(entry.value.contains('LAVS'), isTrue,
            reason: '${entry.key}: AVS document must reference LAVS');
      }
    });

    test('LPP documents reference LPP or LFLP', () {
      for (final entry in fileContents.entries) {
        if (!entry.key.startsWith('lpp_')) continue;
        final hasRef =
            entry.value.contains('LPP') || entry.value.contains('LFLP');
        expect(hasRef, isTrue,
            reason:
                '${entry.key}: LPP document must reference LPP or LFLP');
      }
    });

    test('fiscal documents reference LIFD', () {
      for (final entry in fileContents.entries) {
        if (!entry.key.startsWith('fiscal_')) continue;
        expect(entry.value.contains('LIFD'), isTrue,
            reason:
                '${entry.key}: fiscal document must reference LIFD');
      }
    });

    test('3a documents reference OPP3 or LPP', () {
      for (final entry in fileContents.entries) {
        if (!entry.key.startsWith('3a_')) continue;
        final hasRef =
            entry.value.contains('OPP3') || entry.value.contains('LPP');
        expect(hasRef, isTrue,
            reason:
                '${entry.key}: 3a document must reference OPP3 or LPP');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. CHIFFRE CHOC — Impact number quality
  // ═══════════════════════════════════════════════════════════════════════

  group('Premier Éclairage quality', () {
    test('every premier éclairage contains a number (CHF or %)', () {
      final numberPattern = RegExp(r"(CHF|\d+['\.]?\d+|\d+\s*%|\d+ mois|\d+ ans)");

      for (final entry in fileContents.entries) {
        final chocIdx = entry.value.indexOf('## Premier Éclairage');
        final niv0Idx = entry.value.indexOf('## Niveau 0');
        if (chocIdx < 0 || niv0Idx < 0) continue;

        final chocSection = entry.value.substring(chocIdx, niv0Idx);
        expect(numberPattern.hasMatch(chocSection), isTrue,
            reason:
                '${entry.key}: Premier Éclairage must contain an impactful number');
      }
    });

    test('premier éclairage is concise (< 300 words)', () {
      for (final entry in fileContents.entries) {
        final chocIdx = entry.value.indexOf('## Premier Éclairage');
        final niv0Idx = entry.value.indexOf('## Niveau 0');
        if (chocIdx < 0 || niv0Idx < 0) continue;

        final chocSection = entry.value.substring(chocIdx, niv0Idx);
        final wordCount = chocSection.split(RegExp(r'\s+')).length;
        expect(wordCount, lessThan(300),
            reason:
                '${entry.key}: Premier Éclairage too verbose ($wordCount words)');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. CONTENT QUALITY — Word count, bi-level structure
  // ═══════════════════════════════════════════════════════════════════════

  group('Content quality', () {
    test('Niveau 0 is simpler than Niveau 1 (fewer technical terms)', () {
      final techTerms = RegExp(
          r'(art\.\s*\d+|LAVS|LPP|LIFD|OPP|LFLP|alinéa|al\.\s*\d+|lit\.\s*[a-z])',
          caseSensitive: false);

      for (final entry in fileContents.entries) {
        final n0Idx = entry.value.indexOf('## Niveau 0');
        final n1Idx = entry.value.indexOf('## Niveau 1');
        if (n0Idx < 0 || n1Idx < 0) continue;

        final niveau0 = entry.value.substring(n0Idx, n1Idx);
        final srcIdx = entry.value.indexOf('## Sources');
        final niveau1 = srcIdx > n1Idx
            ? entry.value.substring(n1Idx, srcIdx)
            : entry.value.substring(n1Idx);

        final n0Terms = techTerms.allMatches(niveau0).length;
        final n1Terms = techTerms.allMatches(niveau1).length;

        // Niveau 1 should have MORE technical terms than Niveau 0
        // (or at least equal — some simple topics may have few in both)
        expect(n1Terms, greaterThanOrEqualTo(n0Terms),
            reason:
                '${entry.key}: Niveau 1 ($n1Terms tech terms) should be >= Niveau 0 ($n0Terms tech terms)');
      }
    });

    test('total word count is reasonable (150-800 words)', () {
      for (final entry in fileContents.entries) {
        final wordCount =
            entry.value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        expect(wordCount, greaterThan(150),
            reason: '${entry.key}: too short ($wordCount words)');
        expect(wordCount, lessThan(800),
            reason: '${entry.key}: too long ($wordCount words)');
      }
    });

    test('Niveau 0 uses accessible language (analogies or examples)', () {
      final accessiblePatterns = RegExp(
          r"(comme|imagine|par exemple|c'est un peu|en gros|concrètement|autrement dit)",
          caseSensitive: false);

      for (final entry in fileContents.entries) {
        final n0Idx = entry.value.indexOf('## Niveau 0');
        final n1Idx = entry.value.indexOf('## Niveau 1');
        if (n0Idx < 0 || n1Idx < 0) continue;

        final niveau0 = entry.value.substring(n0Idx, n1Idx);
        expect(accessiblePatterns.hasMatch(niveau0), isTrue,
            reason:
                '${entry.key}: Niveau 0 should use analogies or accessible language');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. SWISS LAW ACCURACY — Key constants validation
  // ═══════════════════════════════════════════════════════════════════════

  group('Swiss law accuracy', () {
    test("AVS rente max referenced correctly (CHF 2'520 or 30'240)", () {
      for (final entry in fileContents.entries) {
        if (!entry.key.startsWith('avs_')) continue;
        final content = entry.value;
        // If the doc mentions rente maximale, it should use correct values
        if (content.contains('rente maximal')) {
          // Handle both straight apostrophe and typographic apostrophe
          final hasCorrectMax = RegExp(r"2['\u2019]?520|30['\u2019]?240")
              .hasMatch(content);
          expect(hasCorrectMax, isTrue,
              reason:
                  '${entry.key}: mentions rente maximale but without correct value');
        }
      }
    });

    test('LPP docs that detail conversion rate mention 6.8%', () {
      // Only check files specifically about conversion rate, not every mention
      const conversionFiles = [
        'lpp_taux_conversion_detail.md',
        'lpp_capital_vs_rente_decision.md',
        'lpp_surobligatoire_role.md',
      ];
      for (final fname in conversionFiles) {
        final content = fileContents[fname];
        if (content == null) continue;
        expect(content.contains('6.8'), isTrue,
            reason: '$fname: must mention conversion rate 6.8%');
      }
    });

    test("3a plafond salarié LPP is CHF 7'258", () {
      for (final entry in fileContents.entries) {
        if (!entry.key.startsWith('3a_')) continue;
        final content = entry.value;
        if (content.contains('plafond') && content.contains('salarié')) {
          final hasCorrect = RegExp(r"7['\u2019]?258").hasMatch(content);
          expect(hasCorrect, isTrue,
              reason: '${entry.key}: mentions 3a plafond salarié but not 7258');
        }
      }
    });

    test("coordination deduction is CHF 26'460", () {
      for (final entry in fileContents.entries) {
        final content = entry.value;
        if (content.contains('déduction de coordination') ||
            content.contains('salaire coordonné')) {
          if (entry.key.contains('lpp_salaire') ||
              entry.key.contains('deduction')) {
            final hasCorrect = RegExp(r"26['\u2019]?460").hasMatch(content);
            expect(hasCorrect, isTrue,
                reason: '${entry.key}: mentions coordination but not 26460');
          }
        }
      }
    });

    test('couple AVS cap is 150% (LAVS art. 35)', () {
      final content = fileContents['avs_plafonnement_couple.md'];
      if (content == null) return; // Skip if file doesn't exist
      expect(content.contains('150'), isTrue,
          reason: 'avs_plafonnement_couple must mention 150% cap');
      expect(content.contains('art. 35') || content.contains('LAVS'),
          isTrue,
          reason: 'avs_plafonnement_couple must reference LAVS art. 35');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. CROSS-DOCUMENT CONSISTENCY
  // ═══════════════════════════════════════════════════════════════════════

  group('Cross-document consistency', () {
    test('no duplicate IDs across documents', () {
      final ids = <String>[];
      for (final fm in parsedFrontmatter.values) {
        if (fm.containsKey('id')) ids.add(fm['id']!);
      }
      expect(ids.toSet().length, equals(ids.length),
          reason: 'Duplicate document IDs found');
    });

    test('all documents use inclusive language (spécialiste, not conseiller)', () {
      for (final entry in fileContents.entries) {
        if (entry.value.contains('spécialiste')) {
          expect(
              entry.value.contains(RegExp(r'\bconseiller\b', caseSensitive: false)),
              isFalse,
              reason:
                  '${entry.key}: uses both "spécialiste" and "conseiller"');
        }
      }
    });

    test('tags use consistent format [bracket, comma, separated]', () {
      for (final entry in parsedFrontmatter.entries) {
        final tags = entry.value['tags'] ?? '';
        if (tags.isNotEmpty) {
          expect(tags.startsWith('['), isTrue,
              reason: '${entry.key}: tags must start with [');
          expect(tags.endsWith(']'), isTrue,
              reason: '${entry.key}: tags must end with ]');
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 11. FRENCH DIACRITICS — No ASCII substitutes
  // ═══════════════════════════════════════════════════════════════════════

  group('French diacritics', () {
    test('no "impot" without accent in body text (must be "impôt")', () {
      for (final entry in fileContents.entries) {
        final body = _stripFrontmatter(entry.value);
        // Exclude "impotent·e" which is a legitimate French word
        final matches = RegExp(r'\bimpots?\b', caseSensitive: false)
            .allMatches(body)
            .where((m) {
          final end = (m.end + 10).clamp(0, body.length);
          return !body.substring(m.start, end).contains('impotent');
        });
        expect(matches.isEmpty, isTrue,
            reason: '${entry.key}: "impot" must be "impôt"');
      }
    });

    test('no "prevoyance" without accent in body text (must be "prévoyance")', () {
      for (final entry in fileContents.entries) {
        final body = _stripFrontmatter(entry.value);
        final hasAscii = RegExp(r'\bprevoyance\b', caseSensitive: false)
            .hasMatch(body);
        expect(hasAscii, isFalse,
            reason: '${entry.key}: "prevoyance" must be "prévoyance"');
      }
    });

    test('no "interet" without accent in body text (must be "intérêt")', () {
      for (final entry in fileContents.entries) {
        final body = _stripFrontmatter(entry.value);
        final hasAscii = RegExp(r'\binterets?\b', caseSensitive: false)
            .hasMatch(body);
        expect(hasAscii, isFalse,
            reason: '${entry.key}: "interet" must be "intérêt"');
      }
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

String _basename(File f) => f.path.split('/').last;

String _stripFrontmatter(String content) {
  if (!content.startsWith('---')) return content;
  final endIdx = content.indexOf('---', 3);
  if (endIdx < 0) return content;
  return content.substring(endIdx + 3);
}

String _findProjectRoot(String from) {
  var dir = Directory(from);
  while (dir.path != '/') {
    if (File('${dir.path}/CLAUDE.md').existsSync()) return dir.path;
    // Also check for education/ dir
    if (Directory('${dir.path}/education').existsSync()) return dir.path;
    dir = dir.parent;
  }
  // Fallback: go up from test dir
  return Directory(from).parent.parent.parent.path;
}

Map<String, String> _parseFrontmatter(String content) {
  final result = <String, String>{};
  // Normalize CRLF → LF
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (!normalized.startsWith('---')) return result;

  final endIdx = normalized.indexOf('---', 3);
  if (endIdx < 0) return result;

  final frontmatter = normalized.substring(3, endIdx).trim();
  for (final line in frontmatter.split('\n')) {
    final colonIdx = line.indexOf(':');
    if (colonIdx > 0) {
      final key = line.substring(0, colonIdx).trim();
      final value = line.substring(colonIdx + 1).trim();
      result[key] = value;
    }
  }
  return result;
}
