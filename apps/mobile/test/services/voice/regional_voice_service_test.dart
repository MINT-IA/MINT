import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/voice/regional_voice_service.dart';

// ────────────────────────────────────────────────────────────
//  REGIONAL VOICE SERVICE TESTS — Swiss linguistic identity
// ────────────────────────────────────────────────────────────
//
// Verifies:
//   - Canton → region mapping for all 26 Swiss cantons
//   - Regional prompt additions are non-empty and authentic
//   - Local expressions are present per region
//   - Financial culture notes and humor style per region
//   - Canton-specific nuances (VS, GE, ZH, BE, TI, etc.)
//   - No banned compliance terms in any prompt addition
//   - Graceful handling of null/empty/unknown cantons
//
// References:
//   - docs/VOICE_SYSTEM.md §9 (Adaptation linguistique)
//   - CLAUDE.md §6 (Compliance rules — banned terms)
// ────────────────────────────────────────────────────────────

/// Compliance-banned terms (CLAUDE.md §6).
const _bannedTerms = [
  'garanti',
  'certain',
  'assuré',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
  'conseiller', // must use "spécialiste"
];

void main() {
  // ═══════════════════════════════════════════════════════════
  // Canton → Region mapping
  // ═══════════════════════════════════════════════════════════

  group('Canton → Region mapping', () {
    test('VD → romande', () {
      expect(
        RegionalVoiceService.regionForCanton('VD'),
        SwissRegion.romande,
      );
    });

    test('GE → romande', () {
      expect(
        RegionalVoiceService.regionForCanton('GE'),
        SwissRegion.romande,
      );
    });

    test('NE → romande', () {
      expect(
        RegionalVoiceService.regionForCanton('NE'),
        SwissRegion.romande,
      );
    });

    test('JU → romande', () {
      expect(
        RegionalVoiceService.regionForCanton('JU'),
        SwissRegion.romande,
      );
    });

    test('VS → romande', () {
      expect(
        RegionalVoiceService.regionForCanton('VS'),
        SwissRegion.romande,
      );
    });

    test('FR → romande', () {
      expect(
        RegionalVoiceService.regionForCanton('FR'),
        SwissRegion.romande,
      );
    });

    test('ZH → deutschschweiz', () {
      expect(
        RegionalVoiceService.regionForCanton('ZH'),
        SwissRegion.deutschschweiz,
      );
    });

    test('BE → deutschschweiz', () {
      expect(
        RegionalVoiceService.regionForCanton('BE'),
        SwissRegion.deutschschweiz,
      );
    });

    test('LU → deutschschweiz', () {
      expect(
        RegionalVoiceService.regionForCanton('LU'),
        SwissRegion.deutschschweiz,
      );
    });

    test('ZG → deutschschweiz', () {
      expect(
        RegionalVoiceService.regionForCanton('ZG'),
        SwissRegion.deutschschweiz,
      );
    });

    test('BS → deutschschweiz', () {
      expect(
        RegionalVoiceService.regionForCanton('BS'),
        SwissRegion.deutschschweiz,
      );
    });

    test('AG → deutschschweiz', () {
      expect(
        RegionalVoiceService.regionForCanton('AG'),
        SwissRegion.deutschschweiz,
      );
    });

    test('SG → deutschschweiz', () {
      expect(
        RegionalVoiceService.regionForCanton('SG'),
        SwissRegion.deutschschweiz,
      );
    });

    test('TI → italiana', () {
      expect(
        RegionalVoiceService.regionForCanton('TI'),
        SwissRegion.italiana,
      );
    });

    test('GR → italiana', () {
      expect(
        RegionalVoiceService.regionForCanton('GR'),
        SwissRegion.italiana,
      );
    });

    test('null canton → unknown', () {
      expect(
        RegionalVoiceService.regionForCanton(null),
        SwissRegion.unknown,
      );
    });

    test('empty string → unknown', () {
      expect(
        RegionalVoiceService.regionForCanton(''),
        SwissRegion.unknown,
      );
    });

    test('invalid canton → unknown', () {
      expect(
        RegionalVoiceService.regionForCanton('XX'),
        SwissRegion.unknown,
      );
    });

    test('lowercase canton normalizes correctly', () {
      expect(
        RegionalVoiceService.regionForCanton('vd'),
        SwissRegion.romande,
      );
      expect(
        RegionalVoiceService.regionForCanton('zh'),
        SwissRegion.deutschschweiz,
      );
      expect(
        RegionalVoiceService.regionForCanton('ti'),
        SwissRegion.italiana,
      );
    });

    test('canton with whitespace normalizes correctly', () {
      expect(
        RegionalVoiceService.regionForCanton(' VS '),
        SwissRegion.romande,
      );
    });

    test('all Deutschschweiz cantons map correctly', () {
      const cantons = [
        'ZH', 'BE', 'LU', 'ZG', 'AG', 'SG', 'BS', 'BL',
        'SO', 'TG', 'SH', 'AI', 'AR', 'GL', 'NW', 'OW', 'SZ', 'UR',
      ];
      for (final c in cantons) {
        expect(
          RegionalVoiceService.regionForCanton(c),
          SwissRegion.deutschschweiz,
          reason: '$c should map to deutschschweiz',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Regional prompt additions — non-empty and authentic
  // ═══════════════════════════════════════════════════════════

  group('Regional prompt additions', () {
    test('romande has non-empty promptAddition', () {
      final flavor = RegionalVoiceService.forCanton('VD');
      expect(flavor.promptAddition, isNotEmpty);
    });

    test('deutschschweiz has non-empty promptAddition', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(flavor.promptAddition, isNotEmpty);
    });

    test('italiana has non-empty promptAddition', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(flavor.promptAddition, isNotEmpty);
    });

    test('unknown canton returns empty promptAddition', () {
      final flavor = RegionalVoiceService.forCanton(null);
      expect(flavor.promptAddition, isEmpty);
    });

    test('romande prompt contains septante', () {
      final flavor = RegionalVoiceService.forCanton('VD');
      expect(flavor.promptAddition, contains('septante'));
    });

    test('romande prompt contains nonante', () {
      final flavor = RegionalVoiceService.forCanton('GE');
      expect(flavor.promptAddition, contains('nonante'));
    });

    test('romande prompt contains chenit', () {
      final flavor = RegionalVoiceService.forCanton('NE');
      expect(flavor.promptAddition, contains('chenit'));
    });

    test('deutschschweiz prompt contains Bitzeli', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(flavor.promptAddition, contains('Bitzeli'));
    });

    test('deutschschweiz prompt contains Feierabend', () {
      final flavor = RegionalVoiceService.forCanton('BE');
      expect(flavor.promptAddition, contains('Feierabend'));
    });

    test('deutschschweiz prompt mentions Sparkultur', () {
      final flavor = RegionalVoiceService.forCanton('LU');
      expect(flavor.promptAddition, contains('Sparkultur'));
    });

    test('italiana prompt contains grotto', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(flavor.promptAddition, contains('grotto'));
    });

    test('italiana prompt mentions famiglia/familiare', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(
        flavor.promptAddition.contains('famigl') ||
            flavor.promptAddition.contains('familiare'),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Local expressions
  // ═══════════════════════════════════════════════════════════

  group('Local expressions', () {
    test('romande has local expressions', () {
      final flavor = RegionalVoiceService.forCanton('VD');
      expect(flavor.localExpressions, isNotEmpty);
      expect(flavor.localExpressions.length, greaterThanOrEqualTo(5));
    });

    test('deutschschweiz has local expressions', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(flavor.localExpressions, isNotEmpty);
      expect(flavor.localExpressions.length, greaterThanOrEqualTo(5));
    });

    test('italiana has local expressions', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(flavor.localExpressions, isNotEmpty);
      expect(flavor.localExpressions.length, greaterThanOrEqualTo(5));
    });

    test('unknown region has empty local expressions', () {
      final flavor = RegionalVoiceService.forCanton(null);
      expect(flavor.localExpressions, isEmpty);
    });

    test('romande expressions include septante', () {
      final flavor = RegionalVoiceService.forCanton('VS');
      expect(flavor.localExpressions, contains('septante'));
    });

    test('romande expressions include natel', () {
      final flavor = RegionalVoiceService.forCanton('GE');
      expect(flavor.localExpressions, contains('natel'));
    });

    test('deutschschweiz expressions include Znüni', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(
        flavor.localExpressions.any((e) => e.contains('ni')),
        isTrue,
        reason: 'Should include Znüni',
      );
    });

    test('italiana expressions include grotto', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(flavor.localExpressions, contains('grotto'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Financial culture & humor style
  // ═══════════════════════════════════════════════════════════

  group('Financial culture notes', () {
    test('romande financial culture is non-empty', () {
      final flavor = RegionalVoiceService.forCanton('VD');
      expect(flavor.financialCultureNote, isNotEmpty);
    });

    test('deutschschweiz financial culture is non-empty', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(flavor.financialCultureNote, isNotEmpty);
    });

    test('italiana financial culture is non-empty', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(flavor.financialCultureNote, isNotEmpty);
    });

    test('deutschschweiz financial culture mentions 3a', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(flavor.financialCultureNote, contains('3a'));
    });

    test('italiana financial culture mentions family', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(
        flavor.financialCultureNote.contains('famil'),
        isTrue,
      );
    });
  });

  group('Humor style', () {
    test('romande humor style is non-empty', () {
      final flavor = RegionalVoiceService.forCanton('VD');
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('deutschschweiz humor style is non-empty', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(flavor.humorStyle, isNotEmpty);
    });

    test('italiana humor style is non-empty', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(flavor.humorStyle, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Canton-specific nuances
  // ═══════════════════════════════════════════════════════════

  group('Canton-specific nuances', () {
    test('VS prompt mentions direct/montagnard', () {
      final flavor = RegionalVoiceService.forCanton('VS');
      expect(
        flavor.promptAddition.contains('direct') ||
            flavor.promptAddition.contains('montagnard'),
        isTrue,
      );
    });

    test('VS canton note mentions fendant', () {
      final flavor = RegionalVoiceService.forCanton('VS');
      expect(flavor.cantonNote, contains('fendant'));
    });

    test('GE prompt mentions cosmopolite', () {
      final flavor = RegionalVoiceService.forCanton('GE');
      expect(flavor.promptAddition, contains('cosmopolite'));
    });

    test('VD prompt mentions huitante', () {
      final flavor = RegionalVoiceService.forCanton('VD');
      expect(
        flavor.promptAddition.contains('uitante') ||
            flavor.cantonNote.contains('uitante'),
        isTrue,
        reason: 'VD should reference huitante',
      );
    });

    test('ZH prompt mentions urbain/finance', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      expect(
        flavor.promptAddition.contains('rbain') ||
            flavor.promptAddition.contains('finance') ||
            flavor.cantonNote.contains('rbain') ||
            flavor.cantonNote.contains('finance'),
        isTrue,
      );
    });

    test('ZG prompt mentions fiscal/Steuervorteil', () {
      final flavor = RegionalVoiceService.forCanton('ZG');
      expect(
        flavor.cantonNote.contains('fiscal') ||
            flavor.cantonNote.contains('Steuer') ||
            flavor.cantonNote.contains('optimisation'),
        isTrue,
      );
    });

    test('BE prompt mentions gemütlich/posé', () {
      final flavor = RegionalVoiceService.forCanton('BE');
      expect(
        flavor.promptAddition.contains('tlich') ||
            flavor.cantonNote.contains('tlich') ||
            flavor.cantonNote.contains('pos'),
        isTrue,
      );
    });

    test('BS canton note mentions Fasnacht', () {
      final flavor = RegionalVoiceService.forCanton('BS');
      expect(flavor.cantonNote, contains('Fasnacht'));
    });

    test('TI prompt mentions sole/soleggiato/soleil', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      expect(
        flavor.promptAddition.contains('sol') ||
            flavor.cantonNote.contains('sol'),
        isTrue,
      );
    });

    test('GR canton note mentions trilingue', () {
      final flavor = RegionalVoiceService.forCanton('GR');
      expect(flavor.cantonNote, contains('trilingue'));
    });

    test('NE canton note mentions horlogerie', () {
      final flavor = RegionalVoiceService.forCanton('NE');
      expect(flavor.cantonNote, contains('horlogerie'));
    });

    test('JU canton note mentions indépendance', () {
      final flavor = RegionalVoiceService.forCanton('JU');
      expect(
        flavor.cantonNote.contains('pendance'),
        isTrue,
      );
    });

    test('FR canton note mentions röstigraben/bilingue', () {
      final flavor = RegionalVoiceService.forCanton('FR');
      expect(
        flavor.cantonNote.contains('stigraben') ||
            flavor.cantonNote.contains('bilingue'),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Compliance — no banned terms
  // ═══════════════════════════════════════════════════════════

  group('Compliance — no banned terms', () {
    test('romande prompt contains no banned terms', () {
      final flavor = RegionalVoiceService.forCanton('VD');
      final lower = flavor.promptAddition.toLowerCase();
      for (final term in _bannedTerms) {
        expect(
          lower.contains(term),
          isFalse,
          reason: 'Romande prompt should not contain "$term"',
        );
      }
    });

    test('deutschschweiz prompt contains no banned terms', () {
      final flavor = RegionalVoiceService.forCanton('ZH');
      final lower = flavor.promptAddition.toLowerCase();
      for (final term in _bannedTerms) {
        expect(
          lower.contains(term),
          isFalse,
          reason: 'Deutschschweiz prompt should not contain "$term"',
        );
      }
    });

    test('italiana prompt contains no banned terms', () {
      final flavor = RegionalVoiceService.forCanton('TI');
      final lower = flavor.promptAddition.toLowerCase();
      for (final term in _bannedTerms) {
        expect(
          lower.contains(term),
          isFalse,
          reason: 'Italiana prompt should not contain "$term"',
        );
      }
    });

    test('no canton note contains banned terms', () {
      const cantons = [
        'VD', 'GE', 'NE', 'JU', 'VS', 'FR', // romande
        'ZH', 'BE', 'LU', 'ZG', 'BS', 'SG', 'AG', // deutschschweiz
        'TI', 'GR', // italiana
      ];
      for (final canton in cantons) {
        final flavor = RegionalVoiceService.forCanton(canton);
        final lower = flavor.cantonNote.toLowerCase();
        for (final term in _bannedTerms) {
          expect(
            lower.contains(term),
            isFalse,
            reason: '$canton canton note should not contain "$term"',
          );
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // RegionalFlavor.empty
  // ═══════════════════════════════════════════════════════════

  group('RegionalFlavor.empty', () {
    test('has unknown region', () {
      expect(RegionalFlavor.empty.region, SwissRegion.unknown);
    });

    test('has empty promptAddition', () {
      expect(RegionalFlavor.empty.promptAddition, isEmpty);
    });

    test('has empty localExpressions', () {
      expect(RegionalFlavor.empty.localExpressions, isEmpty);
    });

    test('has empty financialCultureNote', () {
      expect(RegionalFlavor.empty.financialCultureNote, isEmpty);
    });

    test('has empty humorStyle', () {
      expect(RegionalFlavor.empty.humorStyle, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Region enum coverage
  // ═══════════════════════════════════════════════════════════

  group('SwissRegion enum', () {
    test('has exactly 4 values', () {
      expect(SwissRegion.values.length, 4);
    });

    test('values include all expected regions', () {
      expect(SwissRegion.values, contains(SwissRegion.romande));
      expect(SwissRegion.values, contains(SwissRegion.deutschschweiz));
      expect(SwissRegion.values, contains(SwissRegion.italiana));
      expect(SwissRegion.values, contains(SwissRegion.unknown));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Cross-region consistency
  // ═══════════════════════════════════════════════════════════

  group('Cross-region consistency', () {
    test('every region has distinct prompt prefix', () {
      final romande = RegionalVoiceService.forCanton('VD');
      final deutsch = RegionalVoiceService.forCanton('ZH');
      final italiana = RegionalVoiceService.forCanton('TI');

      // Each region's prompt starts with its own header
      expect(romande.promptAddition, contains('COULEUR'));
      expect(deutsch.promptAddition, contains('REGIONALE'));
      expect(italiana.promptAddition, contains('COLORE'));
    });

    test('different cantons in same region share base content', () {
      final vd = RegionalVoiceService.forCanton('VD');
      final ge = RegionalVoiceService.forCanton('GE');

      // Both romande — both contain septante
      expect(vd.promptAddition, contains('septante'));
      expect(ge.promptAddition, contains('septante'));

      // Same region
      expect(vd.region, ge.region);
    });

    test('different cantons in same region have different canton notes', () {
      final vd = RegionalVoiceService.forCanton('VD');
      final ge = RegionalVoiceService.forCanton('GE');

      expect(vd.cantonNote, isNot(equals(ge.cantonNote)));
    });

    test('canton without specific note returns empty cantonNote', () {
      // BL has no specific note in deutschschweiz
      final flavor = RegionalVoiceService.forCanton('BL');
      expect(flavor.cantonNote, isEmpty);
      // But still has regional content
      expect(flavor.promptAddition, isNotEmpty);
      expect(flavor.region, SwissRegion.deutschschweiz);
    });
  });
}
