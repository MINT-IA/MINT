import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

/// beads MINT_nosync-b6k (lot 1 -zaw) — le FV des rachats LPP de l'écran
/// RvC utilisait `const lppReturn = 0.0125` codé en dur. 1.25% est le
/// taux d'intérêt minimal LPP (OPP2, décision annuelle du Conseil
/// fédéral — clé registre `lpp.min_interest_rate`, unité POURCENT).
/// Review #1002 : le risque réel est l'UNITÉ — cache et fallback doivent
/// tous deux produire le ratio 0.0125.
void main() {
  tearDown(RegulatorySyncService.clearCache);

  test('fallback (cache vide) : 1.25 pourcent -> ratio 0.0125', () {
    RegulatorySyncService.clearCache();
    expect(lppMinInterestRatio(), closeTo(0.0125, 1e-12));
  });

  test('cache synced (percent, comme le snapshot) : ratio 0.0125', () {
    RegulatorySyncService.setMockCache({'lpp.min_interest_rate': 1.25});
    expect(lppMinInterestRatio(), closeTo(0.0125, 1e-12));
  });

  test('une future décision OPP2 (ex. 1.0%) se propage via le cache', () {
    RegulatorySyncService.setMockCache({'lpp.min_interest_rate': 1.0});
    expect(lppMinInterestRatio(), closeTo(0.01, 1e-12));
  });

  test('câblage écran : plus de littéral, helper consommé', () {
    const path = 'lib/screens/arbitrage/rente_vs_capital_screen.dart';
    final src = File(path).readAsStringSync();
    expect(src.contains('const lppReturn = 0.0125'), isFalse,
        reason: 'taux réglementaire codé en dur (beads -b6k)');
    expect(src.contains('lppMinInterestRatio()'), isTrue);
  });
}
