import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/confidence_prompt_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('typed confidence prompts localize without changing machine identity',
      () async {
    final l10n = await S.delegate.load(const Locale('en'));
    const prompt = EnrichmentPrompt.taxDocument();

    expect(prompt.machineCode, 'tax.document.review');
    expect(prompt.fieldPath, 'fiscal.assessedBaseline');
    expect(prompt.impact, 8);
    expect(prompt.category, 'fiscalite');
    expect(prompt.localizedLabel(l10n), 'Tax document');
    expect(
      prompt.localizedAction(l10n),
      'Identify and then confirm the type of tax document before retaining its values.',
    );
    expect(prompt.machineDescriptor, isNot(contains('Tax document')));
  });

  test('dynamic prompt copy keeps a stable code and typed payload', () async {
    final l10n = await S.delegate.load(const Locale('en'));
    const prompt = EnrichmentPrompt.freshnessStale(
      impact: 7,
      fieldPath: 'prevoyance.avoirLppTotal',
      monthsOld: 18,
    );

    expect(prompt.machineCode, 'confidence.freshness.stale');
    expect(prompt.localizedLabel(l10n), 'Update: LPP pension');
    expect(
      prompt.localizedAction(l10n),
      'Updated 18 months ago — check whether it is still current.',
    );
    expect(prompt.stableSortKey, isNot(contains('Update')));
  });

  test('typed copy preserves score, partner null semantics and prompt order',
      () {
    final profile = CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
    );
    final result = ConfidenceScorer.score(profile);

    expect(profile.conjoint, isNull);
    expect(result.score, 16);
    expect(
      result.prompts
          .map((p) => '${p.category}|${p.impact}|${p.fieldPath}')
          .toList(),
      [
        'lpp|18|prevoyance.avoirLppTotal',
        'menage|15|conjoint',
        'avs|7|prevoyance.anneesContribuees',
        'income|12|salaireBrutMensuel',
        '3a|7|prevoyance.totalEpargne3a',
        'lpp|4|prevoyance.tauxConversion',
        'objectif_retraite|7|goalA.targetRetirementAge',
        'patrimoine|6|patrimoine.epargneLiquide',
        'fiscalite|4|commune',
      ],
    );
  });

  test('localized axis prompts preserve the pre-localization ordering', () {
    final profile = CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
    );
    final result = ConfidenceScorer.scoreEnhanced(
      profile,
      now: DateTime.utc(2026, 7, 14),
    );

    expect(
      result.axisPrompts
          .map((p) => '${p.category}|${p.impact}|${p.fieldPath}')
          .toList(),
      [
        'accuracy|14|prevoyance.avoirLppTotal',
        'accuracy|8|prevoyance.anneesContribuees',
        'accuracy|11|etatCivil',
        'accuracy|6|prevoyance.totalEpargne3a',
        'understanding|10|null',
        'accuracy|9|salaireBrutMensuel',
        'accuracy|4|prevoyance.tauxConversion',
        'accuracy|5|patrimoine.epargneLiquide',
        'understanding|5|null',
        'accuracy|3|canton',
        'accuracy|3|age',
      ],
    );
  });
}
