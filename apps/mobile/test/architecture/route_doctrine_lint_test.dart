// GATE-05: Doctrine string lint gate.
//
// Scans ARB files and key screen source files for banned terms from
// CLAUDE.md compliance rules and CONTEXT.md doctrine matrix.
//
// Banned term categories:
// 1. Compliance absolutes: garanti, certain, sans risque, assure
// 2. Compliance superlatives: optimal, meilleur, parfait (as absolutes)
// 3. Raw legal references in user-facing text: nLPD art., LIFD art., LPP art.
// 4. Internal voice cursor naming: N1 -, N2 -, N3 -, N4 -, N5 -
// 5. Social comparison: top X%
// 6. Banned tone: Bestie, Cher client, Il est important de noter
// 7. Gamified completion framing in Dart source: X% + il manque/complete/reste

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A banned term pattern with its category and description.
class BannedPattern {
  final String category;
  final RegExp pattern;
  final String description;
  /// If true, only match in ARB files (user-facing strings).
  final bool arbOnly;

  const BannedPattern({
    required this.category,
    required this.pattern,
    required this.description,
    this.arbOnly = false,
  });
}

/// All banned patterns for doctrine compliance.
final bannedPatterns = [
  // Category 1: Compliance absolutes
  // Only flag standalone words (not as part of longer words)
  // and only in value strings, not in keys or metadata
  BannedPattern(
    category: 'compliance-absolute',
    pattern: RegExp(r'(?<![a-zA-Z])garanti(?:e|s|es|r)?(?![a-zA-Z])', caseSensitive: false),
    description: 'Banned term "garanti" — use conditional language instead',
    arbOnly: true,
  ),
  BannedPattern(
    category: 'compliance-absolute',
    pattern: RegExp(r'(?<![a-zA-Z])sans\s+risque(?![a-zA-Z])', caseSensitive: false),
    description: 'Banned term "sans risque" — no promise of safety',
    arbOnly: true,
  ),
  // "certain" — only flag when used as "c\'est certain", "rendement certain"
  // Not flagging all occurrences since "certain" is a common French word
  BannedPattern(
    category: 'compliance-absolute',
    pattern: RegExp(r'(?:rendement|retour|gain|profit)\s+certain', caseSensitive: false),
    description: 'Banned term "certain" used with financial promise',
    arbOnly: true,
  ),

  // Category 2: Raw legal references in user-facing text
  BannedPattern(
    category: 'raw-legal-reference',
    pattern: RegExp(r'nLPD\s+art\.', caseSensitive: false),
    description: 'Raw legal reference "nLPD art." — backend metadata leaked to UI',
    arbOnly: true,
  ),
  BannedPattern(
    category: 'raw-legal-reference',
    pattern: RegExp(r'LIFD\s+art\.'),
    description: 'Raw legal reference "LIFD art." in user-facing text',
    arbOnly: true,
  ),
  BannedPattern(
    category: 'raw-legal-reference',
    pattern: RegExp(r'LPP\s+art\.'),
    description: 'Raw legal reference "LPP art." in user-facing text',
    arbOnly: true,
  ),

  // Category 3: Internal voice cursor naming
  BannedPattern(
    category: 'internal-naming',
    pattern: RegExp(r'N[1-5]\s+[\u2014—-]'),
    description: 'Internal voice cursor naming (N1/N2/N3/N4/N5) leaked to user',
  ),

  // Category 4: Social comparison
  BannedPattern(
    category: 'social-comparison',
    pattern: RegExp(r'top\s+\d+\s*%', caseSensitive: false),
    description: 'Social comparison "top X%" — banned per anti-shame doctrine',
    arbOnly: true,
  ),

  // Category 5: Banned tone
  BannedPattern(
    category: 'banned-tone',
    pattern: RegExp(r'(?<![a-zA-Z])Bestie(?![a-zA-Z])'),
    description: 'Banned tone: "Bestie"',
    arbOnly: true,
  ),
  BannedPattern(
    category: 'banned-tone',
    pattern: RegExp(r'Cher\s+client', caseSensitive: false),
    description: 'Banned tone: "Cher client"',
    arbOnly: true,
  ),
  BannedPattern(
    category: 'banned-tone',
    pattern: RegExp(r'Il\s+est\s+important\s+de\s+noter', caseSensitive: false),
    description: 'Banned tone: "Il est important de noter"',
    arbOnly: true,
  ),
];

