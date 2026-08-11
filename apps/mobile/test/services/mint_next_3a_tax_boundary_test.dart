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
      // v4 (Lego 3) : domicile + situation civile + revenu canoniques. Sans
      // faits confirmés, rien de personnel n'apparaît, et le plafond 3a est
      // non déterminé — fail-closed.
      'context_version': 4,
      'tax_year': 2026,
      'effective_at': '2026-01-01T00:00:00.000Z',
      'capability': 'no_attested_engine',
      'domicile_status': 'missing',
      'civil_status_status': 'missing',
      'revenu_status': 'missing',
      'plafond_3a_determination': 'undetermined_revenu_missing',
    });
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
