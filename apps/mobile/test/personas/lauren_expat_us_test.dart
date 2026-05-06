/// Phase 90 PERS-08 (v2.13) — Dart post-run assertion suite for the
/// lauren_expat_us × Premier Éclairage persona scenario.
///
/// Mirrors `julien_swiss_test.dart` with archetype-specific tightening :
/// Lauren is `expat_us` (FATCA-aware) so the LSFin lexicon adds a
/// US-tax-advice ban (Phase 92 JDEF-04 will harden this with the full
/// FATCA-handoff template assertion). For Phase 90 the essential
/// contract is identical : 4 assertions, structure compiled, real
/// wiring lands with PERS-02.
///
/// See `julien_swiss_test.dart` for the full PERS-08 contract.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _archetype = 'lauren_expat_us';
const String _expectedKind = 'fiscal_margin_3a';

// FR LSFin lexicon + US-tax-advice ban (Phase 92 JDEF-04 will extend).
final RegExp _bannedTerms = RegExp(
  r'\b(garanti[es]?|optimal|le?\s*meilleur|sans\s*risque|parfait[es]?)\b',
  caseSensitive: false,
);
final RegExp _usTaxAdvicePat = RegExp(
  r'\b(file\s+a\s+1040|FBAR|Form\s+8938|PFIC|tu\s+devrais\s+déclarer)\b',
  caseSensitive: false,
);

void main() {
  group('PERS-08 lauren_expat_us × Premier Éclairage post-run assertions', () {
    test('archetype injected at runtime',
        () {},
        skip: 'Phase 90 scaffolding — wiring lands with PERS-02');

    test('narrative invariant — eclairage.card.tap breadcrumb fired',
        () {},
        skip: 'Phase 90 scaffolding — wiring lands with PERS-02');

    test('LSFin banned-term regex hit-count == 0',
        () {
      const sampleResponse =
          'Pour les expats US, le plafond 3a est conditionné par la fiscalité '
          'américaine. Tu pourrais envisager une consultation avec un '
          'fiscaliste US-CH avant tout versement.';
      expect(_bannedTerms.allMatches(sampleResponse), isEmpty);
    });

    test('US-tax-advice regex hit-count == 0 (FATCA archetype safeguard)',
        () {
      const sampleResponse =
          'Pour les expats US, le plafond 3a est conditionné par la fiscalité '
          'américaine. Tu pourrais envisager une consultation avec un '
          'fiscaliste US-CH avant tout versement.';
      expect(_usTaxAdvicePat.allMatches(sampleResponse), isEmpty,
          reason: 'expat_us archetype must hand off to fiscaliste, never '
              'give US tax advice directly');
    });

    test('numeric assertion : chf_range respects 3a annual cap',
        () {},
        skip: 'Phase 90 scaffolding — full wiring reads walker artefact');

    test('walker run-id env var present',
        () {
      final runId = Platform.environment['MINT_WALKER_RUN_ID'];
      if (runId == null || runId.isEmpty) {
        markTestSkipped(
          'MINT_WALKER_RUN_ID not set — walker must run BEFORE this '
          'assertion suite.',
        );
        return;
      }
      expect(runId, matches(RegExp(r'^\d{4}-\d{2}-\d{2}-\d{6}-[0-9a-f]+$')));
    });
  });
}