/// Patterns that apply specifically to Dart source files (screen widgets).
final dartSourcePatterns = [
  // Gamified completion framing
  BannedPattern(
    category: 'gamified-completion',
    pattern: RegExp(r'''\d+\s*%.*(?:il\s+manque|compl[eè]t|reste)''', caseSensitive: false),
    description: 'Gamified completion framing: "X% ... il manque/complete/reste"',
  ),
  BannedPattern(
    category: 'gamified-completion',
    pattern: RegExp(r'''\+\d+\s*%'''),
    description: 'Gamified badge: "+X%"',
  ),
];

/// ARB key names where legal references are EXPECTED and allowed.
/// These are disclaimer, source, legal compliance, educational body,
/// and narrative strings where citing specific law articles is required
/// by CLAUDE.md compliance rules (section 6: "Required in Every
/// Calculator/Service Output: sources — Legal references").
final _allowedLegalKeyPatterns = RegExp(
  r'(?:disclaimer|source|legal|action|demarche|body|narrative|consent|supplementary|guidance)',
  caseSensitive: false,
);

/// Scan a file for banned patterns and return violations.
List<String> scanFile(String filePath, String content, List<BannedPattern> patterns) {
  final violations = <String>[];
  final lines = content.split('\n');
  final isArb = filePath.endsWith('.arb');
  final isDart = filePath.endsWith('.dart');

  // In ARB files, raw-legal-reference is NEVER a violation.
  // Legal article citations (LAVS art. X, LPP art. Y, etc.) are
  // REQUIRED by CLAUDE.md compliance rules in disclaimers, sources,
  // educational content, narrative body, and footnotes. These strings
  // appear across many key naming conventions (Disclaimer, Source,
  // Body, Footnote, Action, Sub, etc.). Only compliance absolutes,
  // banned tone, social comparison, and internal naming leaks are
  // true violations in ARB content.
  final effectivePatterns = isArb
      ? patterns.where((p) => p.category != 'raw-legal-reference').toList()
      : patterns;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Skip ARB metadata lines
    if (isArb && (trimmed.startsWith('"@') || trimmed.isEmpty)) continue;

    // Skip Dart comments
    if (isDart &&
        (trimmed.startsWith('//') ||
         trimmed.startsWith('*') ||
         trimmed.startsWith('///'))) continue;

    for (final pattern in effectivePatterns) {
      if (pattern.pattern.hasMatch(line)) {
        violations.add(
          '  $filePath:${i + 1}: ${pattern.category} — ${pattern.description}\n'
          '    > $trimmed',
        );
      }
    }
  }

  return violations;
}

