// Les noms de cantons s'écrivent avec leurs accents, dans TOUTES les copies.
//
// Le dépôt contient cinq tables des mêmes 26 noms — `cantonFullNames`,
// `cantonWithArticle`, `FamilyService.cantonNames`, `ExpatService.cantonNames`
// et une copie dans un écran LPP. Quatre d'entre elles écrivaient « Geneve »,
// « Neuchatel », « Bale-Ville » et « Bale-Campagne » sans accents, et ces
// libellés sont AFFICHÉS — sélecteur de canton de l'écart de rentes, écrans
// expatrié, comparateur.
//
// Corriger les quatre copies ne suffit pas : la cinquième arrivera. Ce test
// balaie donc le code source et refuse la faute où qu'elle apparaisse, y
// compris dans une table qui n'existe pas encore.
//
// La règle vient de la doctrine du projet : un « e » ASCII à la place d'un
// « é » est un bug, pas une approximation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nom fautif → forme correcte. Uniquement les cantons dont le nom français
/// porte un accent ; « Zurich », « Vaud » ou « Jura » n'en ont pas.
const Map<String, String> _misspellings = {
  'Geneve': 'Genève',
  'Neuchatel': 'Neuchâtel',
  'Bale-Ville': 'Bâle-Ville',
  'Bale-Campagne': 'Bâle-Campagne',
  'Zoug': 'Zoug', // sans accent, présent pour documenter l'absence de piège
};

void main() {
  test('no source file spells a canton name without its accents', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final wrong in _misspellings.keys) {
          if (_misspellings[wrong] == wrong) continue;
          // Le nom fautif entre guillemets : on cherche un LIBELLÉ, pas une
          // occurrence dans un commentaire ou une URL.
          if (RegExp("['\"]$wrong['\"]").hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1} → ${_misspellings[wrong]}');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'un « e » ASCII à la place d\'un « é » est un bug :\n'
            '${offenders.join('\n')}');
  });

  test('the check would catch a regression', () {
    // Oracle de contraste : sans lui, le test ci-dessus passerait même si son
    // expression régulière ne trouvait plus rien du tout.
    const regression = "  'GE': 'Geneve',";
    expect(RegExp("['\"]Geneve['\"]").hasMatch(regression), isTrue);
    const correct = "  'GE': 'Genève',";
    expect(RegExp("['\"]Geneve['\"]").hasMatch(correct), isFalse);
  });
}
