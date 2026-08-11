import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';

void main() {
  final t0 = DateTime.utc(2026, 8, 11, 20);
  final t1 = DateTime.utc(2026, 8, 11, 21);
  final t2 = DateTime.utc(2026, 8, 11, 22);

  MintNextVersement3aEntry entry({
    String id = 'v1',
    int amountCents = 200000,
    int taxYear = 2026,
    DateTime? creditedAt,
  }) =>
      MintNextVersement3aEntry(
        id: id,
        amountCents: amountCents,
        creditedAt: creditedAt ?? DateTime.utc(2026, 3, 15),
        taxYear: taxYear,
      );

  test('round-trips a multi-entry list through wizard answers', () {
    final fact = MintNextVersements3aFact.empty(at: t0)
        .withEntryAdded(entry(), t0)
        .withEntryAdded(entry(id: 'v2', amountCents: 350000), t1)
        .withEntryAdded(entry(id: 'v3', taxYear: 2025), t1);
    final restored =
        MintNextVersements3aFact.fromWizardAnswers(fact.toWizardAnswers());
    expect(restored, isNotNull);
    expect(restored!.entries, fact.entries);
    expect(restored.bucketRevisions, fact.bucketRevisions);
  });

  test('the annual total is a derived view, aggregated across accounts and '
      'never truncated', () {
    final fact = MintNextVersements3aFact.empty(at: t0)
        .withEntryAdded(entry(amountCents: 500000), t0)
        .withEntryAdded(entry(id: 'v2', amountCents: 600000), t0)
        .withEntryAdded(entry(id: 'v3', taxYear: 2025, amountCents: 100), t0);
    expect(fact.totalForYearCents(2026), 1100000,
        reason: 'above any legal plafond — recorded truthfully, the model '
            'knows no plafond at all');
    expect(fact.totalForYearCents(2025), 100);
    expect(fact.totalForYearCents(2024), 0);
  });

  test('correcting an entry keeps its stable id and bumps only its bucket',
      () {
    final fact = MintNextVersements3aFact.empty(at: t0)
        .withEntryAdded(entry(), t0)
        .withEntryAdded(entry(id: 'v2', taxYear: 2025), t0);
    final rev2026Before = fact.bucketRevision(2026);
    final rev2025Before = fact.bucketRevision(2025);

    final corrected =
        fact.withEntryUpdated('v1', entry(amountCents: 250000), t1);

    expect(corrected.entryById('v1')!.amountCents, 250000);
    expect(corrected.entries.length, 2,
        reason: 'a correction is never delete + duplicate');
    expect(corrected.bucketRevision(2026), isNot(rev2026Before));
    expect(corrected.bucketRevision(2025), rev2025Before,
        reason: 'a 2026 correction never stales the 2025 bucket');
  });

  test('moving an entry across tax years bumps both buckets', () {
    final fact = MintNextVersements3aFact.empty(at: t0)
        .withEntryAdded(entry(), t0)
        .withEntryAdded(entry(id: 'v2', taxYear: 2025), t0);
    final moved =
        fact.withEntryUpdated('v1', entry(taxYear: 2025), t2);
    expect(moved.bucketRevision(2026), t2.toIso8601String());
    expect(moved.bucketRevision(2025), t2.toIso8601String());
    expect(moved.totalForYearCents(2026), 0);
  });

  test('removing an entry bumps its bucket — deletion is an event, not an '
      'absence', () {
    final fact =
        MintNextVersements3aFact.empty(at: t0).withEntryAdded(entry(), t0);
    final removed = fact.withEntryRemoved('v1', t2);
    expect(removed.entries, isEmpty);
    expect(removed.bucketRevision(2026), t2.toIso8601String(),
        reason: 'max(updatedAt) of remaining entries would miss deletions');
  });

  test('tax year is pinned, never derived from the credit date', () {
    final rachat = entry(
        id: 'r1',
        creditedAt: DateTime.utc(2027, 2, 10),
        taxYear: 2026);
    final fact =
        MintNextVersements3aFact.empty(at: t0).withEntryAdded(rachat, t0);
    expect(fact.totalForYearCents(2026), 200000,
        reason: 'a 2027 credit pinned to 2026 counts for 2026 — rachats');
    expect(fact.totalForYearCents(2027), 0);
  });

  test('strict parsing: duplicate ids, zero amounts and garbage yield no '
      'fact', () {
    final valid = MintNextVersements3aFact.empty(at: t0)
        .withEntryAdded(entry(), t0)
        .toWizardAnswers();
    expect(MintNextVersements3aFact.fromWizardAnswers(valid), isNotNull);

    final dupIds = Map<String, dynamic>.from(valid)
      ..['q_versements_3a_fact_entries'] =
          '[{"id":"a","amount_cents":100,"credited_at":"2026-01-01T00:00:00.000Z","tax_year":2026},'
              '{"id":"a","amount_cents":200,"credited_at":"2026-01-02T00:00:00.000Z","tax_year":2026}]';
    expect(MintNextVersements3aFact.fromWizardAnswers(dupIds), isNull);

    final zeroAmount = Map<String, dynamic>.from(valid)
      ..['q_versements_3a_fact_entries'] =
          '[{"id":"a","amount_cents":0,"credited_at":"2026-01-01T00:00:00.000Z","tax_year":2026}]';
    expect(MintNextVersements3aFact.fromWizardAnswers(zeroAmount), isNull);

    final garbage = Map<String, dynamic>.from(valid)
      ..['q_versements_3a_fact_entries'] = 'not json';
    expect(MintNextVersements3aFact.fromWizardAnswers(garbage), isNull);
  });
}
