import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

void main() {
  const semanticContracts = {
    'fr': {
      'contributionChoiceUnknown': 'Je ne sais pas',
      'contributionEdgeTransfer':
          'Ne compte pas un transfert entre deux 3a : ce n’est pas de l’argent neuf.',
      'contributionUnknownTransferWarning':
          'N’additionne jamais un transfert entre deux 3a. Ce serait compter le même argent deux fois.',
    },
    'en': {
      'contributionChoiceUnknown': 'I don’t know',
      'contributionEdgeTransfer':
          'Do not count a transfer between two pillar 3a providers: it is not new money.',
      'contributionUnknownTransferWarning':
          'Never add a transfer between two pillar 3a accounts. That would count the same money twice.',
    },
    'de': {
      'contributionChoiceUnknown': 'Ich weiss es nicht',
      'contributionEdgeTransfer':
          'Zähle einen Transfer zwischen zwei Säulen 3a nicht: Er ist kein neues Geld.',
      'contributionUnknownTransferWarning':
          'Addiere nie einen Transfer zwischen zwei Säulen 3a. Sonst zählst du dasselbe Geld doppelt.',
    },
    'it': {
      'contributionChoiceUnknown': 'Non lo so',
      'contributionEdgeTransfer':
          'Non contare un trasferimento tra due pilastri 3a: non è denaro nuovo.',
      'contributionUnknownTransferWarning':
          'Non sommare mai un trasferimento tra due 3a: conteresti due volte lo stesso denaro.',
    },
    'es': {
      'contributionChoiceUnknown': 'No lo sé',
      'contributionEdgeTransfer':
          'No cuentes una transferencia entre dos pilares 3a: no es dinero nuevo.',
      'contributionUnknownTransferWarning':
          'Nunca sumes una transferencia entre dos 3a. Contarías dos veces el mismo dinero.',
    },
    'pt': {
      'contributionChoiceUnknown': 'Não sei',
      'contributionEdgeTransfer':
          'Não contes uma transferência entre dois pilares 3a: não é dinheiro novo.',
      'contributionUnknownTransferWarning':
          'Nunca somes uma transferência entre dois 3a. Contarias o mesmo dinheiro duas vezes.',
    },
  };
  const catchUpTerms = {
    'fr': 'rachat pour une année passée',
    'en': 'catch-up contribution for a past year',
    'de': 'nachträglichen Einkauf für ein früheres Jahr',
    'it': 'riscatto retroattivo per un anno passato',
    'es': 'aportación retroactiva para cubrir una laguna de un año anterior',
    'pt': 'contribuição retroativa para colmatar uma lacuna de um ano anterior',
  };
  const forbiddenFalseFriends = {
    'en': ['buyback'],
    'es': ['recompra'],
    'pt': ['resgate'],
  };
  for (final locale in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
    test('$locale source preserves unknown and transfer semantics exactly', () {
      final source =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in semanticContracts[locale]!.entries) {
        expect(source[entry.key], entry.value, reason: '$locale ${entry.key}');
      }
    });

    testWidgets(
      '$locale renders the contribution slice without fallback marker',
      (tester) async {
        await tester.pumpWidget(
          MintNextDesignLabApp(locale: Locale(locale), currentYear: 2026),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:today_3a_intent')),
          findsOneWidget,
        );
        for (final action in [
          'action:today_3a_intent.start',
          'action:orientation.continue',
          'action:fact_tax_year.confirm_current_year',
          'action:fact_tax_year.continue',
          'action:fact_lpp_affiliation.choose_yes',
        ]) {
          final finder = find.byKey(ValueKey(action));
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(const ValueKey('node:fact_contribution')),
          findsOneWidget,
        );
        final disclosure = find.byKey(
          const ValueKey('action:fact_contribution.toggle_edge_help'),
        );
        await tester.ensureVisible(disclosure);
        await tester.tap(disclosure);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('content:fact_contribution.edge_help')),
          findsOneWidget,
        );
        expect(find.textContaining(catchUpTerms[locale]!), findsWidgets);
        for (final falseFriend in forbiddenFalseFriends[locale] ?? const []) {
          expect(find.textContaining(falseFriend), findsNothing);
        }
        final unknown = find.byKey(
          const ValueKey('action:fact_contribution.choose_unknown'),
        );
        await tester.ensureVisible(unknown);
        await tester.tap(unknown);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:contribution_unknown_help')),
          findsOneWidget,
        );
        expect(find.textContaining('MISSING_'), findsNothing);
      },
    );
  }
}
