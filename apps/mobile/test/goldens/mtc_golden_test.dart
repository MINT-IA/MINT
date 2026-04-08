// MTC isolation goldens (Plan 04-03).
//
// These tests render MintTrameConfiance in isolation against the locked
// dual-device pair. They are executed LOCALLY ONLY — CI runs only the
// helper unit tests under test/goldens/helpers/. See README.md in this
// directory for the CI scope decision and the local-run command.
//
// S4 response_card_widget goldens are deferred until Plan 04-02 lands on
// dev (it is running in parallel at the time this plan ships).

@Tags(<String>['local-only'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

import 'helpers/screen_pump.dart';

EnhancedConfidence _fixture({
  required double completeness,
  required double accuracy,
  required double freshness,
  required double understanding,
}) {
  const base = ProjectionConfidence(
    score: 70,
    level: 'medium',
    prompts: [],
    assumptions: [],
  );
  return EnhancedConfidence(
    completeness: completeness,
    accuracy: accuracy,
    freshness: freshness,
    understanding: understanding,
    combined: 70,
    level: 'medium',
    baseResult: base,
  );
}

void main() {
  group('MintTrameConfiance isolation goldens [local-only]', () {
    testWidgets('mtc_inline_default — iPhone 14 Pro, dense', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.iphone14Pro,
        disableAnimations: true, // deterministic for golden diffs
        child: SizedBox(
          width: 320,
          child: MintTrameConfiance.inline(
            confidence: _fixture(
              completeness: 85,
              accuracy: 80,
              freshness: 90,
              understanding: 75,
            ),
            bloomStrategy: BloomStrategy.never,
          ),
        ),
      );
      await expectLater(
        find.byType(MintTrameConfiance),
        matchesGoldenFile('masters/mtc_inline_default_iphone14pro.png'),
      );
    });

    testWidgets('mtc_inline_default — Galaxy A14, dense', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.galaxyA14,
        disableAnimations: true,
        child: SizedBox(
          width: 320,
          child: MintTrameConfiance.inline(
            confidence: _fixture(
              completeness: 85,
              accuracy: 80,
              freshness: 90,
              understanding: 75,
            ),
            bloomStrategy: BloomStrategy.never,
          ),
        ),
      );
      await expectLater(
        find.byType(MintTrameConfiance),
        matchesGoldenFile('masters/mtc_inline_default_galaxya14.png'),
      );
    });

    testWidgets('mtc_empty_low_confidence — iPhone 14 Pro', (tester) async {
      await pumpScreen(
        tester,
        device: GoldenDevice.iphone14Pro,
        disableAnimations: true,
        child: SizedBox(
          width: 320,
          child: MintTrameConfiance.inline(
            // Completeness < 40 → factory redirects to MTC.empty state.
            confidence: _fixture(
              completeness: 20,
              accuracy: 30,
              freshness: 40,
              understanding: 25,
            ),
            bloomStrategy: BloomStrategy.never,
          ),
        ),
      );
      await expectLater(
        find.byType(MintTrameConfiance),
        matchesGoldenFile('masters/mtc_empty_low_confidence_iphone14pro.png'),
      );
    });
  });
}
