import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rente vs Capital compliance surface', () {
    test('impact cards do not expose ordinal labels', () {
      final source = File('lib/screens/arbitrage/rente_vs_capital_screen.dart')
          .readAsStringSync();

      expect(
        source,
        isNot(contains("'#\$rank'")),
        reason: 'RvC sensitivity cards must not display a #1/#2 list.',
      );
    });

    test('impact section copy stays neutral across locales', () {
      final bannedPatterns = <RegExp>[
        RegExp(r'change\s+le\s+plus|plus\s+influent', caseSensitive: false),
        RegExp(r'changes\s+the\s+result\s+the\s+most|most\s+influential',
            caseSensitive: false),
        RegExp(r'am\s+meisten|einflussreichsten', caseSensitive: false),
        RegExp(r'cambia\s+m[aá]s|m[aá]s\s+influy', caseSensitive: false),
        RegExp(r'cambia\s+di\s+pi[uù]|pi[uù]\s+influent', caseSensitive: false),
        RegExp(r'mais\s+altera|mais\s+influ', caseSensitive: false),
      ];

      for (final locale in ['fr', 'en', 'de', 'es', 'it', 'pt']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;
        final copy = [
          arb['renteVsCapitalImpactTitle'] as String,
          arb['renteVsCapitalImpactSubtitle'] as String,
        ].join(' ');

        for (final pattern in bannedPatterns) {
          expect(
            pattern.hasMatch(copy),
            isFalse,
            reason: 'RvC impact copy must avoid comparative/advice framing '
                'in app_$locale.arb: $copy',
          );
        }
      }
    });

    test('decision framing copy avoids prescriptive choice verbs', () {
      final checkedKeys = [
        'renteVsCapitalIntro',
        'renteVsCapitalDeltaAdvance',
        'renteVsCapitalConsequenceRenteEyebrow',
        'renteVsCapitalConsequenceCapitalEyebrow',
        'renteVsCapitalConsequenceMixteEyebrow',
        'renteVsCapitalAccrocheEpuise',
      ];
      final bannedPatternsByLocale = <String, List<RegExp>>{
        'fr': [
          RegExp(
            r'\b(chois(?:is|ir)|pre' r'nds|consei[l]|recommand[ée])\b',
            caseSensitive: false,
          ),
          RegExp(r"\b(d['’]avance|gagnant|vainqueur|meill" r"eur)\b",
              caseSensitive: false),
        ],
        'en': [
          RegExp(
            r'\b(choo'
            r'se|ta'
            r'ke|advi'
            r'ce|recomm'
            r'ended|be'
            r'st|opti'
            r'mal)\b',
            caseSensitive: false,
          ),
          RegExp(r'\b(ahead|winner|winning)\b', caseSensitive: false),
        ],
        'de': [
          RegExp(
            r'\b(wähl(?:st|en|e)|empfoh'
            r'len|bes'
            r'te|opti'
            r'mal)\b',
            caseSensitive: false,
          ),
          RegExp(r'\b(Vorsprung|Gewinner)\b', caseSensitive: false),
        ],
        'es': [
          RegExp(
            r'\b(elig(?:es|ir|e)|recomendad[oa]|mej'
            r'or|óptim)\b',
            caseSensitive: false,
          ),
          RegExp(r'\b(ventaja|ganador)\b', caseSensitive: false),
        ],
        'it': [
          RegExp(
            r'\b(scegl(?:i|iere)|consigliat[oa]|migl'
            r'ior|ottim)\b',
            caseSensitive: false,
          ),
          RegExp(r'\b(vantaggio|vincitore)\b', caseSensitive: false),
        ],
        'pt': [
          RegExp(
            r'\b(esco'
            r'lh|recomendad[oa]|melh'
            r'or|[óo]tim)\b',
            caseSensitive: false,
          ),
          RegExp(r'\b(vantagem|vencedor)\b', caseSensitive: false),
        ],
      };

      for (final locale in ['fr', 'en', 'de', 'es', 'it', 'pt']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;
        final copy = checkedKeys.map((key) => arb[key] as String).join(' ');

        for (final pattern in bannedPatternsByLocale[locale]!) {
          expect(
            pattern.hasMatch(copy),
            isFalse,
            reason: 'RvC decision framing must avoid prescriptive choice copy '
                'in app_$locale.arb: $copy',
          );
        }
      }
    });
  });
}
