import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/aujourdhui/mint_next_housing_card.dart';

void main() {
  tearDown(() => FeatureFlags.enableMintNextHousing = false);

  testWidgets('housing entry is absent until its independent flag opens',
      (tester) async {
    await tester.pumpWidget(const _TestApp());
    expect(_entry, findsNothing);

    FeatureFlags.enableMintNextHousing = true;
    await tester.pump();
    expect(_entry, findsOneWidget);

    FeatureFlags.enableMintNextHousing = false;
    await tester.pump();
    expect(_entry, findsNothing);
  });
}

Finder get _entry => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'action:today.open_mint_next_housing',
    );

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: MintNextHousingCard()),
      );
}
