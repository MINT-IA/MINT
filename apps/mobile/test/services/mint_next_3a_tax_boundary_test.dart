import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/services/mint_next_3a_tax_delta_engine.dart';

void main() {
  test('context is versioned and contains no personal data', () {
    final context = MintNext3aFiscalContext(
      taxYear: 2026,
      effectiveAt: DateTime.utc(2026, 1, 1),
    );
    expect(context.toJson(), {
      // v6 (Lego 5) : domicile + situation civile + revenu + affiliation
      // LPP + versements 3a canoniques. Sans faits confirmés, rien de
      // personnel n'apparaît, et le plafond 3a est non déterminé.
      'context_version': 6,
      'tax_year': 2026,
      'effective_at': '2026-01-01T00:00:00.000Z',
      'capability': 'no_attested_engine',
      'domicile_status': 'missing',
      'civil_status_status': 'missing',
      'revenu_status': 'missing',
      'lpp_affiliation_status': 'unknown',
      'versements_status': 'missing',
      'plafond_3a_determination': 'undetermined_lpp_affiliation_unknown',
    });
  });

  test('versements context carries the aggregate and its bucket revision — '
      'and never any marge nor CHF plafond', () {
    const versements = MintNext3aVersementsContext(
      taxYear: 2026,
      totalVerseAnnualCents: 1100000,
      bucketRevision: '2026-08-11T20:00:00.000Z',
    );
    final context = MintNext3aFiscalContext(
      taxYear: 2026,
      effectiveAt: DateTime.utc(2026, 1, 1),
      versements: versements,
    );
    final jsonMap = context.toJson();
    expect(jsonMap['versements_status'], 'known');
    expect((jsonMap['versements'] as Map)['total_verse_annual_cents'],
        1100000,
        reason: 'above any legal plafond — aggregated truthfully, never '
            'truncated');
    final encoded = jsonMap.toString();
    expect(encoded.contains('marge'), isFalse,
        reason: 'the marge is an attested-engine output — it exists nowhere '
            'in the boundary');
  });

  test('plafond determination v5 covers the four fail-closed branches', () {
    MintNext3aFiscalContext ctx(
            {MintNext3aLppAffiliationContext? lpp,
            MintNext3aRevenuContext? revenu}) =>
        MintNext3aFiscalContext(
          taxYear: 2026,
          effectiveAt: DateTime.utc(2026, 1, 1),
          lppAffiliation: lpp,
          revenu: revenu,
        );
    const yes = MintNext3aLppAffiliationContext(
        affiliated: true, revision: '2026-08-11T14:00:00.000Z');
    const no = MintNext3aLppAffiliationContext(
        affiliated: false, revision: '2026-08-11T14:00:00.000Z');
    const revenu = MintNext3aRevenuContext(
        annualNetCents: 7800000,
        periodToken: 'yearly',
        revision: '2026-08-11T12:00:00.000Z');

    expect(ctx().plafond3aDetermination,
        'undetermined_lpp_affiliation_unknown',
        reason: 'unknown affiliation dominates — never read as not '
            'affiliated, never derived from employment status');
    expect(ctx(revenu: revenu).plafond3aDetermination,
        'undetermined_lpp_affiliation_unknown');
    expect(ctx(lpp: yes).plafond3aDetermination, 'lpp_affiliated_max',
        reason: 'the big deduction needs no revenu');
    expect(ctx(lpp: no, revenu: revenu).plafond3aDetermination,
        'non_affiliated_20pct_capped');
    expect(ctx(lpp: no).plafond3aDetermination,
        'undetermined_revenu_missing',
        reason: 'the 20 percent rule needs a confirmed revenu');
  });

  test(
      'plafond determination stays fail-closed with a known revenu — the LPP '
      'affiliation is a distinct fact, never derived from employment status',
      () {
    final context = MintNext3aFiscalContext(
      taxYear: 2026,
      effectiveAt: DateTime.utc(2026, 1, 1),
      revenu: const MintNext3aRevenuContext(
        annualNetCents: 7800000,
        periodToken: 'monthly',
        revision: '2026-08-11T12:00:00.000Z',
      ),
    );
    expect(context.toJson()['revenu_status'], 'known');
    expect(context.toJson()['plafond_3a_determination'],
        'undetermined_lpp_affiliation_unknown');
    expect((context.toJson()['revenu'] as Map)['annual_net_cents'], 7800000,
        reason: 'the context carries the already-normalized annual amount — '
            'it never re-multiplies');
  });

  test('NoAttestedEngine always fails closed as unavailable', () async {
    const engine = NoAttestedEngine();
    final result = await engine.calculate(Pillar3aTaxDeltaRequest(
      context: MintNext3aFiscalContext(
        taxYear: 2026,
        effectiveAt: DateTime.utc(2026),
      ),
    ));
    expect(result, const Pillar3aTaxDeltaUnavailable());
  });

  test('unsupported, stale, and synthetic contexts cannot unlock a result',
      () async {
    const engine = NoAttestedEngine();
    final contexts = [
      MintNext3aFiscalContext(
        contextVersion: 999,
        taxYear: 2026,
        effectiveAt: DateTime.utc(2026, 8, 8),
      ),
      MintNext3aFiscalContext(
        taxYear: 1900,
        effectiveAt: DateTime.utc(1900),
      ),
      MintNext3aFiscalContext(
        taxYear: 9999,
        effectiveAt: DateTime.utc(2026),
      ),
    ];

    for (final context in contexts) {
      expect(
        await engine.calculate(Pillar3aTaxDeltaRequest(context: context)),
        const Pillar3aTaxDeltaUnavailable(),
      );
    }
  });
}
