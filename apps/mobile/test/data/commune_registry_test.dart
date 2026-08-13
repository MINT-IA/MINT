// Registre officiel des communes — oracles d'identité et de recherche.
//
// Ce que ces tests protègent : le fait « domicile » ne doit plus jamais
// reposer sur un nom tapé. Ce qui est enregistré, c'est le numéro OFS ; le
// canton en est dérivé. Les deux relecteurs Codex (axes UX et données) ont
// rejeté toute variante où le canton viendrait d'un texte ou d'un NPA.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/commune_registry.dart';

const String _fixture = '''
# Instantané : 13-08-2026
4001|Aarau|AG|01.01.2010|
225|Rickenbach (ZH)|ZH|12.09.1848|
1097|Rickenbach (LU)|LU|01.01.2013|
6621|Genève|GE|12.09.1848|
2275|Murten|FR|01.01.2022|Morat
371|Biel/Bienne|BE|01.01.2010|Biel,Bienne
353|Bremgarten bei Bern|BE|01.01.2010|
351|Bern|BE|12.09.1848|
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CommuneRegistry.debugReset();
    CommuneRegistry.parse(_fixture);
  });

  tearDown(CommuneRegistry.debugReset);

  test('the canton is derived from the federal identity, never from a string',
      () {
    final commune = CommuneRegistry.byBfs(1097);
    expect(commune, isNotNull);
    expect(commune!.canton, 'LU');
    expect(commune.officialName, 'Rickenbach (LU)');
  });

  test(
      'homonymous communes are distinct entries, each carrying the official '
      'cantonal suffix that the federal register itself provides', () {
    final results = CommuneRegistry.search('Rickenbach');
    expect(results.length, 2);
    expect(results.map((c) => c.officialName).toSet(),
        {'Rickenbach (ZH)', 'Rickenbach (LU)'});
    expect(results.map((c) => c.bfs).toSet(), {225, 1097},
        reason: "deux identités fédérales distinctes, pas un libellé ambigu");
  });

  test('search ignores case and diacritics', () {
    expect(CommuneRegistry.search('geneve').single.bfs, 6621);
    expect(CommuneRegistry.search('GENÈVE').single.bfs, 6621);
  });

  test(
      'a French speaker finds Murten by typing Morat, and the official name '
      'is what comes back', () {
    final results = CommuneRegistry.search('Morat');
    expect(results.single.bfs, 2275);
    expect(results.single.officialName, 'Murten',
        reason: "l'alias sert à chercher, jamais à afficher");
  });

  test('both halves of a dual official name are searchable', () {
    expect(CommuneRegistry.search('Bienne').single.bfs, 371);
    expect(CommuneRegistry.search('Biel').first.bfs, 371);
  });

  test('a name beginning with the query outranks one containing it', () {
    final results = CommuneRegistry.search('Bern');
    expect(results.first.officialName, 'Bern',
        reason: 'Bremgarten bei Bern ne doit pas passer devant Bern');
  });

  test('an empty query proposes nothing rather than everything', () {
    expect(CommuneRegistry.search(''), isEmpty);
    expect(CommuneRegistry.search('   '), isEmpty);
  });

  test('an unknown name resolves to nothing — no approximate match', () {
    expect(CommuneRegistry.search('Zzzzville'), isEmpty);
    expect(CommuneRegistry.byBfs(999999), isNull);
  });

  test('the snapshot date is carried by the registry itself', () {
    expect(CommuneRegistry.snapshotDate, '13-08-2026');
  });

  test(
      'the real embedded asset parses with the real parser, covers the '
      'country and keeps every homonym distinguishable', () {
    // Lecture par le système de fichiers et non par `rootBundle` : en test
    // unitaire le bundle d'assets n'est pas monté, et une attente sur un
    // asset absent ne rend jamais la main. L'intégrité du FICHIER est par
    // ailleurs vérifiée par `tools/data/build_commune_registry.py --check`.
    final asset = File('assets/data/commune_registry.txt');
    expect(asset.existsSync(), isTrue, reason: 'asset embarqué manquant');

    CommuneRegistry.debugReset();
    CommuneRegistry.parse(asset.readAsStringSync());

    expect(CommuneRegistry.communeCount, greaterThan(1900),
        reason: 'couverture nationale, pas un échantillon');
    expect(CommuneRegistry.snapshotDate, isNotEmpty,
        reason: 'un registre sans date de validité ne dit pas quand il est vrai');

    // Moutier a changé de canton au 01.01.2026 : BE 700 devient JU 6831.
    // L'asset doit porter la réalité administrative courante — une API tierce
    // renvoyait encore « BE 700 » le 2026-08-13, d'où le choix de la source
    // fédérale.
    final moutier = CommuneRegistry.byBfs(6831);
    expect(moutier?.officialName, 'Moutier');
    expect(moutier?.canton, 'JU');

    // « Rickenbach » est le record national des homonymes : cinq communes
    // dans cinq cantons, distinguées à l'écran par le seul suffixe officiel.
    // Elles passent devant Langrickenbach, qui ne fait que contenir le mot.
    final rickenbach = CommuneRegistry.search('Rickenbach', limit: 20);
    final exact = rickenbach.take(5).toList();
    expect(exact.map((c) => c.canton).toSet(), {'ZH', 'LU', 'SO', 'TG', 'BL'});
    expect(exact.map((c) => c.officialName).toSet().length, 5,
        reason: 'aucun libellé dupliqué à l\'écran');
    expect(rickenbach.map((c) => c.officialName), contains('Langrickenbach'));
    expect(rickenbach.indexWhere((c) => c.officialName == 'Langrickenbach'),
        greaterThanOrEqualTo(5),
        reason: 'une correspondance interne ne passe pas devant un début de nom');
  });

  group('canonicalisation de la saisie', () {
    // Défaut trouvé par la revue Codex : le nom officiel est « St. Gallen »
    // et personne ne tape le point. Une recherche « tolérante » qui garde la
    // ponctuation rate une commune de 80 000 habitants.
    test('a name written with a period is found without it', () {
      CommuneRegistry.debugReset();
      CommuneRegistry.parse('''
