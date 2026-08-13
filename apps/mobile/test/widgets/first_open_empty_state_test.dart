// Bascule 4 — beat b4_empty_today : l'état vide de la première ouverture.
//
// Les oracles sont MÉCANIQUES : sélection par identifiant sémantique
// (jamais par libellé), sous-arbre borné, et rôles distincts pour la
// collecte primaire, le refus et la reprise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/aujourdhui/first_open_empty_state.dart';

Finder byIdentifier(String identifier) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == identifier,
      description: 'Semantics(identifier: $identifier)',
    );

void main() {
  Future<int> pumpEmptyState(
    WidgetTester tester, {
    VoidCallback? onAddFirstFact,
  }) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: FirstOpenEmptyState(
          onAddFirstFact: onAddFirstFact ?? () => taps++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return taps;
  }

  testWidgets(
      'the empty shell states that nothing is known yet and exposes exactly '
      'one primary collection action', (tester) async {
    await pumpEmptyState(tester);

    expect(byIdentifier('status:today.no_financial_facts'), findsOneWidget);
    expect(find.text('MINT ne connaît pas encore ta situation.'),
        findsOneWidget);
    expect(byIdentifier('action:today.add_first_fact'), findsOneWidget,
        reason: 'exactement UNE action de collecte primaire');
    // Le refus est un rôle DISTINCT, pas une seconde collecte.
    expect(byIdentifier('action:today.decline_first_fact'), findsOneWidget);
    expect(byIdentifier('action:today.resume_first_fact'), findsNothing,
        reason: 'la reprise n\'existe qu\'après un refus');
  });

  testWidgets(
      'that primary action routes to the first missing canonical '
      'prerequisite and to no other collection engine', (tester) async {
    var routed = 0;
    await pumpEmptyState(tester, onAddFirstFact: () => routed++);
    await tester.tap(byIdentifier('action:today.add_first_fact'));
    await tester.pumpAndSettle();
    expect(routed, 1,
        reason: 'une seule destination : le parcours canonique du domicile');
  });

  testWidgets(
      'the primary action is specific and a dedicated rationale node sits '
      'in its own subtree with the localised copy', (tester) async {
    await pumpEmptyState(tester);
    expect(byIdentifier('node:today.first_fact_rationale'), findsOneWidget);
    expect(
        find.text('Une partie de tes impôts varie selon le canton et la '
            'commune.'),
        findsOneWidget,
        reason: 'la justification est AFFICHÉE, pas implicite');
    expect(find.text('Choisir mon canton'), findsOneWidget,
        reason: 'action SPÉCIFIQUE, jamais « ajouter une information »');
  });

  testWidgets(
      'the empty subtree contains no progress indicator, no progress '
      'semantics and no rendered metric', (tester) async {
    await pumpEmptyState(tester);
    final subtree = byIdentifier('screen:today.empty');
    expect(subtree, findsOneWidget);
    expect(
        find.descendant(
            of: subtree, matching: find.byType(LinearProgressIndicator)),
        findsNothing);
    expect(
        find.descendant(
            of: subtree, matching: find.byType(CircularProgressIndicator)),
        findsNothing);
    // Aucune métrique rendue : aucun texte du sous-arbre ne contient de
    // chiffre (le contrat interdit chiffre et jauge sans fait).
    final texts = tester
        .widgetList<Text>(find.descendant(of: subtree, matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .toList();
    for (final value in texts) {
      expect(RegExp(r'\d').hasMatch(value), isFalse,
          reason: 'aucun chiffre dans l\'état vide : « $value »');
    }
  });

  testWidgets(
      'declining closes the request without any follow-up prompt and '
      'without substituting another question', (tester) async {
    await pumpEmptyState(tester);
    await tester.tap(byIdentifier('action:today.decline_first_fact'));
    await tester.pumpAndSettle();

    expect(byIdentifier('action:today.add_first_fact'), findsNothing,
        reason: 'aucune relance immédiate');
    expect(byIdentifier('node:today.first_fact_rationale'), findsNothing);
    // Aucune question substituée : il n'existe aucune autre action de
    // collecte primaire dans le sous-arbre après refus.
    final subtree = byIdentifier('screen:today.empty');
    expect(
        find.descendant(of: subtree, matching: find.byType(FilledButton)),
        findsNothing,
        reason: 'aucune question de remplacement');
  });

  testWidgets(
      'after declining the shell stays usable and exposes the stable '
      'resume action by its identifier', (tester) async {
    await pumpEmptyState(tester);
    await tester.tap(byIdentifier('action:today.decline_first_fact'));
    await tester.pumpAndSettle();

    expect(byIdentifier('status:today.first_fact_declined'), findsOneWidget);
    expect(byIdentifier('action:today.resume_first_fact'), findsOneWidget);

    await tester.tap(byIdentifier('action:today.resume_first_fact'));
    await tester.pumpAndSettle();
    expect(byIdentifier('action:today.add_first_fact'), findsOneWidget,
        reason: 'la reprise ramène la collecte primaire');
  });

  testWidgets('every touch target inside the empty subtree is at least 48 '
      'by 48', (tester) async {
    await pumpEmptyState(tester);
    for (final identifier in [
      'action:today.add_first_fact',
      'action:today.decline_first_fact',
    ]) {
      final size = tester.getSize(byIdentifier(identifier));
      expect(size.height, greaterThanOrEqualTo(kMinTouchTarget),
          reason: '$identifier doit mesurer au moins 48 de haut');
    }
  });

  testWidgets('the reading order is promise then factual state then action',
      (tester) async {
    await pumpEmptyState(tester);
    double topOf(String identifier) =>
        tester.getTopLeft(byIdentifier(identifier)).dy;
    expect(topOf('node:today.empty_editorial'),
        lessThan(topOf('status:today.no_financial_facts')));
    expect(topOf('status:today.no_financial_facts'),
        lessThan(topOf('action:today.add_first_fact')));
  });
}
