import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/onboarding/onboarding_widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('MintSelectableCard renders and reacts to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MintSelectableCard(
            icon: Icons.check,
            label: 'Test card',
            isSelected: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Test card'), findsOneWidget);
    await tester.tap(find.text('Test card'));
    expect(tapped, isTrue);
  });

  testWidgets('MintQuickPickChips selects option', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MintQuickPickChips<int>(
            options: const [1, 2, 3],
            selected: selected,
            labelBuilder: (v) => '$v',
            onSelected: (v) => selected = v,
          ),
        ),
      ),
    );

    await tester.tap(find.text('2'));
    expect(selected, 2);
  });

  testWidgets('MintChfInputField accepts input', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MintChfInputField(
            controller: controller,
            label: 'Montant',
            hint: '100',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1234');
    expect(controller.text, '1234');
  });
}
