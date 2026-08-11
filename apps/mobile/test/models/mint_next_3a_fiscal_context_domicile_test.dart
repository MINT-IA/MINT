import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';

void main() {
  test('fiscal context reports domicile known with canton and commune', () {
    final context = MintNext3aFiscalContext(
      taxYear: 2026,
      effectiveAt: DateTime.utc(2026, 8, 11),
      domicile: const MintNext3aDomicileContext(
        canton: 'VD',
        communeName: 'Lausanne',
        communeBfs: 5586,
        revision: '2026-08-11T07:30:00.000Z',
      ),
    );
    expect(context.domicileKnown, isTrue);
    final json = context.toJson();
    expect(json['domicile_status'], 'known');
    expect((json['domicile'] as Map)['canton'], 'VD');
    expect((json['domicile'] as Map)['revision'], '2026-08-11T07:30:00.000Z');
  });

  test('fiscal context reports domicile missing when no confirmed fact exists',
      () {
    final context = MintNext3aFiscalContext(
      taxYear: 2026,
      effectiveAt: DateTime.utc(2026, 8, 11),
    );
    expect(context.domicileKnown, isFalse);
    final json = context.toJson();
    expect(json['domicile_status'], 'missing');
    expect(json.containsKey('domicile'), isFalse);
  });

  test('a corrected domicile carries a new revision into the context', () {
    const before = MintNext3aDomicileContext(
      canton: 'VD',
      communeName: 'Lausanne',
      revision: '2026-08-11T07:30:00.000Z',
    );
    const after = MintNext3aDomicileContext(
      canton: 'VD',
      communeName: 'Pully',
      revision: '2026-08-11T08:00:00.000Z',
    );
    expect(before.revision, isNot(after.revision),
        reason: 'fiscal derivatives bound to the old revision must go stale');
  });

  test('a fact awaiting confirmation never becomes a known domicile', () {
    final pending = MintNextDomicileFact(
      canton: 'VD',
      communeName: 'Lausanne',
      assertedAt: DateTime.utc(2026, 8, 11),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: true,
    );
    expect(MintNext3aDomicileContext.fromConfirmedFact(pending), isNull);
    final confirmed = MintNextDomicileFact(
      canton: 'VD',
      communeName: 'Lausanne',
      assertedAt: DateTime.utc(2026, 8, 11),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    );
    expect(
      MintNext3aDomicileContext.fromConfirmedFact(confirmed)?.communeName,
      'Lausanne',
    );
    expect(MintNext3aDomicileContext.fromConfirmedFact(null), isNull);
  });

  test(
      'fiscal context reports civil status known with joint taxation for '
      'marie and partenariat_enregistre', () {
    for (final status in [
      MintNextCivilStatus.marie,
      MintNextCivilStatus.partenariatEnregistre,
    ]) {
      final fact = MintNextCivilStatusFact(
        status: status,
        assertedAt: DateTime.utc(2026, 8, 11, 10),
        source: MintNextCivilStatusFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );
      final ctx = MintNext3aCivilStatusContext.fromConfirmedFact(fact);
      expect(ctx?.jointTaxation, isTrue, reason: status.id);
    }
  });

  test(
      'fiscal context reports separate taxation for concubinage and missing '
      'without a confirmed fact', () {
    final concubin = MintNextCivilStatusFact(
      status: MintNextCivilStatus.concubinage,
      assertedAt: DateTime.utc(2026, 8, 11, 10),
      source: MintNextCivilStatusFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    );
    expect(
      MintNext3aCivilStatusContext.fromConfirmedFact(concubin)?.jointTaxation,
      isFalse,
    );
    final pending = MintNextCivilStatusFact(
      status: MintNextCivilStatus.marie,
      assertedAt: DateTime.utc(2026, 8, 11, 10),
      source: MintNextCivilStatusFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: true,
    );
    expect(MintNext3aCivilStatusContext.fromConfirmedFact(pending), isNull);
    expect(MintNext3aCivilStatusContext.fromConfirmedFact(null), isNull);
    final bare = MintNext3aFiscalContext(
      taxYear: 2026,
      effectiveAt: DateTime.utc(2026, 8, 11),
    );
    expect(bare.toJson()['civil_status_status'], 'missing');
  });

  test('fiscal context reports revenu known with the normalized annual amount',
      () {
    final fact = MintNextRevenuFact(
      amountCents: 650000,
      period: MintNextRevenuPeriod.monthly,
      assertedAt: DateTime.utc(2026, 8, 11, 12),
      source: MintNextRevenuFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    );
    final revenu = MintNext3aRevenuContext.fromConfirmedFact(fact);
    expect(revenu, isNotNull);
    expect(revenu!.annualNetCents, 650000 * 12,
        reason: 'annualization happened once, in the fact');
    expect(revenu.periodToken, 'monthly');
    expect(revenu.revision, fact.revision);
  });

  test('a revenu fact awaiting confirmation never becomes a known revenu', () {
    final pending = MintNextRevenuFact(
      amountCents: 650000,
      period: MintNextRevenuPeriod.yearly,
      assertedAt: DateTime.utc(2026, 8, 11, 12),
      source: MintNextRevenuFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: true,
    );
    expect(MintNext3aRevenuContext.fromConfirmedFact(pending), isNull);
    expect(MintNext3aRevenuContext.fromConfirmedFact(null), isNull);
  });
}
