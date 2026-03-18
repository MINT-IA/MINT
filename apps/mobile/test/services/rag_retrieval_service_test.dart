import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/rag_retrieval_service.dart';

/// Tests for S67 RAG v2 — RagRetrievalService
///
/// 20 tests covering:
///   - Retrieval: query matching, filtering, ordering, edge cases
///   - Document quality: 26 cantons, 10 FAQs, frontmatter validation
///   - Compliance: banned terms, French accents, source references
///   - Integration: full pipeline query → retrieve → format
void main() {
  late List<RagDocument> allDocs;
  late Map<String, String> cantonFileContents;
  late Map<String, String> faqFileContents;
  late Map<String, Map<String, String>> cantonFrontmatter;
  late Map<String, Map<String, String>> faqFrontmatter;

  setUpAll(() async {
    final projectRoot = _findProjectRoot(Directory.current.path);

    // Load all docs via the service
    allDocs = await RagRetrievalService.loadAllDocuments(
      projectRoot: projectRoot,
    );

    // Load raw file contents for quality checks
    cantonFileContents = _loadDirectory(
      '$projectRoot/education/inserts/cantons',
    );
    faqFileContents = _loadDirectory(
      '$projectRoot/education/inserts/faq',
    );

    cantonFrontmatter = {
      for (final e in cantonFileContents.entries)
        e.key: _parseFrontmatter(e.value),
    };
    faqFrontmatter = {
      for (final e in faqFileContents.entries)
        e.key: _parseFrontmatter(e.value),
    };
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 1. RETRIEVAL TESTS
  // ═══════════════════════════════════════════════════════════════════════

  group('Retrieval', () {
    test('query "3a" returns 3a-related documents', () async {
      final results = await RagRetrievalService.retrieve(
        query: '3a',
        maxResults: 5,
        allDocuments: allDocs,
      );
      expect(results, isNotEmpty);
      final ids = results.map((d) => d.id).toList();
      final has3a = ids.any((id) => id.contains('3a'));
      expect(has3a, isTrue,
          reason: 'Query "3a" should return at least one 3a document, got: $ids');
    });

    test('query "impôt Vaud" with canton filter returns VD cantonal doc', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt Vaud',
        canton: 'VD',
        maxResults: 5,
        allDocuments: allDocs,
      );
      expect(results, isNotEmpty);
      final ids = results.map((d) => d.id).toList();
      expect(ids, contains('canton_VD'),
          reason: 'Query "impôt Vaud" with canton=VD should include canton_VD, got: $ids');
    });

    test('query "rachat LPP" returns LPP buyback docs', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'rachat LPP',
        maxResults: 5,
        allDocuments: allDocs,
      );
      expect(results, isNotEmpty);
      final ids = results.map((d) => d.id).toList();
      final hasRachat = ids.any((id) =>
          id.contains('rachat') || id.contains('lpp'));
      expect(hasRachat, isTrue,
          reason: 'Query "rachat LPP" should return rachat/LPP docs, got: $ids');
    });

    test('canton filter only returns matching canton docs', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'fiscal impôt',
        canton: 'GE',
        maxResults: 10,
        allDocuments: allDocs,
      );
      // All results with a canton should be GE
      for (final doc in results) {
        if (doc.canton != null) {
          expect(doc.canton, equals('GE'),
              reason: '${doc.id} has canton ${doc.canton}, expected GE');
        }
      }
    });

    test('niveau filter excludes advanced docs', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'prévoyance retraite fiscal',
        maxNiveau: 0,
        maxResults: 20,
        allDocuments: allDocs,
      );
      for (final doc in results) {
        expect(doc.niveau, lessThanOrEqualTo(0),
            reason: '${doc.id} has niveau ${doc.niveau}, expected <= 0');
      }
    });

    test('tag filter only returns docs with required tags', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt prévoyance',
        requiredTags: ['fiscal'],
        maxResults: 20,
        allDocuments: allDocs,
      );
      for (final doc in results) {
        final tagsLower = doc.tags.map((t) => t.toLowerCase()).toSet();
        expect(tagsLower.contains('fiscal'), isTrue,
            reason: '${doc.id} missing required tag "fiscal", has: ${doc.tags}');
      }
    });

    test('empty query returns empty results', () async {
      final results = await RagRetrievalService.retrieve(
        query: '',
        allDocuments: allDocs,
      );
      expect(results, isEmpty);
    });

    test('maxResults is respected', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt fiscal prévoyance capital retraite',
        maxResults: 2,
        allDocuments: allDocs,
      );
      expect(results.length, lessThanOrEqualTo(2));
    });

    test('score ordering is correct (most relevant first)', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'rachat LPP combler lacune',
        maxResults: 5,
        allDocuments: allDocs,
      );
      if (results.length >= 2) {
        final score1 = RagRetrievalService.scoreRelevance(
            'rachat LPP combler lacune', results[0]);
        final score2 = RagRetrievalService.scoreRelevance(
            'rachat LPP combler lacune', results[1]);
        expect(score1, greaterThanOrEqualTo(score2),
            reason: 'First result should have >= score than second');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. DOCUMENT QUALITY TESTS
  // ═══════════════════════════════════════════════════════════════════════

  group('Document quality', () {
    test('all 26 cantonal docs exist and have valid frontmatter', () {
      const cantons = [
        'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
        'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
        'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
      ];

      for (final code in cantons) {
        final filename = 'canton_$code.md';
        expect(cantonFileContents.containsKey(filename), isTrue,
            reason: 'Missing cantonal doc: $filename');

        final fm = cantonFrontmatter[filename];
        expect(fm, isNotNull, reason: '$filename has no frontmatter');
        expect(fm!['id'], equals('canton_$code'),
            reason: '$filename id mismatch');
        expect(fm['canton']?.replaceAll('"', ''), equals(code),
            reason: '$filename canton field mismatch');
      }
    });

    test('all 10 FAQ docs exist and have valid frontmatter', () {
      const faqIds = [
        'faq_3a_versement_retroactif',
        'faq_13e_rente_avs',
        'faq_rachat_lpp',
        'faq_rente_vs_capital',
        'faq_impot_retrait_capital',
        'faq_hypotheque_taux',
        'faq_avs_lacunes',
        'faq_pilier3a_plafond',
        'faq_divorce_prevoyance',
        'faq_expatrie_retour',
      ];

      for (final id in faqIds) {
        final filename = '$id.md';
        expect(faqFileContents.containsKey(filename), isTrue,
            reason: 'Missing FAQ doc: $filename');

        final fm = faqFrontmatter[filename];
        expect(fm, isNotNull, reason: '$filename has no frontmatter');
        expect(fm!['id'], equals(id),
            reason: '$filename id "${fm['id']}" != "$id"');
      }
    });

    test('every doc has id matching filename', () {
      void checkDir(Map<String, Map<String, String>> fmMap) {
        for (final entry in fmMap.entries) {
          final expectedId = entry.key.replaceAll('.md', '');
          expect(entry.value['id'], equals(expectedId),
              reason: '${entry.key}: id "${entry.value['id']}" != "$expectedId"');
        }
      }

      checkDir(cantonFrontmatter);
      checkDir(faqFrontmatter);
    });

    test('every doc has at least 2 triggers', () {
      void checkDir(Map<String, Map<String, String>> fmMap) {
        for (final entry in fmMap.entries) {
          final trigger = entry.value['trigger'] ?? '';
          final keywords = trigger
              .replaceAll('[', '')
              .replaceAll(']', '')
              .split(',')
              .map((k) => k.trim())
              .where((k) => k.isNotEmpty);
          expect(keywords.length, greaterThanOrEqualTo(2),
              reason: '${entry.key}: needs >= 2 triggers, has ${keywords.length}');
        }
      }

      checkDir(cantonFrontmatter);
      checkDir(faqFrontmatter);
    });

    test('no banned terms in any document', () {
      void checkContent(Map<String, String> contents) {
        for (final entry in contents.entries) {
          // "sans risque" — absolute safety promise
          expect(entry.value.toLowerCase().contains('sans risque'), isFalse,
              reason: '${entry.key} contains banned "sans risque"');

          // "parfait" as absolute
          final hasPerfect = RegExp(r'\bparfait(?:e|s|es|ement)?\b',
                  caseSensitive: false)
              .hasMatch(entry.value);
          expect(hasPerfect, isFalse,
              reason: '${entry.key} contains banned "parfait"');

          // "conseiller" — must use "spécialiste"
          final hasConseiller = RegExp(r'\bconseiller\b', caseSensitive: false)
              .hasMatch(entry.value);
          expect(hasConseiller, isFalse,
              reason: '${entry.key} uses "conseiller" — must use "spécialiste"');
        }
      }

      checkContent(cantonFileContents);
      checkContent(faqFileContents);
    });

    test('French accents correct — no "impot" or "prevoyance" without accent', () {
      void checkContent(Map<String, String> contents) {
        for (final entry in contents.entries) {
          final body = _stripFrontmatter(entry.value);

          final hasImpot = RegExp(r'\bimpots?\b', caseSensitive: false)
              .hasMatch(body);
          expect(hasImpot, isFalse,
              reason: '${entry.key}: "impot" must be "impôt"');

          final hasPrevoyance =
              RegExp(r'\bprevoyance\b', caseSensitive: false).hasMatch(body);
          expect(hasPrevoyance, isFalse,
              reason: '${entry.key}: "prevoyance" must be "prévoyance"');
        }
      }

      checkContent(cantonFileContents);
      checkContent(faqFileContents);
    });

    test('every doc has source reference', () {
      void checkDir(Map<String, Map<String, String>> fmMap) {
        for (final entry in fmMap.entries) {
          final source = entry.value['source'] ?? '';
          expect(source.isNotEmpty, isTrue,
              reason: '${entry.key}: missing source in frontmatter');
        }
      }

      checkDir(cantonFrontmatter);
      checkDir(faqFrontmatter);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. FORMAT / INTEGRATION TESTS
  // ═══════════════════════════════════════════════════════════════════════

  group('Format and integration', () {
    test('formatForPrompt stays under maxChars limit', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt fiscal prévoyance retraite capital',
        maxResults: 5,
        allDocuments: allDocs,
      );

      const limit = 2000;
      final formatted = RagRetrievalService.formatForPrompt(
        results,
        maxChars: limit,
      );
      expect(formatted.length, lessThanOrEqualTo(limit),
          reason: 'Formatted output (${formatted.length}) exceeds $limit chars');
    });

    test('formatForPrompt includes source citations', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'rachat LPP',
        maxResults: 3,
        allDocuments: allDocs,
      );

      final formatted = RagRetrievalService.formatForPrompt(results);
      expect(formatted.contains('Source'), isTrue,
          reason: 'Formatted output must include source citations');
    });

    test('full pipeline: query → retrieve → format → usable for LLM', () async {
      // Simulate a user asking about cantonal taxes in Valais
      final results = await RagRetrievalService.retrieve(
        query: 'impôt canton Valais retrait capital',
        canton: 'VS',
        maxResults: 3,
        allDocuments: allDocs,
      );

      expect(results, isNotEmpty,
          reason: 'Should find docs for Valais tax query');

      final formatted = RagRetrievalService.formatForPrompt(results);
      expect(formatted.contains('CONTEXTE RAG'), isTrue);
      expect(formatted.contains('FIN CONTEXTE RAG'), isTrue);
      expect(formatted.length, greaterThan(50),
          reason: 'Formatted context should have meaningful content');
      expect(formatted.length, lessThan(3000),
          reason: 'Formatted context should not be excessively long');
    });

    test('indexByTag produces valid tag index', () {
      final index = RagRetrievalService.indexByTag(allDocs);
      expect(index, isNotEmpty);
      // 'fiscal' should have many entries (26 cantons + fiscal concepts)
      expect(index.containsKey('fiscal'), isTrue);
      expect(index['fiscal']!.length, greaterThanOrEqualTo(26));
    });

    test('indexByCanton produces index with 26 cantons', () {
      final index = RagRetrievalService.indexByCanton(allDocs);
      expect(index.length, greaterThanOrEqualTo(26),
          reason: 'Should have at least 26 cantonal entries, got ${index.length}');
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

String _findProjectRoot(String from) {
  var dir = Directory(from);
  while (dir.path != '/') {
    if (File('${dir.path}/CLAUDE.md').existsSync()) return dir.path;
    if (Directory('${dir.path}/education').existsSync()) return dir.path;
    dir = dir.parent;
  }
  return Directory(from).parent.parent.parent.path;
}

Map<String, String> _loadDirectory(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return {};
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList();
  return {
    for (final f in files)
      f.path.split('/').last:
          f.readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n')
  };
}

Map<String, String> _parseFrontmatter(String content) {
  final result = <String, String>{};
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

String _stripFrontmatter(String content) {
  if (!content.startsWith('---')) return content;
  final endIdx = content.indexOf('---', 3);
  if (endIdx < 0) return content;
  return content.substring(endIdx + 3);
}
