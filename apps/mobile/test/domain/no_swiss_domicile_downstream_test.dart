// Sans domicile fiscal suisse, AUCUN chiffre suisse ne doit être fabriqué.
//
// Ces oracles existent parce que le premier correctif ne suffisait pas. Le
// parcours avait cessé d'obliger un frontalier à choisir une commune, et le
// fait enregistré ne portait plus ni commune ni canton — mais l'aval
// continuait de fabriquer exactement la donnée fausse que le fait venait
// d'écarter :
//
//   * `financial_report_service` remplaçait un canton absent par « ZH » ;
//   * `report_builder` et `budget_inputs` par le pseudo-canton « CH », que
//     `budget_inputs` transmettait ensuite au calcul d'impôt.
//
// Le test d'écran ne l'aurait jamais vu : il vérifiait la sérialisation du
// fait, pas ce que les consommateurs en font. Défaut trouvé par la relecture
// adversariale, converti ici en contrôle gratuit.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';

void main() {
  Map<String, dynamic> answersWithoutSwissDomicile() => <String, dynamic>{
        ...MintNextDomicileFact.noSwissTaxDomicile(
          assertedAt: DateTime.utc(2026, 8, 13),
          source: MintNextDomicileFact.userDeclarationSource,
          schemaVersion: 1,
        ).toWizardAnswers(),
        'q_net_income_monthly': 7000,
        'q_civil_status': 'single',
      };

  test('the fact reads back as "no Swiss tax domicile" from raw answers', () {
    expect(
        MintNextDomicileFact.hasSwissTaxDomicileIn(
            answersWithoutSwissDomicile()),
        isFalse);
  });

  test('answers written before this state existed still read as Swiss', () {
    // Clé absente : un profil écrit avant ne peut pas être présumé étranger.
    expect(
        MintNextDomicileFact.hasSwissTaxDomicileIn(
            <String, dynamic>{'q_canton': 'VD'}),
        isTrue);
    expect(MintNextDomicileFact.hasSwissTaxDomicileIn(<String, dynamic>{}),
        isTrue);
  });

  test('no Swiss tax provision is invented when there is no Swiss commune',
      () {
    final inputs = BudgetInputs.fromMap(answersWithoutSwissDomicile());

    expect(inputs.taxProvision, 0.0,
        reason: 'un impôt suisse estimé sur un pseudo-canton serait faux tout '
            'en ayant l\'air vrai');
  });

  test('the same answers WITH a Swiss canton do produce an estimate', () {
    // Oracle de contraste : sans lui, le test précédent passerait même si
    // l'estimation était cassée pour tout le monde.
    final inputs = BudgetInputs.fromMap(<String, dynamic>{
      'q_canton': 'VD',
      'q_net_income_monthly': 7000,
      'q_civil_status': 'single',
    });

    expect(inputs.taxProvision, greaterThan(0.0));
  });

  test('a declared tax provision is kept as declared, Swiss domicile or not',
      () {
    final inputs = BudgetInputs.fromMap(<String, dynamic>{
      ...answersWithoutSwissDomicile(),
      'q_tax_provision_monthly_chf': 850,
    });

    expect(inputs.taxProvision, 850.0,
        reason: 'ce que la personne déclare lui appartient ; seule '
            "l'estimation est refusée");
  });
}
