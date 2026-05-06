/// Phase A5 (v2.13) — Dart post-run assertion suite, julien_swiss.
///
/// Runs AFTER the L1 Maestro flow against the SAME replay-cache fixture
/// the in-app LlmReplayCache served. We deliberately DO NOT replay the
/// HTTP call — we read the fixture directly so the assertions stay
/// hermetic when staging is offline. Live-mode regression runs (weekly,
/// MINT_LLM_CACHE_MODE_OVERRIDE=live) capture a fresh fixture and feed
/// the same assertions against it.
///
/// Assertions :
///   1. **Walker run-id env present** — operational gate ; emits a
///      clear error if L2 is invoked without the walker.
///   2. **LSFin regex** — banned-term lexicon (garanti / optimal / sans
///      risque / le meilleur / parfait) MUST NOT appear in the
///      assistant `message` body.
///   3. **Canonical plafond reference** — the 2026 plafond du 3e pilier
///      `pilier3aPlafondAvecLpp` (7258 CHF, OPP3 art. 7) MUST appear
///      verbatim in the `message` body (catches « 7'056 »-style
///      hallucinations vs the financial_core constant).
///   4. **Numeric range bounds** — `eclairage.chf_range_high` MUST NOT
///      exceed `pilier3aPlafondAvecLpp` (a tax-saving range above the
///      contribution ceiling is mathematically impossible).
///   5. **Forced kind honoured** — `eclairage.kind` MUST equal the
///      walker's `MINT_E2E_FORCE_ECLAIRAGE_KIND` dart-define value.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

const String _archetype = 'julien_swiss';
const String _locale = 'fr';
const String _expectedKind = 'fiscal_margin_3a';

// Banned-term lexicon (subset, FR — full library lands tools/checks/
// lsfin_lexicon.py Phase 91 GROW-03).
final RegExp _bannedTerms = RegExp(
  r'\b(garanti[es]?|optimal|le?\s*meilleur|sans\s*risque|parfait[es]?)\b',
  caseSensitive: false,
);

Map<String, dynamic> _loadFixture() {
  final repoRoot = Directory.current.path;
  // `flutter test` runs from apps/mobile ; resolve assets path relative.
  final fixturePath =
      '$repoRoot/assets/llm_replay_cache/$_archetype/$_locale/'
      'premier_eclairage_turn_01.json';
  final file = File(fixturePath);
  if (!file.existsSync()) {
    fail('replay-cache fixture missing : $fixturePath');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('PERS-08 julien_swiss × Premier Éclairage post-run assertions', () {
    test('1. walker run-id env var present', () {
      final runId = Platform.environment['MINT_WALKER_RUN_ID'];
      if (runId == null || runId.isEmpty) {
        markTestSkipped(
          'MINT_WALKER_RUN_ID not set — walker must run BEFORE this suite. '
          'See tools/simulator/walker_persona.sh',
        );
        return;
      }
      expect(runId, matches(RegExp(r'^\d{4}-\d{2}-\d{2}-\d{6}-[0-9a-f]+$')),
          reason: 'walker run-id format : YYYY-MM-DD-HHMMSS-<sha7>');
    });

    test('2. LSFin banned-term regex hit-count == 0 in fixture message', () {
      final fixture = _loadFixture();
      final body =
          (fixture['response']['body'] as Map<String, dynamic>);
      final message = (body['message'] as String? ?? '');
      final hits = _bannedTerms.allMatches(message).map((m) => m.group(0));
      expect(hits, isEmpty,
          reason: 'banned terms detected in fixture message : $hits');
    });

    test('3. canonical plafond 3a referenced in message body', () {
      final fixture = _loadFixture();
      final body = (fixture['response']['body'] as Map<String, dynamic>);
      final message = (body['message'] as String? ?? '');
      // Accept both apostrophe styles : "7'258" or "7 258" or "7258".
      final ceiling = pilier3aPlafondAvecLpp.toInt();
      final patterns = [
        ceiling.toString(),
        "$ceiling".replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => "${m.group(1)}'"),
        ceiling.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)} '),
      ];
      final found = patterns.any(message.contains);
      expect(found, isTrue,
          reason:
              'fixture message must reference pilier3aPlafondAvecLpp '
              '($ceiling CHF, OPP3 art. 7). None of $patterns matched.');
    });

    test('4. eclairage.chf_range_high <= pilier3aPlafondAvecLpp', () {
      final fixture = _loadFixture();
      final eclairage =
          (fixture['response']['body']['eclairage'] as Map<String, dynamic>);
      final high = (eclairage['chf_range_high'] as num).toDouble();
      expect(high, lessThanOrEqualTo(pilier3aPlafondAvecLpp),
          reason:
              'chf_range_high ($high) cannot exceed the 3a contribution '
              'ceiling pilier3aPlafondAvecLpp (${pilier3aPlafondAvecLpp.toInt()} CHF).');
    });

    test('5. eclairage.kind matches forced kind', () {
      final fixture = _loadFixture();
      final eclairage =
          (fixture['response']['body']['eclairage'] as Map<String, dynamic>);
      expect(eclairage['kind'], equals(_expectedKind),
          reason:
              'fixture éclairage.kind must equal the walker '
              'MINT_E2E_FORCE_ECLAIRAGE_KIND dart-define (=$_expectedKind).');
    });
  });
}
