import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_de.dart';
import 'package:mint_mobile/l10n/app_localizations_en.dart';
import 'package:mint_mobile/l10n/app_localizations_es.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/l10n/app_localizations_it.dart';
import 'package:mint_mobile/l10n/app_localizations_pt.dart';

void main() {
  test('manual bank import copy promises income confirmation only', () {
    final localizations = <S>[SFr(), SEn(), SDe(), SEs(), SIt(), SPt()];

    for (final s in localizations) {
      expect(
        s.bankImportBudgetPreview.toLowerCase(),
        isNot(contains('budget')),
        reason: '${s.localeName}: preview must not promise a budget import',
      );
      expect(s.bankImportButton.toLowerCase(), isNot(contains('budget')),
          reason: '${s.localeName}: CTA must not promise a budget import');
      expect(s.bankImportSuccess.toLowerCase(), isNot(contains('budget')),
          reason: '${s.localeName}: success must not claim a budget update');
    }

    expect(SFr().bankImportButton, 'Confirmer ce revenu mensuel');
    expect(
      SFr().bankImportSuccess,
      'Revenu mis à jour. Les charges restent à confirmer séparément.',
    );
  });
}
