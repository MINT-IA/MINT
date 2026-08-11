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
      // v3 (Lego 2) : domicile + situation civile canoniques. Sans faits
      // confirmés, rien de personnel n'apparaît.
      'context_version': 3,
      'tax_year': 2026,
      'effective_at': '2026-01-01T00:00:00.000Z',
      'capability': 'no_attested_engine',
      'domicile_status': 'missing',
      'civil_status_status': 'missing',
    });
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