# Instantané : 13-08-2026
3203|St. Gallen|SG|01.01.2003|
''');
      expect(CommuneRegistry.search('St Gallen').single.bfs, 3203);
      expect(CommuneRegistry.search('st.gallen').single.bfs, 3203);
      expect(CommuneRegistry.search('st   gallen').single.bfs, 3203);
    });

    test('apostrophes, hyphens and slashes are all just separators', () {
      CommuneRegistry.debugReset();
      CommuneRegistry.parse('''
# Instantané : 13-08-2026
5871|L'Abbaye|VD|12.09.1848|
6002|Saint-Maurice|VS|12.09.1848|
3506|Domat/Ems|GR|12.09.1848|
''');
      expect(CommuneRegistry.search('l abbaye').single.bfs, 5871);
      expect(CommuneRegistry.search("L'Abbaye").single.bfs, 5871);
      expect(CommuneRegistry.search('saint maurice').single.bfs, 6002);
      expect(CommuneRegistry.search('domat ems').single.bfs, 3506);
    });

    test('the real asset finds St. Gallen typed without its period', () {
      CommuneRegistry.debugReset();
      CommuneRegistry.parse(
          File('assets/data/commune_registry.txt').readAsStringSync());
      final results = CommuneRegistry.search('St Gallen');
      expect(results.map((c) => c.bfs), contains(3203));
    });
  });

  group('un registre corrompu ne se fait pas passer pour le registre', () {
    setUp(CommuneRegistry.debugReset);

    test('a truncated line is a corruption, not a line to skip', () {
      expect(
          () => CommuneRegistry.parse(
              '# Instantané : 13-08-2026\n4001|Aarau|AG\n'),
          throwsFormatException);
    });

    test('a duplicated federal number is refused', () {
      expect(
          () => CommuneRegistry.parse('# Instantané : 13-08-2026\n'
              '4001|Aarau|AG|01.01.2010|\n4001|Autre|AG|01.01.2010|\n'),
          throwsFormatException);
    });

    test('a canton outside the 26 official codes is refused', () {
      expect(
          () => CommuneRegistry.parse(
              '# Instantané : 13-08-2026\n4001|Aarau|XX|01.01.2010|\n'),
          throwsFormatException);
    });

    test('a registry without a snapshot date is refused', () {
      expect(() => CommuneRegistry.parse('4001|Aarau|AG|01.01.2010|\n'),
          throwsFormatException);
      expect(
          () => CommuneRegistry.parse(
              '# Instantané : bientôt\n4001|Aarau|AG|01.01.2010|\n'),
          throwsFormatException);
    });

    test('an empty registry is refused rather than silently loaded', () {
      expect(() => CommuneRegistry.parse('# Instantané : 13-08-2026\n'),
          throwsFormatException);
    });

    test('nothing is published when parsing fails', () {
      try {
        CommuneRegistry.parse('# Instantané : 13-08-2026\n4001|Aarau|AG\n');
      } on FormatException {
        // attendu
      }
      expect(CommuneRegistry.isLoaded, isFalse,
          reason: 'la publication est atomique : rien ou tout');
      expect(CommuneRegistry.snapshotDate, isEmpty);
    });
  });
}
