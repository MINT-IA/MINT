import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';

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
}
