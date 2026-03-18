import 'dart:io';
import 'dart:math';

// ────────────────────────────────────────────────────────────
//  RAG RETRIEVAL SERVICE — S67 / RAG v2 (comprehensive)
// ────────────────────────────────────────────────────────────
//
// Enhanced local retrieval pipeline for the MINT knowledge base.
//
// Searches across 3 document pools:
//   1. education/inserts/concepts/  — 45+ concept documents
//   2. education/inserts/cantons/   — 26 cantonal specifics
//   3. education/inserts/faq/       — 10 FAQ documents
//
// Retrieval algorithm:
//   1. Tokenize query into keywords
//   2. Score each document: tagMatch×3 + triggerMatch×5 +
//      titleMatch×2 + contentMatch×1
//   3. Filter by canton / niveau / tags
//   4. Sort by score descending, return top N
//   5. Format with source citations for LLM context
//
// Pure functions where possible. Async for file I/O.
// ────────────────────────────────────────────────────────────

/// A document loaded from the knowledge base.
class RagDocument {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final List<String> triggers;
  final int niveau; // 0=beginner, 1=intermediate, 2=advanced
  final String? canton; // null=federal, "VS"/"VD"/etc
  final String source;
  final DateTime lastUpdated;

  const RagDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.triggers,
    required this.niveau,
    this.canton,
    required this.source,
    required this.lastUpdated,
  });

  @override
  String toString() => 'RagDocument($id, canton=$canton, niveau=$niveau)';
}

/// Enhanced retrieval service for the MINT knowledge base.
class RagRetrievalService {
  RagRetrievalService._();

  // ═══════════════════════════════════════════════════════
  //  Core retrieval
  // ═══════════════════════════════════════════════════════

  /// Retrieve the most relevant documents for a query.
  ///
  /// [query] — user question or keywords.
  /// [maxResults] — cap on returned documents (default 3).
  /// [canton] — filter to a specific canton code (e.g. "VS").
  /// [maxNiveau] — exclude documents above this complexity.
  /// [requiredTags] — only return docs matching ALL of these tags.
  /// [allDocuments] — pre-loaded docs (avoids re-reading disk).
  static Future<List<RagDocument>> retrieve({
    required String query,
    int maxResults = 3,
    String? canton,
    int? maxNiveau,
    List<String>? requiredTags,
    List<RagDocument>? allDocuments,
  }) async {
    if (query.trim().isEmpty) return [];

    final docs = allDocuments ?? await loadAllDocuments();

    // Apply filters
    var candidates = docs.where((doc) {
      if (canton != null && doc.canton != null && doc.canton != canton) {
        return false;
      }
      if (maxNiveau != null && doc.niveau > maxNiveau) return false;
      if (requiredTags != null && requiredTags.isNotEmpty) {
        final docTagsLower = doc.tags.map((t) => t.toLowerCase()).toSet();
        for (final tag in requiredTags) {
          if (!docTagsLower.contains(tag.toLowerCase())) return false;
        }
      }
      return true;
    }).toList();

    // Score and sort — boost docs matching the requested canton
    final scored = candidates
        .map((doc) {
          var score = scoreRelevance(query, doc);
          // Canton affinity bonus: docs matching the requested canton
          // get a significant boost to ensure cantonal docs surface
          if (canton != null && doc.canton == canton) {
            score += 10;
          }
          return MapEntry(doc, score);
        })
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored
        .take(maxResults)
        .map((e) => e.key)
        .toList();
  }

  // ═══════════════════════════════════════════════════════
  //  Scoring
  // ═══════════════════════════════════════════════════════

  /// Score relevance of a document against a query.
  ///
  /// Weights: trigger×5, tag×3, title×2, content×1.
  static double scoreRelevance(String query, RagDocument doc) {
    final keywords = _tokenize(query);
    if (keywords.isEmpty) return 0;

    double score = 0;

    for (final kw in keywords) {
      final kwLower = kw.toLowerCase();

      // Trigger match (×5)
      for (final trigger in doc.triggers) {
        if (trigger.toLowerCase().contains(kwLower)) {
          score += 5;
        }
      }

      // Tag match (×3)
      for (final tag in doc.tags) {
        if (tag.toLowerCase().contains(kwLower)) {
          score += 3;
        }
      }

      // Title match (×2)
      if (doc.title.toLowerCase().contains(kwLower)) {
        score += 2;
      }

      // Content match (×1)
      if (doc.content.toLowerCase().contains(kwLower)) {
        score += 1;
      }
    }

    return score;
  }

  // ═══════════════════════════════════════════════════════
  //  Formatting for LLM context injection
  // ═══════════════════════════════════════════════════════

