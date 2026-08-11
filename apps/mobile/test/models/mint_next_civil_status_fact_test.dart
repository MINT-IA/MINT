import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';

void main() {
  final asserted = DateTime.utc(2026, 8, 11, 10);

  MintNextCivilStatusFact fact(MintNextCivilStatus status) =>
      MintNextCivilStatusFact(
        status: status,
        assertedAt: asserted,
        source: MintNextCivilStatusFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  test('round-trips through wizard answers for every status token', () {
    for (final status in MintNextCivilStatus.values) {
      final original = fact(status);
      expect(
        MintNextCivilStatusFact.fromWizardAnswers(original.toWizardAnswers()),
        original,
        reason: status.id,
      );
    }
  });

  test('tokens are stable and accent-free', () {
    expect(MintNextCivilStatus.values.map((s) => s.id).toList(), [
      'celibataire',
      'marie',
      'partenariat_enregistre',
      'concubinage',
      'divorce',
      'veuf',
    ]);
  });

  test(
      'joint taxation covers marriage AND registered partnership, never '
      'concubinage', () {
    expect(MintNextCivilStatus.marie.jointTaxation, isTrue);
    expect(MintNextCivilStatus.partenariatEnregistre.jointTaxation, isTrue);
    expect(MintNextCivilStatus.concubinage.jointTaxation, isFalse);
    expect(MintNextCivilStatus.celibataire.jointTaxation, isFalse);
    expect(MintNextCivilStatus.divorce.jointTaxation, isFalse);
    expect(MintNextCivilStatus.veuf.jointTaxation, isFalse);
  });

  test('deletion nulls the complete bundle including the status itself', () {
    final deletion = MintNextCivilStatusFact.deletionWizardAnswers();
    expect(deletion.keys.toSet(), {
      ...MintNextCivilStatusFact.wizardKeys,
      MintNextCivilStatusFact.legacyChoiceKey,
    });
    expect(deletion.containsKey('q_civil_status'), isTrue,
        reason: 'the value IS the fact — deletion tombstones it');
    expect(deletion.containsKey(MintNextCivilStatusFact.legacyChoiceKey),
        isTrue,
        reason: 'the tombstone dominates the legacy alias — otherwise the '
            'old status resurrects through q_civil_status_choice');
    expect(deletion.values.every((v) => v == null), isTrue);
  });

  test('statusFromToken accepts legacy writer tokens, partenariat never '
      'degrades', () {
    expect(MintNextCivilStatusFact.statusFromToken('married'),
        MintNextCivilStatus.marie);
    expect(MintNextCivilStatusFact.statusFromToken('divorced'),
        MintNextCivilStatus.divorce);
    expect(MintNextCivilStatusFact.statusFromToken('single'),
        MintNextCivilStatus.celibataire);
    expect(MintNextCivilStatusFact.statusFromToken('partenariat'),
        MintNextCivilStatus.partenariatEnregistre);
    expect(MintNextCivilStatusFact.statusFromToken('partenariat_enregistre'),
        MintNextCivilStatus.partenariatEnregistre);
    for (final status in MintNextCivilStatus.values) {
      expect(MintNextCivilStatusFact.statusFromToken(status.id), status);
    }
    expect(MintNextCivilStatusFact.statusFromToken('pacse'), isNull);
    expect(MintNextCivilStatusFact.statusFromToken(null), isNull);
  });

  test('legacy alias is never part of the written bundle', () {
    expect(
      fact(MintNextCivilStatus.marie)
          .toWizardAnswers()
          .containsKey(MintNextCivilStatusFact.legacyChoiceKey),
      isFalse,
    );
    expect(
      MintNextCivilStatusFact.wizardKeys
          .contains(MintNextCivilStatusFact.legacyChoiceKey),
      isFalse,
    );
  });

  test('incomplete metadata yields no fact', () {
    expect(
      MintNextCivilStatusFact.fromWizardAnswers({'q_civil_status': 'marie'}),
      isNull,
      reason: 'a bare legacy value without metadata is not a confirmed fact',
    );
    final unknownToken = fact(MintNextCivilStatus.marie).toWizardAnswers()
      ..['q_civil_status'] = 'pacse';
    expect(MintNextCivilStatusFact.fromWizardAnswers(unknownToken), isNull);
  });

  test('revision fingerprint is the UTC assertion instant', () {
    expect(fact(MintNextCivilStatus.veuf).revision,
        '2026-08-11T10:00:00.000Z');
  });
}
