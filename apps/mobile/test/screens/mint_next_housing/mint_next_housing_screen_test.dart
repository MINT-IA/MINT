import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_housing/mint_next_housing_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    FeatureFlags.enableMintNextHousing = true;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => FeatureFlags.enableMintNextHousing = false);

  testWidgets('asks one housing fact before showing a bounded explanation',
      (tester) async {
    await tester.pumpWidget(const _TestApp());

    expect(_semantic('node:fact_logement'), findsOneWidget);
    expect(_semantic('action:fact_logement.continue'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: _semantic('action:fact_logement.continue'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_logement.continue'));
    await tester.pump();

    expect(_semantic('node:housing_owner_boundary'), findsOneWidget);
    expect(find.textContaining('Aucun avantage fiscal'), findsOneWidget);
    expect(
      _semantic('action:housing_owner_boundary.continue'),
      findsOneWidget,
    );
  });

  testWidgets('owner branch asks mortgage status without calculating tax',
      (tester) async {
    await tester.pumpWidget(const _TestApp());
    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_logement.continue'));
    await tester.pump();
    await tester.tap(_semantic('action:housing_owner_boundary.continue'));
    await tester.pump();

    expect(_semantic('node:fact_housing_mortgage'), findsOneWidget);
    expect(_semantic('choice:fact_housing_mortgage.yes'), findsOneWidget);
    expect(_semantic('choice:fact_housing_mortgage.no'), findsOneWidget);
    expect(_semantic('choice:fact_housing_mortgage.unknown'), findsOneWidget);

    await tester.tap(_semantic('choice:fact_housing_mortgage.yes'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_housing_mortgage.continue'));
    await tester.pump();

    expect(_semantic('node:housing_mortgage_yes_boundary'), findsOneWidget);
    expect(find.textContaining('Rien n’est encore calculé'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_semantic('node:fact_housing_mortgage'), findsOneWidget);
    final choice = tester.widget<Semantics>(
      _semantic('choice:fact_housing_mortgage.yes'),
    );
    expect(choice.properties.selected, isTrue);
  });

  testWidgets('mortgaged owner can say whether the annual statement is ready',
      (tester) async {
    await tester.pumpWidget(const _TestApp());
    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_logement.continue'));
    await tester.pump();
    await tester.tap(_semantic('action:housing_owner_boundary.continue'));
    await tester.pump();
    await tester.tap(_semantic('choice:fact_housing_mortgage.yes'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_housing_mortgage.continue'));
    await tester.pump();
    await tester
        .tap(_semantic('action:housing_mortgage_yes_boundary.continue'));
    await tester.pump();

    expect(_semantic('node:fact_mortgage_statement'), findsOneWidget);
    expect(_semantic('choice:fact_mortgage_statement.ready'), findsOneWidget);
    expect(
        _semantic('choice:fact_mortgage_statement.find_later'), findsOneWidget);
    expect(_semantic('choice:fact_mortgage_statement.unknown'), findsOneWidget);

    await tester.tap(_semantic('choice:fact_mortgage_statement.find_later'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_mortgage_statement.continue'));
    await tester.pump();

    expect(
      _semantic('node:mortgage_statement_find_later_boundary'),
      findsOneWidget,
    );
    expect(find.textContaining('aucun chiffre'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_semantic('node:fact_mortgage_statement'), findsOneWidget);
    final choice = tester.widget<Semantics>(
      _semantic('choice:fact_mortgage_statement.find_later'),
    );
    expect(choice.properties.selected, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(_semantic('choice:fact_housing_mortgage.no'));
    await tester.pump();
    await tester.tap(_semantic('choice:fact_housing_mortgage.yes'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_housing_mortgage.continue'));
    await tester.pump();
    await tester
        .tap(_semantic('action:housing_mortgage_yes_boundary.continue'));
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(
            _semantic('choice:fact_mortgage_statement.find_later'),
          )
          .properties
          .selected,
      isFalse,
    );
  });

  testWidgets('ready statement collects annual interest locally without result',
      (tester) async {
    await tester.pumpWidget(const _TestApp());
    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_logement.continue'));
    await tester.pump();
    await tester.tap(_semantic('action:housing_owner_boundary.continue'));
    await tester.pump();
    await tester.tap(_semantic('choice:fact_housing_mortgage.yes'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_housing_mortgage.continue'));
    await tester.pump();
    await tester
        .tap(_semantic('action:housing_mortgage_yes_boundary.continue'));
    await tester.pump();
    await tester.tap(_semantic('choice:fact_mortgage_statement.ready'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_mortgage_statement.continue'));
    await tester.pump();
    await tester
        .tap(_semantic('action:mortgage_statement_ready_boundary.continue'));
    await tester.pump();

    expect(_semantic('node:fact_mortgage_interest_paid'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: _semantic('input:fact_mortgage_statement_year'),
        matching: find.byType(TextField),
      ),
      '2025',
    );
    await tester.pump();
    final continueButton = find.descendant(
      of: _semantic('action:fact_mortgage_interest_paid.continue'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.enterText(
      find.descendant(
        of: _semantic('input:fact_mortgage_interest_paid'),
        matching: find.byType(TextField),
      ),
      "4'250.50",
    );
    await tester.pump();
    final yearInput = find.descendant(
      of: _semantic('input:fact_mortgage_statement_year'),
      matching: find.byType(TextField),
    );
    await tester.enterText(yearInput, '1999');
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
    await tester.enterText(yearInput, '2025');
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: _semantic('input:fact_mortgage_interest_paid'),
        matching: find.byType(TextField),
      ),
      "4'250.50",
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
    await tester.tap(_semantic('action:fact_mortgage_interest_paid.continue'));
    await tester.pump();

    expect(_semantic('node:mortgage_interest_paid_boundary'), findsOneWidget);
    expect(find.textContaining("CHF 4’250.50"), findsOneWidget);
    expect(
      find.textContaining('aucune économie fiscale n’est encore calculée'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_semantic('node:fact_mortgage_interest_paid'), findsOneWidget);
    expect(find.text("4'250.50"), findsOneWidget);

    final input = find.descendant(
      of: _semantic('input:fact_mortgage_interest_paid'),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, '4’250,50');
    await tester.pump();
    await tester.tap(_semantic('action:fact_mortgage_interest_paid.continue'));
    await tester.pump();
    expect(find.textContaining("CHF 4’250.50"), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.enterText(input, '4250.507');
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
  });

  testWidgets('interest is followed by debt balance and a two-fact review',
      (tester) async {
    await tester.pumpWidget(const _TestApp());
    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_logement.continue'));
    await tester.pump();
    await tester.tap(_semantic('action:housing_owner_boundary.continue'));
    await tester.pump();
    await tester.tap(_semantic('choice:fact_housing_mortgage.yes'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_housing_mortgage.continue'));
    await tester.pump();
    await tester
        .tap(_semantic('action:housing_mortgage_yes_boundary.continue'));
    await tester.pump();
    await tester.tap(_semantic('choice:fact_mortgage_statement.ready'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_mortgage_statement.continue'));
    await tester.pump();
    await tester
        .tap(_semantic('action:mortgage_statement_ready_boundary.continue'));
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: _semantic('input:fact_mortgage_statement_year'),
        matching: find.byType(TextField),
      ),
      '2025',
    );
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: _semantic('input:fact_mortgage_interest_paid'),
        matching: find.byType(TextField),
      ),
      "4'250.50",
    );
    await tester.pump();
    await tester.tap(_semantic('action:fact_mortgage_interest_paid.continue'));
    await tester.pump();
    await tester
        .tap(_semantic('action:mortgage_interest_paid_boundary.continue'));
    await tester.pump();

    expect(_semantic('node:fact_mortgage_debt_balance'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: _semantic('input:fact_mortgage_debt_balance'),
        matching: find.byType(TextField),
      ),
      "620'000",
    );
    await tester.pump();
    await tester.tap(_semantic('action:fact_mortgage_debt_balance.continue'));
    await tester.pump();

    expect(_semantic('node:mortgage_statement_review'), findsOneWidget);
    expect(find.textContaining('attestation 2025'), findsOneWidget);
    expect(find.textContaining("CHF 4’250.50"), findsOneWidget);
    expect(find.textContaining("CHF 620’000"), findsOneWidget);
    expect(
      find.textContaining('ni une déduction fiscale confirmée ni un résultat'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_semantic('node:fact_mortgage_debt_balance'), findsOneWidget);
    expect(find.text("620'000"), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_semantic('node:fact_mortgage_interest_paid'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: _semantic('input:fact_mortgage_statement_year'),
        matching: find.byType(TextField),
      ),
      '2024',
    );
    await tester.pump();
    expect(
      find.descendant(
        of: _semantic('input:fact_mortgage_interest_paid'),
        matching: find.text("4'250.50"),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: _semantic('action:fact_mortgage_interest_paid.continue'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('pause discards the answer and exits', (tester) async {
    var exited = false;
    await tester.pumpWidget(_TestApp(onExit: () => exited = true));

    await tester.tap(_semantic('choice:fact_logement.tenant'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_logement.safe_exit'));
    await tester.pump();

    expect(_semantic('action:fact_logement.resume'), findsOneWidget);
    expect(exited, isFalse);
    await tester.tap(_semantic('action:fact_logement.leave_without_saving'));
    await tester.pumpAndSettle();

    expect(exited, isTrue);
  });

  testWidgets('remote kill switch closes and discards an open answer',
      (tester) async {
    var exited = false;
    await tester.pumpWidget(_TestApp(onExit: () => exited = true));
    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();

    FeatureFlags.enableMintNextHousing = false;
    await tester.pump();

    expect(exited, isTrue);
    expect(_semantic('node:housing_owner_boundary'), findsNothing);
  });

  testWidgets('system back from a boundary returns to the question',
      (tester) async {
    await tester.pumpWidget(const _TestApp());
    await tester.tap(_semantic('choice:fact_logement.tenant'));
    await tester.pump();
    await tester.tap(_semantic('action:fact_logement.continue'));
    await tester.pump();
    expect(_semantic('node:housing_tenant_boundary'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(_semantic('node:fact_logement'), findsOneWidget);
    expect(
      _semantic('choice:fact_logement.tenant'),
      findsOneWidget,
    );
  });

  testWidgets('explicit save survives reload and can be deleted',
      (tester) async {
    final provider = CoachProfileProvider();
    await tester.pumpWidget(_TestApp(provider: provider));
    await _reachStatementReview(tester);

    await tester.tap(_semantic('action:mortgage_statement_review.save'));
    await tester.pumpAndSettle();

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact?.statementYear, 2025);
    expect(reloaded.housingFact?.annualInterestCents, 425050);
    expect(reloaded.housingFact?.debtBalanceCents, 62000000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_TestApp(provider: reloaded));
    await tester.pumpAndSettle();
    expect(_semantic('node:housing_saved_summary'), findsOneWidget);
    expect(find.textContaining('2025'), findsWidgets);

    await tester.tap(_semantic('action:housing_saved.delete'));
    await tester.pumpAndSettle();
    await tester.tap(_semantic('action:housing_saved.delete_confirm'));
    await tester.pumpAndSettle();

    expect(reloaded.housingFact, isNull);
    expect(_semantic('node:fact_logement'), findsOneWidget);
  });

  testWidgets('late cold-start hydration restores the saved housing summary',
      (tester) async {
    final provider = CoachProfileProvider();
    await tester.pumpWidget(_TestApp(provider: provider));
    expect(_semantic('node:fact_logement'), findsOneWidget);

    expect(
      await SecureWizardStore.writeCanonicalHousing(_tenantFact()),
      isTrue,
    );
    await provider.loadFromWizard();
    await tester.pump();

    expect(_semantic('node:housing_saved_summary'), findsOneWidget);
  });

  testWidgets('late hydration never overwrites an answer already in progress',
      (tester) async {
    final provider = CoachProfileProvider();
    await tester.pumpWidget(_TestApp(provider: provider));
    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();

    expect(
      await SecureWizardStore.writeCanonicalHousing(_tenantFact()),
      isTrue,
    );
    await provider.loadFromWizard();
    await tester.pump();

    expect(_semantic('node:housing_saved_summary'), findsNothing);
    expect(
      tester
          .widget<Semantics>(
            _semantic('choice:fact_logement.owner_occupier'),
          )
          .properties
          .selected,
      isTrue,
    );
  });

  testWidgets('one-shot restore never overwrites a correction in progress',
      (tester) async {
    final provider = CoachProfileProvider();
    await tester.pumpWidget(_TestApp(provider: provider));
    expect(
      await SecureWizardStore.writeCanonicalHousing(_tenantFact()),
      isTrue,
    );
    await provider.loadFromWizard();
    await tester.pump();
    expect(_semantic('node:housing_saved_summary'), findsOneWidget);

    await tester.tap(_semantic('action:housing_saved.edit'));
    await tester.pump();
    await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
    await tester.pump();

    await provider.loadFromWizard();
    await tester.pump();

    expect(_semantic('node:housing_saved_summary'), findsNothing);
    expect(
      tester
          .widget<Semantics>(
            _semantic('choice:fact_logement.owner_occupier'),
          )
          .properties
          .selected,
      isTrue,
    );
  });

  testWidgets('detaches its profile listener when disposed', (tester) async {
    final provider = _TrackingCoachProfileProvider();
    await tester.pumpWidget(_TestApp(provider: provider));
    expect(provider.listenerBalance, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(provider.listenerBalance, 0);

    await provider.loadFromWizard();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

MintNextHousingFact _tenantFact() => MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 9),
      source: MintNextHousingFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    );

Future<void> _reachStatementReview(WidgetTester tester) async {
  await tester.tap(_semantic('choice:fact_logement.owner_occupier'));
  await tester.pump();
  await tester.tap(_semantic('action:fact_logement.continue'));
  await tester.pump();
  await tester.tap(_semantic('action:housing_owner_boundary.continue'));
  await tester.pump();
  await tester.tap(_semantic('choice:fact_housing_mortgage.yes'));
  await tester.pump();
  await tester.tap(_semantic('action:fact_housing_mortgage.continue'));
  await tester.pump();
  await tester.tap(_semantic('action:housing_mortgage_yes_boundary.continue'));
  await tester.pump();
  await tester.tap(_semantic('choice:fact_mortgage_statement.ready'));
  await tester.pump();
  await tester.tap(_semantic('action:fact_mortgage_statement.continue'));
  await tester.pump();
  await tester.tap(_semantic('action:mortgage_statement_ready_boundary.continue'));
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: _semantic('input:fact_mortgage_statement_year'),
      matching: find.byType(TextField),
    ),
    '2025',
  );
  await tester.enterText(
    find.descendant(
      of: _semantic('input:fact_mortgage_interest_paid'),
      matching: find.byType(TextField),
    ),
    "4'250.50",
  );
  await tester.pump();
  await tester.tap(_semantic('action:fact_mortgage_interest_paid.continue'));
  await tester.pump();
  await tester.tap(_semantic('action:mortgage_interest_paid_boundary.continue'));
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: _semantic('input:fact_mortgage_debt_balance'),
      matching: find.byType(TextField),
    ),
    "620'000",
  );
  await tester.pump();
  await tester.tap(_semantic('action:fact_mortgage_debt_balance.continue'));
  await tester.pump();
}

Finder _semantic(String id) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.identifier == id,
    );

class _TestApp extends StatelessWidget {
  const _TestApp({this.onExit, this.provider});
  final VoidCallback? onExit;
  final CoachProfileProvider? provider;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: provider ?? CoachProfileProvider(),
        child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
          home: MintNextHousingScreen(onExit: onExit),
        ),
      );
}

class _TrackingCoachProfileProvider extends CoachProfileProvider {
  int listenerBalance = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerBalance++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerBalance--;
    super.removeListener(listener);
  }
}