  /// Format retrieved documents for injection into an LLM prompt.
  ///
  /// Returns a string with document excerpts and source citations,
  /// truncated to [maxChars].
  static String formatForPrompt(
    List<RagDocument> docs, {
    int maxChars = 2000,
  }) {
    if (docs.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('--- CONTEXTE RAG ---');

    for (final doc in docs) {
      final entry = StringBuffer();
      entry.writeln('📄 ${doc.title}');

      // Trim content to share budget across docs
      final budgetPerDoc = max(200, (maxChars - 50) ~/ docs.length);
      var excerpt = doc.content;
      if (excerpt.length > budgetPerDoc) {
        excerpt = '${excerpt.substring(0, budgetPerDoc)}…';
      }
      entry.writeln(excerpt);
      entry.writeln('Source\u00a0: ${doc.source}');
      entry.writeln('');

      // Check if adding this entry would exceed maxChars
      if (buf.length + entry.length > maxChars) break;
      buf.write(entry);
    }

    buf.writeln('--- FIN CONTEXTE RAG ---');

    final result = buf.toString();
    if (result.length > maxChars) {
      return '${result.substring(0, maxChars - 1)}…';
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════
  //  Index management
  // ═══════════════════════════════════════════════════════

  /// Load all documents from all knowledge base directories.
  ///
  /// Searches: concepts/, cantons/, faq/ under education/inserts/.
  static Future<List<RagDocument>> loadAllDocuments({
    String? projectRoot,
  }) async {
    final root = projectRoot ?? _findProjectRoot(Directory.current.path);
    final basePath = '$root/education/inserts';

    final docs = <RagDocument>[];

    for (final subdir in ['concepts', 'cantons', 'faq']) {
      final dir = Directory('$basePath/$subdir');
      if (!dir.existsSync()) continue;

      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.md')) continue;
        try {
          final doc = _parseDocument(file);
          if (doc != null) docs.add(doc);
        } catch (_) {
          // Skip malformed documents
        }
      }
    }

    return docs;
  }

  /// Index documents by tag for fast lookup.
  static Map<String, List<RagDocument>> indexByTag(List<RagDocument> docs) {
    final index = <String, List<RagDocument>>{};
    for (final doc in docs) {
      for (final tag in doc.tags) {
        final key = tag.toLowerCase();
        index.putIfAbsent(key, () => []).add(doc);
      }
    }
    return index;
  }

  /// Index documents by canton for fast lookup.
  static Map<String, List<RagDocument>> indexByCanton(List<RagDocument> docs) {
    final index = <String, List<RagDocument>>{};
    for (final doc in docs) {
      if (doc.canton != null) {
        index.putIfAbsent(doc.canton!, () => []).add(doc);
      }
    }
    return index;
  }

  // ═══════════════════════════════════════════════════════
  //  Private helpers
  // ═══════════════════════════════════════════════════════

  /// Tokenize a query into keywords, removing stopwords.
  static List<String> _tokenize(String query) {
    const stopwords = {
      'le', 'la', 'les', 'de', 'du', 'des', 'un', 'une', 'et', 'ou', 'en',
      'à', 'au', 'aux', 'ce', 'ces', 'que', 'qui', 'pour', 'par', 'sur',
      'avec', 'dans', 'est', 'sont', 'mon', 'ma', 'mes', 'ton', 'ta', 'tes',
      'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ils', 'elles', 'ne', 'pas',
      'se', 'si', 'on', 'a', 'the', 'is', 'of', 'and', 'to', 'in', 'it',
      'comment', 'quoi', 'quel', 'quelle',
    };

    return query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sàâäéèêëïîôùûüçœæ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !stopwords.contains(w))
        .toList();
  }

  /// Parse a markdown document with frontmatter into a [RagDocument].
  static RagDocument? _parseDocument(File file) {
    final content = file.readAsStringSync().replaceAll('\r\n', '\n');
    if (!content.startsWith('---')) return null;

    final endIdx = content.indexOf('---', 3);
    if (endIdx < 0) return null;

    final frontmatter = content.substring(3, endIdx).trim();
    final body = content.substring(endIdx + 3).trim();

    final fm = <String, String>{};
    for (final line in frontmatter.split('\n')) {
      final colonIdx = line.indexOf(':');
      if (colonIdx > 0) {
        final key = line.substring(0, colonIdx).trim();
        final value = line.substring(colonIdx + 1).trim();
        fm[key] = value;
      }
    }

    final id = fm['id'];
    if (id == null || id.isEmpty) return null;

    // Parse trigger list
    final triggerRaw = fm['trigger'] ?? '';
    final triggers = triggerRaw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Parse tags list
    final tagsRaw = fm['tags'] ?? '';
    final tags = tagsRaw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Parse niveau
    final niveauStr = fm['niveau'] ?? '1';
    final niveau = int.tryParse(niveauStr) ?? 1;

    // Parse canton
    final canton = fm['canton'];
    final cantonClean = canton != null && canton.isNotEmpty
        ? canton.replaceAll('"', '').trim()
        : null;

    // Source
    final source = fm['source']?.replaceAll('"', '').trim() ?? '';

    return RagDocument(
      id: id,
      title: (fm['title'] ?? id).replaceAll('"', ''),
      content: body,
      tags: tags,
      triggers: triggers,
      niveau: niveau,
      canton: cantonClean,
      source: source,
      lastUpdated: file.lastModifiedSync(),
    );
  }

  /// Find the project root by searching for CLAUDE.md or education/.
  static String _findProjectRoot(String from) {
    var dir = Directory(from);
    while (dir.path != '/') {
      if (File('${dir.path}/CLAUDE.md').existsSync()) return dir.path;
      if (Directory('${dir.path}/education').existsSync()) return dir.path;
      dir = dir.parent;
    }
    return Directory(from).parent.parent.parent.path;
  }
}
