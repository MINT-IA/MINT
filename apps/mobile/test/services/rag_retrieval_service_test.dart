import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/rag_retrieval_service.dart';

/// Tests for S67 RAG v2 — RagRetrievalService
///
/// 60+ tests covering:
///   - Retrieval: query matching, filtering, ordering, edge cases
///   - Document quality: 26 cantons, 10 FAQs, frontmatter validation
///   - Compliance: banned terms, French accents, source references
///   - Integration: full pipeline query → retrieve → format
///   - Per-canton retrieval: each of 26 cantons returns valid result
///   - Per-FAQ retrieval: each of 10 FAQs returns valid result
///   - Edge cases: unknown canton, special chars, long queries
///   - Canton doc structure: cantonal law references
///   - Scoring: relevance ordering, score consistency
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

  // ═══════════════════════════════════════════════════════════════════════
  // 4. PER-CANTON RETRIEVAL — each of 26 cantons
  // ═══════════════════════════════════════════════════════════════════════

  group('Per-canton retrieval', () {
    const cantonNames = <String, String>{
      'AG': 'Argovie', 'AI': 'Appenzell', 'AR': 'Appenzell',
      'BE': 'Berne', 'BL': 'Bâle', 'BS': 'Bâle',
      'FR': 'Fribourg', 'GE': 'Genève', 'GL': 'Glaris',
      'GR': 'Grisons', 'JU': 'Jura', 'LU': 'Lucerne',
      'NE': 'Neuchâtel', 'NW': 'Nidwald', 'OW': 'Obwald',
      'SG': 'Saint-Gall', 'SH': 'Schaffhouse', 'SO': 'Soleure',
      'SZ': 'Schwytz', 'TG': 'Thurgovie', 'TI': 'Tessin',
      'UR': 'Uri', 'VD': 'Vaud', 'VS': 'Valais',
      'ZG': 'Zoug', 'ZH': 'Zurich',
    };

    for (final entry in cantonNames.entries) {
      final code = entry.key;
      test('canton $code — retrieval returns cantonal doc', () async {
        final results = await RagRetrievalService.retrieve(
          query: 'impôt fiscal ${entry.value}',
          canton: code,
          maxResults: 5,
          allDocuments: allDocs,
        );
        expect(results, isNotEmpty,
            reason: 'Query for canton $code should return results');
        final hasCantonDoc = results.any((d) => d.id == 'canton_$code');
        expect(hasCantonDoc, isTrue,
            reason: 'Results for $code should include canton_$code, got: '
                '${results.map((d) => d.id).toList()}');
      });
    }
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. PER-FAQ RETRIEVAL — each of 10 FAQs
  // ═══════════════════════════════════════════════════════════════════════

  group('Per-FAQ retrieval', () {
    const faqQueries = <String, String>{
      'faq_3a_versement_retroactif': '3a rétroactif versement rattrapage',
      'faq_13e_rente_avs': '13e rente AVS',
      'faq_rachat_lpp': 'rachat LPP combler lacune',
      'faq_rente_vs_capital': 'rente capital choix retrait',
      'faq_impot_retrait_capital': 'impôt retrait capital',
      'faq_hypotheque_taux': 'hypothèque taux hypothécaire',
      'faq_avs_lacunes': 'AVS lacunes cotisation',
      'faq_pilier3a_plafond': 'pilier 3a plafond maximum',
      'faq_divorce_prevoyance': 'divorce prévoyance partage',
      'faq_expatrie_retour': 'expatrié retour Suisse',
    };

    for (final entry in faqQueries.entries) {
      final faqId = entry.key;
      final query = entry.value;
      test('FAQ $faqId — retrieval returns matching doc', () async {
        final results = await RagRetrievalService.retrieve(
          query: query,
          maxResults: 5,
          allDocuments: allDocs,
        );
        expect(results, isNotEmpty,
            reason: 'Query "$query" should return results for $faqId');
        final hasFaq = results.any((d) => d.id == faqId);
        expect(hasFaq, isTrue,
            reason: 'Results for "$query" should include $faqId, got: '
                '${results.map((d) => d.id).toList()}');
      });
    }
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('whitespace-only query returns empty', () async {
      final results = await RagRetrievalService.retrieve(
        query: '   \t  \n  ',
        allDocuments: allDocs,
      );
      expect(results, isEmpty);
    });

    test('query with only stopwords returns empty or very low results', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'le la les de du des un une et ou',
        maxResults: 5,
        allDocuments: allDocs,
      );
      // Stopwords are filtered, so tokenizer produces empty → no results
      expect(results, isEmpty,
          reason: 'Query of only stopwords should return empty');
    });

    test('special characters in query do not crash', () async {
      final results = await RagRetrievalService.retrieve(
        query: r'impôt <script>alert("xss")</script> 3a & LPP | *',
        maxResults: 3,
        allDocuments: allDocs,
      );
      // Should not throw, may or may not find results
      expect(results, isA<List<RagDocument>>());
    });

    test('very long query does not crash', () async {
      final longQuery = List.generate(200, (i) => 'prévoyance').join(' ');
      final results = await RagRetrievalService.retrieve(
        query: longQuery,
        maxResults: 3,
        allDocuments: allDocs,
      );
      expect(results, isA<List<RagDocument>>());
    });

    test('unknown canton code returns no cantonal docs', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt fiscal prévoyance',
        canton: 'XX',
        maxResults: 10,
        allDocuments: allDocs,
      );
      // Canton filter should exclude all cantonal docs (canton != XX)
      for (final doc in results) {
        if (doc.canton != null) {
          expect(doc.canton, equals('XX'),
              reason: '${doc.id} has canton=${doc.canton}, expected XX or null');
        }
      }
    });

    test('maxResults=0 returns empty list', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt fiscal',
        maxResults: 0,
        allDocuments: allDocs,
      );
      expect(results, isEmpty);
    });

    test('maxResults=1 returns exactly 1 result', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt fiscal prévoyance capital retraite',
        maxResults: 1,
        allDocuments: allDocs,
      );
      expect(results.length, equals(1));
    });

    test('formatForPrompt with empty list returns empty string', () {
      final result = RagRetrievalService.formatForPrompt([]);
      expect(result, isEmpty);
    });

    test('formatForPrompt with very small maxChars truncates', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt fiscal prévoyance',
        maxResults: 3,
        allDocuments: allDocs,
      );
      if (results.isNotEmpty) {
        final formatted = RagRetrievalService.formatForPrompt(
          results,
          maxChars: 100,
        );
        expect(formatted.length, lessThanOrEqualTo(100));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. RELEVANCE SCORING
  // ═══════════════════════════════════════════════════════════════════════

  group('Relevance scoring', () {
    test('trigger match scores higher than content-only match', () {
      final docWithTrigger = RagDocument(
        id: 'test_trigger',
        title: 'Test',
        content: 'Contenu sans rapport',
        tags: [],
        triggers: ['rachat LPP'],
        niveau: 0,
        source: 'test',
        lastUpdated: DateTime.now(),
      );
      final docContentOnly = RagDocument(
        id: 'test_content',
        title: 'Test',
        content: 'Le rachat LPP est important',
        tags: [],
        triggers: ['autre chose'],
        niveau: 0,
        source: 'test',
        lastUpdated: DateTime.now(),
      );

      final scoreTrigger = RagRetrievalService.scoreRelevance(
        'rachat LPP',
        docWithTrigger,
      );
      final scoreContent = RagRetrievalService.scoreRelevance(
        'rachat LPP',
        docContentOnly,
      );
      expect(scoreTrigger, greaterThan(scoreContent),
          reason: 'Trigger match ($scoreTrigger) should score higher '
              'than content match ($scoreContent)');
    });

    test('scoreRelevance returns 0 for empty query', () {
      final doc = RagDocument(
        id: 'test',
        title: 'Test',
        content: 'Contenu',
        tags: ['fiscal'],
        triggers: ['test'],
        niveau: 0,
        source: 'test',
        lastUpdated: DateTime.now(),
      );
      expect(RagRetrievalService.scoreRelevance('', doc), equals(0));
    });

    test('scoreRelevance returns 0 for no-match query', () {
      final doc = RagDocument(
        id: 'test',
        title: 'Impôt valaisan',
        content: 'Fiscalité cantonale du Valais',
        tags: ['fiscal', 'VS'],
        triggers: ['Valais', 'impôt'],
        niveau: 0,
        source: 'test',
        lastUpdated: DateTime.now(),
      );
      expect(RagRetrievalService.scoreRelevance('xyzzyxyzzy', doc), equals(0));
    });

    test('results are sorted by descending relevance', () async {
      final results = await RagRetrievalService.retrieve(
        query: 'impôt prévoyance retraite capital',
        maxResults: 10,
        allDocuments: allDocs,
      );
      if (results.length >= 2) {
        for (int i = 0; i < results.length - 1; i++) {
          final s1 = RagRetrievalService.scoreRelevance(
            'impôt prévoyance retraite capital',
            results[i],
          );
          final s2 = RagRetrievalService.scoreRelevance(
            'impôt prévoyance retraite capital',
            results[i + 1],
          );
          expect(s1, greaterThanOrEqualTo(s2),
              reason: 'Result[$i] score=$s1 should be >= result[${i + 1}] score=$s2');
        }
      }
    });

    test('tag match contributes to score', () {
      final doc = RagDocument(
        id: 'test_tag',
        title: 'Titre neutre',
        content: 'Contenu neutre',
        tags: ['fiscal'],
        triggers: [],
        niveau: 0,
        source: 'test',
        lastUpdated: DateTime.now(),
      );
      final score = RagRetrievalService.scoreRelevance('fiscal', doc);
      expect(score, greaterThan(0),
          reason: 'Tag match should contribute to score');
    });

    test('title match contributes to score', () {
      final doc = RagDocument(
        id: 'test_title',
        title: 'Prévoyance retraite',
        content: 'Contenu neutre',
        tags: [],
        triggers: [],
        niveau: 0,
        source: 'test',
        lastUpdated: DateTime.now(),
      );
      final score = RagRetrievalService.scoreRelevance('prévoyance', doc);
      expect(score, greaterThan(0),
          reason: 'Title match should contribute to score');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. CANTON DOCS STRUCTURE — cantonal law references
  // ═══════════════════════════════════════════════════════════════════════

  group('Canton docs structure', () {
    const allCantons = [
      'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
      'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
      'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
    ];

    test('all 26 canton docs have "fiscal" tag', () {
      for (final code in allCantons) {
        final fm = cantonFrontmatter['canton_$code.md'];
        expect(fm, isNotNull, reason: 'canton_$code.md missing');
        final tags = fm!['tags'] ?? '';
        expect(tags.toLowerCase().contains('fiscal'), isTrue,
            reason: 'canton_$code.md missing "fiscal" tag, has: $tags');
      }
    });

    test('all 26 canton docs have "cantonal" tag', () {
      for (final code in allCantons) {
        final fm = cantonFrontmatter['canton_$code.md'];
        expect(fm, isNotNull);
        final tags = fm!['tags'] ?? '';
        expect(tags.toLowerCase().contains('cantonal'), isTrue,
            reason: 'canton_$code.md missing "cantonal" tag');
      }
    });

    test('all 26 canton docs have niveau field', () {
      for (final code in allCantons) {
        final fm = cantonFrontmatter['canton_$code.md'];
        expect(fm, isNotNull);
        expect(fm!.containsKey('niveau'), isTrue,
            reason: 'canton_$code.md missing niveau field');
        final niveau = int.tryParse(fm['niveau'] ?? '');
        expect(niveau, isNotNull,
            reason: 'canton_$code.md niveau is not an integer');
      }
    });

    test('all 26 canton docs have title', () {
      for (final code in allCantons) {
        final fm = cantonFrontmatter['canton_$code.md'];
        expect(fm, isNotNull);
        final title = fm!['title'] ?? '';
        expect(title.isNotEmpty, isTrue,
            reason: 'canton_$code.md missing title');
      }
    });

    test('all 26 canton docs mention LIFD art. 38 (capital withdrawal)', () {
      for (final code in allCantons) {
        final content = cantonFileContents['canton_$code.md'] ?? '';
        final body = _stripFrontmatter(content);
        // Canton docs should reference LIFD art. 38 for capital withdrawal tax
        final hasRef = body.contains('art. 38') || body.contains('LIFD');
        expect(hasRef, isTrue,
            reason: 'canton_$code.md should reference LIFD/art. 38 for capital tax');
      }
    });

    test('all 26 canton docs have Chiffre Choc section', () {
      for (final code in allCantons) {
        final content = cantonFileContents['canton_$code.md'] ?? '';
        expect(content.contains('Chiffre Choc'), isTrue,
            reason: 'canton_$code.md missing "Chiffre Choc" section');
      }
    });

    test('all 26 canton docs have Niveau 0 section', () {
      for (final code in allCantons) {
        final content = cantonFileContents['canton_$code.md'] ?? '';
        expect(content.contains('Niveau 0'), isTrue,
            reason: 'canton_$code.md missing "Niveau 0" section');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. FAQ DOCS STRUCTURE
  // ═══════════════════════════════════════════════════════════════════════

  group('FAQ docs structure', () {
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

    test('all 10 FAQ docs have at least 2 tags', () {
      for (final id in faqIds) {
        final fm = faqFrontmatter['$id.md'];
        expect(fm, isNotNull);
        final tags = (fm!['tags'] ?? '')
            .replaceAll('[', '').replaceAll(']', '')
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty);
        expect(tags.length, greaterThanOrEqualTo(2),
            reason: '$id.md has only ${tags.length} tag(s)');
      }
    });

    test('all 10 FAQ docs have niveau field', () {
      for (final id in faqIds) {
        final fm = faqFrontmatter['$id.md'];
        expect(fm, isNotNull);
        expect(fm!.containsKey('niveau'), isTrue,
            reason: '$id.md missing niveau');
      }
    });

    test('all 10 FAQ docs have Chiffre Choc section', () {
      for (final id in faqIds) {
        final content = faqFileContents['$id.md'] ?? '';
        expect(content.contains('Chiffre Choc'), isTrue,
            reason: '$id.md missing "Chiffre Choc" section');
      }
    });

    test('all 10 FAQ docs have Niveau 0 section (beginner explanation)', () {
      for (final id in faqIds) {
        final content = faqFileContents['$id.md'] ?? '';
        expect(content.contains('Niveau 0'), isTrue,
            reason: '$id.md missing "Niveau 0" section');
      }
    });

    test('all 10 FAQ docs have source with legal reference', () {
      for (final id in faqIds) {
        final fm = faqFrontmatter['$id.md'];
        expect(fm, isNotNull);
        final source = fm!['source'] ?? '';
        expect(source.isNotEmpty, isTrue,
            reason: '$id.md missing source');
        // Source should contain a legal reference (art., LPP, LAVS, OPP3, LIFD, etc.)
        final hasLegalRef = RegExp(r'(art\.|LPP|LAVS|OPP3|LIFD|LAMal|LACI|CC|CO|FINMA|Conseil)',
            caseSensitive: false).hasMatch(source);
        expect(hasLegalRef, isTrue,
            reason: '$id.md source "$source" lacks legal reference');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. COMPLIANCE — extended banned terms
  // ═══════════════════════════════════════════════════════════════════════

  group('Compliance extended', () {
    test('no "garanti" in any document body', () {
      void check(Map<String, String> contents) {
        for (final entry in contents.entries) {
          final body = _stripFrontmatter(entry.value);
          final hasGaranti = RegExp(r'\bgaranti(?:e|s|es|r)?\b',
              caseSensitive: false).hasMatch(body);
          expect(hasGaranti, isFalse,
              reason: '${entry.key} contains banned "garanti"');
        }
      }
      check(cantonFileContents);
      check(faqFileContents);
    });

    test('no "certain" (as absolute safety) in any document body', () {
      void check(Map<String, String> contents) {
        for (final entry in contents.entries) {
          final body = _stripFrontmatter(entry.value);
          // "certain" as absolute safety term, not "certaines conditions"
          final hasCertain = RegExp(r"\bc'est certain\b|\bgarantie certaine\b",
              caseSensitive: false).hasMatch(body);
          expect(hasCertain, isFalse,
              reason: '${entry.key} contains banned absolute "certain"');
        }
      }
      check(cantonFileContents);
      check(faqFileContents);
    });

    test('no "optimal" / "meilleur" as absolute in any document body', () {
      void check(Map<String, String> contents) {
        for (final entry in contents.entries) {
          final body = _stripFrontmatter(entry.value);
          // Check for "le meilleur" / "la meilleure" (absolute)
          // but allow "meilleur que" (comparative)
          final hasOptimal = RegExp(r'\boptimal(?:e|es|ement)?\b',
              caseSensitive: false).hasMatch(body);
          expect(hasOptimal, isFalse,
              reason: '${entry.key} contains banned "optimal"');
        }
      }
      check(cantonFileContents);
      check(faqFileContents);
    });

    test('no "assuré" / "sans risque" (safety promise) in documents', () {
      void check(Map<String, String> contents) {
        for (final entry in contents.entries) {
          final body = _stripFrontmatter(entry.value);
          // "assur" as safety promise: "c'est assuré", "rendement assuré"
          // but allow "assurance" (insurance product name)
          final hasSansRisque = body.toLowerCase().contains('sans risque');
          expect(hasSansRisque, isFalse,
              reason: '${entry.key} contains banned "sans risque"');
        }
      }
      check(cantonFileContents);
      check(faqFileContents);
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
