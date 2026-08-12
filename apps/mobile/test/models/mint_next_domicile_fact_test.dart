import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';

void main() {
  final asserted = DateTime.utc(2026, 8, 11, 7, 30);

  MintNextDomicileFact fact({int? bfs}) => MintNextDomicileFact(
        canton: 'VD',
        communeName: 'Lausanne',
        communeBfs: bfs,
        assertedAt: asserted,
        source: MintNextDomicileFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  test('round-trips through wizard answers including nullable BFS', () {
    final withBfs = fact(bfs: 5586);
    expect(
      MintNextDomicileFact.fromWizardAnswers(withBfs.toWizardAnswers()),
      withBfs,
    );
    final withoutBfs = fact();
    final restored =
        MintNextDomicileFact.fromWizardAnswers(withoutBfs.toWizardAnswers());
    expect(restored, withoutBfs);
    expect(restored!.communeBfs, isNull);
  });

  test('writes the shared legacy canton key', () {
    expect(fact().toWizardAnswers()['q_canton'], 'VD');
  });

  test('deletion nulls only owned keys and never the shared canton', () {
    final deletion = MintNextDomicileFact.deletionWizardAnswers();
    expect(deletion.containsKey('q_canton'), isFalse);
    expect(deletion.keys.toSet(), MintNextDomicileFact.ownedKeys);
    expect(deletion.values.every((v) => v == null), isTrue);
  });

  test('incomplete metadata yields no fact (canton alone is legacy profile)',
      () {
    expect(MintNextDomicileFact.fromWizardAnswers({'q_canton': 'VD'}), isNull);
    final missingSource = fact().toWizardAnswers()
      ..remove(MintNextDomicileFact.sourceKey);
    expect(MintNextDomicileFact.fromWizardAnswers(missingSource), isNull);
    final blankCommune = fact().toWizardAnswers()
      ..[MintNextDomicileFact.communeNameKey] = '   ';
    expect(MintNextDomicileFact.fromWizardAnswers(blankCommune), isNull);
  });

  test('revision fingerprint is the UTC assertion instant', () {
    expect(fact().revision, '2026-08-11T07:30:00.000Z');
    final corrected = MintNextDomicileFact(
      canton: 'VD',
      communeName: 'Pully',
      assertedAt: asserted.add(const Duration(minutes: 5)),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    );
    expect(corrected.revision, isNot(fact().revision));
  });
}
