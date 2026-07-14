import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/confidence_prompt_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  test('tax acquisition prompt requires both independent kill switches', () {
    for (final flags in const [
      (typed: false, document: false),
      (typed: true, document: false),
      (typed: false, document: true),
    ]) {
      FeatureFlags.typedTaxProfile = flags.typed;
      FeatureFlags.documentTaxAssessmentEnabled = flags.document;
      final result = ConfidenceScorer.score(CoachProfile.defaults());

      expect(
        result.prompts.where(
          (prompt) =>
              prompt.copyCode == EnrichmentPromptCopyCode.taxDocument ||
              prompt.machineCode == 'tax.document.review' ||
              prompt.fieldPath == 'fiscal.assessedBaseline',
        ),
        isEmpty,
        reason: 'typed=${flags.typed}, document=${flags.document}',
      );
    }
  });

  test('enabled tax prompt keeps identity and copy at the UI boundary',
      () async {
    FeatureFlags.typedTaxProfile = true;
    FeatureFlags.documentTaxAssessmentEnabled = true;
    final result = ConfidenceScorer.score(CoachProfile.defaults());
    final prompt = result.prompts.singleWhere(
      (candidate) => candidate.fieldPath == 'fiscal.assessedBaseline',
    );

    expect(prompt.copyCode, EnrichmentPromptCopyCode.taxDocument);
    expect(prompt.copyArgument, isNull);
    expect(prompt.machineCode, 'tax.document.review');
    expect(prompt.fieldPath, 'fiscal.assessedBaseline');
    expect(prompt.category, 'fiscalite');
    expect(prompt.impact, 8);
    expect(prompt.label, isEmpty);
    expect(prompt.action, isEmpty);
    expect(
      prompt.machineDescriptor,
      'code=tax.document.review;field=fiscal.assessedBaseline;impact=8;category=fiscalite',
    );
    expect('/data-block/${prompt.category}', '/data-block/fiscalite');

    const forbiddenUniversalClaims = [
      'taux marginal',
      'marginal rate',
      'grenzsteuersatz',
      'tipo marginal',
      'aliquota marginale',
      'taxa marginal',
      'lifd',
      'art. 38',
      '60%',
      '130%',
      'garanti',
      'guaranteed',
      'garantiert',
      'garantizado',
      'garantito',
      'garantido',
    ];
    for (final locale in const ['fr', 'en', 'de', 'es', 'it', 'pt']) {
      final l10n = await S.delegate.load(Locale(locale));
      final label = prompt.localizedLabel(l10n);
      final action = prompt.localizedAction(l10n);
      final copy = '$label $action'.toLowerCase();

      expect(label, isNotEmpty, reason: locale);
      expect(action, isNotEmpty, reason: locale);
      expect(copy, isNot(contains(prompt.machineCode)), reason: locale);
      for (final claim in forbiddenUniversalClaims) {
        expect(copy, isNot(contains(claim)), reason: '$locale: $claim');
      }
    }
  });
}
