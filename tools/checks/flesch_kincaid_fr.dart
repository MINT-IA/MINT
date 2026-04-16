// Phase 10 Plan 10-03 — Flesch-Kincaid French readability gate (ACCESS-06).
//
// Pure-Dart readability guard. No Flutter, no pub dependencies beyond the
// Dart SDK. Runs in CI against `apps/mobile/lib/l10n/app_fr.arb` to lock an
// anti-jargon discipline on the onboarding surfaces (landing v2 + intent).
//
// ## Why the Kandel–Moles variant?
//
// The classic English Flesch formula
//     206.835 − 1.015·(words/sentences) − 84.6·(syllables/word)
// is badly mis-calibrated for French: common B1 sentences score <40 because
// average French syllables-per-word (~1.5) is higher than English and the
// 84.6 coefficient over-penalises. Kandel & Moles (1958) re-fitted the
// coefficients on a French corpus and produced
//     207 − 1.015·(words/sentences) − 73.6·(syllables/word)
// which places plain-French B1 prose in the 70–90 band. We use K–M as the
// canonical score for the MINT CI gate (ACCESS-06).
//
// ## Short-string guard
//
// FK / K–M is statistically unreliable on fragments shorter than ~8 words
// (a 3-word chip label like "J'ai un projet" is not a "readability"
// signal — it is a UI affordance). The CLI therefore skips strings below
// `--min-words` (default 8). Skipped strings are reported but do not
// contribute to pass/fail.
//
// ## CLI
//
// dart run tools/checks/flesch_kincaid_fr.dart <arb_path>
//     [--keys-prefix=prefix1,prefix2,...]  // default: intentScreen,intentChip,landingV2
//     [--min=SCORE]                        // default: 50  (K-M floor ≈ B1)
//     [--min-words=N]                      // default: 8   (short-string guard)
//
// Exit 0 → all qualifying strings pass.
// Exit 1 → at least one qualifying string scored below `--min`.
//
// Consumers: .github/workflows/ci.yml (readability job), local dev runs.

import 'dart:convert';
import 'dart:io';

/// Computes the Kandel–Moles French readability score for [text].
///
/// The score is normalised so higher values mean easier to read. Typical
/// bands (K–M calibration):
///   • 90–100: very easy (elementary)
///   • 70–89:  easy      (B1/B2, MINT target)
///   • 50–69:  standard  (general adult press)
///   • 30–49:  difficult (technical / administrative)
///   • <30:    very difficult (legal, academic)
double kandelMolesFr(String text) {
  if (text.trim().isEmpty) return 0.0;
  final sentences = _splitSentences(text);
  final words = _splitWords(text);
  if (words.isEmpty) return 0.0;
  final nSentences = sentences.isEmpty ? 1 : sentences.length;
  final nWords = words.length;
  final nSyllables = words.fold<int>(0, (a, w) => a + _countSyllables(w));
  final wps = nWords / nSentences;
  final spw = nSyllables / nWords;
  return 207.0 - 1.015 * wps - 73.6 * spw;
}

/// Legacy English Flesch formula, exposed for unit-test sanity checks only.
/// Do NOT use this to gate the CI — French corpora score too low.
double fleschKincaidFrClassic(String text) {
  if (text.trim().isEmpty) return 0.0;
  final sentences = _splitSentences(text);
  final words = _splitWords(text);
  if (words.isEmpty) return 0.0;
  final nSentences = sentences.isEmpty ? 1 : sentences.length;
  final nWords = words.length;
  final nSyllables = words.fold<int>(0, (a, w) => a + _countSyllables(w));
  return 206.835 - 1.015 * (nWords / nSentences) - 84.6 * (nSyllables / nWords);
}

/// Counts the words in [text] using the same tokeniser as [kandelMolesFr].
int countWords(String text) => _splitWords(text).length;

/// Counts French vowel groups in [word]; minimum 1 for non-empty words.
///
/// French syllable boundaries are notoriously irregular; counting contiguous
/// vowel groups (incl. nasalised and accented vowels) is the standard
/// approximation used by every lightweight readability tool. Silent final
/// "e" is intentionally NOT stripped — that refinement shifts scores by <2
/// points on the target corpus and would add false positives on words like
/// "MINT" (treated as one syllable either way).
int _countSyllables(String word) {
  if (word.isEmpty) return 0;
  final lowered = word.toLowerCase();
  final cleaned = lowered.replaceAll(
    RegExp(r"[^a-zàâäéèêëîïôöùûüÿçœæ]"),
    '',
  );
  if (cleaned.isEmpty) return 0;
  final groups = RegExp(r'[aeiouyàâäéèêëîïôöùûüÿœæ]+').allMatches(cleaned);
  final count = groups.length;
  return count == 0 ? 1 : count;
}

