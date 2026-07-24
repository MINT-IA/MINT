import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// beads MINT_nosync-b6k (lot 1 -zaw) — le FV des rachats LPP de l'écran
/// RvC utilisait `const lppReturn = 0.0125` codé en dur. 1.25% est le taux
/// d'intérêt minimal LPP (OPP2, fixé par le Conseil fédéral — clé registre
/// `lpp.min_interest_rate`, unité percent) : une valeur réglementaire qui
/// CHANGE par décision annuelle, donc à lire via reg() avec fallback
/// (pattern projection.* -amq), jamais en littéral local.
void main() {
  test('le FV rachat RvC lit le taux LPP via reg(), plus de littéral', () {
    const path = 'lib/screens/arbitrage/rente_vs_capital_screen.dart';
    final src = File(path).readAsStringSync();
    expect(src.contains('const lppReturn = 0.0125'), isFalse,
        reason: 'taux réglementaire codé en dur (beads -b6k)');
    expect(
        src.contains("reg('lpp.min_interest_rate', lppTauxInteretMin) / 100"),
        isTrue,
        reason: 'lecture registre + fallback const + conversion percent');
  });
}
