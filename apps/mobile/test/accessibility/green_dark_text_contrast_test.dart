import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';

/// beads MINT_nosync-dy0 (flag panel a11y -a6e) — greenDark #388E3C rend
/// 3.75:1 sur porcelaine et 4.12:1 sur blanc : sous le seuil AA 4.5:1
/// pour le texte de taille normale. Les sites texte migrent vers
/// greenForest ; greenDark reste toléré pour le grand texte (>= 24px,
/// seuil 3:1) et les icônes/graphiques (WCAG 1.4.11, seuil 3:1).
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double f(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * f((c.r * 255.0).round() / 255) +
        0.7152 * f((c.g * 255.0).round() / 255) +
        0.0722 * f((c.b * 255.0).round() / 255);
  }

  final la = lum(a), lb = lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('tokens : greenForest passe AA texte partout, greenDark non', () {
    const backgrounds = [
      MintColors.porcelaine,
      MintColors.porcelaineHero,
      Colors.white,
    ];
    for (final bg in backgrounds) {
      expect(_contrast(MintColors.greenForest, bg), greaterThanOrEqualTo(4.5),
          reason: 'greenForest doit rester AA texte sur $bg');
      // Documente POURQUOI greenDark est interdit en texte normal : si un
      // futur retuning le fait passer AA, cette garde devient caduque et
      // doit être retirée consciemment.
      expect(_contrast(MintColors.greenDark, bg), lessThan(4.5),
          reason: 'greenDark repasse AA ? retirer la restriction (doc token)');
      expect(_contrast(MintColors.greenDark, bg), greaterThanOrEqualTo(3.0),
          reason: 'grand texte/icônes : greenDark doit garder >= 3:1');
    }
  });

  test('sites texte migrés : plus de greenDark en style de texte normal',
      () {
    // Patterns EXACTS des 7 sites corrigés — une réintroduction du token
    // dans un style de texte normal sur ces surfaces échoue ici.
    const forbidden = {
      'lib/screens/lpp_deep/rachat_echelonne_screen.dart': [
        'bodySmall(color: MintColors.greenDark',
      ],
      'lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart': [
        'labelMedium().copyWith(color: MintColors.greenDark',
        'labelMedium().copyWith(fontWeight: FontWeight.bold, color: MintColors.greenDark',
      ],
      'lib/screens/household/household_screen.dart': [
        'titleMedium(color: MintColors.greenDark',
      ],
      'lib/widgets/educational/leasing_cost_insert_widget.dart': [
        'MintColors.greenDark',
      ],
    };
    forbidden.forEach((path, patterns) {
      final src = File(path).readAsStringSync();
      for (final pat in patterns) {
        expect(src.contains(pat), isFalse,
            reason: '$path réintroduit greenDark en texte normal '
                '(AA 4.5:1 — beads -dy0)');
      }
    });
  });
}