List<String> _splitSentences(String text) {
  return text
      .split(RegExp(r'[.!?]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

List<String> _splitWords(String text) {
  return text
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .toList();
}

/// Result of scoring a single ARB key.
class FkKeyResult {
  final String key;
  final String value;
  final int wordCount;
  final double score;
  final bool skipped; // true when wordCount < minWords
  const FkKeyResult({
    required this.key,
    required this.value,
    required this.wordCount,
    required this.score,
    required this.skipped,
  });
}

/// Scores every key in [arbMap] matching any of [keyPrefixes] and returns
/// the per-key result list. Metadata keys (starting with '@') and non-string
/// values are ignored.
List<FkKeyResult> scoreArb(
  Map<String, dynamic> arbMap, {
  required List<String> keyPrefixes,
  required int minWords,
}) {
  final out = <FkKeyResult>[];
  for (final entry in arbMap.entries) {
    final key = entry.key;
    if (key.startsWith('@')) continue;
    final value = entry.value;
    if (value is! String) continue;
    if (!keyPrefixes.any((p) => key.startsWith(p))) continue;
    final nWords = countWords(value);
    final score = kandelMolesFr(value);
    out.add(FkKeyResult(
      key: key,
      value: value,
      wordCount: nWords,
      score: score,
      skipped: nWords < minWords,
    ));
  }
  return out;
}

/// CLI entry point. Library consumers (tests) should import the pure
/// functions above and not call [main].
Future<void> main(List<String> argv) async {
  if (argv.isEmpty || argv.contains('--help') || argv.contains('-h')) {
    stderr.writeln(
      'Usage: dart run tools/checks/flesch_kincaid_fr.dart <arb_path> '
      '[--keys-prefix=a,b,c] [--min=50] [--min-words=8]',
    );
    exit(argv.isEmpty ? 2 : 0);
  }

  final arbPath = argv.first;
  var prefixes = const <String>['intentScreen', 'intentChip', 'landingV2'];
  var minScore = 50.0;
  var minWords = 8;

  for (final arg in argv.skip(1)) {
    if (arg.startsWith('--keys-prefix=')) {
      prefixes = arg
          .substring('--keys-prefix='.length)
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    } else if (arg.startsWith('--min=')) {
      minScore = double.parse(arg.substring('--min='.length));
    } else if (arg.startsWith('--min-words=')) {
      minWords = int.parse(arg.substring('--min-words='.length));
    } else {
      stderr.writeln('Unknown arg: $arg');
      exit(2);
    }
  }

  final file = File(arbPath);
  if (!file.existsSync()) {
    stderr.writeln('ARB file not found: $arbPath');
    exit(2);
  }
  final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  final results = scoreArb(arb, keyPrefixes: prefixes, minWords: minWords);
  final fails = <FkKeyResult>[];
  final passes = <FkKeyResult>[];
  final skipped = <FkKeyResult>[];
  for (final r in results) {
    if (r.skipped) {
      skipped.add(r);
    } else if (r.score < minScore) {
      fails.add(r);
    } else {
      passes.add(r);
    }
  }

  stdout.writeln('Flesch-Kincaid (Kandel–Moles) French readability gate');
  stdout.writeln('  ARB:      $arbPath');
  stdout.writeln('  Prefixes: ${prefixes.join(", ")}');
  stdout.writeln('  Min K–M:  ${minScore.toStringAsFixed(1)}  (B1 floor)');
  stdout.writeln('  Min words: $minWords  (shorter fragments skipped)');
  stdout.writeln('');
  stdout.writeln('  Scored:   ${passes.length + fails.length}');
  stdout.writeln('  Passed:   ${passes.length}');
  stdout.writeln('  Failed:   ${fails.length}');
  stdout.writeln('  Skipped:  ${skipped.length}');
  stdout.writeln('');

  if (fails.isNotEmpty) {
    stdout.writeln('FAILED keys (score < $minScore):');
    for (final r in fails) {
      stdout.writeln(
        '  [${r.score.toStringAsFixed(1)}] ${r.key}  '
        '(${r.wordCount}w): ${r.value}',
      );
    }
    stdout.writeln('');
    stdout.writeln(
      'FAIL — rewrite the strings above to shorter words / shorter sentences,\n'
      'or wrap a surviving jargon term with [[term:X]] and use JargonText.',
    );
    exit(1);
  }

  stdout.writeln('PASS — onboarding surface is readable at B1 (K–M ≥ $minScore).');
  exit(0);
}
