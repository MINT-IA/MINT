import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

Future<void> openContributedAmountBuilder(
  WidgetTester tester, {
  int currentYear = 2026,
}) async {
  await tester.pumpWidget(
    MintNextDesignLabApp(locale: const Locale('fr'), currentYear: currentYear),
  );
  for (final action in [
    'action:today_3a_intent.start',
    'action:orientation.continue',
    'action:fact_tax_year.confirm_current_year',
    'action:fact_tax_year.continue',
    'action:fact_lpp_affiliation.choose_yes',
    'action:fact_contribution.choose_yes',
  ]) {
    final finder = find.byKey(ValueKey(action));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'yes opens one empty provider amount builder with no multi-provider controls',
    (tester) async {
      await openContributedAmountBuilder(tester);

      expect(
        find.byKey(const ValueKey('node:fact_contributed_amount')),
        findsOneWidget,
      );
      for (final key in [
        'field:fact_contributed_amount.provider_name',
        'field:fact_contributed_amount.amount',
        'action:fact_contributed_amount.toggle_all_reviewed',
        'action:fact_contributed_amount.toggle_where_to_find',
        'action:fact_contributed_amount.unknown_amount',
        'action:fact_contributed_amount.continue',
        'action:fact_contributed_amount.correct_previous',
        'action:fact_contributed_amount.open_safe_exit',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.missing_amount'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.add_provider'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('action:fact_contributed_amount.remove_provider'),
        ),
        findsNothing,
      );
      expect(find.textContaining('2026'), findsWidgets);
      expect(find.textContaining('un seul prestataire 3a'), findsOneWidget);

      final provider = tester.widget<TextFormField>(
        find.byKey(
          const ValueKey('field:fact_contributed_amount.provider_name'),
        ),
      );
      final amount = tester.widget<TextFormField>(
        find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      );
      expect(provider.controller!.text, isEmpty);
      expect(amount.controller!.text, isEmpty);
      expect(find.text('0'), findsNothing);
    },
  );

  testWidgets('Continue focuses the first invalid control and stays put', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.tap(continueAction);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider name');

    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.tap(continueAction);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'ordinary amount');

    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258.50',
    );
    await tester.tap(continueAction);
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirme'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider review');
    expect(
      find.byKey(const ValueKey('error:fact_contributed_amount.all_reviewed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets('provider field rejects sensitive identifiers without routing', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    final provider = find.byKey(
      const ValueKey('field:fact_contributed_amount.provider_name'),
    );
    await tester.enterText(provider, 'VIAC CH93 0076 2011 6238 5295 7');
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
    );
    await tester.pump();

    expect(find.textContaining('sans numéro de compte'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider name');
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets('empty amount opens distinct unknown help and Back restores it', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.unknown_amount'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('node:contributed_amount_unknown_help')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('node:contribution_unknown_help')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('action:contributed_amount_unknown_help.found_amount'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('action:contributed_amount_unknown_help.back')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'unknown amount trigger',
    );
  });

  testWidgets('positive incomplete draft exposes partial help only', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258',
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.missing_amount'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.unknown_amount'),
      ),
      findsNothing,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.missing_amount'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('node:contributed_amount_unknown_help')),
      findsOneWidget,
    );
    expect(find.textContaining('plusieurs prestataires'), findsWidgets);
    expect(
      find.textContaining('ne peut pas encore additionner'),
      findsOneWidget,
    );
    expect(
      find.text('En fait, je n’ai qu’un seul prestataire'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('action:contributed_amount_unknown_help.back')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('action:contributed_amount_unknown_help.found_amount'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('VIAC'), findsOneWidget);
    expect(find.text('7258'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'ordinary amount');
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(
              const ValueKey(
                'action:fact_contributed_amount.toggle_all_reviewed',
              ),
            ),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('complete positive amount reaches canton and Back restores it', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7’258,50',
    );
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    await tester.ensureVisible(reviewed);
    await tester.tap(reviewed);
    await tester.pump();
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('node:fact_canton')), findsOneWidget);
    expect(
      find.text('Dans quel canton es-tu imposé pour 2026 ?'),
      findsOneWidget,
    );
    expect(find.textContaining('aucun versement ordinaire'), findsNothing);
    expect(find.textContaining('Aucun résultat fiscal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.text('VIAC'), findsOneWidget);
    expect(find.text('7’258,50'), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(reviewed);
    expect(checkbox.value, isTrue);
  });

  testWidgets('changing contribution status purges every amount draft', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258',
    );
    final disclosure = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_where_to_find'),
    );
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.correct_previous'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_no')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contribution.choose_yes')),
    );
    await tester.pumpAndSettle();

    final provider = tester.widget<TextFormField>(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
    );
    final amount = tester.widget<TextFormField>(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
    );
    expect(provider.controller!.text, isEmpty);
    expect(amount.controller!.text, isEmpty);
    expect(
      find.byKey(
        const ValueKey('content:fact_contributed_amount.where_to_find'),
      ),
      findsNothing,
    );
  });

  testWidgets('invalid edit cannot silently reuse a previously valid amount', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    final amount = find.byKey(
      const ValueKey('field:fact_contributed_amount.amount'),
    );
    await tester.enterText(amount, '7258');
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    await tester.ensureVisible(reviewed);
    await tester.tap(reviewed);
    await tester.pump();
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:fact_canton.back')));
    await tester.pumpAndSettle();

    await tester.enterText(amount, '7,258');
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
    expect(find.text('7,258'), findsOneWidget);
    expect(find.textContaining('montant CHF valide'), findsOneWidget);
  });

  testWidgets('safe exit resumes amount draft and leave purges all facts', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258,50',
    );
    final disclosure = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_where_to_find'),
    );
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pump();
    final exit = find.byKey(
      const ValueKey('action:fact_contributed_amount.open_safe_exit'),
    );
    await tester.tap(exit);
    await tester.pumpAndSettle();
    final resume = find.byKey(
      const ValueKey('overlay-action:safe_exit.resume'),
    );
    await tester.ensureVisible(resume);
    await tester.tap(resume);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overlay:safe_exit')), findsNothing);

    expect(find.text('VIAC'), findsOneWidget);
    expect(find.text('7258,50'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('content:fact_contributed_amount.where_to_find'),
      ),
      findsOneWidget,
    );

    await tester.tap(exit);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:dismissed.restart')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action:orientation.continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_tax_year')), findsOneWidget);
    expect(find.text('VIAC'), findsNothing);
    expect(find.text('7258,50'), findsNothing);
  });

  testWidgets('tax-year rollover purges amount before the next frame', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258',
    );

    await tester.pumpWidget(
      const MintNextDesignLabApp(locale: Locale('fr'), currentYear: 2027),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('node:fact_tax_year')), findsOneWidget);
    expect(find.text('VIAC'), findsNothing);
    expect(find.text('7258'), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
    expect(
      find.byKey(const ValueKey('action:fact_tax_year.continue')),
      findsNothing,
    );
  });

  testWidgets('amount slice remains reachable at 320x700 and text scale 2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MintNextDesignLabApp(
        locale: Locale('fr'),
        currentYear: 2026,
        textScaler: TextScaler.linear(2),
      ),
    );
    for (final action in [
      'action:today_3a_intent.start',
      'action:orientation.continue',
      'action:fact_tax_year.confirm_current_year',
      'action:fact_tax_year.continue',
      'action:fact_lpp_affiliation.choose_yes',
      'action:fact_contribution.choose_yes',
      'action:fact_contributed_amount.toggle_where_to_find',
      'action:fact_contributed_amount.unknown_amount',
      'action:contributed_amount_unknown_help.back',
    ]) {
      final finder = find.byKey(ValueKey(action));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: action);
    }
    for (final key in [
      'field:fact_contributed_amount.provider_name',
      'field:fact_contributed_amount.amount',
      'action:fact_contributed_amount.toggle_all_reviewed',
      'action:fact_contributed_amount.toggle_where_to_find',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    expect(
      find.byKey(const ValueKey('scroll:fact_contributed_amount')),
      findsOneWidget,
    );
    final continueAction = find.byKey(
      const ValueKey('action:fact_contributed_amount.continue'),
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider name');
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258',
    );
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'provider review');
    expect(tester.takeException(), isNull);

    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    await tester.ensureVisible(reviewed);
    await tester.tap(reviewed);
    await tester.pump();
    await tester.ensureVisible(continueAction);
    await tester.tap(continueAction);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_canton')), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final back = find.byKey(const ValueKey('action:fact_canton.back'));
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('VIAC'), findsOneWidget);
    expect(find.text('7258'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7000',
    );
    await tester.pump();
    final multiple = find.byKey(
      const ValueKey('action:fact_contributed_amount.missing_amount'),
    );
    await tester.ensureVisible(multiple);
    await tester.tap(multiple);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contributed_amount_unknown_help')),
      findsOneWidget,
    );
    expect(
      find.textContaining('ne peut pas encore additionner'),
      findsOneWidget,
    );
    final safeExit = find.byKey(
      const ValueKey('action:contributed_amount_unknown_help.open_safe_exit'),
    );
    await tester.ensureVisible(safeExit);
    await tester.tap(safeExit);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overlay:safe_exit')), findsOneWidget);
    final holdingResume = find.byKey(
      const ValueKey('overlay-action:safe_exit.resume'),
    );
    await tester.ensureVisible(holdingResume);
    await tester.tap(holdingResume);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overlay:safe_exit')), findsNothing);
    expect(
      find.byKey(const ValueKey('node:contributed_amount_unknown_help')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('amount controls expose year-bound semantics and error text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openContributedAmountBuilder(tester);
    final provider = find.byKey(
      const ValueKey('field:fact_contributed_amount.provider_name'),
    );
    final amount = find.byKey(
      const ValueKey('field:fact_contributed_amount.amount'),
    );
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    expect(
      tester.getSemantics(amount).label,
      contains('Cotisations ordinaires créditées · 2026'),
    );
    expect(tester.getSemantics(reviewed).label, contains('2026'));

    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
    );
    await tester.pump();
    expect(tester.getSemantics(provider).label, contains('Prestataire 3a'));
    expect(tester.getSemantics(amount).label, contains('2026'));
    expect(
      tester
          .getSemantics(
            find.byKey(
              const ValueKey('error:fact_contributed_amount.provider_name'),
            ),
          )
          .label,
      contains('Indique le nom du prestataire'),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('error:fact_contributed_amount.amount')),
          )
          .label,
      contains('Indique un montant CHF valide'),
    );
    final reviewedError = tester.getSemantics(
      find.byKey(const ValueKey('error:fact_contributed_amount.all_reviewed')),
    );
    expect(reviewedError.label, contains('Confirme'));
    expect(reviewedError.flagsCollection.isLiveRegion, isTrue);
    expect(tester.getSemantics(reviewed).label, contains('Confirme'));
    semantics.dispose();
  });

  testWidgets('keyboard Done and disclosure never commit or route', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    final amount = find.byKey(
      const ValueKey('field:fact_contributed_amount.amount'),
    );
    await tester.enterText(amount, '7258');
    await tester.showKeyboard(amount);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);

    final disclosure = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_where_to_find'),
    );
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pump();
    expect(find.textContaining('une seule fois'), findsOneWidget);
    expect(find.textContaining('plusieurs contrats'), findsOneWidget);
    expect(find.byKey(const ValueKey('node:fact_canton')), findsNothing);
  });

  testWidgets('education-only from partial help reveals no personal result', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.amount')),
      '7258',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.missing_amount'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'action:contributed_amount_unknown_help.continue_education_only',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:education_explanation')),
      findsOneWidget,
    );
    expect(find.textContaining('aucun montant personnel'), findsOneWidget);
    expect(find.textContaining('7258'), findsNothing);
    expect(find.textContaining('économie fiscale personnelle'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('action:education_explanation.back')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('node:contributed_amount_unknown_help')),
      findsOneWidget,
    );
    expect(
      find.text('En fait, je n’ai qu’un seul prestataire'),
      findsOneWidget,
    );
  });

  testWidgets('editing a reviewed fact requires explicit reconfirmation', (
    tester,
  ) async {
    await openContributedAmountBuilder(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field:fact_contributed_amount.provider_name')),
      'VIAC',
    );
    final amount = find.byKey(
      const ValueKey('field:fact_contributed_amount.amount'),
    );
    await tester.enterText(amount, '7258');
    final reviewed = find.byKey(
      const ValueKey('action:fact_contributed_amount.toggle_all_reviewed'),
    );
    await tester.ensureVisible(reviewed);
    await tester.tap(reviewed);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(reviewed).value, isTrue);
    expect(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.missing_amount'),
      ),
      findsNothing,
    );

    await tester.enterText(amount, '7000');
    await tester.pump();

    expect(tester.widget<CheckboxListTile>(reviewed).value, isFalse);
    expect(
      find.byKey(
        const ValueKey('action:fact_contributed_amount.missing_amount'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
    );
    await tester.tap(
      find.byKey(const ValueKey('action:fact_contributed_amount.continue')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('node:fact_contributed_amount')),
      findsOneWidget,
    );
    expect(find.textContaining('Confirme que'), findsOneWidget);
  });
}