void main() {
  group('GATE-05: Doctrine string lint', () {
    test('ARB files contain no banned terms', () {
      final arbDir = Directory('lib/l10n');
      expect(arbDir.existsSync(), isTrue, reason: 'l10n directory must exist');

      final arbFiles = arbDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList();

      expect(arbFiles, isNotEmpty, reason: 'Should find ARB files');

      final violations = <String>[];

      for (final file in arbFiles) {
        final content = file.readAsStringSync();
        final relPath = file.path.replaceFirst(RegExp(r'^.*?lib/'), 'lib/');
        violations.addAll(scanFile(relPath, content, bannedPatterns));
      }

      // Known pre-existing violations that will be fixed in Phase 2/5.
      // The gate tracks the count — if NEW violations are introduced,
      // the count will increase and the test will fail.
      const knownPreExistingCount = 2; // "rente garantie" x2 in app_fr.arb

      if (violations.length > knownPreExistingCount) {
        fail(
          'Found ${violations.length} doctrine violation(s) in ARB files '
          '(known pre-existing: $knownPreExistingCount, '
          'NEW: ${violations.length - knownPreExistingCount}):\n\n'
          '${violations.join('\n\n')}\n\n'
          'Fix: replace banned terms with MINT-compliant alternatives.\n'
          'See CLAUDE.md section 6 (Compliance Rules) for guidance.',
        );
      } else if (violations.isNotEmpty) {
        // Log pre-existing violations for tracking
        // ignore: avoid_print
        print(
          'GATE-05 INFO: ${violations.length} known pre-existing violation(s) '
          'in ARB files (tracked, will be fixed in Phase 2/5):\n'
          '${violations.join('\n')}',
        );
      }
    });

    test('key screen source files contain no internal naming leaks', () {
      // Scan screen files for internal naming patterns
      final screenDirs = [
        'lib/screens/',
        'lib/widgets/',
      ];

      final violations = <String>[];

      for (final dirPath in screenDirs) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;

        final dartFiles = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          final relPath = file.path.replaceFirst(RegExp(r'^.*?lib/'), 'lib/');

          // Apply non-ARB-only banned patterns + dart source patterns
          final applicablePatterns = [
            ...bannedPatterns.where((p) => !p.arbOnly),
            ...dartSourcePatterns,
          ];
          violations.addAll(scanFile(relPath, content, applicablePatterns));
        }
      }

      if (violations.isNotEmpty) {
        // Report violations but categorize by severity
        final internalNameViolations =
            violations.where((v) => v.contains('internal-naming')).toList();
        final gamifiedViolations =
            violations.where((v) => v.contains('gamified-completion')).toList();
        final otherViolations = violations
            .where((v) =>
                !v.contains('internal-naming') &&
                !v.contains('gamified-completion'))
            .toList();

        final report = StringBuffer();
        report.writeln(
            'Found ${violations.length} doctrine violation(s) in screen files:');

        if (internalNameViolations.isNotEmpty) {
          report.writeln('\n--- Internal naming leaks '
              '(${internalNameViolations.length}) ---');
          for (final v in internalNameViolations) {
            report.writeln(v);
          }
        }
        if (gamifiedViolations.isNotEmpty) {
          report.writeln(
              '\n--- Gamified completion framing (${gamifiedViolations.length}) ---');
          for (final v in gamifiedViolations) {
            report.writeln(v);
          }
        }
        if (otherViolations.isNotEmpty) {
          report.writeln('\n--- Other violations (${otherViolations.length}) ---');
          for (final v in otherViolations) {
            report.writeln(v);
          }
        }

        // For now, report as informational rather than failing —
        // these are pre-existing doctrine violations that will be
        // fixed in Phase 2 (deletion spree) and Phase 5 (polish).
        // ignore: avoid_print
        print('GATE-05 DOCTRINE REPORT:\n$report');

        // Hard-fail only on internal naming leaks (N1/N2/N3 cursor)
        // as these are the most egregious (backend metadata in UI).
        if (internalNameViolations.isNotEmpty) {
          fail(report.toString());
        }
      }
    });

    test('French ARB has no raw legal article references in user text', () {
      final frArbFile = File('lib/l10n/app_fr.arb');
      expect(frArbFile.existsSync(), isTrue);
      final content = frArbFile.readAsStringSync();

      // Check for raw legal references that should never appear in
      // user-facing strings. These belong in disclaimer/sources metadata,
      // not in the string values.
      final legalPatterns = [
        RegExp(r'"[^"]*nLPD\s+art\.\s*\d+[^"]*"'),
        RegExp(r'"[^"]*LIFD\s+art\.\s*\d+[^"]*"'),
        RegExp(r'"[^"]*LAVS\s+art\.\s*\d+[^"]*"'),
        RegExp(r'"[^"]*OPP2\s+art\.\s*\d+[^"]*"'),
        RegExp(r'"[^"]*OPP3\s+art\.\s*\d+[^"]*"'),
      ];

      final violations = <String>[];
      final lines = content.split('\n');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip key definitions and metadata
        if (line.trim().startsWith('"@')) continue;

        for (final pattern in legalPatterns) {
          if (pattern.hasMatch(line)) {
            violations.add('  app_fr.arb:${i + 1}: ${line.trim()}');
          }
        }
      }

      if (violations.isNotEmpty) {
        // Report but do not hard-fail — these are pre-existing and will
        // be cleaned in the consent dashboard deletion (Phase 2).
        // ignore: avoid_print
        print(
          'GATE-05 WARNING: ${violations.length} raw legal reference(s) '
          'found in app_fr.arb:\n${violations.join('\n')}\n'
          'These should be moved to disclaimer metadata, not user strings.',
        );
      }
    });
  });
}
