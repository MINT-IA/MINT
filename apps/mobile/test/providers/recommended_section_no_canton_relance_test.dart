// Le canton ne se redemande pas à qui vient de déclarer n'en avoir aucun.
//
// `recommendedWizardSection` tenait l'identité pour incomplète tant que
// `q_canton` n'était pas répondu. Or, depuis le fait domicile à deux états,
// une personne sans domicile fiscal suisse — frontalier, résidente à
// l'étranger — n'a plus de canton du tout : elle était donc renvoyée à
// l'infini vers la section « identity », pour une information qu'elle venait
// précisément de déclarer inexistante.
//
// C'est la relance que le contrat de la première ouverture interdit, trouvée
// par la relecture adversariale du lot complet et non par les tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';

void main() {
  test('the two-state fact reads correctly from raw answers', () {
    expect(
        MintNextDomicileFact.hasSwissTaxDomicileIn(
            const {'q_domicile_fiscal_suisse': false}),
        isFalse);
    expect(
        MintNextDomicileFact.hasSwissTaxDomicileIn(
            const {'q_domicile_fiscal_suisse': true}),
        isTrue);
    // Clé absente : un profil écrit avant ne peut pas être présumé étranger.
    expect(MintNextDomicileFact.hasSwissTaxDomicileIn(const {}), isTrue);
  });

  test('a no-Swiss-domicile fact carries no canton to be asked about', () {
    final fact = MintNextDomicileFact.noSwissTaxDomicile(
      assertedAt: DateTime.utc(2026, 8, 13),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
    );
    final answers = fact.toWizardAnswers();

    expect(answers['q_canton'], isNull,
        reason: "l'ancien canton ne survit pas à la déclaration");
    expect(MintNextDomicileFact.hasSwissTaxDomicileIn(answers), isFalse,
        reason: 'et la complétude doit lire cet état, pas seulement q_canton');
  });
}
