/// Phase A5 (v2.13) — Dart post-run assertion suite, lauren_expat_us.
///
/// Mirrors `julien_swiss_test.dart` with archetype-specific tightening :
/// Lauren is `expat_us` (FATCA-aware) so the LSFin lexicon adds a
/// US-tax-advice ban — Lauren must always be handed off to a fiscaliste
/// US-CH, never receive direct US tax advice from MINT.
///
/// See `julien_swiss_test.dart` for the full PERS-08 contract.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

const String _archetype = 'lauren_expat_us';
const String _locale = 'fr';
const String _expectedKind = 'fiscal_margin_3a';

final RegExp _bannedTerms = RegExp(
  r'\b(garanti[es]?|optimal|le?\s*meilleur|sans\s*risque|parfait[es]?)\b',
  caseSensitive: false,
);

// Direct US-tax-advice patterns. Lauren is supposed to be ROUTED to a
// fiscaliste US-CH, not advised on FBAR/PFIC/8938 by MINT. Mentioning
// the form name as context (« 8938 ») is allowed when paired with a
// hand-off ; ASKING the user to file is what we ban.
final RegExp _usTaxAdviceImperative = RegExp(
  r'\b(file\s+a\s+1040|tu\s+devrais\s+(remplir|déclarer|filer)\s+(un\s+)?(FBAR|8938|1040)|'
  r'remplis\s+(un\s+)?(FBAR|8938|1040))\b',
  caseSensitive: false,
);

Map<String, dynamic> _loadFixture() {
  final repoRoot = Directory.current.path;
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
  group('PERS-08 lauren_expat_us × Premier Éclairage post-run assertions', () {
    test('1. walker run-id env var present', () {
      final runId = Platform.environment['MINT_WALKER_RUN_ID'];
      if (runId == null || runId.isEmpty) {
        markTestSkipped('MINT_WALKER_RUN_ID not set — walker must run first.');
        return;
      }
      expect(runId, matches(RegExp(r'^\d{4}-\d{2}-\d{2}-\d{6}-[0-9a-f]+$')));
    });

    test('2. LSFin banned-term regex hit-count == 0 in fixture message', () {
      final fixture = _loadFixture();
      final body = (fixture['response']['body'] as Map<String, dynamic>);
      final message = (body['message'] as String? ?? '');
      final hits = _bannedTerms.allMatches(message).map((m) => m.group(0));
      expect(hits, isEmpty,
          reason: 'banned terms detected in fixture message : $hits');
    });

    test(
        '3. US-tax-advice imperative hit-count == 0 (FATCA archetype safeguard)',
        () {
      final fixture = _loadFixture();
      final body = (fixture['response']['body'] as Map<String, dynamic>);
      final message = (body['message'] as String? ?? '');
      final hits =
          _usTaxAdviceImperative.allMatches(message).map((m) => m.group(0));
      expect(hits, isEmpty,
          reason: 'expat_us archetype must hand off to fiscaliste, never '
              'give direct US tax advice : $hits');
    });

    test('4. canonical plafond 3a referenced in message body', () {
      final fixture = _loadFixture();
      final body = (fixture['response']['body'] as Map<String, dynamic>);
      final message = (body['message'] as String? ?? '');
      final ceiling = pilier3aPlafondAvecLpp.toInt();
      final patterns = [
        ceiling.toString(),
        "$ceiling".replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => "${m.group(1)}'"),
        ceiling.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m.group(1)} '),
      ];
      expect(patterns.any(message.contains), isTrue,
          reason: 'fixture must reference pilier3aPlafondAvecLpp '
              '($ceiling CHF). None of $patterns matched.');
    });

    test('5. eclairage.chf_range_high <= pilier3aPlafondAvecLpp', () {
      final fixture = _loadFixture();
      final eclairage =
          (fixture['response']['body']['eclairage'] as Map<String, dynamic>);
      final high = (eclairage['chf_range_high'] as num).toDouble();
      expect(high, lessThanOrEqualTo(pilier3aPlafondAvecLpp),
          reason: 'chf_range_high cannot exceed the 3a contribution ceiling.');
    });

    test('6. eclairage.kind matches forced kind', () {
      final fixture = _loadFixture();
      final eclairage =
          (fixture['response']['body']['eclairage'] as Map<String, dynamic>);
      expect(eclairage['kind'], equals(_expectedKind));
    });
  });
}
